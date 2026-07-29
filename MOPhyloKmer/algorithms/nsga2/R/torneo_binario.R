# =====================================================================
# tournament_selection(population, data, order)
# ---------------------------------------------------------------------
# NSGA-II binary tournament: picks two individuals at random and returns the
# distance matrix of the winner, comparing first by rank
# (lower is better), breaking ties by crowding distance (higher is better).
#   data  : data frame from non_dominated_sort_cw (col 5 = rank, 6 = crowding2)
#   order : index vector already sorted by order(rank, -crowding2)
# =====================================================================
tournament_selection <- function(population, data, orden) {
  s <- sample(seq_along(population), 2)
  a <- orden[s[1]]; b <- orden[s[2]]

  rank_a <- data[[a, 5]]; crow_a <- data[[a, 6]]
  rank_b <- data[[b, 5]]; crow_b <- data[[b, 6]]

  gana_a <- (rank_a < rank_b) ||
            (rank_a == rank_b && crow_a >= crow_b)
  ganador <- if (gana_a) population[[a]] else population[[b]]

  list(dist_kmer = ganador$dist_kmer)
}
