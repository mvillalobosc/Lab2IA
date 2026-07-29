# =====================================================================
# build_base_tree(sequences, k)  ·  k-mer distance + NJ + cleanup
#   (k is honoured; it used to be hard-coded to 5)
# =====================================================================
build_base_tree <- function(sequences, k = 5) {
  distancia <- as.matrix(kdistance(sequences, k = k))
  tree <- NJ(distancia)
  tree$edge.length[tree$edge.length < 0] <- 0
  tree <- multi2di(tree)
  tree <- midpoint(tree)
  tree$dist_kmer     <- distancia
  tree$dist_original <- distancia   # data_list observados (fijos) para el LS
  tree
}
