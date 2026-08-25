# =============================================================================
# diagnostico.R : radiografia rapida cuando el emparejamiento no funciona.
# Correr en la consola y pegar el output completo:
#   source("R/diagnostico.R")
# =============================================================================

source("config.R")
source("R/utils.R")
suppressPackageStartupMessages(library(stringi))

cat("=========== DIAGNOSTICO PIPELINE ===========\n")
cat("Directorio de trabajo:", getwd(), "\n")
cat("carpeta_textos:", config$carpeta_textos,
    "| existe:", dir.exists(config$carpeta_textos), "\n")
arch <- list.files(config$carpeta_textos, recursive = TRUE)
arch <- arch[!basename(arch) %in% c("COLOCAR_TEXTOS_AQUI.txt", "LEEME.md")]
cat("Archivos totales en la carpeta:", length(arch), "\n")
print(table(tolower(tools::file_ext(arch))))

cat("\npdftools instalado:", requireNamespace("pdftools", quietly = TRUE),
    "| tesseract en el sistema:", nzchar(Sys.which("tesseract")), "\n")

sop <- arch[tolower(tools::file_ext(arch)) %in% c("txt", "pdf", "epub", "docx")]
n_m <- min(6, length(sop))
if (n_m > 0) {
  cat("\n--- Muestra de", n_m, "archivos: extraccion de texto ---\n")
  set.seed(1)
  for (a in sample(sop, n_m)) {
    ruta <- file.path(config$carpeta_textos, a)
    txt <- tryCatch(leer_texto_cache(ruta), error = function(e)
      paste("ERROR:", conditionMessage(e)))
    ini <- attr(txt, "inicio_paginas")
    ini1 <- if (!is.null(ini)) ini[1] else substr(as.character(txt), 1, 200)
    meta <- NA_character_
    if (tolower(tools::file_ext(a)) == "pdf" &&
        requireNamespace("pdftools", quietly = TRUE)) {
      inf <- tryCatch(pdftools::pdf_info(ruta), error = function(e) NULL)
      if (!is.null(inf) && !is.null(inf$keys$Title)) meta <- inf$keys$Title
    }
    cat("\n*", a, "\n  chars totales:", nchar(as.character(txt))[1],
        "| titulo en metadatos:", meta, "\n  pagina 1 (150 chars):",
        stri_replace_all_regex(substr(ini1, 1, 150), "\\s+", " "), "\n")
  }
}

ruta_mapeo <- file.path(dirname(config$ruta_xlsx), "mapeo_confirmado.csv")
cat("\nmapeo_confirmado.csv:", ruta_mapeo,
    "| existe:", file.exists(ruta_mapeo), "\n")
if (file.exists(ruta_mapeo)) {
  m <- utils::read.csv(ruta_mapeo, fileEncoding = "UTF-8")
  print(table(m$estado))
  cat("Con nota cuerpo_sin_texto:",
      sum(grepl("cuerpo_sin_texto", m$nota)), "\n")
  cat("\nPrimeras 5 filas del mapeo:\n")
  print(utils::head(m[, c("titulo", "archivo", "puntaje", "estado")], 5))
}
adv <- file.path(config$carpeta_salida, "logs", "log_advertencias.csv")
if (file.exists(adv)) {
  a <- utils::read.csv(adv)
  cat("\nAdvertencias por motivo:\n")
  print(sort(table(a$motivo), decreasing = TRUE))
}
cat("\n=========== FIN DIAGNOSTICO ===========\n")
