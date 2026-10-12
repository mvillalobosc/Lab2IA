# ============================================================
# BD_papers.csv -> data.js
# Salida:
# window.PAPERS_CSV = "...";
# ============================================================

input_csv <- "BD_papers.csv"
output_js <- "data.js"

if (!file.exists(input_csv)) {
  stop("No existe el archivo: ", input_csv)
}

csv_text <- readChar(
  con = input_csv,
  nchars = file.info(input_csv)$size,
  useBytes = TRUE
)

Encoding(csv_text) <- "UTF-8"

# Normaliza saltos de línea
csv_text <- gsub("\r\n?", "\n", csv_text, perl = TRUE)

# Escapa el texto como string válido de JavaScript
js_string <- encodeString(
  enc2utf8(csv_text),
  quote = "\""
)

# Evita problemas si se inserta dentro de HTML.
# OJO: UN solo backslash. Con dos, el navegador muestra el texto
# literal \u003C en vez del caracter '<' (bug de la version anterior).
js_string <- gsub("<", "\\u003C", js_string, fixed = TRUE)
js_string <- gsub(">", "\\u003E", js_string, fixed = TRUE)

js_code <- paste0(
  "window.PAPERS_CSV = ",
  js_string,
  ";\n"
)

writeLines(js_code, output_js, useBytes = TRUE)

cat("Listo:", output_js, "\n")
cat("Filas CSV:", length(strsplit(csv_text, "\n", fixed = TRUE)[[1]]), "\n")
cat("Tamaño JS:", file.info(output_js)$size, "bytes\n")