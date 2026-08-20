# =============================================================================
# stats_helpers.R  Distancias, dendrogramas, clustering y keyness
# =============================================================================

# Matriz de frecuencias -> keyness chi-cuadrado de un documento contra el resto.
# Devuelve el objeto textstat_keyness completo.
keyness_de <- function(dfmat, target_lgl) {
  quanteda.textstats::textstat_keyness(dfmat, target = target_lgl)
}

# Dendrograma coloreado por temporada, guardado como PNG.
plot_dendrograma <- function(mat, etiquetas, grupos, titulo, metodo = "euclidean",
                             cex = 0.71, mar = c(12, 4, 1, 2)) {
  # Se descartan los nombres de fila para que las etiquetas del dendrograma
  # sean indices posicionales. Con rownames presentes, as.integer(labels(dend))
  # devuelve NA y el coloreado por temporada queda mal asignado.
  mat <- as.matrix(mat)
  rownames(mat) <- NULL
  d <- if (identical(metodo, "pearson")) amap::Dist(mat, method = "pearson")
       else stats::dist(mat, method = metodo)
  dend <- stats::as.dendrogram(stats::hclust(d, method = "ward.D2"))
  idx <- as.integer(labels(dend))
  stopifnot(!anyNA(idx), length(idx) == nrow(mat))
  dend <- dendextend::color_labels(dend, col = CFG$colores_dendro[grupos[idx]])
  labels(dend) <- etiquetas[idx]
  dendextend::labels_cex(dend) <- cex
  function() {
    graphics::par(mar = mar + 0.1)
    graphics::plot(dend, main = titulo)
  }
}

# Matriz de correlacion de Pearson entre filas, con nombres legibles.
matriz_correlacion <- function(mat, etiquetas, metodo = "pearson") {
  cm <- stats::cor(t(as.matrix(mat)), method = metodo)
  rownames(cm) <- etiquetas
  colnames(cm) <- etiquetas
  cm
}

plot_corrplot <- function(cm, titulo, cex = 0.9, is_corr = TRUE) {
  function() {
    corrplot::corrplot(cm, method = "square", type = "upper", tl.col = "black",
                       tl.cex = cex, title = paste0("\n", titulo),
                       mar = c(1, 1, 2, 1) + 0.1, is.corr = is_corr,
                       col.lim = if (is_corr) NULL else c(min(cm), max(cm)))
  }
}

# Clustering MST-kNN sobre una matriz de distancias, con ambas metricas.
clusters_mst_knn <- function(mat) {
  mat <- as.matrix(mat); rownames(mat) <- NULL
  list(
    euclidiana = mstknnclust::mst.knn(as.matrix(stats::dist(mat, method = "euclidean"))),
    pearson    = mstknnclust::mst.knn(as.matrix(amap::Dist(mat, method = "pearson")))
  )
}

plot_clusters_mst_knn <- function(res) {
  function() {
    graphics::par(mfrow = c(1, 2))
    for (nm in names(res)) {
      r <- res[[nm]]
      graphics::plot(
        r$network, vertex.size = 16,
        vertex.color = igraph::components(r$network)$membership,
        layout = igraph::layout_with_fr(r$network, niter = 10000),
        main = paste0("MST-kNN (", nm, ")\nN clusters = ", r$cnumber)
      )
    }
    graphics::par(mfrow = c(1, 1))
  }
}

# Tabla larga con la asignacion de cluster de cada elemento.
tabla_clusters <- function(res, etiquetas) {
  do.call(rbind, lapply(names(res), function(nm) {
    m <- igraph::components(res[[nm]]$network)$membership
    data.frame(metrica = nm, elemento = etiquetas[as.integer(names(m))],
               cluster = as.integer(m), row.names = NULL)
  }))
}

# Reescala a [0, 1]. Devuelve 0 si el vector es constante, en lugar de NaN.
rescale01 <- function(x) {
  r <- range(x, na.rm = TRUE)
  if (!is.finite(r[1]) || !is.finite(r[2]) || r[1] == r[2]) return(rep(0, length(x)))
  (x - r[1]) / (r[2] - r[1])
}
