# =============================================================================
# R/funciones_modelos.R
# Balanceo, búsqueda de hiperparámetros, validación cruzada repetida y modelos
# finales de regresión logística (RL), Random Forest (RF) y XGBoost (XGB).
#
# El orden de las llamadas que consumen números aleatorios (createFolds,
# sample, randomForest) es el del script original. Cambiarlo cambia los
# resultados aunque las semillas sean las mismas.
# =============================================================================

# Funciones que los workers del cluster necesitan para el grid search.
# R/02_ajustar_modelos.R las exporta con clusterExport().
FUNCIONES_PARA_WORKERS <- c("balancear", "entrenar_xgb",
                            "evaluar_combinacion_rf", "evaluar_combinacion_xgb")

# -----------------------------------------------------------------------------
# Balanceo por sobremuestreo aleatorio.
# Toma, con reemplazo, tantas filas de la clase SI como filas tiene la clase NO
# y las une a la clase NO completa. Supone que SI es la clase minoritaria, lo
# que se cumple en las 12 enfermedades (prevalencia máxima: 41 %). Devuelve
# NULL si falta alguna de las dos clases.
# Solo se aplica a datos de entrenamiento: los folds de validación y las filas
# que explica SHAP conservan la proporción original.
# -----------------------------------------------------------------------------
balancear <- function(datos, enfermedad) {
  minoritaria <- datos[datos[[enfermedad]] == "SI", ]
  mayoritaria <- datos[datos[[enfermedad]] == "NO", ]
  if (nrow(minoritaria) == 0 || nrow(mayoritaria) == 0) return(NULL)
  rbind(mayoritaria,
        minoritaria[sample(nrow(minoritaria), nrow(mayoritaria), replace = TRUE), ])
}

# -----------------------------------------------------------------------------
# Muestra completa balanceada con la que se ajusta cada modelo final. Fija la
# semilla CFG$semilla_final antes de sobremuestrear, así que los tres modelos
# finales parten de la misma muestra. Si falta una clase, devuelve los datos
# sin balancear.
# -----------------------------------------------------------------------------
muestra_final <- function(datos, enfermedad) {
  set.seed(CFG$semilla_final)
  balanceada <- balancear(datos, enfermedad)
  if (is.null(balanceada)) datos else balanceada
}

# -----------------------------------------------------------------------------
# Ajusta un XGBoost binario. Usa xgb.train() y no xgboost(): en la serie 1.7
# ambas dan el mismo modelo, y xgb.train() conserva esta forma de llamada en
# la serie 3.x, donde xgboost() cambió de interfaz. nthread = NULL deja el
# número de hilos por defecto del paquete.
# -----------------------------------------------------------------------------
entrenar_xgb <- function(dtrain, eta, max_depth, nrounds, nthread = NULL) {
  params <- list(objective = "binary:logistic", eta = eta, max_depth = max_depth)
  if (!is.null(nthread)) params$nthread <- nthread
  xgboost::xgb.train(params = params, data = dtrain, nrounds = nrounds, verbose = 0)
}


# =============================================================================
# BÚSQUEDA DE HIPERPARÁMETROS (grid search con validación cruzada)
# =============================================================================

# -----------------------------------------------------------------------------
# Evalúa una combinación (mtry, ntree) de RF con validación cruzada y devuelve
# su AUC-ROC promedio. El balanceo se hace solo en el fold de entrenamiento.
# Corre en los workers.
# -----------------------------------------------------------------------------
evaluar_combinacion_rf <- function(idx, grid, folds, data_modelo, enfermedad) {
  comb <- grid[idx, ]
  aucs <- numeric(length(folds))

  for (f in seq_along(folds)) {
    tr  <- data_modelo[-folds[[f]], ]
    val <- data_modelo[ folds[[f]], ]

    if (length(unique(val[[enfermedad]])) < 2) { aucs[f] <- NA; next }

    tr_bal <- balancear(tr, enfermedad)
    if (!is.null(tr_bal)) tr <- tr_bal

    mod <- randomForest::randomForest(
      as.formula(paste(enfermedad, "~ .")),
      data = tr, mtry = comb$mtry, ntree = comb$ntree
    )
    prob    <- predict(mod, val, type = "prob")[, "SI"]
    aucs[f] <- suppressMessages(
      as.numeric(pROC::auc(pROC::roc(ifelse(val[[enfermedad]] == "SI", 1, 0), prob,
                                     levels = c(0, 1), direction = "<")))
    )
  }
  data.frame(mtry = comb$mtry, ntree = comb$ntree,
             AUC_ROC_CV = round(mean(aucs, na.rm = TRUE), 4))
}

