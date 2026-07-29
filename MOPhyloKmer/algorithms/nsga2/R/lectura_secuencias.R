# =====================================================================
# read_sequences(file_path, type)
# ---------------------------------------------------------------------
# Reads a PHYLIP file and returns it as a phyDat object.
#   file_path : FULL path to the .phylip file.
#   type      : "DNA" or "AA".
# Returns: a phyDat object ready for the pipeline.
# =====================================================================
read_sequences <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  tipo <- match.arg(tipo)
  if (tipo == "DNA") {
    phyDat(read.dna(ruta_archivo), type = "DNA")
  } else {
    phyDat(read.aa(ruta_archivo),  type = "AA")
  }
}
