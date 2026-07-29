# =====================================================================
# generate_random_tree(individual)
# ---------------------------------------------------------------------
# Returns a random NxN U(0,1) distance matrix used to inject
# diversity (completely random trees) into the population.
# =====================================================================
generate_random_tree <- function(individuo) {
  n <- nrow(individuo$dist_kmer)
  M <- matrix(runif(n * n), ncol = n)
  M <- (M + t(M)) / 2   # symmetric (valid distance matrix)
  diag(M) <- 0          # diagonal nula
  M
}
