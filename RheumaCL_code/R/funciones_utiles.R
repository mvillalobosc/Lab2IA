# =============================================================================
# R/funciones_utiles.R
# Funciones de apoyo que no hacen cálculo estadístico: formato de tiempos,
# lectura de argumentos y registro del entorno de cada corrida.
# =============================================================================

# -----------------------------------------------------------------------------
# Formatea segundos como mm:ss o hh:mm:ss.
# -----------------------------------------------------------------------------
formatear_tiempo <- function(segundos) {
  segundos <- round(segundos)
  h <- segundos %/% 3600
  m <- (segundos %% 3600) %/% 60
  s <- segundos %% 60
  if (h > 0) sprintf("%02dh %02dm %02ds", h, m, s)
  else        sprintf("%02dm %02ds", m, s)
}

# -----------------------------------------------------------------------------
# Enfermedades pedidas por línea de comandos.
#   Rscript R/02_ajustar_modelos.R V8 V10
# corre solo esas dos, lo que permite repartir una corrida larga entre sesiones
# o máquinas. Sin argumentos, o cuando el paso lo llama run_all.R, se usan las
# 12 de config.R. Devuelve los índices dentro de CFG$enfermedades.
# -----------------------------------------------------------------------------
enfermedades_pedidas <- function() {
  if (isTRUE(getOption("rheumacl.desde_run_all"))) return(seq_along(CFG$enfermedades))

  argumentos <- commandArgs(trailingOnly = TRUE)
  argumentos <- argumentos[!grepl("^--", argumentos)]
  if (length(argumentos) == 0) return(seq_along(CFG$enfermedades))

  indices <- match(argumentos, CFG$enfermedades)
  if (anyNA(indices)) {
    stop("Enfermedad desconocida: ", paste(argumentos[is.na(indices)], collapse = ", "),
         ". Las válidas son: ", paste(CFG$enfermedades, collapse = ", "), call. = FALSE)
  }
  indices
}

# -----------------------------------------------------------------------------
# Guarda en results/logs/sesion_<paso>.txt el entorno que produjo una corrida:
# fecha, versión de R, configuración regional, versión de cada paquete y los
# parámetros de config.R.
#
# Dos cosas del entorno cambian los números y por eso quedan registradas:
#   - la versión de xgboost: entre la serie 1.7 y la 3.x cambió el método de
#     construcción de árboles por defecto;
#   - la configuración regional (LC_COLLATE): as.factor() ordena los niveles
#     de cada variable según ella, y ese orden fija el de las columnas one-hot.
# -----------------------------------------------------------------------------
registrar_sesion <- function(paso) {
  versiones <- vapply(PAQUETES, function(p) as.character(utils::packageVersion(p)), character(1))
  parametros <- CFG[setdiff(names(CFG), "prueba")]
  lineas <- c(
    paste("Paso:               ", paso),
    paste("Fecha:              ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("Modo de prueba:     ", if (MODO_PRUEBA) "SI" else "NO"),
    paste("R:                  ", R.version.string),
    paste("Plataforma:         ", R.version$platform),
    paste("LC_COLLATE:         ", Sys.getlocale("LC_COLLATE")),
    paste("LC_CTYPE:           ", Sys.getlocale("LC_CTYPE")),
    paste("Núcleos detectados: ", parallel::detectCores()),
    "",
    "Paquetes:",
    sprintf("  %-14s %s", names(versiones), versiones),
    "",
    "Parámetros (config.R):",
    vapply(names(parametros), function(nombre) {
      valor <- parametros[[nombre]]
      sprintf("  %-20s %s", nombre, if (is.null(valor)) "NULL" else paste(valor, collapse = ", "))
    }, character(1))
  )
  ruta <- file.path(RUTAS$registros, paste0("sesion_", paso, ".txt"))
  writeLines(enc2utf8(lineas), ruta, useBytes = TRUE)
  invisible(ruta)
}
