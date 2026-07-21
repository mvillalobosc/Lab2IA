# =====================================================================
# crear_arbol_base(secuencias, k)  ·  distancia k-mer + NJ + limpieza
#   (k ahora se respeta; antes estaba fijo en 5)
# =====================================================================
crear_arbol_base <- function(secuencias, k = 5) {
  distancia <- as.matrix(kdistance(secuencias, k = k))
  arbol <- NJ(distancia)
  arbol$edge.length[arbol$edge.length < 0] <- 0
  arbol <- multi2di(arbol)
  arbol <- midpoint(arbol)
  arbol$dist_kmer     <- distancia
  arbol$dist_original <- distancia   # datos observados (fijos) para el LS
  arbol
}
