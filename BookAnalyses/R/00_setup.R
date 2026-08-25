# =============================================================================
# 00_setup.R : paquetes, carpetas y modelo udpipe.
# =============================================================================

paquetes <- c("readxl", "writexl", "dplyr", "tidyr", "stringr", "stringi",
              "ggplot2", "data.table", "Matrix", "irlba", "uwot", "pvclust",
              "vegan", "udpipe", "syuzhet", "stm", "stopwords", "xml2",
              "MASS", "mgcv", "cluster", "parallel")

faltantes <- setdiff(paquetes, rownames(installed.packages()))
if (length(faltantes) > 0) {
  message("Instalando paquetes faltantes: ", paste(faltantes, collapse = ", "))
  install.packages(faltantes, repos = "https://cloud.r-project.org",
                   Ncpus = max(1, parallel::detectCores() - 1))
}
# mgcv y MASS NO se adjuntan: mgcv::s tapa el s() de stm en la formula de
# prevalencia y MASS::select tapa dplyr::select. Se usan con prefijo ::.
paquetes_cargar <- setdiff(paquetes, c("mgcv", "MASS"))
invisible(lapply(paquetes_cargar, function(p)
  suppressPackageStartupMessages(library(p, character.only = TRUE))))

# lectura de PDF: pdftools si esta, si no el binario pdftotext
if (!requireNamespace("pdftools", quietly = TRUE)) {
  try(suppressWarnings(install.packages("pdftools",
    repos = "https://cloud.r-project.org")), silent = TRUE)
}
if (!requireNamespace("pdftools", quietly = TRUE)) {
  pt_setup <- encontrar_pdftotext()
  if (nzchar(pt_setup)) {
    message("pdftools no disponible: se usara el binario pdftotext en ",
            pt_setup)
  } else {
    stop("Para leer PDF instalar una de dos:\n",
         "  a) sistema: sudo apt install libpoppler-cpp-dev ; ",
         "luego install.packages('pdftools')\n",
         "  b) sistema: sudo apt install poppler-utils  (binario pdftotext)\n",
         "  c) sin sudo, todo en consola R: poppler de usuario via micromamba",
         " y apuntar config$ruta_pdftotext")
  }
}

# carpetas de salida
for (d in c("tablas", "figuras", "logs", "cache", file.path("cache", "anot")))
  dir.create(file.path(config$carpeta_salida, d), recursive = TRUE,
             showWarnings = FALSE)

# logs frescos por corrida (el cache de anotacion si se conserva)
for (f in c("pipeline.log", "log_exclusiones.csv", "log_advertencias.csv"))
  unlink(file.path(config$carpeta_salida, "logs", f))

# modelo udpipe espanol (spanish-gsd-ud-2.5, el mismo de los papers previos)
dir.create(config$ruta_modelo, showWarnings = FALSE)
modelo_archivo <- list.files(config$ruta_modelo, pattern = "^spanish-gsd.*udpipe$",
                             full.names = TRUE)
if (length(modelo_archivo) == 0) {
  message("Descargando modelo udpipe spanish-gsd...")
  dl <- udpipe::udpipe_download_model(language = "spanish-gsd",
                                      model_dir = config$ruta_modelo)
  modelo_archivo <- dl$file_model
}
config$archivo_modelo <- modelo_archivo[1]

set.seed(config$semilla)
