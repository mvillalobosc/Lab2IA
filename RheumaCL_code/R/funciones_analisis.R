# =============================================================================
# R/funciones_analisis.R
# Flujo completo de una enfermedad, de la selección de variables a SHAP.
#
# Objetivo descriptivo (caracterización): se usa la muestra completa.
#   1. chi-cuadrado sobre la muestra completa y las 20 variables de menor p
#   2. one-hot encoding
#   3. RL: validación cruzada repetida y modelo final
#   4. RF: grid search, validación cruzada repetida y modelo final
#   5. XGB: grid search, validación cruzada repetida y modelo final
#   6. hipervolumen de cada modelo y elección del ganador
#   7. valores SHAP del ganador sobre todas las filas originales
# El balanceo siempre se hace dentro de cada fold de entrenamiento, así que
# cada modelo se evalúa con observaciones que no usó para ajustarse.
#
# Cada etapa fija su propia semilla (ver config.R), de modo que el resultado
# de una enfermedad no depende de cuáles se corrieron antes.
# =============================================================================

# -----------------------------------------------------------------------------
# Flujo completo de una enfermedad. Devuelve la lista que se guarda como
# checkpoint, o NULL si ninguna variable resulta significativa.
# -----------------------------------------------------------------------------
analizar_enfermedad <- function(enfermedad, data_filtrado) {
  aviso <- function(...) cat("  [", enfermedad, "] ", ..., "\n", sep = "")

  # --- 1. Selección de características (chi-cuadrado) -------------------------
  aviso("Chi-cuadrado...")
  resultados_sig <- chi_cuadrado(data_filtrado, enfermedad)

  if (nrow(resultados_sig) == 0) {
    aviso("Sin variables significativas (p < ", CFG$alfa_chi2, "): enfermedad omitida")
    return(NULL)
  }

  seleccion       <- datos_de_modelamiento(data_filtrado, enfermedad, resultados_sig$Variable)
  data_enfermedad <- seleccion$datos
  if (seleccion$n_excluidos > 0) {
    aviso("  -> ", seleccion$n_excluidos, " filas fuera por datos faltantes en las ",
          "variables seleccionadas; quedan ", nrow(data_enfermedad))
  }

  # --- 2. One-hot encoding ---------------------------------------------------
  aviso("One-hot encoding...")
  codificado <- codificar_one_hot(data_enfermedad, enfermedad)
  data_ohe   <- codificado$ohe   # RF y XGB (enfermedad con niveles SI, NO)
  data_rl    <- codificado$rl    # RL (enfermedad con niveles NO, SI)
  aviso("  -> ", ncol(data_ohe) - 1, " predictoras (columnas .NO eliminadas)")

  # --- 3. Regresión logística ------------------------------------------------
  aviso("RL: CV repetida (", CFG$n_iter, " x ", CFG$k_fold, " folds)...")
  cv_rl <- cv_repetida(data_rl, enfermedad, aprendiz_rl(enfermedad))

  aviso("RL: modelo final...")
  final_rl <- ajustar_rl_final(data_rl, enfermedad, cv_rl$ranking)

  # --- 4. Random Forest ------------------------------------------------------
  aviso("RF: grid search...")
  grid_results_rf <- buscar_hiperparametros_rf(data_ohe, enfermedad)
  mtry_opt  <- grid_results_rf$mtry[1]
  ntree_opt <- grid_results_rf$ntree[1]
  aviso("  -> RF óptimo: mtry = ", mtry_opt, " | ntree = ", ntree_opt)

  aviso("RF: CV repetida (", CFG$n_iter, " x ", CFG$k_fold, " folds)...")
  cv_rf <- cv_repetida(data_ohe, enfermedad, aprendiz_rf(enfermedad, mtry_opt, ntree_opt))

  aviso("RF: modelo final...")
  final_rf <- ajustar_rf_final(data_ohe, enfermedad, mtry_opt, ntree_opt, cv_rf$ranking)

  # --- 5. XGBoost ------------------------------------------------------------
  aviso("XGB: grid search...")
  grid_results_xgb <- buscar_hiperparametros_xgb(data_ohe, enfermedad,
                                                 codificado$X, codificado$y)
  best_xgb <- grid_results_xgb[1, ]
  aviso("  -> XGB óptimo: eta = ", best_xgb$eta, " | max_depth = ", best_xgb$max_depth,
        " | nrounds = ", best_xgb$nrounds)

  aviso("XGB: CV repetida (", CFG$n_iter, " x ", CFG$k_fold, " folds)...")
  cv_xgb <- cv_repetida(data_ohe, enfermedad,
                        aprendiz_xgb(enfermedad, best_xgb$eta, best_xgb$max_depth,
                                     best_xgb$nrounds))

  aviso("XGB: modelo final...")
  final_xgb <- ajustar_xgb_final(data_ohe, enfermedad, best_xgb$eta, best_xgb$max_depth,
                                 best_xgb$nrounds, cv_xgb$ranking)

  # --- 6. Hipervolumen y modelo ganador --------------------------------------
  comparacion <- comparar_modelos(list(RL = cv_rl, RF = cv_rf, XGB = cv_xgb))
  ganador     <- comparacion$ganador
  aviso("  -> GANADOR: ", ganador, " (hipervolumen = ",
        round(comparacion$hipervolumen_ganador, 6), ")")

  # --- 7. SHAP, solo del modelo ganador --------------------------------------
  aviso("SHAP (", ganador, ", nsim = ", CFG$shap_nsim, ", n = ", nrow(data_ohe), ")...")
  shap <- switch(
    ganador,
    RL  = explicar_ganador("RL",  final_rl$modelo,  data_rl,  enfermedad),
    RF  = explicar_ganador("RF",  final_rf$modelo,  data_ohe, enfermedad),
    XGB = explicar_ganador("XGB", final_xgb$modelo, data_ohe, enfermedad)
  )

  # Ranking de variables del ganador: odds ratios (RL), MeanDecreaseAccuracy y
  # MeanDecreaseGini (RF) o Gain, Cover y Frequency (XGB), siempre con la
  # frecuencia de selección de la CV repetida. Si el modelo RL final no se
  # pudo ajustar, queda solo esa frecuencia.
  ranking_ganador <- switch(
    ganador,
    RL  = if (!is.null(final_rl$tabla_or)) final_rl$tabla_or else cv_rl$ranking,
    RF  = final_rf$importancia,
    XGB = final_xgb$importancia
  )

  # --- Configuración del experimento (primera sección de la hoja de Excel) ---
  # Los tres parámetros que lee R/03_tablas.R conservan el nombre que tenían en
  # el script original, para que sus checkpoints sigan sirviendo.
  config <- data.frame(
    Parametro = c(
      "Variable objetivo", "Fecha de ejecución",
      "Datos de modelamiento", "N total (tras limpieza)",
      "N casos (clase SI)",
      "Prevalencia clase SI", "N variables chi-cuadrado (p < 0.05)",
      "N variables usadas (máx. 20)",
      "N repeticiones de la CV", "N folds (CV repetida y grid search)",
      "RF: mtry óptimo", "RF: ntree óptimo",
      "XGB: eta óptimo", "XGB: max_depth óptimo", "XGB: nrounds óptimo",
      "Modelo ganador", "Hipervolumen ganador (CV repetida)",
      "N filas SHAP (originales)",
      "Semilla modelos finales (set.seed)", "Semilla SHAP (set.seed)",
      "N filas de la base",
      "N filas excluidas por datos faltantes en las variables seleccionadas",
      "Semilla grid search (set.seed)", "SHAP: repeticiones Monte Carlo (nsim)",
      "Versión de R", "Versión de randomForest", "Versión de xgboost"
    ),
    Valor = as.character(c(
      enfermedad,
      format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      paste0("Muestra completa (CV repetida ", CFG$n_iter, " x ", CFG$k_fold, " folds)"),
      nrow(data_enfermedad),
      sum(data_enfermedad[[enfermedad]] == "SI"),
      round(mean(data_enfermedad[[enfermedad]] == "SI"), 3),
      nrow(resultados_sig),
      ncol(data_enfermedad) - 1,
      CFG$n_iter, CFG$k_fold,
      mtry_opt, ntree_opt,
      best_xgb$eta, best_xgb$max_depth, best_xgb$nrounds,
      ganador, round(comparacion$hipervolumen_ganador, 6),
      nrow(shap$X_shap),
      CFG$semilla_final, CFG$semilla_shap,
      nrow(data_filtrado),
      seleccion$n_excluidos,
      CFG$semilla_grid, CFG$shap_nsim,
      as.character(getRversion()),
      as.character(packageVersion("randomForest")),
      as.character(packageVersion("xgboost"))
    )),
    stringsAsFactors = FALSE
  )

  # Los nombres de esta lista son los del script original.
  list(
    config            = config,
    resultados_sig    = resultados_sig %>%
                          rename(P_valor = P_value) %>%
                          mutate(P_valor = round(P_valor, 6)),
    grid_results_rf   = grid_results_rf,
    grid_results_xgb  = grid_results_xgb,
    tabla_comparacion = comparacion$tabla,
    resumen_boot      = bind_rows(
      resumen_cv_repetida("RL",  cv_rl$prec,  cv_rl$rec,  cv_rl$f1,  cv_rl$acc,  cv_rl$auc),
      resumen_cv_repetida("RF",  cv_rf$prec,  cv_rf$rec,  cv_rf$f1,  cv_rf$acc,  cv_rf$auc),
      resumen_cv_repetida("XGB", cv_xgb$prec, cv_xgb$rec, cv_xgb$f1, cv_xgb$acc, cv_xgb$auc)
    ),
    ranking_ganador   = ranking_ganador,
    shap_tabla        = shap$tabla,
    tabla_or_rl       = final_rl$tabla_or,   # NULL solo si el modelo RL final no se pudo ajustar
    ganador           = ganador,
    # El modelo ganador y los datos de SHAP se guardan para poder recalcular o
    # graficar SHAP sin reentrenar.
    modelo_ganador    = switch(ganador, RL = final_rl$modelo,
                               RF = final_rf$modelo, XGB = final_xgb$modelo),
    X_shap            = shap$X_shap,
    shap_valores      = shap$valores
  )
}
