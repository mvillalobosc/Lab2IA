# =====================================================================
# mutacion(porcentaje, individuo)
# ---------------------------------------------------------------------
# Mutacion elemento a elemento de la matriz de distancias: con
# probabilidad `porcentaje`, se suma ruido U(-porcentaje, porcentaje).
# VECTORIZADO con una mascara logica (antes: doble bucle for i/j).
# =====================================================================
mutacion <- function(porcentaje, individuo) {
  if (porcentaje < 0 || porcentaje > 1)
    stop("El porcentaje de mutacion debe estar en [0, 1].")

  M <- individuo$dist_kmer
  mascara <- matrix(runif(length(M)) < porcentaje, nrow = nrow(M))
  ruido   <- matrix(runif(length(M), -porcentaje, porcentaje), nrow = nrow(M))
  M[mascara] <- M[mascara] + ruido[mascara]
  M[M < 0] <- 0
  M[M > 1] <- 1
  M
}
