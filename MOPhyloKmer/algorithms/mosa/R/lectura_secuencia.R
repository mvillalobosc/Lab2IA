# =====================================================================
# read_sequences(file_path, type)  ·  read_front PHYLIP -> phyDat
#   type: "DNA", "AA" or one type per file (SEQ_TYPE in config.R)
# =====================================================================
read_sequences <- function(ruta_archivo, tipo = c("DNA", "AA")) {
  if (!is.null(names(tipo)))
    tipo <- if (basename(ruta_archivo) %in% names(tipo)) tipo[[basename(ruta_archivo)]] else tipo[["default"]]
  tipo <- match.arg(tipo)
  if (tipo == "DNA") phyDat(read.dna(ruta_archivo), type = "DNA")
  else               read.phyDat(ruta_archivo, format = "interleaved", type = "AA")
}
