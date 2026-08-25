# =============================================================================
# 11_desajustados.R : deteccion de libros cuyo perfil no calza con su nivel.
#   Via 1: regresion logistica ordinal (MASS::polr) con validacion LOOCV,
#          prediciendo el nivel desde las metricas; se marca |delta| >= umbral.
#          Si polr no converge (corpus chico o separacion), fallback lineal
#          documentado en el log.
#   Via 2: z robusto (mediana y MAD) por metrica dentro de cada nivel.
# =============================================================================

set.seed(config$semilla)
maestra <- P$maestra
feats <- intersect(config$features_modelo, colnames(maestra))
d <- maestra[, c("id_libro", "titulo", "nivel", feats)]
incompletos <- !stats::complete.cases(d)
for (i in which(incompletos))
  registrar_advertencia("11_desajustados", d$id_libro[i], d$titulo[i],
    "excluido del modelo ordinal por NA en features (texto corto)", NA)
d <- d[!incompletos, ]
X <- scale(as.matrix(d[, feats]))
X <- X[, apply(X, 2, function(c) all(is.finite(c))), drop = FALSE]
dat <- data.frame(nivel_f = factor(d$nivel, ordered = TRUE), X)

ajustar_predecir <- function(train, test) {
  fit <- tryCatch(
    suppressWarnings(MASS::polr(nivel_f ~ ., data = train, Hess = FALSE)),
    error = function(e) NULL)
  if (!is.null(fit)) {
    pr <- tryCatch(predict(fit, test), error = function(e) NULL)
    if (!is.null(pr)) return(list(pred = as.integer(as.character(pr)),
                                  modelo = "polr"))
  }
  # fallback lineal
  tr <- train; tr$nivel_num <- as.integer(as.character(tr$nivel_f))
  fit2 <- stats::lm(nivel_num ~ . - nivel_f, data = tr)
  p <- predict(fit2, test)
  list(pred = pmin(12L, pmax(1L, as.integer(round(p)))), modelo = "lm")
}

pred <- integer(nrow(dat)); modelos <- character(nrow(dat))
for (i in seq_len(nrow(dat))) {
  r <- ajustar_predecir(dat[-i, ], dat[i, , drop = FALSE])
  pred[i] <- r$pred; modelos[i] <- r$modelo
}
if (any(modelos == "lm"))
  log_msg("Desajustados: fallback lineal usado en ", sum(modelos == "lm"),
          " de ", length(modelos), " pliegues LOOCV (polr no convergio)")

res <- data.frame(id_libro = d$id_libro, titulo = d$titulo,
                  nivel_asignado = d$nivel, nivel_predicho = pred,
                  delta = pred - d$nivel, modelo = modelos)
res$desajustado_modelo <- abs(res$delta) >= config$umbral_delta_nivel
mae <- mean(abs(res$delta))
acc1 <- mean(abs(res$delta) <= 1)
log_msg("Desajustados (LOOCV): MAE = ", round(mae, 2),
        ", |delta| <= 1 en ", round(100 * acc1, 1), "% de los libros")

# --- z robusto dentro de nivel ----------------------------------------------
zlargo <- maestra %>%
  dplyr::select(id_libro, titulo, nivel, dplyr::all_of(feats)) %>%
  tidyr::pivot_longer(dplyr::all_of(feats), names_to = "metrica",
                      values_to = "valor") %>%
  dplyr::group_by(nivel, metrica) %>%
  dplyr::mutate(z = z_robusto(valor)) %>%
  dplyr::ungroup()
z_flags <- zlargo %>%
  dplyr::filter(!is.na(z), abs(z) > config$umbral_z_robusto) %>%
  dplyr::arrange(dplyr::desc(abs(z)))
z_resumen <- z_flags %>%
  dplyr::group_by(id_libro, titulo, nivel) %>%
  dplyr::summarise(n_metricas_extremas = dplyr::n(),
                   metricas = paste0(metrica, " (z=", round(z, 1), ")",
                                     collapse = "; "), .groups = "drop")

candidatos <- res %>%
  dplyr::full_join(z_resumen, by = c("id_libro", "titulo",
                                     "nivel_asignado" = "nivel")) %>%
  dplyr::mutate(n_metricas_extremas =
                  dplyr::coalesce(n_metricas_extremas, 0L)) %>%
  dplyr::arrange(dplyr::desc(abs(dplyr::coalesce(delta, 0L))),
                 dplyr::desc(n_metricas_extremas))
guardar_tabla(candidatos, "libros_desajustados")
guardar_tabla(data.frame(mae_loocv = mae, prop_delta_max1 = acc1,
                         modelo_principal = names(sort(table(modelos),
                                                      decreasing = TRUE))[1]),
              "desajustados_resumen_modelo")

p_d <- ggplot2::ggplot(res, ggplot2::aes(nivel_asignado, nivel_predicho,
                                         colour = desajustado_modelo)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2,
                       colour = "grey50") +
  ggplot2::geom_jitter(width = 0.15, height = 0.15, size = 2, alpha = 0.85) +
  ggplot2::scale_colour_manual(values = c("FALSE" = "#4477AA",
                                          "TRUE" = "#B2182B")) +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::scale_y_continuous(breaks = 1:12) +
  ggplot2::labs(title = "Nivel predicho (LOOCV) vs nivel asignado",
                x = "Nivel asignado", y = "Nivel predicho",
                colour = paste0("|delta| >= ", config$umbral_delta_nivel)) +
  tema_pipeline()
guardar_fig(p_d, "11_desajustados", 8.5, 6.5)

P$desajustados <- candidatos
