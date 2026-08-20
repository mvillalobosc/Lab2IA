# =============================================================================
# 07_popularity.R  Factores asociados a likes, suscriptores y visualizaciones
# =============================================================================
# Cambios respecto al original:
#  - Las fechas venian como "Mayo 2, 2016" y se parseaban con
#    as.Date(x, "%B %d, %Y"), que depende del locale. Bajo locale C, habitual en
#    servidores Linux, devuelve NA y todo este modulo colapsaba a NA sin aviso.
#    Las fechas ahora estan en ISO 8601 en episodes.csv.
#  - El original normalizaba likes por dias y suscriptores/visualizaciones por
#    meses. Como despues todo se reescala a [0,1] el resultado no cambia, pero
#    la inconsistencia se elimina: se usa meses en los tres casos.
#  - Los tres bloques casi identicos de Random Forest y regresion se unifican en
#    una funcion, de modo que un cambio de criterio se aplica a los tres.
# =============================================================================

log_step("07  Factores de popularidad")

rd    <- load_step("06_readability")
tp    <- load_step("04_topics")
sn    <- load_step("05_sentiment")
serie <- rd$serie
n     <- nrow(serie)

meses_expuesto <- as.numeric(CFG$fecha_corte - serie$publish_date) / 30
if (any(!is.finite(meses_expuesto)) || any(meses_expuesto <= 0)) {
  stop("Exposicion no valida. Revise publish_date y CFG$fecha_corte.")
}
log_msg("exposicion: ", round(min(meses_expuesto), 1), " a ",
        round(max(meses_expuesto), 1), " meses desde la publicacion")

# --- matriz de predictores ---------------------------------------------------
# Los temas entran como proporcion dentro del capitulo, no como frecuencia
# absoluta, porque los capitulos no tienen el mismo largo.
limpia_nombre <- function(x) {
  x <- gsub("[/ ]+", "_", x)
  x <- chartr("aeiouAEIOUnN", "aeiouAEIOUnN", x)
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- gsub("[^A-Za-z0-9_]", "", x)
  make.names(x, unique = TRUE)
}

temas_pct <- tp$temas_cap_pct
colnames(temas_pct) <- limpia_nombre(colnames(temas_pct))
# "sentimientos" es a la vez un tema y el nombre de la variable de sentimiento.
colnames(temas_pct)[colnames(temas_pct) == "sentimientos"] <- "tema_sentimientos"

emo <- sn$emociones_cap
colnames(emo) <- limpia_nombre(colnames(emo))

predictores <- data.frame(
  Equipo           = factor(serie$animation_team),
  Modismos_etnicas = serie$pct_cultural,
  temas_pct,
  Sentimiento      = serie$sentimiento,
  emo,
  ARI              = serie$ARI,
  MATTR            = serie$MATTR,
  check.names = FALSE
)

# Reescalado a [0,1] de todo lo numerico, para que la importancia de Random
# Forest no dependa de las unidades de cada variable.
num <- vapply(predictores, is.numeric, logical(1))
predictores[num] <- lapply(predictores[num], rescale01)

constantes <- names(predictores)[num][vapply(predictores[num],
                                             function(x) stats::var(x) == 0, logical(1))]
if (length(constantes)) {
  log_msg("aviso: predictores constantes descartados: ",
          paste(constantes, collapse = ", "))
  predictores <- predictores[, !names(predictores) %in% constantes, drop = FALSE]
}
log_msg("predictores: ", ncol(predictores), " para ", n, " capitulos")

