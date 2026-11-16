# =============================================================================
# R/funciones_seleccion.R
# Selección de características con chi-cuadrado y codificación one-hot.
# =============================================================================

# -----------------------------------------------------------------------------
# Prueba chi-cuadrado de independencia entre cada variable predictora y la
# enfermedad, sobre la muestra completa. Devuelve las variables con
# p < CFG$alfa_chi2 ordenadas de menor a mayor valor p (columnas Variable y
# P_value). Una variable con un solo nivel, o cuya prueba falla, queda con
# p = NA y no se selecciona. Las tablas de 2 x 2 llevan la corrección de
# continuidad de Yates, que es la opción por defecto de chisq.test().
# -----------------------------------------------------------------------------
chi_cuadrado <- function(datos, enfermedad) {
  vars_pred <- setdiff(names(datos), enfermedad)

  p_valores <- vapply(vars_pred, function(var) {
    tbl <- table(datos[[var]], datos[[enfermedad]])
    if (all(dim(tbl) > 1))
      tryCatch(suppressWarnings(chisq.test(tbl)$p.value), error = function(e) NA_real_)
    else NA_real_
  }, numeric(1), USE.NAMES = FALSE)

  resultados <- data.frame(Variable = vars_pred, P_value = p_valores,
                           stringsAsFactors = FALSE)
  resultados <- resultados[order(resultados$P_value), ]
  subset(resultados, !is.na(P_value) & P_value < CFG$alfa_chi2)
}

# -----------------------------------------------------------------------------
# Arma los datos de modelamiento de una enfermedad: la variable objetivo más
# las CFG$max_variables variables significativas de menor valor p. Después
# quita las filas con algún dato faltante en esas columnas (casos completos).
# Devuelve los datos y el número de filas que salieron, para que ninguna
# exclusión pase sin registro.
# -----------------------------------------------------------------------------
datos_de_modelamiento <- function(datos, enfermedad, variables_significativas) {
  data_enfermedad <- datos %>%
    select(all_of(enfermedad), all_of(variables_significativas))
  data_enfermedad <- data_enfermedad[, 1:min(CFG$max_variables + 1, ncol(data_enfermedad))]

  n_antes <- nrow(data_enfermedad)
  if (anyNA(data_enfermedad)) data_enfermedad <- na.omit(data_enfermedad)

  list(datos = data_enfermedad, n_excluidos = n_antes - nrow(data_enfermedad))
}

# -----------------------------------------------------------------------------
# One-hot encoding de las predictoras.
# Cada nivel de cada variable pasa a ser una columna 0/1. En las variables
# SI/NO se elimina la columna .NO, que es redundante; las variables de más de
# dos niveles conservan todas sus columnas. Devuelve:
#   ohe   data.frame one-hot con la enfermedad como factor de niveles SI, NO
#         (RF y XGB)
#   rl    lo mismo con niveles NO, SI. glm(family = "binomial") modela la
#         probabilidad del segundo nivel, así que predict() devuelve P(SI)
#   X, y  matriz numérica y etiqueta 0/1 para el grid search de XGBoost
# -----------------------------------------------------------------------------
codificar_one_hot <- function(data_modelo, enfermedad) {
  dummies  <- dummyVars(~ ., data = data_modelo %>% select(-all_of(enfermedad)))
  data_ohe <- as.data.frame(predict(dummies, newdata = data_modelo))
  colnames(data_ohe) <- make.names(colnames(data_ohe))
  data_ohe <- data_ohe %>% select(-ends_with(".NO"))

  data_ohe[[enfermedad]] <- factor(data_modelo[[enfermedad]], levels = c("SI", "NO"))

  data_rl <- data_ohe
  data_rl[[enfermedad]] <- factor(data_rl[[enfermedad]], levels = c("NO", "SI"))

  list(
    ohe = data_ohe,
    rl  = data_rl,
    X   = as.matrix(data_ohe %>% select(-all_of(enfermedad))),
    y   = ifelse(data_ohe[[enfermedad]] == "SI", 1, 0)
  )
}
