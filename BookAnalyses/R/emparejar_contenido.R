# =============================================================================
# emparejar_contenido.R : identifica que obra del catalogo es cada archivo
# cuando los nombres de archivo no dicen nada. Correr despues de la descarga
# y antes de run_all.R:
#   Rscript R/emparejar_contenido.R      (o source() en la consola de RStudio)
#
# Para cada archivo extrae metadatos PDF (titulo y autor incrustados) y el
# inicio del texto (portada y primeras paginas), y puntua contra cada obra:
#   +100 titulo del catalogo igual al titulo de metadatos o al nombre de archivo
#   + 70 titulo del catalogo contenido en el inicio del texto
#   + 40 * proporcion de tokens informativos del titulo presentes en el inicio
#   + 15 apellido del autor presente en el inicio o metadatos
# Asignacion "auto" si puntaje >= umbral_auto Y ventaja sobre el segundo
# candidato >= margen_auto. El resto queda "revisar" con los 3 mejores
# candidatos y el inicio del texto para decidir a ojo.
#
# Salidas (junto al xlsx del catalogo):
#   mapeo_confirmado.csv : titulo_norm -> archivo (estado auto / confirmado /
#     revisar). 01_ingesta consume las filas auto y confirmado. Se puede
#     editar a mano: cambiar archivo o poner estado = confirmado y volver a
#     correr run_all.R. Las decisiones manuales se conservan entre corridas.
#   mapeo_revision.csv : casos dudosos con candidatos, puntajes e inicio.
# =============================================================================

source("config.R")
source("R/utils.R")
for (d in c("tablas", "logs", file.path("cache", "texto")))
  dir.create(file.path(config$carpeta_salida, d), recursive = TRUE,
             showWarnings = FALSE)

suppressPackageStartupMessages({
  library(dplyr); library(readxl); library(stringi)
})

catalogo <- construir_catalogo()
obras <- catalogo %>%
  dplyr::distinct(titulo, titulo_norm, autor) %>%
  dplyr::mutate(apellido = normalizar_titulo(
    stringi::stri_extract_first_regex(autor, "^[^,]+")))
log_msg("Emparejador: ", nrow(obras), " obras unicas contra los archivos de ",
        config$carpeta_textos)

archivos <- list.files(config$carpeta_textos, recursive = TRUE,
                       pattern = "\\.(txt|pdf|epub|docx)$", ignore.case = TRUE)
archivos <- archivos[basename(archivos) != "COLOCAR_TEXTOS_AQUI.txt"]
if (length(archivos) == 0)
  stop("No hay archivos en ", config$carpeta_textos,
       ". Primero: Rscript R/descarga_drive.R")

