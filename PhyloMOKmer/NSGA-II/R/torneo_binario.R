# =====================================================================
# torneo_seleccion(poblacion, data, orden)
# ---------------------------------------------------------------------
# Torneo binario NSGA-II: elige 2 individuos al azar y devuelve la
# matriz de distancias del ganador, comparando primero por ranking
# (menor es mejor) y desempatando por crowding distance (mayor mejor).
#   data  : data.frame de nom_dominated_sort_cw (col 5 = ranking, 6 = crowding2)
#   orden : vector de indices ya ordenados (order(ranking, -crowding2))
# =====================================================================
torneo_seleccion <- function(poblacion, data, orden) {
  s <- sample(seq_along(poblacion), 2)
  a <- orden[s[1]]; b <- orden[s[2]]

  rank_a <- data[[a, 5]]; crow_a <- data[[a, 6]]
  rank_b <- data[[b, 5]]; crow_b <- data[[b, 6]]

  gana_a <- (rank_a < rank_b) ||
            (rank_a == rank_b && crow_a >= crow_b)
  ganador <- if (gana_a) poblacion[[a]] else poblacion[[b]]

  list(dist_kmer = ganador$dist_kmer)
}