# -----------------------------------------------------------------------------
# Evalúa una combinación (eta, max_depth, nrounds) de XGB con validación
# cruzada y devuelve su AUC-ROC promedio. El balanceo se hace solo en el fold
# de entrenamiento. Corre en los workers, con un hilo por modelo.
# -----------------------------------------------------------------------------
evaluar_combinacion_xgb <- function(idx, grid, folds, X_mod, y_mod) {
  params <- grid[idx, ]
  aucs   <- c()

  for (f in seq_along(folds)) {
    tr_idx  <- setdiff(seq_len(nrow(X_mod)), folds[[f]])
    val_idx <- folds[[f]]
    if (length(unique(y_mod[val_idx])) < 2) next

    idx_min <- tr_idx[y_mod[tr_idx] == 1]
    idx_may <- tr_idx[y_mod[tr_idx] == 0]
    if (length(idx_min) > 0 && length(idx_may) > 0)
      tr_idx <- c(idx_may, idx_min[sample.int(length(idx_min), length(idx_may),
                                              replace = TRUE)])

    dtrain <- xgboost::xgb.DMatrix(data = X_mod[tr_idx,  ], label = y_mod[tr_idx])
    dval   <- xgboost::xgb.DMatrix(data = X_mod[val_idx, ], label = y_mod[val_idx])

    mod  <- entrenar_xgb(dtrain, params$eta, params$max_depth, params$nrounds, nthread = 1)
    prob <- predict(mod, dval)
    aucs <- c(aucs,
              suppressMessages(as.numeric(pROC::auc(pROC::roc(y_mod[val_idx], prob,
                                                              levels = c(0, 1),
                                                              direction = "<")))))
  }
  data.frame(eta = params$eta, max_depth = params$max_depth,
             nrounds = params$nrounds,
             AUC_ROC_CV = if (length(aucs) > 0) round(mean(aucs), 4) else NA)
}

# -----------------------------------------------------------------------------
# Grid search de RF. Devuelve todas las combinaciones ordenadas de mayor a
# menor AUC-ROC; la primera fila (Optimo = "SI") es la que se usa después.
# %dorng% asigna un flujo aleatorio propio a cada combinación, así que el
# resultado no depende del número de núcleos.
# -----------------------------------------------------------------------------
buscar_hiperparametros_rf <- function(data_ohe, enfermedad) {
  n_pred    <- ncol(data_ohe) - 1
  mtry_vals <- floor(seq(1, min(CFG$rf_mtry_max, n_pred), length.out = CFG$rf_mtry_n))
  grid_rf   <- expand.grid(mtry = mtry_vals, ntree = CFG$rf_ntree)

  set.seed(CFG$semilla_grid)
  folds_cv <- createFolds(data_ohe[[enfermedad]], k = CFG$k_fold_grid)

  resultados <- foreach(
    i         = seq_len(nrow(grid_rf)),
    .combine  = rbind,
    .packages = c("randomForest", "pROC", "caret")
  ) %dorng% {
    evaluar_combinacion_rf(i, grid_rf, folds_cv, data_ohe, enfermedad)
  }

  resultados        <- resultados[order(-resultados$AUC_ROC_CV), ]
  resultados$Optimo <- c("SI", rep("NO", nrow(resultados) - 1))
  resultados
}

# -----------------------------------------------------------------------------
# Grid search de XGB. Misma lógica que el de RF.
# -----------------------------------------------------------------------------
buscar_hiperparametros_xgb <- function(data_ohe, enfermedad, X_mod, y_mod) {
  grid_xgb <- expand.grid(
    eta       = CFG$xgb_eta,
    max_depth = CFG$xgb_max_depth,
    nrounds   = CFG$xgb_nrounds
  )

  set.seed(CFG$semilla_grid)
  folds_cv <- createFolds(data_ohe[[enfermedad]], k = CFG$k_fold_grid)

  resultados <- foreach(
    i         = seq_len(nrow(grid_xgb)),
    .combine  = rbind,
    .packages = c("xgboost", "pROC", "caret")
  ) %dorng% {
    evaluar_combinacion_xgb(i, grid_xgb, folds_cv, X_mod, y_mod)
  }

  resultados        <- resultados[order(-resultados$AUC_ROC_CV), ]
  resultados$Optimo <- c("SI", rep("NO", nrow(resultados) - 1))
  resultados
}


