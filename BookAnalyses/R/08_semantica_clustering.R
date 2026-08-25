# =============================================================================
# 08_semantica_clustering.R : espacio semantico LSA sobre TF-IDF, clustering
# jerarquico con soporte bootstrap, UMAP y contraste contra el curriculo.
#   Corrida principal: distancia chord (euclidea sobre vectores L2) + Ward.D2,
#   valida para Ward. Replica: distancia de correlacion + Ward, el stack del
#   paper de Papelucho, para comparabilidad.
# =============================================================================

set.seed(config$semilla)
tfidf <- P$tfidf
niv <- P$catalogo[, c("id_libro", "titulo", "nivel", "etapa")]
niv <- niv[match(rownames(tfidf), niv$id_libro), ]

# --- LSA ---------------------------------------------------------------------
k_lsa <- min(config$lsa_dim, nrow(tfidf) - 2, ncol(tfidf) - 2)
if (k_lsa < 0.5 * min(dim(tfidf))) {
  sv <- irlba::irlba(tfidf, nv = k_lsa)
} else {
  svb <- svd(as.matrix(tfidf), nu = k_lsa, nv = 0)
  sv <- list(u = svb$u, d = svb$d[seq_len(k_lsa)])
}
lsa <- sv$u %*% diag(sv$d)
rownames(lsa) <- rownames(tfidf)
nl <- sqrt(rowSums(lsa^2)); nl[nl == 0] <- 1
lsa_n <- lsa / nl
log_msg("LSA: ", k_lsa, " dimensiones, varianza singular acumulada = ",
        round(sum(sv$d^2) / sum(tfidf@x^2), 3))

cos_sim <- lsa_n %*% t(lsa_n)
d_sem <- stats::as.dist(sqrt(pmax(2 * (1 - cos_sim), 0)))   # chord

# --- clustering principal ----------------------------------------------------
hc <- stats::hclust(d_sem, method = "ward.D2")
etiquetas <- paste0(substr(niv$titulo, 1, 22), " (", niv$nivel, ")")
cols_etapa <- c("Basica inicial" = "#4477AA", "Basica superior" = "#DDAA33",
                "Media" = "#BB5566")

dend_pdf <- file.path(config$carpeta_salida, "figuras", "08_dendrograma_lsa")
for (dev in c("pdf", "png")) {
  if (dev == "pdf") grDevices::cairo_pdf(paste0(dend_pdf, ".pdf"), 12, 7)
  else grDevices::png(paste0(dend_pdf, ".png"), 3600, 2100, res = 300)
  par(mar = c(9, 3, 2, 1))
  plot(stats::as.dendrogram(hc), main = "Clustering semantico (LSA, chord, Ward.D2)",
       leaflab = "none")
  ord <- hc$order
  graphics::mtext(etiquetas[ord], side = 1, at = seq_along(ord), las = 2,
                  cex = 0.45, col = cols_etapa[as.character(niv$etapa[ord])],
                  line = 0.3)
  grDevices::dev.off()
}

# --- replica correlacion + Ward (comparabilidad con Papelucho) --------------
tf_dense <- as.matrix(tfidf)
d_cor <- stats::as.dist(1 - stats::cor(t(tf_dense)))
hc_cor <- stats::hclust(d_cor, method = "ward.D2")

# --- cortes, ARI, silueta ----------------------------------------------------
eval_corte <- function(hcl, d, nombre) {
  k12 <- stats::cutree(hcl, k = min(12, nrow(niv) - 1))
  k3 <- stats::cutree(hcl, k = 3)
  data.frame(
    espacio = nombre,
    ari_nivel_k12 = rand_ajustado(k12, niv$nivel),
    ari_etapa_k3 = rand_ajustado(k3, as.integer(niv$etapa)),
    silueta_k3 = mean(cluster::silhouette(k3, d)[, 3]),
    silueta_k12 = mean(cluster::silhouette(k12, d)[, 3]))
}
eval_tab <- rbind(eval_corte(hc, d_sem, "lsa_chord_ward"),
                  eval_corte(hc_cor, d_cor, "tfidf_correlacion_ward"))

