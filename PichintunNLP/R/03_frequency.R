# =============================================================================
# 03_frequency.R  Frecuencia de palabras por capitulo y por temporada
# =============================================================================
# Cambios respecto al original:
#  - Los bloques de temporada dejan de estar codificados como rangos fijos de
#    filas (1:6, 7:16, 17:26, 27:34). Se derivan de la columna season, que es
#    lo unico que garantiza que agregar un capitulo no corrompa los resultados.
#  - La matriz de frecuencias se construye directamente desde la dfm, en vez de
#    acumularse con rbind dentro del bucle de keyness.
# =============================================================================

log_step("03  Frecuencia de palabras")

cl    <- load_step("02_clean")
serie <- cl$serie
n     <- nrow(serie)
etq   <- serie$title_es
temp  <- serie$season
bloques <- split(seq_len(n), temp)

# --- corpus de todas las palabras (generico + cultural) por capitulo ---------
tokens_cap <- lapply(seq_len(n), function(i)
  c(serie$pal_generico[[i]], serie$pal_cultural[[i]]))

corp <- quanteda::corpus(vapply(tokens_cap, paste, character(1), collapse = " "),
                         docvars = data.frame(episode_id = serie$episode_id,
                                              season = temp, title = etq))
dfmat_cap <- quanteda::dfm(quanteda::tokens(corp))

# Matriz capitulo x palabra en orden alfabetico de rasgo. Es la base de todas
# las distancias entre capitulos de este modulo.
frecuencias <- as.matrix(dfmat_cap)[, order(quanteda::featnames(dfmat_cap)), drop = FALSE]
rownames(frecuencias) <- serie$episode_id

log_msg("dfm capitulos: ", nrow(frecuencias), " x ", ncol(frecuencias), " rasgos")

# --- keyness por capitulo ----------------------------------------------------
keyness_cap <- lapply(seq_len(n), function(i)
  keyness_de(dfmat_cap, quanteda::docvars(dfmat_cap, "episode_id") == serie$episode_id[i]))
names(keyness_cap) <- serie$episode_id

save_fig_grid(
  lapply(seq_len(n), function(i)
    quanteda.textplots::textplot_keyness(keyness_cap[[i]], labelsize = 3, n = 10,
      margin = 1, color = c(CFG$colores_temporada[temp[i]], "gray")) +
      ggplot2::ggtitle(etq[i])),
  "03_keyness_palabras_capitulo", nrow = 2, ncol = 2)

# --- nubes de palabras por capitulo -----------------------------------------
save_fig_grid(
  lapply(seq_len(n), function(i) {
    fr <- sort(table(tokens_cap[[i]]), decreasing = TRUE)
    ggwordcloud::ggwordcloud(names(fr), as.integer(fr), min.freq = 1,
      scale = c(3, 0.22), random.color = TRUE, random.order = FALSE,
      colors = CFG$paleta_nube) + ggplot2::ggtitle(etq[i])
  }),
  "03_nube_capitulo", nrow = 2, ncol = 2)

# --- composicion lexica por capitulo ----------------------------------------
comp <- tidyr::pivot_longer(
  data.frame(title = etq, season = temp,
             `Espanol generico` = serie$n_generico,
             `Cultural/modismos` = serie$n_cultural, check.names = FALSE),
  cols = c("Espanol generico", "Cultural/modismos"),
  names_to = "categoria", values_to = "n")

save_fig(
  ggplot2::ggplot(comp, ggplot2::aes(x = stats::reorder(title, n), y = n,
                                     fill = categoria)) +
    ggplot2::geom_col(position = "fill", colour = "black", linewidth = 0.2) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::percent) +
    ggplot2::scale_fill_manual(values = c("#008B8B", "#EE2C2C")) +
    ggplot2::labs(x = NULL, y = "Proporcion de tokens", fill = NULL,
                  title = "Espanol generico frente a lexico cultural por capitulo") +
    ggplot2::theme_minimal(),
  "03_composicion_lexica", height = 9)

# --- distancias entre capitulos ---------------------------------------------
save_fig(plot_dendrograma(frecuencias, etq, temp,
  "Distancia euclidiana entre capitulos (frecuencia de palabras)", "euclidean"),
  "03_dendro_capitulos_euclidiana")
save_fig(plot_dendrograma(frecuencias, etq, temp,
  "Distancia de correlacion de Pearson entre capitulos (frecuencia de palabras)", "pearson"),
  "03_dendro_capitulos_pearson")

cm_cap <- matriz_correlacion(frecuencias, etq)
save_fig(plot_corrplot(cm_cap, "Correlacion entre capitulos (frecuencia de palabras)"),
         "03_corr_capitulos", width = 12, height = 11)

