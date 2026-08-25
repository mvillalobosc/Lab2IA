# =============================================================================
# run_all.R : ejecuta el pipeline completo.
#   Rscript run_all.R
# Antes de correr, revisar las rutas y columnas en config.R.
# =============================================================================

t_inicio <- Sys.time()
source("config.R")
source("R/utils.R")
source("R/00_setup.R")     # paquetes, carpetas, modelo udpipe

# Tests unitarios de metricas: si algo falla, no se toca el corpus
log_msg("Version del pipeline: ", config$version_pipeline)
log_msg("Ejecutando tests unitarios de metricas...")
source("tests/test_metricas.R")

# Ambiente compartido entre modulos
P <- new.env()

modulos <- c("01_ingesta", "02_validacion", "03_anotacion",
             "04_perfil_gramatical", "05_afectivo", "06_complejidad",
             "07_lexico", "08_semantica_clustering", "09_topicos",
             "10_estadistica_nivel", "11_desajustados", "12_reporte")

tiempos <- data.frame(modulo = character(), segundos = numeric())
for (.m in modulos) {
  log_msg("========== MODULO ", .m, " ==========")
  .t0 <- Sys.time()
  tryCatch(
    source(file.path("R", paste0(.m, ".R"))),
    error = function(e) {
      log_msg("ERROR en ", .m, ": ", conditionMessage(e))
      stop("Pipeline detenido en ", .m, ": ", conditionMessage(e), call. = FALSE)
    }
  )
  .dt <- as.numeric(difftime(Sys.time(), .t0, units = "secs"))
  tiempos <- rbind(tiempos, data.frame(modulo = .m, segundos = round(.dt, 1)))
  log_msg("Modulo ", .m, " completado en ", round(.dt, 1), " s")
}

guardar_tabla(tiempos, "tiempos_ejecucion")
log_msg("PIPELINE COMPLETO en ",
        round(as.numeric(difftime(Sys.time(), t_inicio, units = "mins")), 1),
        " min. Resultados en ", config$carpeta_salida, "/")
