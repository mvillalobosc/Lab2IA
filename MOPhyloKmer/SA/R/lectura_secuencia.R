# =====================================================================
# lectura_secuencia(ruta_archivo, tipo)  ·  lee PHYLIP -> phyDat
# =====================================================================
lectura_secuencia <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  tipo <- match.arg(tipo)
  if (tipo == "DNA") phyDat(read.dna(ruta_archivo), type = "DNA")
  else               phyDat(read.aa(ruta_archivo),  type = "AA")
}
