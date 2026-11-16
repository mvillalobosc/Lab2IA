# =============================================================================
# R/02_ajustar_modelos.R
# Ajusta y compara RL, RF y XGBoost para cada enfermedad con
# analizar_enfermedad() (R/funciones_analisis.R). Es el paso largo.
#
# Entrada:  data/processed/encuesta_modelo.rds (paso 1)
# Salida:   results/checkpoints/<hoja>.rds, uno por enfermedad
#
# Cada enfermedad se guarda apenas termina. Si la corrida se interrumpe, al
# volver a correr se saltan las que ya tienen checkpoint; para repetir una hay
# que borrar su archivo.
#
#   Rscript R/02_ajustar_modelos.R            las 12 enfermedades
#   Rscript R/02_ajustar_modelos.R V8 V10     solo esas (para repartir la corrida)
# =============================================================================

source(file.path("R", "00_inicio.R"))
registrar_sesion("02_ajustar_modelos")

if (!file.exists(RUTAS$datos_modelo)) {
  stop("Falta ", RUTAS$datos_modelo, ". Corra antes R/01_preparar_datos.R.", call. = FALSE)
}
data_filtrado <- readRDS(RUTAS$datos_modelo)

indices    <- enfermedades_pedidas()
rutas_ckpt <- file.path(RUTAS$checkpoints, paste0(CFG$nombres_enfermedades, ".rds"))
pendientes <- indices[!file.exists(rutas_ckpt[indices])]

cat("\n============================================================\n")
cat("ANÁLISIS UNIFICADO:", length(indices), "ENFERMEDADES\n")
cat("Checkpoints en:", normalizePath(RUTAS$checkpoints), "\n")
cat("============================================================\n")

if (length(pendientes) < length(indices)) {
  cat("\nYa tienen checkpoint y se omiten:\n")
  for (i in setdiff(indices, pendientes)) cat("  -", CFG$nombres_enfermedades[i], "\n")
}

# Cluster paralelo, solo para el grid search de RF y XGB
cl <- NULL
if (length(pendientes) > 0) {
  n_nucleos <- if (is.null(CFG$n_nucleos)) max(1, parallel::detectCores() - 1) else CFG$n_nucleos
  cl <- parallel::makePSOCKcluster(n_nucleos)
  registerDoParallel(cl)
  parallel::clusterExport(cl, FUNCIONES_PARA_WORKERS)
  cat("\nCluster paralelo con", n_nucleos, "núcleos\n")
}

tiempo_inicio <- Sys.time()
tiempos       <- setNames(rep(NA_real_, length(indices)), CFG$nombres_enfermedades[indices])
sin_resultado <- character(0)

tryCatch({
  for (i in pendientes) {
    enfermedad  <- CFG$enfermedades[i]
    nombre_hoja <- CFG$nombres_enfermedades[i]

    cat("\n[", match(i, indices), "/", length(indices), "] ", nombre_hoja, "\n", sep = "")

    t_ini <- Sys.time()
    resultado <- tryCatch(
      analizar_enfermedad(enfermedad, data_filtrado),
      error = function(e) {
        cat("  !! ERROR en", enfermedad, ":", conditionMessage(e), "\n")
        NULL
      }
    )
    t_enf <- as.numeric(difftime(Sys.time(), t_ini, units = "secs"))
    tiempos[nombre_hoja] <- t_enf

    # El checkpoint se guarda apenas termina la enfermedad
    if (!is.null(resultado)) {
      resultado$tiempo_segundos <- t_enf
      saveRDS(resultado, rutas_ckpt[i])
      cat("  -> Checkpoint guardado:", rutas_ckpt[i], "\n")
    } else {
      sin_resultado <- c(sin_resultado, nombre_hoja)
    }

    t_total <- as.numeric(difftime(Sys.time(), tiempo_inicio, units = "secs"))
    hechas  <- match(i, pendientes)
    cat("  Tiempo de la enfermedad: ", formatear_tiempo(t_enf),
        " | Transcurrido: ", formatear_tiempo(t_total),
        " | Restante estimado: ",
        formatear_tiempo(t_total / hechas * (length(pendientes) - hechas)),
        "\n", sep = "")
  }
}, finally = {
  if (!is.null(cl)) {
    parallel::stopCluster(cl)
    cat("\nCluster paralelo cerrado\n")
  }
})

cat("\nTIEMPOS POR ENFERMEDAD\n")
for (nombre in names(tiempos)) {
  cat(sprintf("  %-28s %s\n", nombre,
              if (is.na(tiempos[nombre])) "(ya tenía checkpoint)"
              else formatear_tiempo(tiempos[nombre])))
}
cat(sprintf("  %-28s %s\n", "TOTAL",
            formatear_tiempo(as.numeric(difftime(Sys.time(), tiempo_inicio, units = "secs")))))

# Ninguna enfermedad queda fuera en silencio
if (length(sin_resultado) > 0) {
  cat("\n!! Sin resultado (revise los mensajes de arriba):",
      paste(sin_resultado, collapse = ", "), "\n")
} else {
  cat("\nEnfermedades pedidas con checkpoint:", length(indices), "de", length(indices), "\n")
}
