# =============================================================================
# 05_sentiment.R  Sentimiento y emociones
# =============================================================================
# sentimentr solo dispone de lexicos en ingles, de modo que el analisis corre
# sobre las traducciones (data/raw/dialogues_en). Esto se hereda del diseno
# original y es una limitacion metodologica declarada en el README.
#
# Cambios respecto al original:
#  - tokenize_sentence() (singular) en el calculo de tramos no existe en el
#    paquete tokenizers; la funcion es tokenize_sentences(). Era un error de
#    ejecucion garantizado.
#  - plotly::as.widget() fue retirado del paquete. Las curvas de tendencia se
#    generan ahora con ggplot2 y se guardan como PNG.
#  - El rbind incremental de emociones fallaba si un capitulo carecia de algun
#    tipo emocional. Ahora se arma una matriz con el conjunto completo de tipos.
# =============================================================================

log_step("05  Sentimiento y emociones")

cl    <- load_step("02_clean")
serie <- cl$serie
n     <- nrow(serie)
etq   <- serie$title_es
temp  <- serie$season

# --- sentimiento por capitulo ------------------------------------------------
serie$sentimiento <- vapply(seq_len(n), function(i)
  sentimentr::sentiment_by(sentimentr::get_sentences(serie$texto_en_orig[i]))$ave_sentiment[1],
  numeric(1))

sent_oracion <- lapply(seq_len(n), function(i)
  sentimentr::sentiment(sentimentr::get_sentences(serie$texto_en_orig[i])))

save_fig_grid(
  lapply(seq_len(n), function(i) {
    d <- sent_oracion[[i]]
    ggplot2::ggplot(d, ggplot2::aes(x = sentence_id, y = sentiment)) +
      ggplot2::geom_line() + ggplot2::geom_point(size = 0.8) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = pmax(sentiment, 0)),
                           fill = "blue", alpha = 0.5) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = pmin(sentiment, 0), ymax = 0),
                           fill = "red", alpha = 0.5) +
      ggplot2::labs(x = "Oracion", y = "Sentimiento", title = etq[i],
        subtitle = paste("Valor del capitulo:", round(serie$sentimiento[i], 4))) +
      ggplot2::theme_minimal()
  }),
  "05_sentimiento_capitulo", nrow = 2, ncol = 2)

# --- emociones por capitulo --------------------------------------------------
emo_raw <- lapply(seq_len(n), function(i)
  sentimentr::emotion_by(sentimentr::get_sentences(serie$texto_en_orig[i])))

tipos_emo <- sort(unique(unlist(lapply(emo_raw, function(d) as.character(d$emotion_type)))))
log_msg("tipos emocionales detectados: ", length(tipos_emo))

matriz_emociones <- function(lst) {
  m <- matrix(0, nrow = length(lst), ncol = length(tipos_emo),
              dimnames = list(NULL, tipos_emo))
  for (i in seq_along(lst)) {
    d <- lst[[i]]
    m[i, as.character(d$emotion_type)] <- d$ave_emotion
  }
  m
}

emociones_cap <- matriz_emociones(emo_raw)

save_fig_grid(
  lapply(seq_len(n), function(i) {
    d <- data.frame(emotion_type = factor(tipos_emo, levels = rev(tipos_emo)),
                    ave_emotion = emociones_cap[i, ])
    ggplot2::ggplot(d, ggplot2::aes(emotion_type, ave_emotion, fill = emotion_type)) +
      ggplot2::geom_col(colour = "black", linewidth = 0.2) +
      ggplot2::scale_fill_manual(values = stats::setNames(
        grDevices::rainbow(length(tipos_emo)), rev(tipos_emo))) +
      ggplot2::coord_flip() + ggplot2::guides(fill = "none") +
      ggplot2::labs(title = etq[i], x = NULL, y = "Emocion promedio") +
      ggplot2::theme_minimal(base_size = 9)
  }),
  "05_emociones_capitulo", nrow = 2, ncol = 2)

save_fig(plot_dendrograma(emociones_cap, etq, temp,
  "Distancia euclidiana entre capitulos (emociones)", "euclidean"),
  "05_dendro_capitulos_euclidiana")
save_fig(plot_dendrograma(emociones_cap, etq, temp,
  "Distancia de correlacion de Pearson entre capitulos (emociones)", "pearson"),
  "05_dendro_capitulos_pearson")
save_fig(plot_corrplot(matriz_correlacion(emociones_cap, etq),
  "Correlacion entre capitulos (emociones)"), "05_corr_capitulos",
  width = 12, height = 11)

cl_emo <- clusters_mst_knn(emociones_cap)
save_fig(plot_clusters_mst_knn(cl_emo), "05_clusters_capitulos", width = 14, height = 7)
write_table_out(tabla_clusters(cl_emo, etq), "05_clusters_capitulos")

# --- nivel temporada ---------------------------------------------------------
texto_temp <- vapply(split(serie$texto_en_orig, temp), paste, character(1), collapse = " ")
sent_temp  <- vapply(texto_temp, function(t)
  sentimentr::sentiment_by(sentimentr::get_sentences(t))$ave_sentiment[1], numeric(1))
emociones_temp <- matriz_emociones(lapply(texto_temp, function(t)
  sentimentr::emotion_by(sentimentr::get_sentences(t))))
rownames(emociones_temp) <- paste("Temporada", sort(unique(temp)))

