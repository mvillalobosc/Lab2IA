# =============================================================================
#  01_datos.R
#  Metadata, coordenadas y definicion de los grupos de analisis.
#
#  QUE HACE Y POR QUE
#  Este paso decide la unidad de analisis y la congela. Ningun paso posterior
#  puede modificarla. En la version anterior 01 fusionaba grupos en silencio y
#  el resto del pipeline nunca se enteraba; aca la fusion es opcional, queda
#  registrada cepa por cepa y 12_validar.R la comprueba contra los linajes.
#
#  DECISIONES QUE SE TOMAN ACA
#  1. Una cepa sin grupo o sin coordenada no se inventa ni se manda a un cajon:
#     queda marcada como excluida con el motivo, y el conteo de excluidas viaja
#     hasta el manifiesto.
#  2. La ecologia y la ploidia se leen pero NO filtran. Filtrar por ecologia
#     antes de correr meteria la hipotesis dentro del analisis, y ademas la
#     etiqueta silvestre/domesticado deriva de la misma asignacion de linajes
#     que despues se quiere evaluar. Entran como estrato de sensibilidad en
#     11_controles.R.
#  3. El linaje se conserva por cepa. No agrupa, pero permite descomponer la
#     diversidad dentro y entre linajes en 04_diversidad.R, que es la respuesta
#     empirica al reparo de Wahlund.
# =============================================================================

# --- Ubicacion del script -----------------------------------------------------
# RStudio no cambia el directorio de trabajo al apretar Source, asi que
# source("00_config.R") falla si la sesion esta parada en otra carpeta. Este
# bloque encuentra la carpeta del propio archivo y se para ahi. Tres vias, en
# orden de fiabilidad:
#   1. sys.frames(): cuando el archivo se ejecuta con source(), R guarda su ruta
#      en ofile. Funciona con el boton Source de RStudio y no necesita paquetes.
#   2. rstudioapi: para cuando se ejecutan lineas sueltas desde el editor, donde
#      no hay ofile. Se usa solo si el paquete esta instalado.
#   3. El directorio actual, si ya contiene 00_config.R.
# Con Rscript ninguna de las tres hace falta y el bloque no toca nada.
local({
  cand <- character(0)
  for (i in seq_len(sys.nframe())) {
    of <- get0("ofile", envir = sys.frames()[[i]], inherits = FALSE)
    if (!is.null(of) && is.character(of) && nzchar(of)) cand <- c(cand, of)
  }
  if (!length(cand) && requireNamespace("rstudioapi", quietly = TRUE) &&
      isTRUE(try(rstudioapi::isAvailable(), silent = TRUE))) {
    p <- try(rstudioapi::getSourceEditorContext()$path, silent = TRUE)
    if (!inherits(p, "try-error") && length(p) && nzchar(p)) cand <- p
    q <- try(rstudioapi::getActiveProject(), silent = TRUE)
    if (!length(cand) && !inherits(q, "try-error") && length(q) && nzchar(q))
      cand <- file.path(q, "x")
  }
  for (p in cand) {
    d <- tryCatch(dirname(normalizePath(p, mustWork = FALSE)), error = function(e) "")
    if (nzchar(d) && file.exists(file.path(d, "00_config.R"))) {
      if (!identical(normalizePath(d), normalizePath(getwd()))) {
        setwd(d); message("Directorio de trabajo: ", d)
      }
      return(invisible(NULL))
    }
  }
  if (!file.exists("00_config.R"))
    stop("No encuentro 00_config.R. Abri la carpeta del pipeline como proyecto ",
         "en RStudio, o corre setwd() a mano.", call. = FALSE)
})

source("00_config.R")
log <- nuevo_log("01_datos"); log("=== 01 DATOS Y GRUPOS ===")

if (!file.exists(ARCHIVO_META))   stop("No existe ", ARCHIVO_META, call. = FALSE)
if (!file.exists(ARCHIVO_COORDS)) stop("No existe ", ARCHIVO_COORDS, call. = FALSE)

m <- leer_tabla(ARCHIVO_META)
log("Metadata: ", nrow(m), " filas, ", ncol(m), " columnas")

falta <- setdiff(c(COL_CEPA, COL_GRUPO, COL_SITIO), names(m))
if (length(falta)) stop("Faltan columnas en la metadata: ",
                        paste(falta, collapse = ", "), "\n  Hay: ",
                        paste(names(m), collapse = ", "), call. = FALSE)

