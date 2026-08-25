# =============================================================================
# paso0_traer_textos.R : deja los textos en datos/textos, vengan de donde
# vengan. Busca el zip bajado desde la web de Drive (drive-download-*.zip o
# Libros*.zip) en Descargas, Downloads, home y el proyecto; si no lo
# encuentra, abre el selector de archivos para elegirlo a mano. Descomprime
# aplanando. Ademas recoge PDF sueltos de despliegues anteriores si se le
# indica una carpeta. Correr en la consola:
#   source("R/paso0_traer_textos.R")
# =============================================================================

source("config.R")
dir.create(config$carpeta_textos, recursive = TRUE, showWarnings = FALSE)
cat("Directorio de trabajo:", getwd(), "\n")
cat("Destino de los textos:", normalizePath(config$carpeta_textos), "\n\n")

candidatas <- unique(c(
  file.path(Sys.getenv("USERPROFILE"), "Downloads"),
  path.expand("~/Downloads"), path.expand("~/Descargas"),
  path.expand("~"), getwd(), dirname(getwd())))
candidatas <- candidatas[nzchar(candidatas) & dir.exists(candidatas)]

zips <- unlist(lapply(candidatas, list.files, pattern = "\\.zip$",
                      full.names = TRUE))
zips <- unique(zips[grepl("drive-download|libros",
                          tolower(basename(zips)))])
if (length(zips) == 0) {
  if (interactive()) {
    message("No encontre ningun drive-download*.zip ni Libros*.zip en:\n  ",
            paste(candidatas, collapse = "\n  "),
            "\nElige el zip a mano en la ventana que se abre...")
    zips <- file.choose()
  } else {
    stop("No encontre el zip de la carpeta de Drive. Dejarlo en Descargas o",
         " en la carpeta del proyecto y volver a correr, o correr este paso",
         " en la consola para elegirlo a mano.")
  }
}
cat("Zips a descomprimir:\n"); print(basename(zips))
for (z in zips) {
  cat("Descomprimiendo", basename(z), "...\n")
  utils::unzip(z, exdir = config$carpeta_textos, junkpaths = TRUE)
}

n <- length(list.files(config$carpeta_textos, pattern = "\\.pdf$",
                       recursive = TRUE, ignore.case = TRUE))
cat("\nPDF en", config$carpeta_textos, ":", n, "\n")
if (n < 100)
  cat("OJO: se esperaban ~878. Si el zip esta en otra parte, correr de nuevo",
      "este paso en la consola y elegirlo a mano con el selector.\n")
cat("Siguiente: rstudioapi::jobRunScript('run_all.R', workingDir = getwd())\n")
