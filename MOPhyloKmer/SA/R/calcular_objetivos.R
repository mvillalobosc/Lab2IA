# =====================================================================
# calcular_objetivos(arbol)  ·  ME y LS de un unico arbol
#   LS se mide contra dist_original (datos fijos), igual que en NSGA-II.
# =====================================================================
calcular_objetivos <- function(arbol) {
  arbol$scores$me <- round(sum(arbol$edge.length), 4)
  arbol$scores$ls <- round(sum(abs(arbol$dist_original - cophenetic.phylo(arbol))), 4)
  arbol
}
