# =====================================================================
# crossover(padre1, padre2, porcentaje)
# ---------------------------------------------------------------------
# Cruce ponderado de dos matrices de distancia k-mer.
#   hija = w * padre1 + (1 - w) * padre2,  recortada a [0, 1].
# VECTORIZADO: reemplaza el doble bucle for i/j original por una unica
# operacion matricial (mucho mas rapido en datasets grandes).
# =====================================================================
crossover <- function(padre1, padre2, porcentaje) {
  w <- min(max(porcentaje, 0), 1)
  hija <- w * padre1$dist_kmer + (1 - w) * padre2$dist_kmer
  hija[hija < 0] <- 0
  hija[hija > 1] <- 1
  hija
}
