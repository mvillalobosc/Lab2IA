# =====================================================================
# perturb_tree(tree)  ·  MOSA neighbour: scales the matrix by U(0.9,1.1)
# =====================================================================
perturb_tree <- function(tree) {
  factor    <- runif(length(tree$dist_kmer), 0.9, 1.1)
  dist_new  <- tree$dist_kmer * factor
  dist_new[dist_new <= 0] <- 0.00001
  new_tree <- NJ(dist_new)
  new_tree$dist_kmer     <- dist_new
  new_tree$dist_original <- tree$dist_original   # the fixed reference is preserved
  new_tree$edge.length[new_tree$edge.length < 0] <- 0
  new_tree <- multi2di(new_tree)
  midpoint(new_tree)
}
