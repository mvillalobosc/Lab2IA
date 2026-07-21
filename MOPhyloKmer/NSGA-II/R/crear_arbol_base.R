# =====================================================================
# crear_arbol_base(secuencias, k)
# ---------------------------------------------------------------------
# Construye el árbol base (semilla) libre de alineamiento:
#   1. matriz de distancias k-mer,
#   2. Neighbour Joining,
#   3. limpieza (aristas negativas, multifurcaciones, enraizado midpoint).
#   k : longitud de palabra k-mer (se RESPETA; antes estaba fijo en 5).
# Devuelve: objeto phylo con $dist_kmer adjunta.
# =====================================================================
crear_arbol_base <- function(secuencias, k = 5) {
  distancia <- as.matrix(kdistance(secuencias, k = k))   # <- usa k real
  arbol <- NJ(distancia)
  arbol$edge.length[arbol$edge.length < 0] <- 0          # aristas negativas -> 0
  arbol <- multi2di(arbol)                               # binariza multifurcaciones
  arbol <- midpoint(arbol)                               # enraiza por midpoint
  arbol$dist_kmer <- distancia
  arbol
}
