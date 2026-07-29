# =====================================================================
# crossover(padre1, padre2, porcentaje)
# ---------------------------------------------------------------------
# Weighted crossover of two k-mer distance matrices.
#   child = w * parent1 + (1 - w) * parent2, clipped to [0, 1].
# Vectorised: replaces the original double for loop with a single
# matrix operation (much faster on large data sets).
# =====================================================================
crossover <- function(padre1, padre2, porcentaje) {
  w <- min(max(porcentaje, 0), 1)
  hija <- w * padre1$dist_kmer + (1 - w) * padre2$dist_kmer
  hija[hija < 0] <- 0
  hija[hija > 1] <- 1
  hija
}
