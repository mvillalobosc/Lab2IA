# =====================================================================
# compute_hypervolume(front)
# ---------------------------------------------------------------------
# Hypervolume of the non-dominated front with respect to the reference point
# r = (2, 2) in the (ME_norm, LS_norm) space. Higher is better.
#   front : Nx2 matrix with columns (ls_norm, me_norm).
# =====================================================================
compute_hypervolume <- function(frente) {
  round(computeHV(t(frente), ref.point = c(2, 2)), 4)
}