# =============================================================================
# APRENDICES
# Cada modelo se describe con tres funciones, de modo que la validación
# cruzada repetida sea un solo bucle para los tres:
#   ajustar(tr_bal)           ajusta el modelo en un fold balanceado (NULL si falla)
#   seleccionadas(modelo)     variables que el modelo "selecciona" en ese fold
#   predecir(modelo, val_f)   probabilidad de SI en el fold de validación
# =============================================================================

# -----------------------------------------------------------------------------
# RL: sin hiperparámetros. Una variable cuenta como seleccionada si su
# coeficiente tiene p < CFG$alfa_rl.
# -----------------------------------------------------------------------------
aprendiz_rl <- function(enfermedad) {
  formula_rl <- as.formula(paste(enfermedad, "~ ."))
  list(
    ajustar = function(tr_bal) {
      tryCatch(suppressWarnings(glm(formula_rl, data = tr_bal, family = "binomial")),
               error = function(e) NULL)
    },
    seleccionadas = function(modelo) {
      cs <- coef(summary(modelo))
      rownames(cs)[!is.na(cs[, 4]) & cs[, 4] < CFG$alfa_rl &
                     rownames(cs) != "(Intercept)"]
    },
    predecir = function(modelo, val_f) predict(modelo, val_f, type = "response")
  )
}

# -----------------------------------------------------------------------------
# RF: una variable cuenta como seleccionada si su MeanDecreaseAccuracy supera
# la media de las variables en ese fold.
# -----------------------------------------------------------------------------
aprendiz_rf <- function(enfermedad, mtry, ntree) {
  list(
    ajustar = function(tr_bal) {
      randomForest(as.formula(paste(enfermedad, "~ .")),
                   data = tr_bal, mtry = mtry, ntree = ntree, importance = TRUE)
    },
    seleccionadas = function(modelo) {
      imp <- randomForest::importance(modelo, type = 1)   # type = 1: MeanDecreaseAccuracy
      rownames(imp)[imp[, 1] > mean(imp[, 1])]
    },
    predecir = function(modelo, val_f) predict(modelo, val_f, type = "prob")[, "SI"]
  )
}

# -----------------------------------------------------------------------------
# XGB: una variable cuenta como seleccionada si su Gain es mayor que cero, es
# decir, si algún árbol la usó.
# -----------------------------------------------------------------------------
aprendiz_xgb <- function(enfermedad, eta, max_depth, nrounds) {
  matriz <- function(datos) as.matrix(datos %>% select(-all_of(enfermedad)))
  list(
    ajustar = function(tr_bal) {
      dtrain <- xgb.DMatrix(data = matriz(tr_bal),
                            label = ifelse(tr_bal[[enfermedad]] == "SI", 1, 0))
      entrenar_xgb(dtrain, eta, max_depth, nrounds)
    },
    seleccionadas = function(modelo) {
      imp <- xgb.importance(model = modelo)
      imp$Feature[imp$Gain > 0]
    },
    predecir = function(modelo, val_f) {
      dval <- xgb.DMatrix(data = matriz(val_f),
                          label = ifelse(val_f[[enfermedad]] == "SI", 1, 0))
      predict(modelo, dval)
    }
  )
}


# =============================================================================
# VALIDACIÓN CRUZADA REPETIDA
# =============================================================================

