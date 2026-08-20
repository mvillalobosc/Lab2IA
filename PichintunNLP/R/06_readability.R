# =============================================================================
# 06_readability.R  Complejidad (ARI) y diversidad lexica (MATTR)
# =============================================================================
# ARI se calcula sobre el texto en ingles porque quanteda no dispone de la
# parametrizacion del indice para espanol; MATTR se calcula sobre el texto en
# espanol, que es donde interesa la diversidad. Ambas metricas usan el texto sin
# limpiar: requieren puntuacion, mayusculas y segmentacion de oraciones intactas.
#
# Cambios respecto al original:
#  - El bucle identificaba el capitulo con which(capitulos$texto == capitulo),
#    comparando textos completos como cadenas. Dos capitulos identicos habrian
#    colapsado en un mismo indice. Aqui la identificacion es posicional.
#  - Las curvas de tendencia usaban plotly::as.widget(), retirado del paquete.
# =============================================================================

log_step("06  Complejidad y diversidad lexica")

st    <- load_step("05_sentiment")
serie <- st$serie
n     <- nrow(serie)
etq   <- serie$title_es
temp  <- serie$season

ari_de <- function(txt) {
  quanteda.textstats::textstat_readability(
    txt, measure = "ARI", remove_hyphens = TRUE,
    min_sentence_length = 1, max_sentence_length = 10000, intermediate = FALSE)$ARI
}

mattr_de <- function(txt, window = CFG$mattr_window) {
  suppressMessages(suppressWarnings(
    koRpus::MATTR(txt, force.lang = "es", window = window)@MATTR$MATTR))
}

serie$ARI   <- vapply(serie$texto_en_orig, ari_de, numeric(1))
serie$MATTR <- vapply(serie$texto_es_orig, mattr_de, numeric(1))

log_msg("ARI:   media ", round(mean(serie$ARI), 3),
        " | rango ", round(min(serie$ARI), 2), " a ", round(max(serie$ARI), 2))
log_msg("MATTR: media ", round(mean(serie$MATTR), 4),
        " | rango ", round(min(serie$MATTR), 4), " a ", round(max(serie$MATTR), 4))

# --- nivel temporada ---------------------------------------------------------
txt_en_temp <- vapply(split(serie$texto_en_orig, temp), paste, character(1), collapse = " ")
txt_es_temp <- vapply(split(serie$texto_es_orig, temp), paste, character(1), collapse = " ")

complejidad_temp <- data.frame(
  temporada = sort(unique(temp)),
  ARI   = vapply(txt_en_temp, ari_de, numeric(1)),
  MATTR = vapply(txt_es_temp, mattr_de, numeric(1)),
  row.names = NULL
)

save_fig_grid(
  unlist(lapply(sort(unique(temp)), function(s) {
    d <- data.frame(x = seq_len(sum(temp == s)),
                    ARI = serie$ARI[temp == s], MATTR = serie$MATTR[temp == s])
    list(
      ggplot2::ggplot(d, ggplot2::aes(x, ARI)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = ARI), fill = "purple", alpha = 0.5) +
        ggplot2::geom_line() + ggplot2::geom_point() +
        ggplot2::ylim(0, max(serie$ARI)) + ggplot2::scale_x_continuous(breaks = d$x) +
        ggplot2::labs(x = "Capitulo de la temporada", y = "ARI (complejidad)",
          title = paste("Complejidad, temporada", s),
          subtitle = paste("Valor de la temporada:",
                           round(complejidad_temp$ARI[complejidad_temp$temporada == s], 3))) +
        ggplot2::theme_minimal(),
      ggplot2::ggplot(d, ggplot2::aes(x, MATTR)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = MATTR), fill = "orange", alpha = 0.5) +
        ggplot2::geom_line() + ggplot2::geom_point() +
        ggplot2::ylim(0, max(serie$MATTR)) + ggplot2::scale_x_continuous(breaks = d$x) +
        ggplot2::labs(x = "Capitulo de la temporada", y = "MATTR (diversidad)",
          title = paste("Diversidad, temporada", s),
          subtitle = paste("Valor de la temporada:",
                           round(complejidad_temp$MATTR[complejidad_temp$temporada == s], 3))) +
        ggplot2::theme_minimal())
  }), recursive = FALSE),
  "06_complejidad_temporada", nrow = 1, ncol = 2, height = 5)

# --- distancias --------------------------------------------------------------
mat_cd <- as.matrix(serie[, c("ARI", "MATTR")])

save_fig(plot_dendrograma(mat_cd, etq, temp,
  "Distancia euclidiana entre capitulos (complejidad y diversidad)", "euclidean"),
  "06_dendro_capitulos_euclidiana")
