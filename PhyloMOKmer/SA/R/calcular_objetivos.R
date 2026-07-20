# =====================================================================
# calcular_objetivos(arbol)  ·  ME y LS de un unico arbol
# =====================================================================
calcular_objetivos <- function(arbol) {
  arbol$scores$me <- round(sum(arbol$edge.length), 4)
  arbol$scores$ls <- round(sum(abs(arbol$dist_kmer - cophenetic.phylo(arbol))), 4)
  arbol
}
