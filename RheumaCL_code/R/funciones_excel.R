# =============================================================================
# R/funciones_excel.R
# Escritura del Excel de resultados: una hoja por enfermedad y una hoja de
# resumen. Todo se arma desde los checkpoints, sin reentrenar.
# =============================================================================

# -----------------------------------------------------------------------------
# Busca un parámetro en la tabla de configuración de un checkpoint. Acepta
# varios nombres porque los checkpoints del script original rotulan como
# "bootstrap" lo que aquí se llama validación cruzada repetida.
# -----------------------------------------------------------------------------
valor_config <- function(config, nombres) {
  valor <- config$Valor[match(nombres, config$Parametro)]
  valor <- valor[!is.na(valor)]
  if (length(valor) == 0) NA_character_ else valor[1]
}

# -----------------------------------------------------------------------------
# Escribe una sección (título resaltado y tabla) en una hoja. Devuelve la
# siguiente fila disponible.
# -----------------------------------------------------------------------------
escribir_seccion <- function(wb, sheet, titulo, datos, fila_inicio) {
  estilo_titulo <- createStyle(textDecoration = "bold", fontSize = 11,
                               fgFill = "#D9E1F2", halign = "left")
  estilo_header <- createStyle(textDecoration = "bold")

  writeData(wb, sheet, titulo, startRow = fila_inicio, startCol = 1)
  addStyle(wb, sheet, style = estilo_titulo,
           rows = fila_inicio, cols = 1:max(ncol(datos), 1),
           gridExpand = TRUE)
  writeData(wb, sheet, datos,
            startRow    = fila_inicio + 1,
            startCol    = 1,
            headerStyle = estilo_header,
            borders     = "surrounding")

  fila_inicio + 1 + nrow(datos) + 1 + 2
}

# -----------------------------------------------------------------------------
# Escribe la hoja de una enfermedad con sus ocho secciones (nueve si ganó RL).
# -----------------------------------------------------------------------------
escribir_hoja_enfermedad <- function(wb, nombre_hoja, resultado) {
  n_iter <- valor_config(resultado$config, c("N repeticiones de la CV",
                                             "N iteraciones bootstrap"))
  k_fold <- valor_config(resultado$config, c("N folds (CV repetida y grid search)",
                                             "N folds bootstrap / CV grid search"))

  addWorksheet(wb, nombre_hoja)
  fila <- 1

  fila <- escribir_seccion(wb, nombre_hoja,
                           "1. CONFIGURACIÓN DEL EXPERIMENTO",
                           resultado$config, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           "2. VARIABLES SIGNIFICATIVAS (chi-cuadrado)",
                           resultado$resultados_sig, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           "3. GRID SEARCH RF: AUC-ROC por combinación (mtry x ntree)",
                           resultado$grid_results_rf, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           "4. GRID SEARCH XGB: AUC-ROC por combinación (eta x max_depth x nrounds)",
                           resultado$grid_results_xgb, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           "5. CV REPETIDA: MEDIAS DE RL, RF Y XGB, HIPERVOLUMEN Y GANADOR",
                           resultado$tabla_comparacion, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           paste0("6. ESTABILIDAD EN LA CV REPETIDA: media, SD y percentiles 2,5 y 97,5 (",
                                  n_iter, " repeticiones x ", k_fold, " folds)"),
                           resultado$resumen_boot, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           paste0("7. RANKING DE VARIABLES DEL MODELO GANADOR (",
                                  resultado$ganador, ")"),
                           resultado$ranking_ganador, fila)

  fila <- escribir_seccion(wb, nombre_hoja,
                           paste0("8. VALORES SHAP DEL MODELO GANADOR (",
                                  resultado$ganador, "): VARIABLES MÁS IMPORTANTES"),
                           resultado$shap_tabla, fila)

  # Los odds ratios solo se informan cuando RL es el modelo ganador
  if (resultado$ganador == "RL" && !is.null(resultado$tabla_or_rl)) {
    escribir_seccion(wb, nombre_hoja,
                     "9. ODDS RATIOS DEL MODELO RL (solo cuando RL es el ganador)",
                     resultado$tabla_or_rl, fila)
  }

  setColWidths(wb, nombre_hoja, cols = 1:10, widths = "auto")
  invisible(wb)
}

