# =============================================================================
# 01_preparar_datos.R
# Lee los seis archivos GRD públicos de Fonasa (2019-2024), unifica el
# identificador del beneficiario, calcula el signo (12 y 13 signos) y la
# estancia, agrupa diagnósticos y procedimientos, y guarda una base compacta.
#
# Entrada: CFG$dir_grd/GRD_PUBLICO_<año>.txt (separador "|"), tal como se
#          descargan del catálogo de datos GRD de Fonasa:
#          https://public.tableau.com/views/PropuestaTableroGRD/PropuestaTableroGRD
# Salida:  CFG$dir_datos/base_grd.rds
#          CFG$dir_resultados/filas_excluidas.csv
#          CFG$dir_resultados/episodios_por_beneficiario.csv
#          CFG$dir_resultados/episodios_por_signo.csv
# =============================================================================

source("00_funciones.R")
dir_crear(CFG$dir_datos)
dir_crear(CFG$dir_resultados)

# Solo se leen las columnas que usa el análisis.
COLUMNAS <- c("ID_BENEFICIARIO", "CIP_ENCRIPTADO", "FECHA_NACIMIENTO",
              "ESPECIALIDAD_MEDICA", "FECHA_INGRESO", "FECHAALTA",
              campos_diag(), campos_proc())
NA_TEXTO <- c("", "NA", "N/A", "NULL", "NaN", "nan", "null")

# Lectura de un archivo según su codificación:
# - 2022 y 2023 vienen en UTF-16;
# - 2024 trae bytes corruptos: se decodifica como latin-1, se reemplazan los
#   bytes inválidos y se eliminan las líneas en blanco intercaladas;
# - el resto viene en UTF-8.
# Como en la lectura original (pandas, on_bad_lines = "skip"), se descartan las
# líneas con más campos que el encabezado y se completan las que traen menos.
leer_grd <- function(anio) {
  ruta <- file.path(CFG$dir_grd, sprintf("GRD_PUBLICO_%d.txt", anio))
  if (!file.exists(ruta)) stop("No existe el archivo ", ruta)
  if (anio == 2024) {
    bytes <- readBin(ruta, "raw", file.info(ruta)$size)
    bytes <- bytes[bytes != as.raw(0)]
    texto <- iconv(rawToChar(bytes), from = "latin1", to = "UTF-8", sub = "?")
    lineas <- strsplit(gsub("\r\n", "\n", texto, fixed = TRUE), "\n", fixed = TRUE)[[1]]
    rm(bytes, texto)
  } else {
    con <- file(ruta, encoding = if (anio %in% c(2022, 2023)) "UTF-16" else "UTF-8")
    lineas <- readLines(con, warn = FALSE)
    close(con)
  }
  # Quita la marca BOM inicial, si viene.
  b <- charToRaw(lineas[1])
  if (length(b) >= 3 && identical(b[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    lineas[1] <- rawToChar(b[-(1:3)])
    Encoding(lineas[1]) <- "UTF-8"
  }
  lineas <- lineas[nzchar(trimws(lineas))]
  n_sep <- nchar(lineas) - nchar(gsub("|", "", lineas, fixed = TRUE))
  descartadas <- sum(n_sep[-1] > n_sep[1])
  lineas <- lineas[c(TRUE, n_sep[-1] <= n_sep[1])]
  cab <- strsplit(lineas[1], "|", fixed = TRUE)[[1]]
  dt <- fread(text = lineas, sep = "|", quote = "", colClasses = "character",
              select = intersect(COLUMNAS, cab), na.strings = NA_TEXTO,
              fill = TRUE, showProgress = FALSE)
  if (descartadas > 0) message(sprintf("%d: %d líneas con campos de más descartadas", anio, descartadas))
  # Los archivos anteriores a 2024 llaman CIP_ENCRIPTADO al identificador.
  if ("CIP_ENCRIPTADO" %in% names(dt)) setnames(dt, "CIP_ENCRIPTADO", "ID_BENEFICIARIO")
  dt[, ANIO_ARCHIVO := anio]
  message(sprintf("%d: %s episodios", anio, format(nrow(dt), big.mark = ",")))
  dt
}

base <- rbindlist(lapply(CFG$anios, leer_grd), use.names = TRUE, fill = TRUE)
message("Total unificado: ", format(nrow(base), big.mark = ","))

# --- Signo zodiacal ----------------------------------------------------------
base[, FECHA_NACIMIENTO := leer_fecha(FECHA_NACIMIENTO)]
excluir <- is.na(base$FECHA_NACIMIENTO)
fwrite(base[excluir], file.path(CFG$dir_resultados, "filas_excluidas.csv"))
base <- base[!excluir]
message("Episodios sin fecha de nacimiento excluidos: ", sum(excluir))

base[, SIGNO := signo_12(FECHA_NACIMIENTO)]
base[, SIGNO13 := signo_13(FECHA_NACIMIENTO)]

# --- Estancia en días (vacía o negativa -> 0) ---------------------------------
base[, ESTANCIA_DIAS := as.integer(leer_fecha(FECHAALTA) - leer_fecha(FECHA_INGRESO))]
base[is.na(ESTANCIA_DIAS) | ESTANCIA_DIAS < 0, ESTANCIA_DIAS := 0L]

# --- Agrupación de códigos (se guardan como factores para ahorrar memoria) ----
for (cmp in campos_diag()) set(base, j = cmp, value = factor(agrupar_diagnostico(base[[cmp]])))
for (cmp in campos_proc()) set(base, j = cmp, value = factor(agrupar_procedimiento(base[[cmp]])))
base[, ESPECIALIDAD_MEDICA := factor(ESPECIALIDAD_MEDICA)]

# --- Episodios por beneficiario ----------------------------------------------
epi <- base[!is.na(ID_BENEFICIARIO), .N, by = ID_BENEFICIARIO]
resumen_epi <- data.table(
  indicador = c("episodios", "beneficiarios_unicos", "episodios_por_beneficiario",
                "beneficiarios_con_mas_de_un_episodio", "porcentaje_beneficiarios_repetidos",
                "porcentaje_episodios_de_beneficiarios_repetidos"),
  valor = c(nrow(base), nrow(epi), nrow(base) / nrow(epi), sum(epi$N > 1),
            100 * mean(epi$N > 1), 100 * sum(epi$N[epi$N > 1]) / nrow(base)))
fwrite(resumen_epi, file.path(CFG$dir_resultados, "episodios_por_beneficiario.csv"))

# --- Episodios por signo en los dos calendarios -------------------------------
conteo <- merge(base[, .(doce_signos = .N), keyby = .(signo = SIGNO)],
                base[, .(trece_signos = .N), keyby = .(signo = SIGNO13)], all = TRUE)
fwrite(conteo, file.path(CFG$dir_resultados, "episodios_por_signo.csv"))
print(conteo)

base[, c("FECHA_NACIMIENTO", "FECHA_INGRESO", "FECHAALTA") := NULL]
saveRDS(base, file.path(CFG$dir_datos, "base_grd.rds"))
message("Base preparada: ", format(nrow(base), big.mark = ","), " episodios")
