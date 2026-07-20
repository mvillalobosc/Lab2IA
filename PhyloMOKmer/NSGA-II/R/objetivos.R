# =====================================================================
# calcular_puntajes(arboles)  /  calcular_puntajes_normalizados(...)
# ---------------------------------------------------------------------
# Objetivos bi-criterio del problema:
#   ME (minimum evolution) = suma de longitudes de rama.
#   LS (least squares)     = |dist_original - dist_cofenetica|.
# La version normalizada divide por (max_ls, max_me) para el hipervolumen.
# =====================================================================
calcular_puntajes <- function(arboles) {
  for (i in seq_along(arboles)) {
    me <- sum(arboles[[i]]$edge.length)
    ls <- sum(abs(arboles[[i]]$dist_original - cophenetic.phylo(arboles[[i]])))
    arboles[[i]]$scores$me <- round(me, 4)
    arboles[[i]]$scores$ls <- round(ls, 4)
  }
  arboles
}

calcular_puntajes_normalizados <- function(arboles, max_ls, max_me) {
  for (i in seq_along(arboles)) {
    arboles[[i]]$scores$me_norm <- round(arboles[[i]]$scores$me / max_me, 4)
    arboles[[i]]$scores$ls_norm <- round(arboles[[i]]$scores$ls / max_ls, 4)
  }
  arboles
}
