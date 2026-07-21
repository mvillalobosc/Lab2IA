# =====================================================================
# crear_poblacion(arbol_base, n)
# ---------------------------------------------------------------------
# Genera una poblacion inicial de n arboles perturbando la matriz de
# distancias del arbol base con ruido uniforme pequeno (+-0.01).
# Devuelve: lista de n arboles phylo (el primero es el arbol base).
# =====================================================================
crear_poblacion <- function(arbol_base, n) {
  arboles <- vector("list", n)                 # preasignado (antes crecia con [[i]])
  arboles[[1]] <- arbol_base
  arboles[[1]]$dist_original <- arbol_base$dist_kmer

  for (i in 2:n) {
    # ruido uniforme sobre la matriz de distancias k-mer
    ruido <- runif(length(arbol_base$dist_kmer), -0.01, 0.01)
    dist_tmp <- arbol_base$dist_kmer + ruido
    dist_tmp[dist_tmp <= 0] <- 0

    arbol <- NJ(dist_tmp)
    arbol$dist_kmer     <- dist_tmp
    arbol$dist_original <- arbol_base$dist_kmer
    arbol$edge.length[arbol$edge.length < 0] <- 0
    arbol <- multi2di(arbol)
    arbol <- midpoint(arbol)
    arboles[[i]] <- arbol
  }
  arboles
}