# -----------------------------------------------------------------------------
# CFG$n_iter repeticiones de una validación cruzada estratificada de
# CFG$k_fold folds. En cada fold: se balancea el entrenamiento, se ajusta el
# modelo, se anotan las variables que selecciona y se evalúa en el fold de
# validación, que nunca se balancea ni entra al entrenamiento.
#
# Devuelve:
#   prec, rec, f1, acc, auc   un valor por repetición (promedio de sus folds)
#   ranking                   Variable, Frecuencia (folds en que el modelo la
#                             seleccionó) y Proporcion (sobre n_iter * k_fold)
# -----------------------------------------------------------------------------
cv_repetida <- function(datos, enfermedad, aprendiz) {
  n_iter <- CFG$n_iter
  k_fold <- CFG$k_fold

  ranking <- data.frame(Variable = setdiff(colnames(datos), enfermedad),
                        Frecuencia = 0L, stringsAsFactors = FALSE)
  prec <- rec <- f1 <- acc <- auc <- numeric(n_iter)

  pb <- txtProgressBar(min = 0, max = n_iter, style = 3)
  for (i in seq_len(n_iter)) {
    set.seed(i)
    folds_i <- createFolds(datos[[enfermedad]], k = k_fold)

    prec_f <- rec_f <- f1_f <- acc_f <- auc_f <- rep(NA_real_, k_fold)

    for (f in seq_along(folds_i)) {
      tr_orig <- datos[-folds_i[[f]], ]
      val_f   <- datos[ folds_i[[f]], ]

      # Sobremuestreo de la clase minoritaria solo dentro del fold de entrenamiento
      tr_bal <- balancear(tr_orig, enfermedad)
      if (is.null(tr_bal)) next

      modelo <- aprendiz$ajustar(tr_bal)
      if (is.null(modelo)) next

      elegidas <- ranking$Variable %in% aprendiz$seleccionadas(modelo)
      ranking$Frecuencia[elegidas] <- ranking$Frecuencia[elegidas] + 1L

      if (length(unique(val_f[[enfermedad]])) > 1) {
        prob_v  <- aprendiz$predecir(modelo, val_f)
        class_v <- ifelse(prob_v > CFG$umbral_clase, "SI", "NO")
        m       <- calcular_metricas(val_f[[enfermedad]], class_v, prob_v)
        prec_f[f] <- m["Precision"]; rec_f[f] <- m["Recall"]
        f1_f[f]   <- m["F1"];        acc_f[f] <- m["Accuracy"]
        auc_f[f]  <- m["ROC_AUC"]
      }
    }

    # Promedio de los k folds de esta repetición
    prec[i] <- mean(prec_f, na.rm = TRUE)
    rec[i]  <- mean(rec_f,  na.rm = TRUE)
    f1[i]   <- mean(f1_f,   na.rm = TRUE)
    acc[i]  <- mean(acc_f,  na.rm = TRUE)
    auc[i]  <- mean(auc_f,  na.rm = TRUE)

    setTxtProgressBar(pb, i)
  }
  close(pb)

  ranking <- ranking %>%
    mutate(Proporcion = round(Frecuencia / (n_iter * k_fold), 4)) %>%
    arrange(desc(Proporcion))

  list(prec = prec, rec = rec, f1 = f1, acc = acc, auc = auc, ranking = ranking)
}


# =============================================================================
# MODELOS FINALES (muestra completa balanceada)
# =============================================================================

