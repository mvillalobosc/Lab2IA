# =============================================================================
# R/03_tablas.R
# Arma el Excel de resultados y las tablas en CSV a partir de los checkpoints.
# No reentrena nada: se puede repetir cuantas veces haga falta.
#
# Entrada:  results/checkpoints/<hoja>.rds (paso 2). También sirven los
#           checkpoints del script original (checkpoints_caracterizacion/).
# Salidas:  results/tables/Resultados_Unificado.xlsx   hoja Resumen y una hoja
#                                                      por enfermedad
#           results/tables/resumen.csv                 la hoja Resumen
#           results/tables/comparacion_modelos.csv     RL, RF y XGB por enfermedad
#           results/tables/estabilidad_cv.csv          media, SD y percentiles
#           results/tables/shap_top.csv                tabla SHAP del ganador
#
#   Rscript R/03_tablas.R
# =============================================================================

source(file.path("R", "00_inicio.R"))
registrar_sesion("03_tablas")

wb <- createWorkbook()
addWorksheet(wb, "Resumen")

filas_resumen <- list()
comparaciones <- list()
estabilidades <- list()
tablas_shap   <- list()
sin_resultado <- character(0)

for (i in seq_along(CFG$enfermedades)) {
  nombre_hoja <- CFG$nombres_enfermedades[i]
  ruta_ckpt   <- file.path(RUTAS$checkpoints, paste0(nombre_hoja, ".rds"))

  if (!file.exists(ruta_ckpt)) {
    sin_resultado <- c(sin_resultado, nombre_hoja)
    next
  }
  resultado <- readRDS(ruta_ckpt)

  escribir_hoja_enfermedad(wb, nombre_hoja, resultado)

  filas_resumen[[nombre_hoja]] <- fila_resumen(nombre_hoja, resultado)
  comparaciones[[nombre_hoja]] <- cbind(Enfermedad = nombre_hoja, resultado$tabla_comparacion)
  estabilidades[[nombre_hoja]] <- cbind(Enfermedad = nombre_hoja, resultado$resumen_boot)
  tablas_shap[[nombre_hoja]]   <- cbind(Enfermedad = nombre_hoja,
                                        Modelo_Ganador = resultado$ganador,
                                        as.data.frame(resultado$shap_tabla))
  cat("  [", CFG$enfermedades[i], "] Hoja escrita\n", sep = "")
}

if (length(filas_resumen) == 0) {
  stop("No hay ningún checkpoint en ", RUTAS$checkpoints,
       ". Corra antes R/02_ajustar_modelos.R.", call. = FALSE)
}

unir <- function(lista) {
  tabla <- do.call(rbind, lista)
  rownames(tabla) <- NULL
  tabla
}
tabla_resumen <- unir(filas_resumen)
escribir_hoja_resumen(wb, tabla_resumen)

ruta_excel <- file.path(RUTAS$tablas, "Resultados_Unificado.xlsx")
saveWorkbook(wb, ruta_excel, overwrite = TRUE)

guardar_csv <- function(tabla, nombre) {
  write.csv(tabla, file.path(RUTAS$tablas, nombre), row.names = FALSE, fileEncoding = "UTF-8")
}
guardar_csv(tabla_resumen,       "resumen.csv")
guardar_csv(unir(comparaciones), "comparacion_modelos.csv")
guardar_csv(unir(estabilidades), "estabilidad_cv.csv")
guardar_csv(unir(tablas_shap),   "shap_top.csv")

cat("\nExcel guardado en ", ruta_excel, " (", nrow(tabla_resumen), " enfermedades)\n", sep = "")
print(tabla_resumen[, c("Enfermedad", "N_Total", "Prevalencia_SI", "Modelo_Ganador",
                        "Hipervolumen", "AUC_CV_Media")], row.names = FALSE, right = FALSE)

# Ninguna enfermedad queda fuera en silencio
if (length(sin_resultado) > 0) {
  cat("\n!! Sin checkpoint, no están en las tablas:", paste(sin_resultado, collapse = ", "), "\n")
} else {
  cat("\nEnfermedades en las tablas:", nrow(tabla_resumen), "de", length(CFG$enfermedades), "\n")
}
