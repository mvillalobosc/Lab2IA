## ============================================================================
## cargar_funciones.R
## ----------------------------------------------------------------------------
## Carga las funciones y la configuración (CFG) de ../consciencia_discreta.R
## sin ejecutar su sección 10 (la corrida completa), para que los análisis
## post hoc usen exactamente el mismo agente, los mismos bancos de ensayos y
## los mismos objetivos que la corrida del servidor. Las salidas de estos
## análisis quedan en post_hoc/resultados en vez de ../salida.
##
## Loads the functions and the configuration (CFG) of ../consciencia_discreta.R
## without running its section 10 (the full run), so that the post hoc
## analyses use exactly the same agent, trial banks and objectives as the
## server run. Their outputs go to post_hoc/resultados instead of ../salida.
## ============================================================================
local({
  lineas <- readLines("../consciencia_discreta.R", encoding = "UTF-8")
  fin <- grep("^## 10\\. Ejecución", lineas) - 2
  if (length(fin) != 1 || fin < 1) stop("No se encontró la sección 10 de consciencia_discreta.R")
  lineas <- lineas[seq_len(fin)]
  ## carpeta de salida de los análisis post hoc
  lineas <- sub('carpeta = "salida"', 'carpeta = "resultados"', lineas, fixed = TRUE)
  eval(parse(text = lineas, encoding = "UTF-8"), envir = globalenv())
})

## Lee un CSV que puede estar comprimido (el repositorio guarda
## validation_seed_fronts.csv como .csv.gz por su tamaño).
## Reads a CSV that may be gzipped (the repository stores
## validation_seed_fronts.csv as .csv.gz because of its size).
leer_csv <- function(ruta, ...) {
  if (!file.exists(ruta) && file.exists(paste0(ruta, ".gz"))) ruta <- paste0(ruta, ".gz")
  read.csv(ruta, stringsAsFactors = FALSE, ...)
}
