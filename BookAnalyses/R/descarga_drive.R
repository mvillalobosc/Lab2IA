# =============================================================================
# descarga_drive.R : baja los textos desde la carpeta de Google Drive a
# config$carpeta_textos. Correr UNA VEZ antes de run_all.R:
#   Rscript R/descarga_drive.R
#
# Intenta primero sin autenticacion (sirve para carpetas compartidas con
# "cualquiera con el enlace"). Si Google rechaza el listado, cae a
# drive_auth(): en RStudio abre el navegador una vez y guarda el token.
# Descarga txt, pdf, epub y docx tal cual; los Google Docs nativos se
# exportan a txt. Todo lo demas se salta y queda registrado en
# output/tablas/descarga_drive.csv. No re-descarga archivos ya presentes.
# =============================================================================

source("config.R")
source("R/utils.R")
dir.create(file.path(config$carpeta_salida, "tablas"), recursive = TRUE,
           showWarnings = FALSE)
dir.create(file.path(config$carpeta_salida, "logs"), recursive = TRUE,
           showWarnings = FALSE)
dir.create(config$carpeta_textos, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("googledrive", quietly = TRUE)) {
  message("Instalando googledrive...")
  install.packages("googledrive", repos = "https://cloud.r-project.org")
}
library(googledrive)

id_carpeta <- extraer_id_drive(config$drive_url)
if (is.na(id_carpeta))
  stop("No pude extraer el ID de la carpeta desde config$drive_url: ",
       config$drive_url)
log_msg("Carpeta Drive: ", id_carpeta)

# Modo de acceso: token propio si ya existe uno cacheado (mucha mas cuota
# para descargas masivas), si no sin autenticacion (sirve para listar y
# para pocas descargas; Google limita las descargas masivas en ese modo).
modo_auth <- tryCatch({
  drive_auth(email = TRUE)
  invisible(drive_user())   # canario: valida que el token tenga scope de Drive
  TRUE
}, error = function(e) {
  if (grepl("insufficient|PERMISSION_DENIED", conditionMessage(e),
            ignore.case = TRUE))
    stop("El token cacheado quedo SIN el permiso de Drive (en la pantalla de",
         " Google no se marco la casilla).\nArreglo, en la CONSOLA:\n",
         "  unlink(gargle::gargle_oauth_cache(), recursive = TRUE)\n",
         "  googledrive::drive_auth()  # MARCAR la casilla de Google Drive",
         " y responder 1 si pregunta por cachear\n",
         "y relanzar este script.", call. = FALSE)
  drive_deauth()
  FALSE
})
log_msg("Modo Drive: ", if (modo_auth) "autenticado (token cacheado)"
        else "sin autenticacion")

subir_a_auth <- function() {
  if (modo_auth) return(FALSE)
  if (!interactive()) {
    stop("Google esta limitando las descargas sin autenticacion.\n",
         "En la CONSOLA de RStudio correr una vez:\n",
         "  googledrive::drive_auth()   (responder 1 si pregunta por cachear)\n",
         "y relanzar source('R/descarga_drive.R'): retoma donde quedo.")
  }
  log_msg("Limite de tasa sin autenticacion: cambiando a drive_auth()...")
  drive_auth()
  modo_auth <<- TRUE
  TRUE
}

listar <- function() drive_ls(as_id(id_carpeta), recursive = TRUE)
archivos <- tryCatch(listar(), error = function(e) { subir_a_auth(); listar() })
log_msg("Drive: ", nrow(archivos), " elementos listados")

# Reintentos con backoff; ante fallos consecutivos, sube a autenticado.
fallos_seguidos <- 0
con_reintentos <- function(expr_fun, nombre, esperas = c(5, 15, 45)) {
  for (k in seq_len(length(esperas) + 1)) {
    ok <- tryCatch({ expr_fun(); TRUE }, error = function(e) {
      log_msg("  intento ", k, " fallo para ", nombre, ": ",
              conditionMessage(e)); FALSE })
    if (ok) { fallos_seguidos <<- 0; return(TRUE) }
    if (fallos_seguidos >= 5 && subir_a_auth()) next
    if (k <= length(esperas)) Sys.sleep(esperas[k])
  }
  fallos_seguidos <<- fallos_seguidos + 1
  FALSE
}

soportados <- c("txt", "pdf", "epub", "docx")
mime_gdoc <- "application/vnd.google-apps.document"
mime_carpeta <- "application/vnd.google-apps.folder"

sanear <- function(x) gsub("[/\\\\]", "_", x)

resultado <- lapply(seq_len(nrow(archivos)), function(i) {
  nombre <- archivos$name[i]
  rec <- archivos$drive_resource[[i]]
  mime <- if (!is.null(rec$mimeType)) rec$mimeType else NA_character_
  if (identical(mime, mime_carpeta))
    return(data.frame(nombre = nombre, mime = mime, estado = "carpeta"))
  ext <- tolower(tools::file_ext(nombre))
  es_gdoc <- identical(mime, mime_gdoc)
  if (!es_gdoc && !ext %in% soportados)
    return(data.frame(nombre = nombre, mime = mime,
                      estado = "omitido: formato no soportado"))
  destino <- file.path(config$carpeta_textos,
                       if (es_gdoc) paste0(sanear(nombre), ".txt")
                       else sanear(nombre))
  if (file.exists(destino))
    return(data.frame(nombre = nombre, mime = mime, estado = "ya existia"))
  ok <- con_reintentos(function() {
    if (es_gdoc)
      drive_download(archivos[i, ], path = destino, type = "text/plain",
                     overwrite = FALSE)
    else
      drive_download(archivos[i, ], path = destino, overwrite = FALSE)
  }, nombre)
  if (!ok) log_msg("ERROR descargando ", nombre, " tras reintentos")
  Sys.sleep(0.3)
  data.frame(nombre = nombre, mime = mime,
             estado = if (ok) "descargado" else "error")
})
tabla <- do.call(rbind, resultado)
guardar_tabla(tabla, "descarga_drive")
print(table(tabla$estado))
n_err <- sum(tabla$estado == "error")
if (n_err > 0)
  log_msg(n_err, " archivos con error tras reintentos: relanzar este mismo ",
          "script (retoma solo lo que falta), idealmente autenticado")
log_msg("Descarga Drive terminada. Detalle en tablas/descarga_drive.csv. ",
        "Ahora: Rscript run_all.R")
