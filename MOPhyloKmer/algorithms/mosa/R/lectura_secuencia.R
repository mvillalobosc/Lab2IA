# =====================================================================
# read_sequences(file_path, type)  ·  read_front PHYLIP -> phyDat
# =====================================================================
read_sequences <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  tipo <- match.arg(tipo)
  if (tipo == "DNA") phyDat(read.dna(ruta_archivo), type = "DNA")
  else               phyDat(read.aa(ruta_archivo),  type = "AA")
}
