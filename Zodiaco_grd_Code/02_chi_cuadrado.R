# =============================================================================
# 02_chi_cuadrado.R
# Filtro chi-cuadrado sobre la base completa, como lo haría un análisis sin
# escrutinio metodológico: cada nivel de especialidad, de cada posición de
# diagnóstico (letra CIE-10) y de cada posición de procedimiento (grupo 00-99)
# es una variable binaria; se conserva la que tiene p < 0,01 frente al signo.
# El filtro se aplica a todos los episodios, antes de la partición 80/20, igual
# que en el análisis original.
#
# Entrada: CFG$dir_datos/base_grd.rds
# Salida:  CFG$dir_resultados/chi2_<calendario>.csv           (todas las variables)
#          CFG$dir_resultados/chi2_<calendario>_familias.csv  (resumen por familia)
#          CFG$dir_datos/seleccion_<calendario>.rds           (variables retenidas)
# =============================================================================

source("00_funciones.R")
base <- readRDS(file.path(CFG$dir_datos, "base_grd.rds"))

filtro_chi2 <- function(base, col_signo) {
  signos <- sort(unique(base[[col_signo]]))
  n_signo <- base[, .N, keyby = c(col_signo)][J(signos), N]
  res <- rbindlist(lapply(campos_categoricos(), function(cmp) {
    # Conteo de episodios por nivel y signo (una tabla por campo).
    tab <- base[!is.na(get(cmp)), .N, by = c(cmp, col_signo)]
    setnames(tab, c("nivel", "signo", "N"))
    ancho <- dcast(tab, nivel ~ signo, value.var = "N", fill = 0)
    for (s in setdiff(signos, names(ancho))) ancho[, (s) := 0L]
    conteos <- as.matrix(ancho[, ..signos])
    ch <- chi2_sklearn(conteos, n_signo)
    data.table(campo = cmp, nivel = as.character(ancho$nivel),
               codigo = match(as.character(ancho$nivel), levels(base[[cmp]])),
               chi2 = ch$chi2, p_value = ch$p)
  }))
  res[, variable := paste0(campo, "_", nivel)]
  res[, familia := fifelse(campo == "ESPECIALIDAD_MEDICA", "ESPECIALIDAD_MEDICA",
                   fifelse(startsWith(campo, "DIAGNOSTICO"), "DIAGNOSTICO", "PROCEDIMIENTO"))]
  res[, significativa := p_value < CFG$alfa_chi2]
  # Variables que también pasan una corrección de Bonferroni (solo para reportar).
  res[, bonferroni_01 := p_value < CFG$alfa_chi2 / .N]
  setorder(res, -chi2)
  res
}

for (cal in c("12", "13")) {
  col_signo <- if (cal == "12") "SIGNO" else "SIGNO13"
  res <- filtro_chi2(base, col_signo)
  fwrite(res[, .(variable, familia, chi2, p_value, significativa, bonferroni_01)],
         file.path(CFG$dir_resultados, sprintf("chi2_%s.csv", cal)))
  fam <- res[, .(total_variables = .N, significativas = sum(significativa),
                 bonferroni_01 = sum(bonferroni_01)), by = familia]
  fwrite(fam, file.path(CFG$dir_resultados, sprintf("chi2_%s_familias.csv", cal)))
  saveRDS(res[significativa == TRUE, .(campo, nivel, codigo, variable)],
          file.path(CFG$dir_datos, sprintf("seleccion_%s.rds", cal)))
  message(sprintf("Calendario de %s signos: %d variables, %d con p < %.2f, %d con Bonferroni",
                  cal, nrow(res), sum(res$significativa), CFG$alfa_chi2, sum(res$bonferroni_01)))
  print(fam)
}
