# ============================================================
# academicos.xlsx + MEMORIAS_ALUMNOS_2015_2025.xlsx  ->  data.js
#
# Lee los XLSX directamente. Ya no hay que exportar a CSV a mano.
# Escribe los CSV (siempre con COMA) y luego data.js:
#   window.MEMORIAS_CSV = "...";
#   window.ACADEMICOS_CSV = "...";
#
# POR QUE SE FUERZA LA COMA:
# el parser de la app (parseCSV en app_init.js) solo corta por coma.
# Si el CSV sale con punto y coma, la app lo lee como UNA sola
# columna y se pierden CORREO e IMAGEN. Eso es lo que estaba
# pasando con academicos.csv exportado a mano desde Excel.
#
# Requiere readxl (una sola vez):  install.packages("readxl")
# ============================================================

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop("Falta el paquete readxl. Ejecuta:  install.packages(\"readxl\")")
}

xlsx_academicos <- "academicos.xlsx"
hoja_academicos <- "academicos"
xlsx_memorias   <- "MEMORIAS_ALUMNOS_2015_2025.xlsx"
hoja_memorias   <- "DATOS"
csv_academicos  <- "academicos.csv"
csv_memorias    <- "memorias.csv"
archivo_salida  <- "data.js"

# Lee una hoja como texto plano, asi los anios no se vuelven 2015.0
leer_hoja <- function(ruta, hoja) {
  if (!file.exists(ruta)) stop("No existe el archivo: ", ruta)

  df <- readxl::read_excel(ruta, sheet = hoja,
                           col_types = "text", .name_repair = "minimal")
  df <- as.data.frame(df, stringsAsFactors = FALSE)

  df[] <- lapply(df, function(col) {
    col <- as.character(col)
    col[is.na(col)] <- ""
    col <- trimws(col)
    # readxl entrega los numeros como "2015.0". Deja "2015".
    num <- grepl("^-?[0-9]+\\.0+$", col)
    col[num] <- sub("\\.0+$", "", col[num])
    col
  })

  # Bota columnas fantasma de Excel y filas vacias
  nom <- trimws(names(df))
  df <- df[, nom != "" & !grepl("^\\.{3}[0-9]+$", nom), drop = FALSE]
  df <- df[rowSums(df != "") > 0, , drop = FALSE]
  df
}

# CSV con coma, UTF-8, sin BOM.
# OJO: no se usa write.csv() con fileEncoding. Segun el locale del equipo,
# R convierte los acentos en basura tipo <U+00BF>. Se arma el texto a mano
# y se escribe en bytes, asi el resultado no depende del locale.
celda_csv <- function(x) {
  x <- enc2utf8(as.character(x))
  necesita <- grepl('[",\n\r]', x)
  x[necesita] <- paste0('"', gsub('"', '""', x[necesita], fixed = TRUE), '"')
  x
}

escribir_csv <- function(df, ruta) {
  cabecera <- paste(celda_csv(names(df)), collapse = ",")

  if (nrow(df) == 0) {
    lineas <- cabecera
  } else {
    cols <- lapply(df, celda_csv)
    cuerpo <- do.call(paste, c(cols, sep = ","))
    lineas <- c(cabecera, cuerpo)
  }

  texto <- paste0(paste(lineas, collapse = "\n"), "\n")

  con <- file(ruta, open = "wb")
  on.exit(close(con), add = TRUE)
  writeChar(enc2utf8(texto), con, eos = NULL, useBytes = TRUE)
}

leer_texto_crudo <- function(ruta) {
  if (!file.exists(ruta)) stop("No existe el archivo: ", ruta)
  texto <- readChar(ruta, nchars = file.info(ruta)$size, useBytes = TRUE)
  Encoding(texto) <- "UTF-8"
  texto <- gsub("\r\n?", "\n", texto, perl = TRUE)
  texto <- sub("^\ufeff", "", texto)
  texto
}

escapar_js <- function(texto) {
  texto <- enc2utf8(texto)
  texto <- gsub("\\\\", "\\\\\\\\", texto, perl = TRUE)
  texto <- gsub("\"", "\\\\\"", texto, perl = TRUE)
  texto <- gsub("\n", "\\\\n", texto, perl = TRUE)
  texto <- gsub("\t", "\\\\t", texto, perl = TRUE)
  # OJO: UN solo backslash. Con dos, el navegador muestra el texto
  # literal \u003C en vez del caracter '<'.
  texto <- gsub("<", "\\u003C", texto, fixed = TRUE)
  texto <- gsub(">", "\\u003E", texto, fixed = TRUE)
  texto
}

avisar_separador <- function(df, nombre) {
  n <- sum(vapply(df, function(col) {
    sum(grepl(";", col, fixed = TRUE) & !grepl(",", col, fixed = TRUE))
  }, numeric(1)))
  if (n > 0) cat("  aviso:", nombre, "tiene", n, "celdas con ';'\n")
}

cat("Leyendo XLSX...\n")
academicos <- leer_hoja(xlsx_academicos, hoja_academicos)
memorias   <- leer_hoja(xlsx_memorias,   hoja_memorias)
cat("  academicos:", nrow(academicos), "filas,", ncol(academicos), "columnas\n")
cat("  memorias  :", nrow(memorias),   "filas,", ncol(memorias),   "columnas\n")

faltan <- setdiff(c("ACADEMICO", "CORREO", "IMAGEN"), names(academicos))
if (length(faltan)) stop("A academicos.xlsx le faltan columnas: ",
                         paste(faltan, collapse = ", "))

faltan <- setdiff(c("ESTUDIANTE", "PROFESOR GUIA", "TITULO", "ANIO PUBLICACION"),
                  names(memorias))
if (length(faltan)) stop("A ", xlsx_memorias, " le faltan columnas: ",
                         paste(faltan, collapse = ", "))

avisar_separador(academicos, "academicos")
avisar_separador(memorias,   "memorias")

cat("Escribiendo CSV (separador: coma)...\n")
escribir_csv(academicos, csv_academicos)
escribir_csv(memorias,   csv_memorias)

cat("Empaquetando data.js...\n")
data_js <- paste0(
  "/* Datos empaquetados automaticamente. NO editar a mano.\n",
  "   Edita los XLSX y ejecuta Conversor_tesis_v2.R para regenerar data.js */\n",
  "window.MEMORIAS_CSV = \"",   escapar_js(leer_texto_crudo(csv_memorias)),   "\";\n",
  "window.ACADEMICOS_CSV = \"", escapar_js(leer_texto_crudo(csv_academicos)), "\";\n"
)
writeLines(data_js, archivo_salida, useBytes = TRUE)

cat("\nListo.\n")
cat("  ", csv_academicos, "-", file.info(csv_academicos)$size, "bytes\n")
cat("  ", csv_memorias,   "-", file.info(csv_memorias)$size,   "bytes\n")
cat("  ", archivo_salida, "-", file.info(archivo_salida)$size, "bytes\n")
