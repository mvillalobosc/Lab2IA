# =====================================================================
# build_population(base_tree, n)
# ---------------------------------------------------------------------
# Generates an initial population of n trees by perturbing the
# base-tree distance matrix with small uniform noise (+-0.01).
# Returns: list of n phylo trees (the first one is the base tree).
# =====================================================================
build_population <- function(base_tree, n) {
  arboles <- vector("list", n)                 # preasignado (antes crecia con [[i]])
  arboles[[1]] <- base_tree
  arboles[[1]]$dist_original <- base_tree$dist_kmer

  for (i in 2:n) {
    # uniform noise on the k-mer distance matrix
    ruido <- runif(length(base_tree$dist_kmer), -0.01, 0.01)
    dist_new <- base_tree$dist_kmer + ruido
    dist_new[dist_new <= 0] <- 0

    tree <- NJ(dist_new)
    tree$dist_kmer     <- dist_new
    tree$dist_original <- base_tree$dist_kmer
    tree$edge.length[tree$edge.length < 0] <- 0
    tree <- multi2di(tree)
    tree <- midpoint(tree)
    arboles[[i]] <- tree
  }
  arboles
}
