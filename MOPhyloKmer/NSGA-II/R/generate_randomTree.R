# =====================================================================
# generate_randomTree(individuo)
# ---------------------------------------------------------------------
# Devuelve una matriz de distancias NxN aleatoria U(0,1) para inyectar
# diversidad (arboles totalmente aleatorios) en la poblacion.
# =====================================================================
generate_randomTree <- function(individuo) {
  n <- nrow(individuo$dist_kmer)
  M <- matrix(runif(n * n), ncol = n)
  M <- (M + t(M)) / 2   # simetrica (matriz de distancias valida)
  diag(M) <- 0          # diagonal nula
  M
}
