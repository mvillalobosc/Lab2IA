# =====================================================================
# lectura_secuencia(ruta_archivo, tipo)
# ---------------------------------------------------------------------
# Lee un archivo PHYLIP y lo devuelve como objeto phyDat.
#   ruta_archivo : ruta COMPLETA al .phylip (sin rutas absolutas fijas).
#   tipo         : "DNA" o "AA".
# Devuelve: objeto phyDat listo para el pipeline.
# =====================================================================
lectura_secuencia <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  tipo <- match.arg(tipo)
  if (tipo == "DNA") {
    phyDat(read.dna(ruta_archivo), type = "DNA")
  } else {
    phyDat(read.aa(ruta_archivo),  type = "AA")
  }
}
