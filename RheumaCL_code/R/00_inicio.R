# =============================================================================
# R/00_inicio.R
# Punto de partida común de todos los pasos: comprueba y carga los paquetes,
# lee config.R, activa el modo de prueba si se pidió, carga las funciones y
# crea las carpetas de salida.
#
# Cada paso empieza con source(file.path("R", "00_inicio.R")), así que los
# scripts se corren desde la carpeta del proyecto (la que tiene run_all.R).
# =============================================================================

# Los archivos y la encuesta traen tildes y eñes. R debe correr con una
# configuración regional que las admita: UTF-8 es la opción por defecto en
# Linux, en macOS y en Windows desde R 4.2. (Este mensaje va sin tildes porque
# se muestra justo cuando la sesión no las admite.)
if (is.na(iconv("í", from = "UTF-8", to = ""))) {
  stop("R esta corriendo con una configuracion regional sin tildes (",
       Sys.getlocale("LC_CTYPE"), "). Use una UTF-8, por ejemplo en Linux:\n",
       "  LC_ALL=es_CL.UTF-8 Rscript run_all.R     (o LC_ALL=C.UTF-8)", call. = FALSE)
}

if (!file.exists("config.R") || !dir.exists("R")) {
  stop("Corra los scripts desde la carpeta del proyecto (la que tiene config.R y run_all.R).",
       call. = FALSE)
}

# -----------------------------------------------------------------------------
# Paquetes
# -----------------------------------------------------------------------------
# Ningún script instala paquetes: si falta alguno, se detiene y muestra la
# llamada a install.packages() lista para copiar.
PAQUETES <- c(
  "readxl",        # lectura del Excel de la encuesta
  "dplyr",         # manipulación de datos
  "tidyr",         # pivot_longer para la tabla SHAP
  "forcats",       # orden de las barras en las figuras
  "caret",         # folds estratificados y one-hot encoding (dummyVars)
  "randomForest",  # Random Forest
  "xgboost",       # XGBoost
  "pROC",          # AUC-ROC
  "doParallel",    # backend paralelo de foreach
  "foreach",       # bucle paralelo del grid search
  "doRNG",         # semillas reproducibles en el bucle paralelo (%dorng%)
  "fastshap",      # valores SHAP por permutaciones
  "shapviz",       # contenedor de los valores SHAP
  "ggplot2",       # figuras
  "openxlsx"       # Excel de resultados con varias hojas
)

local({
  faltan <- PAQUETES[!vapply(PAQUETES, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan) > 0) {
    stop("Faltan paquetes. Instálelos con:\n  install.packages(c(",
         paste0('"', faltan, '"', collapse = ", "), "))", call. = FALSE)
  }
})

suppressPackageStartupMessages({
  for (paquete in PAQUETES) library(paquete, character.only = TRUE)
})
rm(paquete)

# -----------------------------------------------------------------------------
# Configuración y modo de prueba
# -----------------------------------------------------------------------------
source("config.R", encoding = "UTF-8")

# El modo de prueba se activa con Rscript run_all.R --prueba, con el argumento
# --prueba en cualquier paso o con la variable de entorno RHEUMACL_PRUEBA=1.
MODO_PRUEBA <- "--prueba" %in% commandArgs(trailingOnly = TRUE) ||
  identical(Sys.getenv("RHEUMACL_PRUEBA"), "1")
if (MODO_PRUEBA) {
  CFG <- utils::modifyList(CFG, CFG$prueba)
  message("MODO DE PRUEBA: ", CFG$n_iter, " repeticiones, grillas reducidas, salida en ",
          CFG$dir_resultados, "/. Estas cifras no son las del artículo.")
}

stopifnot(
  length(CFG$enfermedades) == length(CFG$nombres_enfermedades),
  length(CFG$enfermedades) == length(CFG$nombres_ingles),
  !anyDuplicated(CFG$enfermedades),
  !anyDuplicated(CFG$nombres_enfermedades)
)

# -----------------------------------------------------------------------------
# Rutas derivadas (se crean si no existen)
# -----------------------------------------------------------------------------
RUTAS <- list(
  datos_modelo = file.path(CFG$dir_procesados, "encuesta_modelo.rds"),
  checkpoints  = file.path(CFG$dir_resultados, "checkpoints"),
  tablas       = file.path(CFG$dir_resultados, "tables"),
  figuras      = file.path(CFG$dir_resultados, "figures"),
  registros    = file.path(CFG$dir_resultados, "logs")
)
for (carpeta in c(CFG$dir_procesados, RUTAS$checkpoints, RUTAS$tablas,
                  RUTAS$figuras, RUTAS$registros)) {
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
}
rm(carpeta)

# -----------------------------------------------------------------------------
# Funciones
# -----------------------------------------------------------------------------
for (archivo in c("funciones_utiles.R", "funciones_metricas.R", "funciones_seleccion.R",
                  "funciones_modelos.R", "funciones_shap.R", "funciones_analisis.R",
                  "funciones_excel.R")) {
  source(file.path("R", archivo), encoding = "UTF-8")
}
rm(archivo)
