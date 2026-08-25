# =============================================================================
# 05_afectivo.R : analisis afectivo con lexicon NRC en espanol (via syuzhet).
# Emparejamiento rapido por join sobre los tokens de udpipe: primero forma
# superficial, luego lema para lo no emparejado. Arcos emocionales por DCT.
# =============================================================================

nrc <- syuzhet::get_sentiment_dictionary(dictionary = "nrc", language = "spanish")
nrc <- nrc[, c("word", "sentiment")]
nrc$word <- stringi::stri_trans_nfc(stringi::stri_trans_tolower(nrc$word))
log_msg("Lexicon NRC-es: ", length(unique(nrc$word)), " palabras, ",
        length(unique(nrc$sentiment)), " categorias")

pal <- P$anot[P$anot$es_palabra, c("doc_id", "oracion_uid", "token_lower",
                                   "lemma_lower")]

# match por token; para tokens sin match, por lema
m_tok <- dplyr::inner_join(pal, nrc, by = c("token_lower" = "word"),
                           relationship = "many-to-many")
sin <- dplyr::anti_join(pal, nrc, by = c("token_lower" = "word"))
m_lem <- dplyr::inner_join(sin, nrc, by = c("lemma_lower" = "word"),
                           relationship = "many-to-many")
matches <- dplyr::bind_rows(m_tok, m_lem)

emo_ora <- matches %>%
  dplyr::count(doc_id, oracion_uid, sentiment) %>%
  tidyr::pivot_wider(names_from = sentiment, values_from = n, values_fill = 0)
cats <- c("anger", "anticipation", "disgust", "fear", "joy", "sadness",
          "surprise", "trust", "positive", "negative")
for (cc in setdiff(cats, colnames(emo_ora))) emo_ora[[cc]] <- 0

oraciones <- P$oraciones %>%
  dplyr::left_join(emo_ora, by = c("doc_id", "oracion_uid"))
oraciones[cats][is.na(oraciones[cats])] <- 0
oraciones$polaridad <- oraciones$positive - oraciones$negative
oraciones$polaridad_norm <- oraciones$polaridad / pmax(1, oraciones$n_tokens)

# --- agregados por libro -----------------------------------------------------
emos8 <- c("anger", "anticipation", "disgust", "fear", "joy", "sadness",
           "surprise", "trust")
afect_libro <- oraciones %>%
  dplyr::group_by(doc_id) %>%
  dplyr::summarise(
    n_oraciones_af = dplyr::n(),
    polaridad_media = mean(polaridad_norm),
    polaridad_sd = stats::sd(polaridad_norm),
    prop_oraciones_negativas = mean(polaridad < 0),
    dplyr::across(dplyr::all_of(emos8), sum, .names = "n_{.col}"),
    .groups = "drop")
tot8 <- rowSums(afect_libro[paste0("n_", emos8)])
for (e in emos8)
  afect_libro[[paste0("prop_", switch(e, joy = "alegria", sadness = "tristeza",
    fear = "miedo", anger = "ira", disgust = "asco", surprise = "sorpresa",
    trust = "confianza", anticipation = "anticipacion"))]] <-
    afect_libro[[paste0("n_", e)]] / pmax(1, tot8)
guardar_tabla(afect_libro, "afectivo_por_libro")

# --- figura: polaridad y emociones por nivel --------------------------------
niv <- P$catalogo[, c("id_libro", "nivel", "etapa")]
af_niv <- afect_libro %>% dplyr::inner_join(niv, by = c("doc_id" = "id_libro"))

p_pol <- ggplot2::ggplot(af_niv, ggplot2::aes(nivel, polaridad_media)) +
  capas_etapas() +
  ggplot2::geom_jitter(width = 0.12, alpha = 0.5, size = 1.6) +
  ggplot2::stat_summary(fun = mean, geom = "line", colour = "#B2182B",
                        linewidth = 1) +
  ggplot2::stat_summary(fun = mean, geom = "point", colour = "#B2182B", size = 2) +
  ggplot2::geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::scale_fill_manual(values = c("#88CCEE", "#DDCC77", "#CC6677")) +
  ggplot2::labs(title = "Polaridad media por libro y nivel (NRC-es)",
                x = "Nivel", y = "Polaridad media normalizada", fill = "Etapa") +
  tema_pipeline()
guardar_fig(p_pol, "05_polaridad_por_nivel", 9, 5.5)

emo_larga <- af_niv %>%
  dplyr::select(nivel, dplyr::starts_with("prop_")) %>%
  dplyr::select(-dplyr::any_of("prop_oraciones_negativas")) %>%
  tidyr::pivot_longer(-nivel, names_to = "emocion", values_to = "prop") %>%
  dplyr::mutate(emocion = sub("^prop_", "", emocion)) %>%
  dplyr::group_by(nivel, emocion) %>%
  dplyr::summarise(prop = mean(prop), .groups = "drop")