# -----------------------------------------------------------------------------
# Fila de una enfermedad en la tabla resumen: tamaño de muestra, prevalencia,
# modelo ganador con sus métricas medias, hipervolumen, AUC-ROC de la CV
# repetida, variable de mayor importancia SHAP y tiempo de ejecución.
# -----------------------------------------------------------------------------
fila_resumen <- function(nombre_hoja, resultado) {
  ganador  <- resultado$ganador
  metricas <- resultado$tabla_comparacion[resultado$tabla_comparacion$Modelo == ganador, ]
  auc_cv   <- resultado$resumen_boot[
    resultado$resumen_boot$Modelo == ganador &
      resultado$resumen_boot$Metrica == "AUC-ROC", ]
  top_shap <- if (nrow(resultado$shap_tabla) > 0) resultado$shap_tabla$Variable[1] else NA_character_

  data.frame(
    Enfermedad        = nombre_hoja,
    N_Total           = as.integer(valor_config(resultado$config, "N total (tras limpieza)")),
    Prevalencia_SI    = as.numeric(valor_config(resultado$config, "Prevalencia clase SI")),
    N_Vars_Chi2       = as.integer(valor_config(resultado$config,
                                                "N variables chi-cuadrado (p < 0.05)")),
    Modelo_Ganador    = ganador,
    Precision         = metricas$Precision,
    Recall            = metricas$Recall,
    F1                = metricas$F1,
    Accuracy          = metricas$Accuracy,
    AUC_ROC           = metricas$AUC_ROC,
    Hipervolumen      = metricas$Hipervolumen,
    AUC_CV_Media      = if (nrow(auc_cv) > 0) auc_cv$Media else NA_real_,
    AUC_CV_SD         = if (nrow(auc_cv) > 0) auc_cv$SD    else NA_real_,
    Top_Variable_SHAP = top_shap,
    Tiempo_Ejecucion  = formatear_tiempo(resultado$tiempo_segundos),
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------------------------
# Escribe la hoja Resumen: una fila por enfermedad, coloreada según el modelo
# ganador (verde XGB, azul RF, naranja RL).
# -----------------------------------------------------------------------------
escribir_hoja_resumen <- function(wb, tabla_resumen) {
  borde <- list(border = "TopBottomLeftRight", borderColour = "#BFBFBF", halign = "center")
  estilo_titulo <- createStyle(textDecoration = "bold", fontSize = 13,
                               fgFill = "#1F3864", fontColour = "#FFFFFF", halign = "center")
  estilo_header <- createStyle(textDecoration = "bold", fgFill = "#2E75B6",
                               fontColour = "#FFFFFF", halign = "center",
                               border = "TopBottomLeftRight", borderColour = "#FFFFFF")
  estilo_celda  <- do.call(createStyle, borde)
  estilo_modelo <- list(
    XGB = do.call(createStyle, c(list(fgFill = "#C6EFCE"), borde)),
    RF  = do.call(createStyle, c(list(fgFill = "#DDEBF7"), borde)),
    RL  = do.call(createStyle, c(list(fgFill = "#FCE4D6"), borde))
  )

  n_cols <- ncol(tabla_resumen)

  # Título principal
  writeData(wb, "Resumen",
            "RESUMEN DEL ANÁLISIS UNIFICADO DE 12 ENFERMEDADES REUMÁTICAS",
            startRow = 1, startCol = 1)
  mergeCells(wb, "Resumen", cols = 1:n_cols, rows = 1)
  addStyle(wb, "Resumen", style = estilo_titulo,
           rows = 1, cols = 1:n_cols, gridExpand = TRUE)

  # Leyenda de colores
  writeData(wb, "Resumen",
            "Color de la fila: verde = gana XGB | azul = gana RF | naranja = gana RL",
            startRow = 2, startCol = 1)
  addStyle(wb, "Resumen",
           style = createStyle(textDecoration = "italic", fontColour = "#595959", fontSize = 9),
           rows = 2, cols = 1:n_cols, gridExpand = TRUE)

  # Tabla: encabezado en la fila 3 y datos desde la fila 4
  writeData(wb, "Resumen", tabla_resumen, startRow = 3, startCol = 1,
            headerStyle = estilo_header, borders = "all")
  addStyle(wb, "Resumen", style = estilo_celda,
           rows = 4:(3 + nrow(tabla_resumen)), cols = 1:n_cols, gridExpand = TRUE)

  # Color de cada fila según su modelo ganador
  for (r in seq_len(nrow(tabla_resumen))) {
    estilo <- estilo_modelo[[tabla_resumen$Modelo_Ganador[r]]]
    if (is.null(estilo)) estilo <- estilo_celda
    addStyle(wb, "Resumen", style = estilo,
             rows = r + 3, cols = 1:n_cols, gridExpand = TRUE)
  }

  setColWidths(wb, "Resumen", cols = 1:n_cols, widths = "auto")
  invisible(wb)
}
