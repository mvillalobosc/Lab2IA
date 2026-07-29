# =====================================================================
# non_dominated_sort_cw(trees)
# ---------------------------------------------------------------------
# Ordenamiento no dominado (fast non-dominated sort) + crowding distance
# on (LSnorm, MEnorm). Returns a data frame with columns:
#   LS, ME, LSnorm, MEnorm, rank, crowding2
# =====================================================================
non_dominated_sort_cw <- function(arboles) {
  # score matrix (one row per tree)
  M <- t(vapply(arboles, function(a)
    c(a$scores$ls, a$scores$me, a$scores$ls_norm, a$scores$me_norm),
    numeric(4)))
  df <- data.frame(M)
  colnames(df) <- c("LS", "ME", "LSnorm", "MEnorm")

  nds <- doNondominatedSorting(t(df))
  df$ranking <- nds$ranks

  # crowding distance per front
  crowding <- numeric(length(nds$ranks))
  for (r in seq_len(max(nds$ranks))) {
    idx <- which(nds$ranks == r)
    sub <- df[idx, ]
    if (is.null(ncol(sub))) sub <- rbind(sub, sub)      # single-point front
    cw <- computeCrowdingDistance(t(sub))
    crowding[idx] <- if (length(idx) == 1) cw[1] else cw
  }
  df$crowding2 <- crowding
  df
}
