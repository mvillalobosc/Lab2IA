# =============================================================================
# R/funciones_metricas.R
# Métricas de clasificación, hipervolumen, resumen de la validación cruzada
# repetida y elección del modelo ganador.
# =============================================================================

# -----------------------------------------------------------------------------
# Precisión, Recall, F1, Accuracy y AUC-ROC de un fold de validación.
# "SI" es siempre la clase positiva. y_true puede ser factor o carácter;
# y_pred es carácter ("SI"/"NO"); y_prob es la probabilidad predicha de "SI".
# Una métrica con denominador cero vale 0, y el AUC vale NA si el fold tiene
# una sola clase.
# -----------------------------------------------------------------------------
calcular_metricas <- function(y_true, y_pred, y_prob) {
  y_true_f <- factor(y_true, levels = c("SI", "NO"))
  y_pred_f <- factor(y_pred, levels = c("SI", "NO"))
  cm <- table(Real = y_true_f, Pred = y_pred_f)

  TP <- cm["SI", "SI"]
  TN <- cm["NO", "NO"]
  FP <- cm["NO", "SI"]
  FN <- cm["SI", "NO"]

  precision <- ifelse((TP + FP) == 0, 0, TP / (TP + FP))
  recall    <- ifelse((TP + FN) == 0, 0, TP / (TP + FN))
  f1        <- ifelse((precision + recall) == 0, 0,
                      2 * precision * recall / (precision + recall))
  accuracy  <- ifelse((TP + TN + FP + FN) == 0, 0,
                      (TP + TN) / (TP + TN + FP + FN))
  roc_auc   <- suppressMessages(
    if (length(unique(y_true_f)) == 1) NA_real_
    else as.numeric(pROC::auc(pROC::roc(ifelse(y_true_f == "SI", 1, 0), y_prob,
                                        levels = c(0, 1), direction = "<")))
  )

  c(Precision = precision, Recall = recall, F1 = f1,
    Accuracy = accuracy, ROC_AUC = roc_auc)
}

# -----------------------------------------------------------------------------
# Hipervolumen de un modelo.
# En el espacio de minimización error_i = 1 - métrica_i, con el punto de
# referencia (1, 1, 1, 1), el hipervolumen de un solo punto es el producto de
# Precisión, Recall, F1 y AUC-ROC. Mayor hipervolumen = mejor desempeño
# conjunto. Acepta vectores (un valor por modelo). El producto se escribe en
# este orden para repetir bit a bit la operación del script original.
# -----------------------------------------------------------------------------
calcular_hipervolumen <- function(precision, recall, f1, auc) {
  precision * recall * f1 * auc
}

# -----------------------------------------------------------------------------
# Resumen de estabilidad de un modelo en la validación cruzada repetida.
# Cada vector trae una cifra por repetición (el promedio de sus k folds).
# Devuelve media, desviación estándar y los percentiles 2,5 y 97,5 de las
# repeticiones. Esos percentiles (columnas IC95_inf e IC95_sup) describen
# cuánto se mueve la métrica al cambiar la partición; no son un intervalo de
# confianza del desempeño en otra muestra.
# -----------------------------------------------------------------------------
resumen_cv_repetida <- function(modelo, prec, rec, f1, acc, auc) {
  series  <- list(auc, f1, prec, rec, acc)
  resumir <- function(f, ...) round(vapply(series, f, numeric(1), ..., USE.NAMES = FALSE), 3)
  cuantil <- function(x, p) unname(quantile(x, p, na.rm = TRUE))
  data.frame(
    Modelo   = modelo,
    Metrica  = c("AUC-ROC", "F1", "Precision", "Recall", "Accuracy"),
    Media    = resumir(mean, na.rm = TRUE),
    SD       = resumir(sd, na.rm = TRUE),
    IC95_inf = resumir(cuantil, p = 0.025),
    IC95_sup = resumir(cuantil, p = 0.975),
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------------------------
# Compara los tres modelos y elige el ganador.
# cv es una lista con los elementos RL, RF y XGB; cada uno trae los vectores
# prec, rec, f1, acc y auc de cv_repetida(). El ganador es el modelo con mayor
# hipervolumen calculado sobre las medias de las repeticiones; un hipervolumen
# NA cuenta como 0 y, si hay empate, gana el primero en el orden RL, RF, XGB.
# Devuelve la tabla de comparación, el nombre del ganador y su hipervolumen.
# -----------------------------------------------------------------------------
comparar_modelos <- function(cv) {
  media <- function(x) mean(x, na.rm = TRUE)
  medias <- data.frame(
    Modelo    = c("RL", "RF", "XGB"),
    Precision = c(media(cv$RL$prec), media(cv$RF$prec), media(cv$XGB$prec)),
    Recall    = c(media(cv$RL$rec),  media(cv$RF$rec),  media(cv$XGB$rec)),
    F1        = c(media(cv$RL$f1),   media(cv$RF$f1),   media(cv$XGB$f1)),
    Accuracy  = c(media(cv$RL$acc),  media(cv$RF$acc),  media(cv$XGB$acc)),
    AUC_ROC   = c(media(cv$RL$auc),  media(cv$RF$auc),  media(cv$XGB$auc)),
    stringsAsFactors = FALSE
  )

  hipervolumen <- calcular_hipervolumen(medias$Precision, medias$Recall,
                                        medias$F1, medias$AUC_ROC)
  names(hipervolumen) <- medias$Modelo
  hipervolumen[is.na(hipervolumen)] <- 0
  ganador <- names(which.max(hipervolumen))

  tabla <- medias %>%
    mutate(across(c(Precision, Recall, F1, Accuracy, AUC_ROC), ~ round(.x, 4)),
           Hipervolumen = round(hipervolumen[Modelo], 6),
           Ganador      = ifelse(Modelo == ganador, "SI", ""))

  list(tabla = tabla, ganador = ganador, hipervolumen_ganador = max(hipervolumen))
}
