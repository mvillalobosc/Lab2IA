# =====================================================================
# read_sequences(file_path, type)
# ---------------------------------------------------------------------
# Reads a PHYLIP file and returns it as a phyDat object.
#   file_path : FULL path to the .phylip file.
#   type      : "DNA" or "AA", or a named vector with one type per file
#               and a "default" entry (SEQ_TYPE in config.R).
# Returns: a phyDat object ready for the pipeline.
# =====================================================================
read_sequences <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  if (!is.null(names(tipo)))   # one type per data set, e.g. c(default = "DNA", conrado_126.phylip = "AA")
    tipo <- if (basename(ruta_archivo) %in% names(tipo)) tipo[[basename(ruta_archivo)]] else tipo[["default"]]
  tipo <- match.arg(tipo)
  if (tipo == "DNA") {
    phyDat(read.dna(ruta_archivo), type = "DNA")
  } else {
    read.phyDat(ruta_archivo, format = "interleaved", type = "AA")   # phangorn 2.12.1 no longer exports read.aa()
  }
}