# --- extraccion de senales por archivo ---------------------------------------
extraer_senales <- function(archivo) {
  ruta <- file.path(config$carpeta_textos, archivo)
  meta_titulo <- NA_character_; meta_autor <- NA_character_
  if (tolower(tools::file_ext(archivo)) == "pdf" &&
      requireNamespace("pdftools", quietly = TRUE)) {
    inf <- tryCatch(pdftools::pdf_info(ruta), error = function(e) NULL)
    if (!is.null(inf)) {
      meta_titulo <- inf$keys$Title %||% NA_character_
      meta_autor <- inf$keys$Author %||% NA_character_
    }
  }
  txt <- tryCatch(leer_texto_cache(ruta), error = function(e) NA_character_)
  n_chars <- if (length(txt) != 1 || is.na(txt)) 0L else nchar(txt)
  ini_pags <- attr(txt, "inicio_paginas")
  if (is.null(ini_pags)) ini_pags <- if (n_chars > 0)
    stringi::stri_sub(txt, 1, 2000) else ""
  pag1_sin_texto <- nchar(gsub("\\s", "", ini_pags[1])) < 40
  ini_pags <- paste(ini_pags, collapse = "\n")
  ocr_usado <- FALSE; ocr_txt <- ""
  # OCR si el libro entero viene sin capa de texto, o si la PORTADA es una
  # imagen aunque el cuerpo tenga texto (caso tipico de BDEscolar)
  if (tolower(tools::file_ext(archivo)) == "pdf" &&
      (n_chars < 200 || pag1_sin_texto)) {
    o <- ocr_portada(ruta)
    if (!is.na(o) && nchar(o) > 30) { ocr_txt <- o; ocr_usado <- TRUE }
  }
  base_inicio <- paste(ocr_txt, ini_pags,
    if (n_chars > 0) stringi::stri_sub(txt, 1, config$n_chars_inicio) else "")
  inicio <- if (nzchar(gsub("\\s", "", base_inicio)))
    stringi::stri_sub(stringi::stri_trans_nfc(base_inicio), 1,
                      config$n_chars_inicio + 2500) else NA_character_
  list(archivo = archivo, ocr_usado = ocr_usado,
       meta_titulo_norm = normalizar_titulo(meta_titulo),
       meta_autor_norm = normalizar_titulo(meta_autor),
       archivo_norm = normalizar_titulo(
         tools::file_path_sans_ext(basename(archivo))),
       inicio_norm = normalizar_titulo(inicio),
       n_chars = n_chars)
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# OCR de las primeras paginas para portadas escaneadas como imagen.
# Requiere el binario tesseract en el sistema (apt install tesseract-ocr
# tesseract-ocr-spa). Si no esta, devuelve NA y no pasa nada.
ocr_portada <- function(ruta, paginas = 1:2) {
  if (!nzchar(Sys.which("tesseract"))) return(NA_character_)
  if (!requireNamespace("pdftools", quietly = TRUE)) return(NA_character_)
  pngs <- tryCatch(suppressMessages(pdftools::pdf_convert(
    ruta, format = "png", pages = paginas, dpi = 200,
    filenames = file.path(tempdir(),
      paste0("ocr_", gsub("[^A-Za-z0-9]", "_", basename(ruta)),
             "_", paginas, ".png")), verbose = FALSE)),
    error = function(e) NULL)
  if (is.null(pngs)) return(NA_character_)
  langs <- tryCatch(system2("tesseract", "--list-langs", stdout = TRUE,
                            stderr = FALSE), error = function(e) "")
  idioma <- if (any(grepl("^spa$", langs))) "spa" else "eng"
  txt <- vapply(pngs, function(p)
    paste(tryCatch(system2("tesseract", c(shQuote(p), "stdout", "-l", idioma),
                           stdout = TRUE, stderr = FALSE),
                   error = function(e) ""), collapse = " "), character(1))
  unlink(pngs)
  paste(txt, collapse = " ")
}

log_msg("Extrayendo metadatos e inicio de ", length(archivos),
        " archivos (con cache)...")
senales <- lapply(archivos, extraer_senales)
sin_texto <- vapply(senales, function(s)
  s$n_chars < 200 && !s$ocr_usado, logical(1))
for (s in senales[sin_texto])
  registrar_advertencia("emparejar_contenido", NA, s$archivo,
    "sin texto extraible (PDF escaneado; portada tampoco dio OCR)", NA)
solo_portada <- vapply(senales, function(s)
  s$ocr_usado && s$n_chars < 200, logical(1))
if (any(solo_portada))
  log_msg("OJO: ", sum(solo_portada), " PDF con portada reconocida por OCR ",
          "pero cuerpo sin texto; se pueden emparejar pero el analisis ",
          "necesita OCR completo (ver columna nota del mapeo)")

sw_es <- stopwords::stopwords("es", source = "snowball")
tokens_info <- function(tn) {
  tk <- stringi::stri_split_fixed(tn, " ")[[1]]
  tk[nchar(tk) >= 4 & !tk %in% sw_es]
}

# --- puntaje obra x archivo --------------------------------------------------
puntuar <- function(obra_i, sen) {
  tn <- obras$titulo_norm[obra_i]
  ap <- obras$apellido[obra_i]
  p <- 0
  if (nzchar(tn)) {
    if (!is.na(sen$meta_titulo_norm) && sen$meta_titulo_norm == tn) p <- p + 100
    else if (sen$archivo_norm == tn) p <- p + 100
    else {
      en_inicio <- !is.na(sen$inicio_norm) &&
        stringi::stri_detect_fixed(sen$inicio_norm, tn)
      en_meta <- !is.na(sen$meta_titulo_norm) &&
        stringi::stri_detect_fixed(sen$meta_titulo_norm, tn)
      en_arch <- stringi::stri_detect_fixed(sen$archivo_norm, tn)
      if (en_inicio || en_meta || en_arch) p <- p + 70
    }
    tk <- tokens_info(tn)
    if (length(tk) > 0 && !is.na(sen$inicio_norm))
      p <- p + 40 * mean(vapply(tk, function(t)
        stringi::stri_detect_fixed(sen$inicio_norm, t), logical(1)))
  }
  if (!is.na(ap) && nzchar(ap)) {
    en <- (!is.na(sen$inicio_norm) &&
             stringi::stri_detect_fixed(sen$inicio_norm, ap)) ||
          (!is.na(sen$meta_autor_norm) &&
             stringi::stri_detect_fixed(sen$meta_autor_norm, ap))
    if (en) p <- p + 15
  }
  p
}

M <- matrix(0, nrow(obras), length(archivos),
            dimnames = list(obras$titulo_norm, archivos))
for (j in seq_along(senales))
  M[, j] <- vapply(seq_len(nrow(obras)), puntuar, numeric(1),
                   sen = senales[[j]])

# --- asignacion por obra -----------------------------------------------------
asignar <- function(i) {
  fila <- M[i, ]
  ord <- order(fila, decreasing = TRUE)
  mejor <- fila[ord[1]]
  segundo <- if (length(ord) > 1) fila[ord[2]] else 0
  cand3 <- paste0(archivos[ord[seq_len(min(3, length(ord)))]], " (",
                  round(fila[ord[seq_len(min(3, length(ord)))]]), ")",
                  collapse = " | ")
  estado <- if (mejor >= config$umbral_auto &&
                (mejor - segundo) >= config$margen_auto) "auto" else "revisar"
  nota <- if (estado == "auto" && solo_portada[ord[1]])
    "cuerpo_sin_texto: requiere OCR completo" else ""
  data.frame(titulo = obras$titulo[i], titulo_norm = obras$titulo_norm[i],
             autor = obras$autor[i],
             archivo = if (estado == "auto") archivos[ord[1]] else "",
             puntaje = round(mejor, 1), puntaje_segundo = round(segundo, 1),
             estado = estado, nota = nota, candidatos = cand3)
}
mapeo <- dplyr::bind_rows(lapply(seq_len(nrow(obras)), asignar))

# decisiones manuales previas se conservan (estado confirmado o descartar)
ruta_mapeo <- file.path(dirname(config$ruta_xlsx), "mapeo_confirmado.csv")
if (file.exists(ruta_mapeo)) {
  previo <- utils::read.csv(ruta_mapeo, fileEncoding = "UTF-8")
  manual <- previo[previo$estado %in% c("confirmado", "descartar"), ,
                   drop = FALSE]
  if (nrow(manual) > 0) {
    mapeo <- mapeo[!mapeo$titulo_norm %in% manual$titulo_norm, ]
    mapeo <- dplyr::bind_rows(manual[, colnames(mapeo)[colnames(mapeo) %in%
                                                       colnames(manual)]], mapeo)
    log_msg("Se conservaron ", nrow(manual), " decisiones manuales previas")
  }
}
utils::write.csv(mapeo, ruta_mapeo, row.names = FALSE, fileEncoding = "UTF-8")

# tabla de revision: dudosos con inicio del texto, y archivos sin dueno
inicios <- vapply(senales, function(s)
  substr(ifelse(is.na(s$inicio_norm), "", s$inicio_norm), 1, 180), character(1))
names(inicios) <- archivos
rev_obras <- mapeo %>% dplyr::filter(estado == "revisar") %>%
  dplyr::select(titulo, autor, puntaje, candidatos)
usados <- unique(mapeo$archivo[mapeo$estado %in% c("auto", "confirmado")])
sueltos <- setdiff(archivos, usados)
rev_archivos <- data.frame(archivo = sueltos,
                           inicio_texto = unname(inicios[sueltos]))
guardar_tabla(rev_obras, "mapeo_revision")
guardar_tabla(rev_archivos, "archivos_sin_obra")

cat("\n================ RESUMEN EMPAREJADOR ================\n")
print(table(mapeo$estado))
cat("Archivos sin obra asignada:", length(sueltos), "\n")
comp <- mapeo %>% dplyr::filter(estado %in% c("auto", "confirmado")) %>%
  dplyr::count(archivo) %>% dplyr::filter(n > 1)
if (nrow(comp) > 0) {
  cat("OJO:", nrow(comp), "archivos asignados a mas de una obra (titulos casi",
      "identicos en el catalogo); quedan como duplicados de contenido y el",
      "modulo 10 corre sensibilidad sin ellos:\n")
  print(as.data.frame(comp))
}
cat("Editar", ruta_mapeo, "si hay que corregir (estado = confirmado),\n",
    "revisar output/tablas/mapeo_revision.csv y archivos_sin_obra.csv,\n",
    "luego correr run_all.R\n")
log_msg("Emparejador por contenido: ", sum(mapeo$estado == "auto"),
        " auto, ", sum(mapeo$estado == "revisar"), " a revisar")