cl_cap <- clusters_mst_knn(frecuencias)
save_fig(plot_clusters_mst_knn(cl_cap), "03_clusters_capitulos", width = 14, height = 7)
write_table_out(tabla_clusters(cl_cap, etq), "03_clusters_capitulos")

# --- nivel temporada ---------------------------------------------------------
frec_temp <- do.call(rbind, lapply(bloques, function(idx) colSums(frecuencias[idx, , drop = FALSE])))
rownames(frec_temp) <- paste("Temporada", names(bloques))

for (campo in c("pal_generico", "pal_cultural")) {
  etiqueta <- if (campo == "pal_generico") "espanol generico" else "cultural/modismos"
  sfx      <- if (campo == "pal_generico") "generico" else "cultural"

  largo <- do.call(rbind, lapply(seq_len(n), function(i) {
    w <- serie[[campo]][[i]]
    if (!length(w)) return(NULL)
    data.frame(season = temp[i], word = w)
  }))

  corp_t <- quanteda::corpus(
    vapply(split(largo$word, largo$season), paste, character(1), collapse = " "),
    docvars = data.frame(season = as.integer(names(split(largo$word, largo$season)))))
  dfmat_t <- quanteda::dfm(quanteda::tokens(corp_t))

  save_fig_grid(
    lapply(sort(unique(temp)), function(s) {
      fr <- sort(table(largo$word[largo$season == s]), decreasing = TRUE)
      ggwordcloud::ggwordcloud(names(fr), as.integer(fr), min.freq = 1,
        scale = c(5, 0.38), random.color = TRUE, random.order = FALSE,
        colors = CFG$paleta_nube) +
        ggplot2::ggtitle(paste0("Temporada ", s, ": ", etiqueta))
    }),
    paste0("03_nube_temporada_", sfx), nrow = 2, ncol = 2)

  save_fig_grid(
    lapply(sort(unique(temp)), function(s)
      quanteda.textplots::textplot_keyness(
        keyness_de(dfmat_t, quanteda::docvars(dfmat_t, "season") == s),
        labelsize = 4, n = 10, margin = 0.6,
        color = c(CFG$colores_temporada[s], "gray")) +
        ggplot2::ggtitle(paste0("Temporada ", s, ": ", etiqueta))),
    paste0("03_keyness_temporada_", sfx), nrow = 2, ncol = 2)

  assign(paste0("keyness_temp_", sfx),
         stats::setNames(lapply(sort(unique(temp)), function(s)
           keyness_de(dfmat_t, quanteda::docvars(dfmat_t, "season") == s)),
           paste0("T", sort(unique(temp)))))
}

save_fig(plot_dendrograma(frec_temp, rownames(frec_temp), sort(unique(temp)),
  "Distancia euclidiana entre temporadas (frecuencia de palabras)", "euclidean",
  cex = 1.2, mar = c(4, 4, 1, 2)), "03_dendro_temporadas_euclidiana", height = 6)
save_fig(plot_dendrograma(frec_temp, rownames(frec_temp), sort(unique(temp)),
  "Distancia de correlacion de Pearson entre temporadas (frecuencia de palabras)", "pearson",
  cex = 1.2, mar = c(4, 4, 1, 2)), "03_dendro_temporadas_pearson", height = 6)
save_fig(plot_corrplot(matriz_correlacion(frec_temp, rownames(frec_temp)),
  "Correlacion entre temporadas (frecuencia de palabras)", cex = 1.1),
  "03_corr_temporadas", width = 7, height = 6)

# --- exportes ----------------------------------------------------------------
top_cap <- do.call(rbind, lapply(seq_len(n), function(i) {
  k <- keyness_cap[[i]]
  k <- k[order(-k$chi2), ][seq_len(min(15, nrow(k))), ]
  data.frame(episode_id = serie$episode_id[i], title_es = etq[i], season = temp[i],
             rank = seq_len(nrow(k)), feature = k$feature,
             chi2 = round(k$chi2, 3), p = signif(k$p, 3),
             n_target = k$n_target, n_reference = k$n_reference)
}))
write_table_out(top_cap, "03_keyness_top15_capitulo")
write_table_out(data.frame(episode_id = rownames(frecuencias), frecuencias,
                           check.names = FALSE), "03_matriz_frecuencias")
write_table_out(data.frame(temporada = rownames(frec_temp), frec_temp,
                           check.names = FALSE), "03_frecuencias_temporada")

save_step(list(frecuencias = frecuencias, frec_temp = frec_temp,
               keyness_cap = keyness_cap, bloques = bloques,
               keyness_temp_generico = keyness_temp_generico,
               keyness_temp_cultural = keyness_temp_cultural), "03_frequency")
