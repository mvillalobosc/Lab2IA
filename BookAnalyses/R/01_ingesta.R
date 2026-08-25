# =============================================================================
# 01_ingesta.R : catalogo xlsx, emparejamiento con archivos, lectura y limpieza.
# Produce: P$catalogo (un libro por fila y nivel asignado) y P$textos.
# =============================================================================

catalogo <- construir_catalogo()

# --- emparejamiento titulo/archivo ------------------------------------------
archivos <- list.files(config$carpeta_textos, recursive = TRUE,
                       pattern = "\\.(txt|pdf|epub|docx)$", ignore.case = TRUE)
archivos <- archivos[basename(archivos) != "COLOCAR_TEXTOS_AQUI.txt"]
nombres_base <- basename(archivos)
if (length(archivos) == 0)
  stop("No hay archivos txt/pdf/epub/docx en ", config$carpeta_textos,
       ".\nCon el zip bajado desde la web de Drive:",
       " source('R/paso0_traer_textos.R')",
       "\nO via API: source('R/descarga_drive.R')")
if (nrow(catalogo) >= 20 && length(archivos) < 5)
  stop("Solo ", length(archivos), " archivo(s) en ", config$carpeta_textos,
       " frente a ", nrow(catalogo), " obras del catalogo: la descarga de los",
       " textos no ha ocurrido o la carpeta esta mal apuntada.",
       "\nCon el zip de la web de Drive: source('R/paso0_traer_textos.R')",
       "\nO via API: source('R/descarga_drive.R')")
arch_norm <- normalizar_titulo(tools::file_path_sans_ext(nombres_base))

# mapeo confirmado por contenido (generado por R/emparejar_contenido.R)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
ruta_mapeo <- file.path(dirname(config$ruta_xlsx), "mapeo_confirmado.csv")
mapeo_cont <- if (file.exists(ruta_mapeo)) {
  m <- utils::read.csv(ruta_mapeo, fileEncoding = "UTF-8")
  m <- m[!is.na(m$archivo) & nzchar(m$archivo) &
         m$estado %in% c("auto", "confirmado"), ]
  log_msg("Mapeo por contenido: ", nrow(m), " obras con archivo asignado (",
          basename(ruta_mapeo), ")")
  m
} else NULL

num_archivos <- numero_de_archivo(nombres_base)

emparejar <- function(i) {
  # 0) numero de catalogo en el prefijo del nombre de archivo
  if (!is.na(catalogo$numero[i])) {
    hit <- which(num_archivos == catalogo$numero[i])
    if (length(hit) > 1) {
      registrar_advertencia("01_ingesta", catalogo$id_libro[i],
        catalogo$titulo[i], "mas de un archivo con el mismo numero de catalogo",
        paste(archivos[hit], collapse = " | "))
      # desempate por titulo: se queda el archivo cuyo nombre mejor calza
      tk <- stringi::stri_split_fixed(catalogo$titulo_norm[i], " ")[[1]]
      tk <- tk[nchar(tk) >= 3]
      punt <- vapply(hit, function(h) {
        if (arch_norm[h] == catalogo$titulo_norm[i]) return(2)
        if (length(tk) == 0) return(0)
        mean(vapply(tk, function(t)
          stringi::stri_detect_fixed(arch_norm[h], t), logical(1)))
      }, numeric(1))
      hit <- hit[order(punt, decreasing = TRUE)]
    }
    if (length(hit) >= 1) return(c(archivos[hit[1]], "numero_catalogo"))
    if (isTRUE(config$solo_numero_si_existe)) {
      # con catalogo numerado y sin archivo para este numero, la obra no
      # esta conseguida: no se busca por titulo (evita falsos positivos
      # tipo Blancanieves -> Blancanieve y Rojaflor)
      hit_m <- if (!is.null(mapeo_cont))
        mapeo_cont$archivo[mapeo_cont$titulo_norm == catalogo$titulo_norm[i]] else
        character(0)
      hit_m <- hit_m[hit_m %in% archivos]
      if (length(hit_m) >= 1) return(c(hit_m[1], "contenido"))
      return(c(NA_character_, "sin_archivo_para_numero"))
    }
  }
  # 0.5) mapeo confirmado por contenido
  if (!is.null(mapeo_cont)) {
    hit <- mapeo_cont$archivo[mapeo_cont$titulo_norm == catalogo$titulo_norm[i]]
    hit <- hit[hit %in% archivos]
    if (length(hit) >= 1) return(c(hit[1], "contenido"))
  }
  # 1) columna de archivo del catalogo
  a <- catalogo$archivo_cat[i]
  if (!is.na(a) && nzchar(a)) {
    hit <- archivos[tolower(nombres_base) == tolower(basename(a))]
    if (length(hit) == 1) return(c(hit, "columna_archivo"))
  }
  # 2) titulo normalizado exacto
  hit <- archivos[arch_norm == catalogo$titulo_norm[i]]
  if (length(hit) >= 1) return(c(hit[1], "titulo_exacto"))
  # 3) contencion en ambos sentidos
  hit <- archivos[stringr::str_detect(arch_norm,
           stringr::fixed(catalogo$titulo_norm[i])) |
         stringr::str_detect(catalogo$titulo_norm[i], stringr::fixed(arch_norm))]
  if (length(hit) >= 1) return(c(hit[1], "titulo_parcial"))
  # 4) aproximado
  hit <- agrep(catalogo$titulo_norm[i], arch_norm, max.distance = 0.15)
  if (length(hit) >= 1) return(c(archivos[hit[1]], "titulo_aproximado"))
  c(NA_character_, "sin_match")
}

