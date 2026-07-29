# =====================================================================
# build_base_tree(sequences, k)
# ---------------------------------------------------------------------
# Builds the alignment-free base (seed) tree:
#   1. k-mer distance matrix,
#   2. Neighbour Joining,
#   3. cleanup (negative edges, multifurcations, midpoint rooting).
#   k : k-mer word length (honoured; it used to be hard-coded to 5).
# Returns: a phylo object with $dist_kmer attached.
# =====================================================================
build_base_tree <- function(sequences, k = 5) {
  distancia <- as.matrix(kdistance(sequences, k = k))   # <- usa k real
  tree <- NJ(distancia)
  tree$edge.length[tree$edge.length < 0] <- 0          # aristas negativas -> 0
  tree <- multi2di(tree)                               # binariza multifurcaciones
  tree <- midpoint(tree)                               # enraiza por midpoint
  tree$dist_kmer <- distancia
  tree
}
