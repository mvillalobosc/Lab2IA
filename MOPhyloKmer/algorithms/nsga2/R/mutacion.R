# =====================================================================
# mutation(rate, individual)
# ---------------------------------------------------------------------
# Element-wise mutation of the distance matrix: with
# probability `rate`, noise U(-rate, rate) is added.
# Vectorised with a logical mask (previously a double for loop).
# =====================================================================
mutation <- function(porcentaje, individuo) {
  if (porcentaje < 0 || porcentaje > 1)
    stop("El porcentaje de mutation debe estar en [0, 1].")

  M <- individuo$dist_kmer
  mascara <- matrix(runif(length(M)) < porcentaje, nrow = nrow(M))
  ruido   <- matrix(runif(length(M), -porcentaje, porcentaje), nrow = nrow(M))
  M[mascara] <- M[mascara] + ruido[mascara]
  M[M < 0] <- 0
  M[M > 1] <- 1
  M
}
