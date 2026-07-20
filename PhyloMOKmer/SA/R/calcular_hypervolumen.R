# =====================================================================
# calcular_hypervolumen(arbol)  ·  HV de una solucion, ref = (2,2)
# =====================================================================
calcular_hypervolumen <- function(arbol) {
  puntajes <- cbind(arbol$scores$me_norm, arbol$scores$ls_norm)
  arbol$scores$hyp <- round(computeHV(t(puntajes), ref.point = c(2, 2)), 4)
  arbol
}
