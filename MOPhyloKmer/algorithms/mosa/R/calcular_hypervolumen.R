# =====================================================================
# compute_hypervolume(tree)  ·  hypervolume of one solution, ref = (2,2)
# =====================================================================
compute_hypervolume <- function(tree) {
  puntajes <- cbind(tree$scores$me_norm, tree$scores$ls_norm)
  tree$scores$hyp <- round(computeHV(t(puntajes), ref.point = c(2, 2)), 4)
  tree
}