p_emo <- ggplot2::ggplot(emo_larga, ggplot2::aes(nivel, prop, colour = emocion)) +
  capas_etapas() +
  ggplot2::geom_line(linewidth = 0.8) +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::scale_fill_manual(values = c("#88CCEE", "#DDCC77", "#CC6677"),
                             guide = "none") +
  ggplot2::labs(title = "Proporcion media de emociones NRC por nivel",
                x = "Nivel", y = "Proporcion sobre palabras emocionales") +
  tema_pipeline()
guardar_fig(p_emo, "05_emociones_por_nivel", 9, 5.5)

# --- arcos emocionales (DCT, 100 puntos) ------------------------------------
series <- split(oraciones[order(oraciones$doc_id, oraciones$orden), ],
                oraciones$doc_id[order(oraciones$doc_id, oraciones$orden)])
arcos <- list()
for (id in names(series)) {
  s <- series[[id]]$polaridad
  if (length(s) < config$min_oraciones_arco) {
    registrar_exclusion("05_afectivo_arcos", id,
      P$catalogo$titulo[P$catalogo$id_libro == id],
      paste0("menos de ", config$min_oraciones_arco,
             " oraciones para arco DCT"), length(s))
    next
  }
  if (stats::sd(s) == 0) {
    # sin variacion no hay arco: cero coincidencias con el lexico NRC
    # (texto no espanol o extraccion corrupta) o polaridad identica siempre
    registrar_exclusion("05_afectivo_arcos", id,
      P$catalogo$titulo[P$catalogo$id_libro == id],
      "polaridad constante: sin arco (revisar idioma o extraccion)",
      unique(s)[1])
    next
  }
  arco <- syuzhet::get_dct_transform(s, low_pass_size = 5,
                                     x_reverse_len = 100,
                                     scale_range = TRUE)
  if (any(!is.finite(arco))) {
    registrar_exclusion("05_afectivo_arcos", id,
      P$catalogo$titulo[P$catalogo$id_libro == id],
      "arco DCT no finito", NA)
    next
  }
  arcos[[id]] <- arco
}
if (length(arcos) >= 4) {
  M <- do.call(rbind, arcos)
  set.seed(config$semilla)
  kmax <- min(6, nrow(M) - 1)
  sil <- sapply(2:kmax, function(k) {
    km <- stats::kmeans(M, centers = k, nstart = 10)
    mean(cluster::silhouette(km$cluster, stats::dist(M))[, 3])
  })
  k_opt <- (2:kmax)[which.max(sil)]
  km <- stats::kmeans(M, centers = k_opt, nstart = 25)
  arcos_df <- data.frame(id_libro = rownames(M), cluster_arco = km$cluster)
  guardar_tabla(dplyr::inner_join(arcos_df, niv,
                                  by = c("id_libro" = "id_libro")),
                "arcos_clusters")
  log_msg("Arcos: k optimo por silueta = ", k_opt)

  arc_larga <- as.data.frame(M) %>%
    dplyr::mutate(id_libro = rownames(M), cluster = factor(km$cluster)) %>%
    tidyr::pivot_longer(-c(id_libro, cluster), names_to = "p",
                        values_to = "valor") %>%
    dplyr::mutate(p = as.integer(sub("^V", "", p)))
  p_arc <- ggplot2::ggplot(arc_larga, ggplot2::aes(p, valor, group = id_libro)) +
    ggplot2::geom_line(alpha = 0.25, colour = "grey55") +
    ggplot2::stat_summary(ggplot2::aes(group = cluster, colour = cluster),
                          fun = mean, geom = "line", linewidth = 1.2) +
    ggplot2::facet_wrap(~cluster) +
    ggplot2::labs(title = "Arcos emocionales (DCT 100 puntos) por cluster",
                  x = "Tiempo narrativo (%)", y = "Polaridad escalada") +
    tema_pipeline()
  guardar_fig(p_arc, "05_arcos_clusters", 10, 6)

  prop_arc <- dplyr::inner_join(arcos_df, niv, by = "id_libro") %>%
    dplyr::count(etapa, cluster_arco) %>%
    dplyr::group_by(etapa) %>% dplyr::mutate(prop = n / sum(n)) %>%
    dplyr::ungroup()
  guardar_tabla(prop_arc, "arcos_proporcion_por_etapa")
  P$arcos <- arcos_df
} else {
  log_msg("Arcos: menos de 4 libros con largo suficiente, se omite clustering")
  P$arcos <- NULL
}

P$oraciones_afect <- oraciones
P$afect_libro <- afect_libro
