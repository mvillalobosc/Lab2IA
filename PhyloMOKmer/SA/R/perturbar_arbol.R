# =====================================================================
# perturbar_arbol(arbol)  ·  vecino SA: escala la matriz por U(0.9,1.1)
# =====================================================================
perturbar_arbol <- function(arbol) {
  factor    <- runif(length(arbol$dist_kmer), 0.9, 1.1)
  dist_tmp  <- arbol$dist_kmer * factor
  dist_tmp[dist_tmp <= 0] <- 0.00001
  nuevo <- NJ(dist_tmp)
  nuevo$dist_kmer <- dist_tmp
  nuevo$edge.length[nuevo$edge.length < 0] <- 0
  nuevo <- multi2di(nuevo)
  midpoint(nuevo)
}