emp <- t(vapply(seq_len(nrow(catalogo)), emparejar, character(2)))
catalogo$archivo <- emp[, 1]
catalogo$tipo_match <- emp[, 2]

# si el matching por nombre fracasa en masa y aun no hay mapeo por contenido,
# se corre el emparejador automaticamente y se reintenta una vez
prop_sin <- mean(is.na(catalogo$archivo))
if (is.null(mapeo_cont) && prop_sin > (config$umbral_auto_emparejador %||% 0.3)) {
  log_msg("Sin archivo para ", round(100 * prop_sin), "% de las obras y no ",
          "hay mapeo por contenido: corriendo R/emparejar_contenido.R ",
          "automaticamente...")
  source("R/emparejar_contenido.R", local = new.env())
  if (file.exists(ruta_mapeo)) {
    m <- utils::read.csv(ruta_mapeo, fileEncoding = "UTF-8")
    mapeo_cont <<- m[!is.na(m$archivo) & nzchar(m$archivo) &
                     m$estado %in% c("auto", "confirmado"), ]
    log_msg("Mapeo por contenido: ", nrow(mapeo_cont),
            " obras con archivo asignado; reintentando emparejamiento")
    emp <- t(vapply(seq_len(nrow(catalogo)), emparejar, character(2)))
    catalogo$archivo <- emp[, 1]
    catalogo$tipo_match <- emp[, 2]
  }
}
guardar_tabla(catalogo[, c("id_libro", "titulo", "nivel", "archivo", "tipo_match")],
              "mapeo_archivos")

sin_arch <- which(is.na(catalogo$archivo))
for (i in sin_arch)
  registrar_exclusion("01_ingesta", catalogo$id_libro[i], catalogo$titulo[i],
    ifelse(catalogo$tipo_match[i] == "sin_archivo_para_numero",
           "sin archivo para su numero de catalogo (no conseguida)",
           "archivo de texto no encontrado"),
    ifelse(catalogo$tipo_match[i] == "sin_archivo_para_numero",
           catalogo$numero[i], catalogo$archivo_cat[i]))
if (length(sin_arch) > 0 && config$detener_si_faltan)
  stop(length(sin_arch), " libros sin archivo. Ver mapeo_archivos.csv y ",
       "log_exclusiones.csv. Con detener_si_faltan = FALSE se excluyen y sigue.")
catalogo <- catalogo[!is.na(catalogo$archivo), ]

# --- lectura y limpieza ------------------------------------------------------
textos <- list()
for (i in seq_len(nrow(catalogo))) {
  ruta <- file.path(config$carpeta_textos, catalogo$archivo[i])
  txt <- tryCatch(limpiar_texto(leer_texto_cache(ruta)), error = function(e) {
    registrar_exclusion("01_ingesta", catalogo$id_libro[i], catalogo$titulo[i],
                        paste("error de lectura:", conditionMessage(e)), ruta)
    NULL
  })
  if (!is.null(txt) && stringi::stri_count_regex(txt, "\\S") >= 20) {
    textos[[catalogo$id_libro[i]]] <- txt
  } else if (!is.null(txt)) {
    registrar_exclusion("01_ingesta", catalogo$id_libro[i], catalogo$titulo[i],
      "texto vacio tras extraccion (PDF escaneado: requiere OCR completo)",
      catalogo$archivo[i])
  }
}
catalogo <- catalogo[catalogo$id_libro %in% names(textos), ]

log_msg("Ingesta: ", nrow(catalogo), " libros leidos")
P$catalogo <- catalogo
P$textos <- textos