m$.CEPA <- as.character(m[[COL_CEPA]])
if (length(RENOMBRAR)) {
  k <- m$.CEPA %in% names(RENOMBRAR)
  if (any(k)) { log("Cepas renombradas: ", sum(k)); m$.CEPA[k] <- RENOMBRAR[m$.CEPA[k]] }
}

# --- Grupo -------------------------------------------------------------------
# COL_GRUPO admite varias columnas. Con una sola se comporta como siempre; con
# varias, la etiqueta es la concatenacion. Sirve para correr la escala
# sitio-por-linaje sin tocar nada mas, que es la que da pi dentro de linaje sin
# perder la geografia.
partes <- lapply(COL_GRUPO, function(cl) {
  v <- as.character(m[[cl]])
  v[is.na(v) | !nzchar(trimws(v))] <- NA_character_
  v
})
incompleto <- Reduce(`|`, lapply(partes, is.na))
m$.GRUPO <- do.call(paste, c(partes, sep = " | "))
m$.GRUPO[incompleto] <- NA_character_
if (length(COL_GRUPO) > 1) log("Grupo compuesto: ", paste(COL_GRUPO, collapse = " + "))

m$.SITIO  <- as.character(m[[COL_SITIO]])
m$.LINAJE <- if (COL_LINAJE %in% names(m)) as.character(m[[COL_LINAJE]]) else NA_character_
m$.ECOL   <- if (nzchar(COL_ECOL) && COL_ECOL %in% names(m)) as.character(m[[COL_ECOL]]) else NA_character_
m$.PLOID  <- if (nzchar(COL_PLOIDIA) && COL_PLOIDIA %in% names(m)) as.character(m[[COL_PLOIDIA]]) else NA_character_
if (!is.null(SUBSET_COL) && !is.null(SUBSET_VAL)) m$.GRUPO[m[[SUBSET_COL]] != SUBSET_VAL] <- NA

# --- Coordenadas -------------------------------------------------------------
co <- leer_tabla(ARCHIVO_COORDS)
falta <- setdiff(c("Site", "Latitud", "Longitud"), names(co))
if (length(falta)) stop(basename(ARCHIVO_COORDS), " sin columna ",
                        paste(falta, collapse = ", "), call. = FALSE)
k <- match(normalizar_texto(m$.SITIO), normalizar_texto(co$Site))
m$.LAT <- suppressWarnings(as.numeric(co$Latitud[k]))
m$.LON <- suppressWarnings(as.numeric(co$Longitud[k]))
log("Coordenadas resueltas: ", sum(!is.na(m$.LAT)), " de ", nrow(m), " cepas")
sin_co <- unique(m$.SITIO[is.na(k)])
if (length(sin_co)) log("  Sitios sin fila en coordenadas (", length(sin_co), "): ",
                        paste(head(sin_co, 8), collapse = ", "))

# --- Exclusiones, declaradas una por una -------------------------------------
motivo <- rep(NA_character_, nrow(m))
if (length(EXCLUIR_LINAJE)) {
  fuera <- m$.LINAJE %in% EXCLUIR_LINAJE
  motivo[fuera] <- paste0("linaje excluido (", m$.LINAJE[fuera], ")")
  log("Linajes excluidos por configuracion: ", paste(EXCLUIR_LINAJE, collapse = ", "),
      " -> ", sum(fuera), " cepas fuera")
}
motivo[is.na(motivo) & is.na(m$.GRUPO)] <- "sin grupo"
motivo[is.na(motivo) & is.na(m$.LAT)] <- "sin coordenada"
usable <- is.na(motivo)
log("\nCepas usables: ", sum(usable), " de ", nrow(m))
for (mo in unique(na.omit(motivo)))
  log("  excluidas por ", mo, ": ", sum(motivo == mo, na.rm = TRUE))

md <- m[usable, ]

# --- Grupos, coordenada por grupo y peso -------------------------------------
tab <- table(md$.GRUPO)
grupos <- names(tab)
coord <- data.frame(
  grupo = grupos,
  lat = vapply(grupos, function(g) median(md$.LAT[md$.GRUPO == g], na.rm = TRUE), numeric(1)),
  lon = vapply(grupos, function(g) median(md$.LON[md$.GRUPO == g], na.rm = TRUE), numeric(1)),
  stringsAsFactors = FALSE)
precision <- rep("sitio", length(grupos))
log("\nGrupos formados: ", length(grupos))

