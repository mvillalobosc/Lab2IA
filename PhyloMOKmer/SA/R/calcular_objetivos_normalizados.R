# =====================================================================
# calcular_objetivos_normalizados(arbol, max_ls, max_me)
# =====================================================================
calcular_objetivos_normalizados <- function(arbol, max_ls, max_me) {
  arbol$scores$me_norm <- round(arbol$scores$me / max_me, 4)
  arbol$scores$ls_norm <- round(arbol$scores$ls / max_ls, 4)
  arbol
}
