# =============================================================================
# 04_topics.R  Frecuencia y relevancia de los 16 temas
# =============================================================================
# Cambios respecto al original:
#  - La asignacion palabra -> tema usaba temas_palabra$tema[temas_palabra$palabra == p]
#    dentro de un bucle anidado sobre capitulos y rasgos, del orden de 1.2e5
#    subconjuntos de data.frame. Aqui se resuelve con un vector nombrado.
#  - if (is.na(temas_cap[i, tema])) fallaba con error, no con aviso, cuando la
#    palabra no estaba en el lexico: en R >= 4.2 una condicion de largo cero es
#    un error. Ahora las palabras sin tema se agrupan y se reportan.
#  - Se elimino la duplicacion de los chunks test33 y test342, que repetian el
#    mismo analisis de keyness por temporada.
# =============================================================================

log_step("04  Temas")

cl    <- load_step("02_clean")
fr    <- load_step("03_frequency")
serie <- cl$serie
n     <- nrow(serie)
etq   <- serie$title_es
temp  <- serie$season
temas <- cl$temas

# --- matriz capitulo x tema --------------------------------------------------
# Se agrega la frecuencia de cada palabra al tema que le corresponde.
tema_de <- cl$mapa_tema[colnames(fr$frecuencias)]
sin_tema_col <- is.na(tema_de)
if (any(sin_tema_col)) {
  log_msg("aviso: ", sum(sin_tema_col), " rasgo(s) sin tema, agrupados como '",
          CFG$tema_sin_definir, "': ",
          paste(utils::head(colnames(fr$frecuencias)[sin_tema_col], 10), collapse = ", "))
  tema_de[sin_tema_col] <- CFG$tema_sin_definir
}

agrega_por_tema <- function(mat) {
  m <- t(rowsum(t(as.matrix(mat)), group = tema_de))
  faltantes <- setdiff(temas, colnames(m))
  if (length(faltantes)) {
    m <- cbind(m, matrix(0, nrow(m), length(faltantes),
                         dimnames = list(NULL, faltantes)))
  }
  m[, temas, drop = FALSE]   # se descarta la columna "sin definir"
}

temas_cap  <- agrega_por_tema(fr$frecuencias)
temas_temp <- agrega_por_tema(fr$frec_temp)
rownames(temas_cap)  <- serie$episode_id
rownames(temas_temp) <- rownames(fr$frec_temp)

log_msg("matriz de temas: ", nrow(temas_cap), " capitulos x ", ncol(temas_cap), " temas")
log_msg("cobertura tematica: ",
        round(100 * sum(temas_cap) / sum(fr$frecuencias), 1),
        "% de los tokens quedan en un tema definido")

# --- radar charts ------------------------------------------------------------
radar_df <- function(fila, maxv) {
  as.data.frame(rbind(rep(maxv, ncol(temas_cap)), rep(0, ncol(temas_cap)), fila))
}

save_radar <- function(mat, nombres, colores, archivo, maxv) {
  paginas <- split(seq_len(nrow(mat)), ceiling(seq_len(nrow(mat)) / 4))
  for (i in seq_along(paginas)) {
    sfx <- if (length(paginas) > 1) sprintf("_p%02d", i) else ""
    grDevices::png(file.path(CFG$dir_figures, paste0(archivo, sfx, ".png")),
                   width = CFG$fig_width, height = CFG$fig_height,
                   units = "in", res = CFG$fig_dpi)
    graphics::par(mfrow = c(2, 2), mar = c(0, 0, 2, 0) + 0.7)
    for (k in paginas[[i]]) {
      d <- radar_df(mat[k, ], maxv)
      colnames(d) <- colnames(mat)
      fmsb::radarchart(d, cglty = 1, cglcol = "gray", pcol = colores[k],
                       plwd = 2, plty = 1, vlcex = 0.8,
                       pfcol = scales::alpha(colores[k], 0.3))
      graphics::title(nombres[k])
    }
    grDevices::dev.off()
  }
  log_msg("figura: outputs/figures/", archivo, " (", length(paginas), " pagina(s))")
}

save_radar(temas_cap, etq, CFG$colores_temporada[temp],
           "04_radar_temas_capitulo", max(temas_cap))
save_radar(temas_temp, rownames(temas_temp),
           CFG$colores_temporada[seq_len(nrow(temas_temp))],
           "04_radar_temas_temporada", max(temas_temp))