# --- Fusion por coordenada ---------------------------------------------------
fusionados <- character(0)
if (FUSIONAR_COORD && length(grupos) > 1) {
  con_c <- which(!is.na(coord$lat))
  if (length(con_c) > 1) {
    DD <- outer(con_c, con_c, function(i, j)
      dist_km(coord$lat[i], coord$lon[i], coord$lat[j], coord$lon[j]))
    cl <- cutree(hclust(as.dist(DD), method = "single"), h = max(AGRUPAR_KM, 1e-6))
    nn <- grupos
    for (kk in unique(cl)) {
      mi <- con_c[cl == kk]; if (length(mi) < 2) next
      pri <- mi[order(-as.integer(tab[grupos[mi]]))][1]
      nn[mi] <- grupos[pri]
      fusionados <- c(fusionados, paste0(grupos[pri], " <- ",
                                         paste(grupos[mi], collapse = ", ")))
    }
    if (length(fusionados)) {
      log("\nAVISO: ", length(fusionados), " fusiones por coordenada compartida.")
      for (x in fusionados) log("  ", x)
      log("  Si la unidad de analisis fuera el linaje, esto seria un error:")
      log("  la coordenada de un linaje es un centroide sin significado.")
      mp <- setNames(nn, grupos)
      md$.GRUPO <- unname(mp[md$.GRUPO])
      tab <- table(md$.GRUPO); grupos <- names(tab)
      keep <- match(grupos, coord$grupo)
      coord <- coord[keep, ]; precision <- precision[keep]
      log("  Grupos tras fusionar: ", length(grupos))
    }
  }
} else if (!FUSIONAR_COORD) {
  log("\nFUSIONAR_COORD = FALSE: no se fusiona nada por coordenada compartida.")
}

n_g <- as.integer(tab[grupos])
peso <- if (PONDERAR) n_g * unname(PESO_PRECISION[precision]) else rep(1, length(grupos))
elegible <- n_g >= MIN_N_GRUPO & !is.na(coord$lat)
motivo_g <- ifelse(elegible, "ok",
                   ifelse(is.na(coord$lat), "sin coordenada",
                          paste0("n < ", MIN_N_GRUPO)))
log("\nGrupos elegibles: ", sum(elegible), " de ", length(grupos))
log("Cepas en grupos elegibles: ", sum(n_g[elegible]), " de ", sum(n_g))
log("Grupos con n < ", N_MIN_ARBOL, " (quedan fuera del arbol y de los tiempos): ",
    sum(n_g < N_MIN_ARBOL))

# --- Composicion de linajes por grupo, para el diagnostico de Wahlund --------
tb_lin <- table(md$.GRUPO, md$.LINAJE)
n_lin <- rowSums(tb_lin > 0)
mez <- names(n_lin)[n_lin > 1]
if (length(mez)) {
  cep_mez <- sum(rowSums(tb_lin)[mez])
  log("\nGrupos con mas de un linaje: ", length(mez), " de ", length(n_lin),
      ", con ", cep_mez, " de ", sum(rowSums(tb_lin)), " cepas (",
      round(100 * cep_mez / sum(rowSums(tb_lin))), "%)")
  log("  En esos grupos pi incorpora la diferencia ENTRE linajes (efecto")
  log("  Wahlund). 04_diversidad.R lo descompone y 11_controles.R comprueba")
  log("  que el origen estimado no dependa de esa componente.")
}

if (any(!is.na(md$.ECOL)))
  log("\nEcologia registrada: ", length(unique(na.omit(md$.ECOL))), " categorias")
if (any(!is.na(md$.PLOID))) {
  pl <- table(md$.PLOID)
  log("Ploidia: ", paste(names(pl), pl, sep = "=", collapse = ", "))
  alta <- sum(suppressWarnings(as.numeric(md$.PLOID)) > 2, na.rm = TRUE)
  if (alta > 0) log("  AVISO: ", alta, " cepas con ploidia > 2. Las frecuencias",
                    " alelicas de un llamador diploide estan sesgadas ahi.")
}

saveRDS(list(meta = md, excluidas = data.frame(cepa = m$.CEPA[!usable],
                                               motivo = motivo[!usable],
                                               stringsAsFactors = FALSE),
             grupos = grupos, coord = coord, precision = precision,
             n_cepas = n_g, peso = peso, elegible = elegible, motivo = motivo_g,
             fusionados = fusionados,
             linaje_por_cepa = setNames(md$.LINAJE, md$.CEPA),
             grupo_de_cepa = setNames(md$.GRUPO, md$.CEPA)),
        paso("datos"))
log("\nSiguiente: 02_variantes.R")
cerrar_log(log)
