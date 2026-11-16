# =============================================================================
# run_all.R
# Corre el análisis completo en orden. Cada paso es un script que también se
# puede correr solo; este archivo los encadena y se detiene en el primero que
# falla.
#
#   Rscript run_all.R                 los cuatro pasos
#   Rscript run_all.R --prueba        los cuatro pasos en modo de prueba (minutos)
#   Rscript run_all.R --desde 3       del paso 3 al final
#   Rscript run_all.R --solo 4        solo el paso 4
#   Rscript run_all.R --desde 2 --hasta 3
#   Rscript run_all.R --lista         muestra los pasos y termina
#
# El paso 2 es el largo: 1.000 repeticiones x 5 folds x 3 modelos x 12
# enfermedades. Guarda un checkpoint por enfermedad, así que se puede
# interrumpir y retomar, o repartir entre sesiones:
#   Rscript R/02_ajustar_modelos.R V8 V10
# Los pasos 3 y 4 solo leen checkpoints y toman segundos.
# =============================================================================

# El script se mueve a su propia carpeta, así que se puede llamar desde cualquiera.
local({
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(f) == 1) setwd(dirname(normalizePath(f)))
})

PASOS <- data.frame(
  numero = 1:4,
  script = c("01_preparar_datos.R", "02_ajustar_modelos.R", "03_tablas.R", "04_figuras.R"),
  descripcion = c(
    "lee la encuesta y deja la base de modelamiento",
    "chi-cuadrado, grid search, CV repetida, ganador y SHAP por enfermedad",
    "Excel de resultados y tablas CSV desde los checkpoints",
    "figuras SHAP desde los checkpoints"
  ),
  stringsAsFactors = FALSE
)

args <- commandArgs(trailingOnly = TRUE)

if ("--lista" %in% args) {
  cat("Pasos del análisis\n\n")
  for (i in seq_len(nrow(PASOS))) {
    cat(sprintf("  %d  %-24s %s\n", PASOS$numero[i], PASOS$script[i], PASOS$descripcion[i]))
  }
  quit(save = "no", status = 0)
}

valor_arg <- function(bandera, defecto) {
  i <- match(bandera, args)
  if (is.na(i)) return(defecto)
  valor <- suppressWarnings(as.integer(args[i + 1L]))
  if (is.na(valor) || !valor %in% PASOS$numero) {
    stop(bandera, " necesita un número de paso entre 1 y ", nrow(PASOS), call. = FALSE)
  }
  valor
}

solo  <- valor_arg("--solo", NA_integer_)
desde <- if (!is.na(solo)) solo else valor_arg("--desde", 1L)
hasta <- if (!is.na(solo)) solo else valor_arg("--hasta", nrow(PASOS))
if (desde > hasta) stop("--desde no puede ser mayor que --hasta", call. = FALSE)

# Los números que acompañan a --desde, --hasta y --solo no son enfermedades:
# con esta opción el paso 2 corre siempre las 12.
options(rheumacl.desde_run_all = TRUE)

for (i in which(PASOS$numero >= desde & PASOS$numero <= hasta)) {
  message("\n==================== Paso ", PASOS$numero[i], ": ", PASOS$script[i],
          " ====================")
  t0 <- Sys.time()
  source(file.path("R", PASOS$script[i]), local = new.env(), echo = FALSE, encoding = "UTF-8")
  message(sprintf("Paso %d terminado en %.0f s", PASOS$numero[i],
                  as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
message("\nAnálisis terminado. Los resultados están en la carpeta results/ ",
        "(results_prueba/ en modo de prueba).")
