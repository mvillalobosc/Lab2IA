# =====================================================================
# calcular_hypervolumen(frente)
# ---------------------------------------------------------------------
# Hipervolumen del frente no dominado respecto al punto de referencia
# r = (2, 2) en el espacio (ME_norm, LS_norm). Mayor = mejor.
#   frente : matriz Nx2 con columnas (ls_norm, me_norm).
# =====================================================================
calcular_hypervolumen <- function(frente) {
  round(computeHV(t(frente), ref.point = c(2, 2)), 4)
}
