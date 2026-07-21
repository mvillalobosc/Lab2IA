# =====================================================================
# nom_dominated_sort_cw(arboles)
# ---------------------------------------------------------------------
# Ordenamiento no dominado (fast non-dominated sort) + crowding distance
# sobre (LSnorm, MEnorm). Devuelve un data.frame con columnas:
#   LS, ME, LSnorm, MEnorm, ranking, crowding2
# =====================================================================
nom_dominated_sort_cw <- function(arboles) {
  # matriz de puntajes (una fila por arbol)
  M <- t(vapply(arboles, function(a)
    c(a$scores$ls, a$scores$me, a$scores$ls_norm, a$scores$me_norm),
    numeric(4)))
  df <- data.frame(M)
  colnames(df) <- c("LS", "ME", "LSnorm", "MEnorm")

  nds <- doNondominatedSorting(t(df))
  df$ranking <- nds$ranks

  # crowding distance por frente
  crowding <- numeric(length(nds$ranks))
  for (r in seq_len(max(nds$ranks))) {
    idx <- which(nds$ranks == r)
    sub <- df[idx, ]
    if (is.null(ncol(sub))) sub <- rbind(sub, sub)      # frente de 1 elemento
    cw <- computeCrowdingDistance(t(sub))
    crowding[idx] <- if (length(idx) == 1) cw[1] else cw
  }
  df$crowding2 <- crowding
  df
}