save_fig_grid(
  lapply(sort(unique(temp)), function(s) {
    d <- data.frame(x = seq_len(sum(temp == s)), y = serie$sentimiento[temp == s])
    ggplot2::ggplot(d, ggplot2::aes(x, y)) +
      ggplot2::geom_line() + ggplot2::geom_point() +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = pmax(y, 0)),
                           fill = "blue", alpha = 0.5) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = pmin(y, 0), ymax = 0),
                           fill = "red", alpha = 0.5) +
      ggplot2::scale_x_continuous(breaks = d$x) +
      ggplot2::labs(x = "Capitulo de la temporada", y = "Sentimiento",
        title = paste("Sentimiento durante la temporada", s),
        subtitle = paste("Valor de la temporada:", round(sent_temp[s], 4))) +
      ggplot2::theme_minimal()
  }),
  "05_sentimiento_temporada", nrow = 2, ncol = 2)

save_fig_grid(
  lapply(sort(unique(temp)), function(s) {
    d <- data.frame(emotion_type = factor(tipos_emo, levels = rev(tipos_emo)),
                    ave_emotion = emociones_temp[s, ])
    ggplot2::ggplot(d, ggplot2::aes(emotion_type, ave_emotion, fill = emotion_type)) +
      ggplot2::geom_col(colour = "black", linewidth = 0.2) +
      ggplot2::scale_fill_manual(values = stats::setNames(
        grDevices::rainbow(length(tipos_emo)), rev(tipos_emo))) +
      ggplot2::coord_flip() + ggplot2::guides(fill = "none") +
      ggplot2::labs(title = paste("Emociones, temporada", s), x = NULL,
                    y = "Emocion promedio") +
      ggplot2::theme_minimal(base_size = 9)
  }),
  "05_emociones_temporada", nrow = 2, ncol = 2)

save_fig(plot_dendrograma(emociones_temp, rownames(emociones_temp), sort(unique(temp)),
  "Distancia euclidiana entre temporadas (emociones)", "euclidean",
  cex = 1.2, mar = c(4, 4, 1, 2)), "05_dendro_temporadas_euclidiana", height = 6)
save_fig(plot_corrplot(matriz_correlacion(emociones_temp, rownames(emociones_temp)),
  "Correlacion entre temporadas (emociones)", cex = 1.1),
  "05_corr_temporadas", width = 7, height = 6)

# --- curva de tendencia por tramos -------------------------------------------
# Cada capitulo se divide en el mismo numero de tramos de oraciones, lo que
# permite comparar temporadas de distinto largo sobre una escala comun.
n_tramos <- CFG$n_tramos_sentimiento
if (is.null(n_tramos)) {
  n_tramos <- min(vapply(serie$texto_en_orig, n_oraciones, integer(1)))
}
log_msg("tramos por capitulo para la curva de sentimiento: ", n_tramos)

tramos <- do.call(rbind, lapply(seq_len(n), function(i) {
  partes <- tramos_oraciones(serie$texto_en_orig[i], n_tramos)
  data.frame(season = temp[i], episode_id = serie$episode_id[i],
             tramo = seq_len(n_tramos),
             sentimiento = vapply(partes, function(p)
               if (is.na(p) || !nzchar(p)) NA_real_
               else sentimentr::sentiment_by(sentimentr::get_sentences(p))$ave_sentiment[1],
               numeric(1)))
}))

resumen_tramos <- dplyr::summarise(dplyr::group_by(tramos, season, tramo),
  media = mean(sentimiento, na.rm = TRUE),
  sd = stats::sd(sentimiento, na.rm = TRUE), .groups = "drop")
resumen_tramos$sd[is.na(resumen_tramos$sd)] <- 0

save_fig(
  ggplot2::ggplot(resumen_tramos, ggplot2::aes(tramo, media,
                                               colour = factor(season), fill = factor(season))) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = media - sd, ymax = media + sd),
                         alpha = 0.2, colour = NA) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::facet_wrap(~ season, labeller = ggplot2::labeller(season = function(x)
      paste("Temporada", x))) +
    ggplot2::scale_colour_manual(values = CFG$colores_temporada) +
    ggplot2::scale_fill_manual(values = CFG$colores_temporada) +
    ggplot2::guides(colour = "none", fill = "none") +
    ggplot2::labs(x = paste0("Tramo del capitulo (1 a ", n_tramos, ")"),
                  y = "Sentimiento medio",
                  title = "Tendencia del sentimiento a lo largo de cada temporada",
                  subtitle = "Banda: una desviacion estandar entre capitulos de la temporada") +
    ggplot2::theme_minimal(),
  "05_tendencia_sentimiento")

# --- exportes ----------------------------------------------------------------
write_table_out(data.frame(episode_id = serie$episode_id, title_es = etq,
                           season = temp, sentimiento = round(serie$sentimiento, 6),
                           round(emociones_cap, 6), check.names = FALSE),
                "05_sentimiento_emociones_capitulo")
write_table_out(data.frame(temporada = rownames(emociones_temp),
                           sentimiento = round(as.numeric(sent_temp), 6),
                           round(emociones_temp, 6), check.names = FALSE),
                "05_sentimiento_emociones_temporada")
write_table_out(tramos, "05_sentimiento_por_tramo")

save_step(list(serie = serie, emociones_cap = emociones_cap,
               emociones_temp = emociones_temp, sent_temp = sent_temp,
               tramos = tramos, tipos_emo = tipos_emo), "05_sentiment")
