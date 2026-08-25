# =============================================================================
# prevuelo.R : chequeo de 1 minuto ANTES de la corrida larga. Solo catalogo y
# emparejamiento por numero, sin leer textos ni anotar nada.
#   source("R/prevuelo.R")
# Si esto se ve bien, run_all.R va a funcionar; si algo esta mal, aparece
# aqui con nombre y apellido en vez de a las 2 horas de corrida.
# =============================================================================

source("config.R")
source("R/utils.R")
for (d in c("logs", "tablas"))
  dir.create(file.path(config$carpeta_salida, d), recursive = TRUE,
             showWarnings = FALSE)
suppressPackageStartupMessages({ library(dplyr); library(readxl) })

cat("Version del pipeline:", config$version_pipeline, "\n")
catalogo <- construir_catalogo()

archivos <- list.files(config$carpeta_textos, recursive = TRUE,
                       pattern = "\\.(txt|pdf|epub|docx)$", ignore.case = TRUE)
archivos <- archivos[basename(archivos) != "COLOCAR_TEXTOS_AQUI.txt"]
cat("\nArchivos en", config$carpeta_textos, ":", length(archivos), "\n")
if (length(archivos) == 0)
  stop("Carpeta de textos vacia. source('R/paso0_traer_textos.R') o ",
       "source('R/descarga_drive.R')")

num_archivos <- numero_de_archivo(basename(archivos))
cat("Archivos con prefijo numerico:", sum(!is.na(num_archivos)), "\n")

catalogo$archivo_prevuelo <- archivos[match(catalogo$numero, num_archivos)]
con <- !is.na(catalogo$archivo_prevuelo)
cat("\n===== PREVUELO =====\n")
cat("Filas del catalogo (tras filtros y expansion):", nrow(catalogo), "\n")
cat("Con archivo por numero de catalogo:", sum(con), "\n")
cat("Sin archivo (no conseguidas):", sum(!con), "\n\n")
cat("Por nivel (con archivo):\n")
print(table(factor(catalogo$nivel[con], levels = 1:12)))
cat("\nMuestra de emparejamientos:\n")
print(head(catalogo[con, c("numero", "titulo", "nivel", "archivo_prevuelo")], 8),
      right = FALSE)
sin <- catalogo[!con, c("numero", "titulo", "nivel")]
if (nrow(sin) > 0) {
  cat("\nMuestra sin archivo (quedaran excluidas con motivo en el log):\n")
  print(head(sin, 8), right = FALSE)
}
umbral <- 0.6
prop <- sum(con) / nrow(catalogo)
cat("\nVEREDICTO:", if (prop >= umbral)
  "OK. Lanzar: rstudioapi::jobRunScript('run_all.R', workingDir = getwd())"
  else paste0("REVISAR: solo ", round(100 * prop),
              "% con archivo. Pegar este output completo."), "\n")