# --- keyness sobre temas -----------------------------------------------------
# Se reconstruye un pseudo-texto donde cada tema aparece tantas veces como su
# frecuencia agregada, que es lo que espera textstat_keyness.
dfm_de_matriz <- function(mat, docvars) {
  txt <- apply(mat, 1, function(fila)
    paste(rep(abreviar_temas(colnames(mat)), times = as.integer(fila)), collapse = " "))
  quanteda::dfm(quanteda::tokens(quanteda::corpus(txt, docvars = docvars)))
}

dfm_tema_cap  <- dfm_de_matriz(temas_cap,
                               data.frame(episode_id = serie$episode_id, season = temp))
dfm_tema_temp <- dfm_de_matriz(temas_temp,
                               data.frame(season = as.integer(sub("Temporada ", "",
                                                                  rownames(temas_temp)))))

keyness_tema_cap <- lapply(seq_len(n), function(i)
  keyness_de(dfm_tema_cap, quanteda::docvars(dfm_tema_cap, "episode_id") == serie$episode_id[i]))

save_fig_grid(
  lapply(seq_len(n), function(i)
    quanteda.textplots::textplot_keyness(keyness_tema_cap[[i]], labelsize = 3,
      margin = 0.6, color = c(CFG$colores_temporada[temp[i]], "gray")) +
      ggplot2::ggtitle(etq[i])),
  "04_keyness_temas_capitulo", nrow = 2, ncol = 2)

save_fig_grid(
  lapply(sort(unique(temp)), function(s)
    quanteda.textplots::textplot_keyness(
      keyness_de(dfm_tema_temp, quanteda::docvars(dfm_tema_temp, "season") == s),
      labelsize = 3, margin = 0.6,
      color = c(CFG$colores_temporada[s], "gray")) +
      ggplot2::ggtitle(paste("Temporada", s))),
  "04_keyness_temas_temporada", nrow = 2, ncol = 2)

# --- distancias --------------------------------------------------------------
save_fig(plot_dendrograma(temas_cap, etq, temp,
  "Distancia euclidiana entre capitulos (temas)", "euclidean"),
  "04_dendro_capitulos_euclidiana")
save_fig(plot_dendrograma(temas_cap, etq, temp,
  "Distancia de correlacion de Pearson entre capitulos (temas)", "pearson"),
  "04_dendro_capitulos_pearson")
save_fig(plot_corrplot(matriz_correlacion(temas_cap, etq),
  "Correlacion entre capitulos (temas)"), "04_corr_capitulos", width = 12, height = 11)

cl_tema <- clusters_mst_knn(temas_cap)
save_fig(plot_clusters_mst_knn(cl_tema), "04_clusters_capitulos", width = 14, height = 7)
write_table_out(tabla_clusters(cl_tema, etq), "04_clusters_capitulos")

save_fig(plot_dendrograma(temas_temp, rownames(temas_temp), sort(unique(temp)),
  "Distancia euclidiana entre temporadas (temas)", "euclidean",
  cex = 1.2, mar = c(4, 4, 1, 2)), "04_dendro_temporadas_euclidiana", height = 6)
save_fig(plot_dendrograma(temas_temp, rownames(temas_temp), sort(unique(temp)),
  "Distancia de correlacion de Pearson entre temporadas (temas)", "pearson",
  cex = 1.2, mar = c(4, 4, 1, 2)), "04_dendro_temporadas_pearson", height = 6)
save_fig(plot_corrplot(matriz_correlacion(temas_temp, rownames(temas_temp)),
  "Correlacion entre temporadas (temas)", cex = 1.1),
  "04_corr_temporadas", width = 7, height = 6)

# --- exportes ----------------------------------------------------------------
write_table_out(data.frame(episode_id = rownames(temas_cap), title_es = etq,
                           season = temp, temas_cap, check.names = FALSE),
                "04_temas_por_capitulo")
write_table_out(data.frame(temporada = rownames(temas_temp), temas_temp,
                           check.names = FALSE), "04_temas_por_temporada")

# Proporcion de cada tema dentro del capitulo. Normaliza el largo desigual de
# los capitulos y es la forma en que los temas entran al modelo de popularidad.
temas_cap_pct <- temas_cap / rowSums(temas_cap)
write_table_out(data.frame(episode_id = rownames(temas_cap), title_es = etq,
                           round(temas_cap_pct, 5), check.names = FALSE),
                "04_temas_por_capitulo_proporcion")

save_step(list(temas_cap = temas_cap, temas_temp = temas_temp,
               temas_cap_pct = temas_cap_pct,
               keyness_tema_cap = keyness_tema_cap), "04_topics")
