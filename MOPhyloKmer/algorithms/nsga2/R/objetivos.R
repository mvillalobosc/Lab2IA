# =====================================================================
# compute_scores(trees)  /  compute_normalized_scores(...)
# ---------------------------------------------------------------------
# Bi-objective criteria of the problem:
#   ME (minimum evolution) = sum of branch lengths.
#   LS (least squares)     = |dist_original - cophenetic distance|.
# The normalised version divides by (max_ls, max_me) for the hypervolume.
# =====================================================================
compute_scores <- function(arboles) {
  for (i in seq_along(arboles)) {
    me <- sum(arboles[[i]]$edge.length)
    ls <- sum(abs(arboles[[i]]$dist_original - cophenetic.phylo(arboles[[i]])))
    arboles[[i]]$scores$me <- round(me, 4)
    arboles[[i]]$scores$ls <- round(ls, 4)
  }
  arboles
}

compute_normalized_scores <- function(arboles, max_ls, max_me) {
  for (i in seq_along(arboles)) {
    arboles[[i]]$scores$me_norm <- round(arboles[[i]]$scores$me / max_me, 4)
    arboles[[i]]$scores$ls_norm <- round(arboles[[i]]$scores$ls / max_ls, 4)
  }
  arboles
}