# --- Mantel: distancia semantica vs distancia curricular --------------------
d_niv <- stats::dist(niv$nivel)
mt <- vegan::mantel(d_sem, d_niv, method = "spearman",
                    permutations = config$mantel_perm)
eval_tab$mantel_r <- mt$statistic
eval_tab$mantel_p <- mt$signif
guardar_tabla(eval_tab, "clustering_evaluacion")
log_msg("Mantel semantica vs nivel: r = ", round(mt$statistic, 3),
        ", p = ", mt$signif)

membresias <- data.frame(id_libro = rownames(tfidf),
                         cluster_lsa_k3 = stats::cutree(hc, 3),
                         cluster_lsa_k12 = stats::cutree(hc, min(12, nrow(niv) - 1)),
                         cluster_cor_k3 = stats::cutree(hc_cor, 3))
guardar_tabla(dplyr::inner_join(membresias, niv, by = "id_libro"),
              "clustering_membresias")

# --- pvclust: soporte bootstrap sobre el perfil de metricas -----------------
met <- P$comp_libro %>%
  dplyr::inner_join(P$gram_libro, by = "doc_id") %>%
  dplyr::inner_join(P$afect_libro, by = "doc_id")
num <- met %>% dplyr::select(dplyr::where(is.numeric)) %>%
  dplyr::select(dplyr::where(~ stats::sd(.x, na.rm = TRUE) > 0))
completos <- stats::complete.cases(num)
for (id in met$doc_id[!completos])
  registrar_advertencia("08_clustering", id,
    P$catalogo$titulo[P$catalogo$id_libro == id],
    "excluido del pvclust de metricas por NA (texto corto)", NA)
Mm <- t(scale(as.matrix(num[completos, ])))
colnames(Mm) <- met$doc_id[completos]
pv <- pvclust::pvclust(Mm, method.dist = "euclidean",
                       method.hclust = "ward.D2",
                       nboot = config$pvclust_nboot, quiet = TRUE)
for (dev in c("pdf", "png")) {
  base <- file.path(config$carpeta_salida, "figuras", "08_pvclust_metricas")
  if (dev == "pdf") grDevices::cairo_pdf(paste0(base, ".pdf"), 12, 7)
  else grDevices::png(paste0(base, ".png"), 3600, 2100, res = 300)
  plot(pv, cex = 0.5, cex.pv = 0.55,
       main = paste0("pvclust sobre perfil de metricas (nboot = ",
                     config$pvclust_nboot, ")"))
  pvclust::pvrect(pv, alpha = 0.90)
  grDevices::dev.off()
}

if (config$run_pvclust_lexico) {
  pv2 <- pvclust::pvclust(t(tf_dense), method.dist = "correlation",
                          method.hclust = "ward.D2",
                          nboot = config$pvclust_nboot, quiet = TRUE)
  base <- file.path(config$carpeta_salida, "figuras", "08_pvclust_tfidf")
  grDevices::cairo_pdf(paste0(base, ".pdf"), 12, 7)
  plot(pv2, cex = 0.5, cex.pv = 0.55); pvclust::pvrect(pv2, alpha = 0.90)
  grDevices::dev.off()
}

# --- UMAP --------------------------------------------------------------------
set.seed(config$semilla)
um <- uwot::umap(lsa_n, n_neighbors = min(config$umap_vecinos, nrow(lsa_n) - 1),
                 min_dist = 0.1, metric = "cosine")
umap_df <- data.frame(id_libro = rownames(lsa_n), U1 = um[, 1], U2 = um[, 2]) %>%
  dplyr::inner_join(niv, by = "id_libro")
p_um <- ggplot2::ggplot(umap_df,
    ggplot2::aes(U1, U2, colour = nivel, shape = etapa)) +
  ggplot2::geom_point(size = 2.6, alpha = 0.9) +
  ggplot2::scale_colour_viridis_c(breaks = c(1, 4, 8, 12)) +
  ggplot2::labs(title = "UMAP del espacio semantico LSA",
                x = "UMAP 1", y = "UMAP 2", colour = "Nivel", shape = "Etapa") +
  tema_pipeline()
guardar_fig(p_um, "08_umap_lsa", 8.5, 6.5)

P$lsa <- lsa_n
P$d_sem <- d_sem
P$membresias <- membresias
P$eval_clustering <- eval_tab