save_fig(plot_dendrograma(mat_cd, etq, temp,
  "Distancia de correlacion de Pearson entre capitulos (complejidad y diversidad)", "pearson"),
  "06_dendro_capitulos_pearson")

# La correlacion se calcula sobre las variables reescaladas: ARI y MATTR estan
# en escalas muy distintas y sin reescalar la matriz queda dominada por ARI.
mat_norm <- cbind(ARI = rescale01(serie$ARI), MATTR = rescale01(serie$MATTR))
dist_corr <- 1 - matriz_correlacion(mat_norm, etq)
save_fig(plot_corrplot(dist_corr,
  "Distancia de correlacion entre capitulos (complejidad y diversidad)",
  is_corr = FALSE), "06_dist_corr_capitulos", width = 12, height = 11)

cl_cd <- clusters_mst_knn(mat_cd)
save_fig(plot_clusters_mst_knn(cl_cd), "06_clusters_capitulos", width = 14, height = 7)
write_table_out(tabla_clusters(cl_cd, etq), "06_clusters_capitulos")

mat_temp <- as.matrix(complejidad_temp[, c("ARI", "MATTR")])
save_fig(plot_dendrograma(mat_temp, paste("Temporada", complejidad_temp$temporada),
  complejidad_temp$temporada,
  "Distancia euclidiana entre temporadas (complejidad y diversidad)", "euclidean",
  cex = 1.2, mar = c(4, 4, 1, 2)), "06_dendro_temporadas_euclidiana", height = 6)

# --- capitulos mas y menos parecidos ----------------------------------------
d_pear <- as.matrix(amap::Dist(mat_cd, method = "pearson"))
diag(d_pear) <- NA
vecinos <- data.frame(
  episode_id = serie$episode_id, title_es = etq,
  mas_cercano   = etq[apply(d_pear, 1, which.min)],
  dist_min      = round(apply(d_pear, 1, min, na.rm = TRUE), 6),
  mas_lejano    = etq[apply(d_pear, 1, which.max)],
  dist_max      = round(apply(d_pear, 1, max, na.rm = TRUE), 6)
)
write_table_out(vecinos, "06_vecinos_complejidad")

# --- tendencia de la serie ---------------------------------------------------
# Cada temporada se interpola a un numero fijo de periodos para poder promediar
# temporadas de distinto largo.
interp_periodos <- function(v, grupos, k) {
  do.call(rbind, lapply(sort(unique(grupos)), function(s) {
    y <- rescale01(v)[grupos == s]
    x <- seq_along(y)
    if (length(x) != k) y <- stats::approx(x, y, xout = seq(min(x), max(x), length.out = k))$y
    data.frame(temporada = s, periodo = seq_len(k), valor = y)
  }))
}

k <- CFG$n_tramos_lexico
tend <- rbind(
  cbind(metrica = "ARI (complejidad)",  interp_periodos(serie$ARI,   temp, k)),
  cbind(metrica = "MATTR (diversidad)", interp_periodos(serie$MATTR, temp, k))
)
res_tend <- dplyr::summarise(dplyr::group_by(tend, metrica, periodo),
  media = mean(valor), sd = stats::sd(valor), .groups = "drop")

save_fig(
  ggplot2::ggplot(res_tend, ggplot2::aes(periodo, media, colour = metrica, fill = metrica)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = media - sd, ymax = media + sd),
                         alpha = 0.2, colour = NA) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::facet_wrap(~ metrica) +
    ggplot2::scale_colour_manual(values = c("purple", "orange")) +
    ggplot2::scale_fill_manual(values = c("purple", "orange")) +
    ggplot2::scale_x_continuous(breaks = seq_len(k)) +
    ggplot2::guides(colour = "none", fill = "none") +
    ggplot2::labs(x = paste0("Periodo de la temporada (1 a ", k, ")"),
                  y = "Valor normalizado",
                  title = "Tendencia lexica a lo largo de las cuatro temporadas",
                  subtitle = "Banda: una desviacion estandar entre temporadas") +
    ggplot2::theme_minimal(),
  "06_tendencia_lexica", height = 5)

write_table_out(data.frame(episode_id = serie$episode_id, title_es = etq, season = temp,
                           ARI = round(serie$ARI, 6), MATTR = round(serie$MATTR, 6)),
                "06_complejidad_capitulo")
write_table_out(complejidad_temp, "06_complejidad_temporada")
write_table_out(res_tend, "06_tendencia_lexica")

save_step(list(serie = serie, complejidad_temp = complejidad_temp,
               vecinos = vecinos, tendencia = res_tend), "06_readability")