# -----------------------------------------------------------------------------
# RL final. Se ajusta el modelo con todas las variables y después se reduce a
# las que tienen p < CFG$alfa_rl; si ninguna lo cumple, queda el modelo
# completo. Devuelve el modelo y su tabla de odds ratios con IC 95 % de Wald,
# unida a la frecuencia de selección de la validación cruzada.
#
# La muestra balanceada repite filas de la clase SI. El error estándar de los
# coeficientes las trata como observaciones independientes, de modo que los
# IC y los valores p de esta tabla son más estrechos que los de la muestra
# original, y el intercepto corresponde a una prevalencia del 50 %.
# -----------------------------------------------------------------------------
ajustar_rl_final <- function(data_rl, enfermedad, ranking_rl) {
  formula_rl <- as.formula(paste(enfermedad, "~ ."))
  bal_rl     <- muestra_final(data_rl, enfermedad)

  modelo_full <- tryCatch(
    glm(formula_rl, data = bal_rl, family = "binomial",
        control = glm.control(maxit = 200)),
    error = function(e) {
      cat("  !! RL: el modelo completo no se pudo ajustar:", conditionMessage(e), "\n")
      NULL
    }
  )

  if (!is.null(modelo_full)) {
    cf     <- coef(summary(modelo_full))
    sig_rl <- rownames(cf)[!is.na(cf[, 4]) & cf[, 4] < CFG$alfa_rl &
                             rownames(cf) != "(Intercept)"]
  } else {
    sig_rl <- character(0)
  }

  if (length(sig_rl) > 0) {
    formula_red  <- reformulate(paste0("`", sig_rl, "`"), response = enfermedad)
    modelo_final <- suppressWarnings(glm(formula_red, data = bal_rl, family = "binomial"))
  } else {
    cat("  !! RL: sin variables significativas, se usa el modelo completo\n")
    modelo_final <- modelo_full
  }

  tabla_or <- NULL
  if (!is.null(modelo_final)) {
    cs <- summary(modelo_final)$coefficients
    OR <- exp(cs[, "Estimate"])
    IC <- exp(cbind(
      IC_2.5  = cs[, "Estimate"] - 1.96 * cs[, "Std. Error"],
      IC_97.5 = cs[, "Estimate"] + 1.96 * cs[, "Std. Error"]
    ))
    tabla_or <- data.frame(
      Variable    = rownames(cs),
      Coeficiente = round(cs[, "Estimate"], 4),
      OR          = round(OR,               4),
      IC_2.5      = round(IC[, 1],          4),
      IC_97.5     = round(IC[, 2],          4),
      P_value     = round(cs[, "Pr(>|z|)"], 6),
      stringsAsFactors = FALSE
    ) %>%
      left_join(ranking_rl %>% select(Variable, Frecuencia, Proporcion),
                by = "Variable")
  } else {
    cat("  !! RL: modelo final no disponible\n")
  }

  list(modelo = modelo_final, tabla_or = tabla_or)
}

# -----------------------------------------------------------------------------
# RF final. Devuelve el modelo y la importancia de cada variable
# (MeanDecreaseAccuracy y MeanDecreaseGini), unida a la frecuencia de
# selección de la validación cruzada.
# -----------------------------------------------------------------------------
ajustar_rf_final <- function(data_ohe, enfermedad, mtry, ntree, ranking_rf) {
  bal_rf <- muestra_final(data_ohe, enfermedad)

  modelo <- randomForest(
    as.formula(paste(enfermedad, "~ .")),
    data = bal_rf, mtry = mtry, ntree = ntree, importance = TRUE
  )

  imp_df <- as.data.frame(randomForest::importance(modelo))
  importancia <- data.frame(
    Variable             = rownames(imp_df),
    MeanDecreaseAccuracy = round(imp_df[, "MeanDecreaseAccuracy"], 4),
    MeanDecreaseGini     = round(imp_df[, "MeanDecreaseGini"],     4),
    stringsAsFactors = FALSE
  ) %>%
    left_join(ranking_rf %>% select(Variable, Frecuencia, Proporcion),
              by = "Variable") %>%
    arrange(desc(MeanDecreaseAccuracy))

  list(modelo = modelo, importancia = importancia)
}

# -----------------------------------------------------------------------------
# XGB final. Devuelve el modelo y la importancia de cada variable (Gain, Cover
# y Frequency), unida a la frecuencia de selección de la validación cruzada.
# -----------------------------------------------------------------------------
ajustar_xgb_final <- function(data_ohe, enfermedad, eta, max_depth, nrounds, ranking_xgb) {
  bal_xgb <- muestra_final(data_ohe, enfermedad)

  X_bal  <- as.matrix(bal_xgb %>% select(-all_of(enfermedad)))
  y_bal  <- ifelse(bal_xgb[[enfermedad]] == "SI", 1, 0)
  modelo <- entrenar_xgb(xgb.DMatrix(data = X_bal, label = y_bal), eta, max_depth, nrounds)

  imp_raw <- xgb.importance(model = modelo)
  importancia <- data.frame(
    Variable  = imp_raw$Feature,
    Gain      = round(imp_raw$Gain,      4),
    Cover     = round(imp_raw$Cover,     4),
    Frequency = round(imp_raw$Frequency, 4),
    stringsAsFactors = FALSE
  ) %>%
    left_join(ranking_xgb %>% select(Variable, Frecuencia, Proporcion),
              by = "Variable") %>%
    arrange(desc(Gain))

  list(modelo = modelo, importancia = importancia)
}