# --- funcion comun para las tres variables respuesta -------------------------
analiza_popularidad <- function(y_raw, nombre, semilla) {
  y <- rescale01(y_raw / meses_expuesto)
  d <- cbind(stats::setNames(data.frame(y), nombre), predictores)

  set.seed(semilla)
  modelo_rf <- caret::train(stats::as.formula(paste(nombre, "~ .")),
                            data = d, method = "rf")

  imp <- caret::varImp(modelo_rf)$importance
  imp <- data.frame(variable = rownames(imp), importancia = imp$Overall)
  imp <- imp[order(-imp$importancia), ]
  rownames(imp) <- NULL

  sel <- imp$variable[imp$importancia >= CFG$umbral_importancia_rf]
  # varImp expande los factores a nombres de nivel (EquipoXxx). Se mapea de
  # vuelta a la columna original antes de armar la formula de la regresion.
  sel <- unique(vapply(sel, function(v)
    if (v %in% names(predictores)) v
    else {
      hit <- names(predictores)[startsWith(v, names(predictores))]
      if (length(hit)) hit[which.max(nchar(hit))] else NA_character_
    }, character(1)))
  sel <- sel[!is.na(sel)]

  if (!length(sel)) {
    log_msg(nombre, ": ninguna variable supera el umbral de ",
            CFG$umbral_importancia_rf, "% de importancia")
    return(list(importancia = imp, modelo_lm = NULL, coeficientes = NULL,
                r2 = NA_real_, seleccionadas = character(0)))
  }

  fml <- stats::as.formula(paste(nombre, "~", paste(sprintf("`%s`", sel), collapse = " + ")))
  modelo_lm <- stats::lm(fml, data = d)
  s <- summary(modelo_lm)

  coefs <- data.frame(variable = rownames(s$coefficients),
                      estimado = s$coefficients[, 1],
                      error_std = s$coefficients[, 2],
                      t = s$coefficients[, 3],
                      p = s$coefficients[, 4], row.names = NULL)
  coefs$significancia <- cut(coefs$p, c(-Inf, 0.05, 0.1, Inf),
                             labels = c("p <= 0.05", "0.05 < p <= 0.1", "no significativo"))
  coefs$sentido <- ifelse(coefs$estimado > 0, "positivo", "negativo")
  coefs <- coefs[order(coefs$p), ]

  log_msg(nombre, ": ", length(sel), " variable(s) sobre el umbral | R2 ajustado = ",
          round(s$adj.r.squared, 4), " | significativas (p<=0.05): ",
          sum(coefs$p <= 0.05 & coefs$variable != "(Intercept)"),
          " | gl residuales = ", modelo_lm$df.residual)

  # Con 34 capitulos, un umbral de importancia bajo deja pasar mas predictores
  # que observaciones puede sostener la regresion. El R2 ajustado se infla y los
  # p-valores dejan de ser interpretables. Se advierte de forma explicita en vez
  # de reportar el ajuste como si fuera valido.
  if (modelo_lm$df.residual < nrow(d) / 3) {
    warning(sprintf(paste0("Modelo '%s': %d predictores para %d observaciones ",
      "(%d gl residuales). El ajuste esta sobreparametrizado; suba ",
      "CFG$umbral_importancia_rf o reduzca el conjunto de predictores."),
      nombre, length(coefs$variable) - 1L, nrow(d), modelo_lm$df.residual),
      call. = FALSE)
    log_msg("  ADVERTENCIA: modelo sobreparametrizado para ", nombre)
  }

  list(importancia = imp, modelo_lm = modelo_lm, coeficientes = coefs,
       r2 = s$adj.r.squared, seleccionadas = sel,
       df_residual = modelo_lm$df.residual, n_obs = nrow(d))
}

respuestas <- list(
  Likes           = list(v = serie$likes,               s = CFG$seed_likes),
  Suscriptores    = list(v = serie$subscribers_current, s = CFG$seed_subscribers),
  Visualizaciones = list(v = serie$views,               s = CFG$seed_views)
)

resultados <- lapply(names(respuestas), function(nm)
  analiza_popularidad(respuestas[[nm]]$v, nm, respuestas[[nm]]$s))
names(resultados) <- names(respuestas)

# --- exportes ----------------------------------------------------------------
for (nm in names(resultados)) {
  r <- resultados[[nm]]
  write_table_out(r$importancia, paste0("07_importancia_rf_", tolower(nm)))
  if (!is.null(r$coeficientes)) {
    write_table_out(r$coeficientes, paste0("07_coeficientes_lm_", tolower(nm)))
  }
  imp <- utils::head(r$importancia, 20)
  save_fig(
    ggplot2::ggplot(imp, ggplot2::aes(stats::reorder(variable, importancia), importancia)) +
      ggplot2::geom_col(fill = "#00688B") +
      ggplot2::geom_hline(yintercept = CFG$umbral_importancia_rf,
                          linetype = "dashed", colour = "red") +
      ggplot2::coord_flip() +
      ggplot2::labs(x = NULL, y = "Importancia relativa (%)",
        title = paste("Importancia de predictores sobre", nm),
        subtitle = paste0("Random Forest, top 20. Linea: umbral de ",
                          CFG$umbral_importancia_rf, "%")) +
      ggplot2::theme_minimal(),
    paste0("07_importancia_rf_", tolower(nm)), height = 7)
}

resumen <- do.call(rbind, lapply(names(resultados), function(nm) data.frame(
  respuesta = nm, r2_ajustado = round(resultados[[nm]]$r2, 4),
  n_obs = n,
  gl_residuales = if (is.null(resultados[[nm]]$df_residual)) NA_integer_ else
    resultados[[nm]]$df_residual,
  sobreparametrizado = !is.null(resultados[[nm]]$df_residual) &&
    resultados[[nm]]$df_residual < n / 3,
  n_seleccionadas = length(resultados[[nm]]$seleccionadas),
  n_significativas = if (is.null(resultados[[nm]]$coeficientes)) 0L else
    sum(resultados[[nm]]$coeficientes$p <= 0.05 &
        resultados[[nm]]$coeficientes$variable != "(Intercept)"))))
write_table_out(resumen, "07_resumen_modelos")

save_step(list(resultados = resultados, predictores = predictores,
               meses_expuesto = meses_expuesto, resumen = resumen), "07_popularity")
