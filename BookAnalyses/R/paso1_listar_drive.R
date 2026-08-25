# =============================================================================
# paso1_listar_drive.R : solo LISTA la carpeta de Drive, sin bajar nada.
# El "dir" para confirmar acceso y ver que hay, antes de descargar y emparejar.
#   source("R/paso1_listar_drive.R")
# =============================================================================
source("config.R")
source("R/utils.R")
if (!requireNamespace("googledrive", quietly = TRUE))
  install.packages("googledrive", repos = "https://cloud.r-project.org")
library(googledrive)

id_carpeta <- extraer_id_drive(config$drive_url)
cat("ID de carpeta:", id_carpeta, "\n")
lista <- tryCatch({
  drive_deauth()
  drive_ls(as_id(id_carpeta), recursive = TRUE)
}, error = function(e) {
  message("Listado sin autenticacion fallo: ", conditionMessage(e),
          " -> probando con drive_auth(). Si pregunta por cachear",
          " credenciales, responder 1 (Yes) y autorizar en el navegador.")
  drive_auth()
  drive_ls(as_id(id_carpeta), recursive = TRUE)
})
cat("Elementos listados:", nrow(lista), "\n\nPor tipo (mime):\n")
mimes <- vapply(lista$drive_resource, function(r)
  if (is.null(r$mimeType)) NA_character_ else r$mimeType, character(1))
print(sort(table(mimes), decreasing = TRUE))
cat("\nPrimeros 25 nombres:\n")
print(utils::head(lista$name, 25))
cat("\nSi esto se ve bien, paso 2: source('R/descarga_drive.R')\n")
