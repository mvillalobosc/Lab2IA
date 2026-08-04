# =============================================================================
# download_udpipe_model.R
# -----------------------------------------------------------------------------
# EN: Downloads the Spanish UDPipe model used for part-of-speech tagging in
#     step 04. The file is about 28 MB and is not tracked in git, so this needs
#     to be run once after cloning the repository.
# ES: Descarga el modelo UDPipe del espanol usado para el etiquetado
#     morfosintactico del paso 04. El archivo pesa unos 28 MB y no se versiona en
#     git, asi que hay que correr esto una vez despues de clonar el repositorio.
# =============================================================================

if (!requireNamespace("udpipe", quietly = TRUE)) {
  stop("Package 'udpipe' is required. Install with: install.packages('udpipe')",
       call. = FALSE)
}

model_dir <- "models"
if (!dir.exists(model_dir)) dir.create(model_dir, recursive = TRUE)

target <- file.path(model_dir, "spanish-gsd-ud-2.5-191206.udpipe")

if (file.exists(target)) {
  message("Model already present at ", target)
  quit(save = "no")
}

message("Downloading Spanish GSD UD 2.5 model into ", model_dir, " ...")

# EN: The language string 'spanish-gsd' pins the exact treebank. Using plain
#     'spanish' would resolve to whichever Spanish model udpipe considers
#     default, which can change between package versions and would silently
#     alter the tagging results.
# ES: La cadena de idioma 'spanish-gsd' fija el treebank exacto. Usar solo
#     'spanish' resolveria al modelo del espanol que udpipe considere por
#     defecto, que puede cambiar entre versiones del paquete y alteraria en
#     silencio los resultados del etiquetado.
info <- udpipe::udpipe_download_model(language = "spanish-gsd", model_dir = model_dir)

if (is.na(info$file_model) || !file.exists(info$file_model)) {
  stop("Download failed. Fetch the model manually from ",
       "https://lindat.mff.cuni.cz/repository/xmlui/handle/11234/1-3131 ",
       "and place it at ", target, call. = FALSE)
}

if (normalizePath(info$file_model) != normalizePath(target, mustWork = FALSE)) {
  file.rename(info$file_model, target)
}

message("Model ready at ", target)
