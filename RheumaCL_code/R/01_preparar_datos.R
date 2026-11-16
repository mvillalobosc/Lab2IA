# =============================================================================
# R/01_preparar_datos.R
# Lee la encuesta, unifica las respuestas SI/NO, convierte todo a factor y
# saca las variables que no entran al análisis.
#
# Entrada:  CFG$archivo_encuesta (data/raw/data_encuesta_filtrado.xlsx)
# Salidas:  data/processed/encuesta_modelo.rds   base lista para modelar
#           results/tables/flujo_registros.csv   filas y columnas en cada regla
#           results/tables/prevalencias.csv      casos y prevalencia por enfermedad
#
#   Rscript R/01_preparar_datos.R
# =============================================================================

source(file.path("R", "00_inicio.R"))
registrar_sesion("01_preparar_datos")

if (!file.exists(CFG$archivo_encuesta)) {
  stop("No se encuentra ", CFG$archivo_encuesta,
       ". La encuesta no viene en el repositorio: copie ahí el archivo ",
       "(ver data/README.md).", call. = FALSE)
}

# -----------------------------------------------------------------------------
# Lectura y limpieza
# -----------------------------------------------------------------------------
data_original <- read_excel(CFG$archivo_encuesta)

# Las respuestas afirmativas y negativas vienen escritas de varias formas
# (SI, Si, Sí, SÍ; NO, No, no): se dejan como SI y NO. Todas las variables son
# categóricas y pasan a factor.
data_filtrado <- data_original %>%
  mutate(across(everything(), ~ case_when(
    . %in% c("SI", "Si", "Sí", "SÍ") ~ "SI",
    . %in% c("NO", "No", "no")       ~ "NO",
    TRUE                              ~ as.character(.)
  ))) %>%
  mutate(across(everything(), as.factor))

# Variables fuera del análisis (ver config.R)
no_estan <- setdiff(CFG$variables_excluidas, names(data_filtrado))
if (length(no_estan) > 0) {
  stop("La base no trae estas variables de CFG$variables_excluidas: ",
       paste(no_estan, collapse = ", "), call. = FALSE)
}
data_filtrado <- data_filtrado %>% select(-all_of(CFG$variables_excluidas))

# -----------------------------------------------------------------------------
# Controles: ninguna enfermedad ni encuestado se pierde sin aviso
# -----------------------------------------------------------------------------
no_estan <- setdiff(CFG$enfermedades, names(data_filtrado))
if (length(no_estan) > 0) {
  stop("La base no trae estas enfermedades de CFG$enfermedades: ",
       paste(no_estan, collapse = ", "), call. = FALSE)
}
for (enfermedad in CFG$enfermedades) {
  valores <- data_filtrado[[enfermedad]]
  if (anyNA(valores) || !setequal(levels(valores), c("SI", "NO"))) {
    stop(enfermedad, " debe tener solo respuestas SI y NO, sin datos faltantes. Niveles: ",
         paste(levels(valores), collapse = ", "), call. = FALSE)
  }
}
stopifnot(nrow(data_filtrado) == nrow(data_original))

saveRDS(data_filtrado, RUTAS$datos_modelo)

# -----------------------------------------------------------------------------
# Flujo de registros y prevalencias
# -----------------------------------------------------------------------------
# Aquí no sale ninguna fila. Las filas con datos faltantes se conservan y solo
# salen, enfermedad por enfermedad, si el faltante cae en una de sus variables
# seleccionadas (paso 2, casos completos); ese número queda en la
# configuración de cada enfermedad.
con_faltantes <- names(data_filtrado)[vapply(data_filtrado, anyNA, logical(1))]

flujo <- data.frame(
  Regla = c(
    "Filas leídas del Excel",
    "Columnas leídas del Excel",
    paste0("Columnas excluidas (", paste(CFG$variables_excluidas, collapse = ", "), ")"),
    "Filas de la base de modelamiento",
    "Columnas de la base de modelamiento",
    "Enfermedades analizadas (variables objetivo)",
    paste0("Columnas con datos faltantes",
           if (length(con_faltantes) > 0) paste0(" (", paste(con_faltantes, collapse = ", "), ")") else ""),
    "Filas con algún dato faltante"
  ),
  N = c(
    nrow(data_original),
    ncol(data_original),
    length(CFG$variables_excluidas),
    nrow(data_filtrado),
    ncol(data_filtrado),
    length(CFG$enfermedades),
    length(con_faltantes),
    sum(!complete.cases(data_filtrado))
  ),
  stringsAsFactors = FALSE
)
write.csv(flujo, file.path(RUTAS$tablas, "flujo_registros.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

prevalencias <- data.frame(
  Codigo      = CFG$enfermedades,
  Enfermedad  = CFG$nombres_enfermedades,
  N_casos     = vapply(CFG$enfermedades,
                       function(e) sum(data_filtrado[[e]] == "SI"), integer(1),
                       USE.NAMES = FALSE),
  stringsAsFactors = FALSE
)
prevalencias$N_total     <- nrow(data_filtrado)
prevalencias$Prevalencia <- round(prevalencias$N_casos / prevalencias$N_total, 4)
write.csv(prevalencias, file.path(RUTAS$tablas, "prevalencias.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

cat("\nBase de modelamiento: ", nrow(data_filtrado), " encuestados y ",
    ncol(data_filtrado), " variables (", RUTAS$datos_modelo, ")\n\n", sep = "")
print(flujo, row.names = FALSE, right = FALSE)
cat("\n")
print(prevalencias, row.names = FALSE, right = FALSE)
