## ============================================================================
## reajuste_deodato.R
## ----------------------------------------------------------------------------
## Reajuste de Deodato y Melcher leyendo el ISI como pausa en blanco entre
## destellos de 10 ms (SOA = ISI + 10 ms). Mismo procedimiento que la
## pregunta 2 del script principal; solo cambia el intervalo simulado.
##
## Refit of Deodato and Melcher reading the ISI as a blank gap between 10 ms
## flashes (SOA = ISI + 10 ms). Same procedure as question 2 of the main
## script; only the simulated interval changes. It is the slowest step of the
## post hoc analyses (152 fits; about two hours on one core).
##
## Uso / usage (desde post_hoc/): N_CORES=4 Rscript reajuste_deodato.R
## Salida / output: resultados/ajuste_deodato_pausa.csv
## ============================================================================
source("cargar_funciones.R", encoding = "UTF-8")
dm <- normalizar_datos(read.csv(file.path("..", "datos_reales", "deodato_melcher_2024", "deodato_melcher_2024_ensayos.csv")))
dm <- dm[dm$incluido == 1, ]
dm$isi_reportado <- dm$isi
dm$isi[dm$n_pulsos == 2] <- dm$isi[dm$n_pulsos == 2] + CFG$pulso_dur
res <- ajustar_dataset(dm, "deodato_melcher_2024_pausa", CFG)
write.csv(res, file.path(CFG$carpeta, "ajuste_deodato_pausa.csv"), row.names = FALSE)
cat("\nMejor arquitectura por participante:\n"); print(table(res$arquitectura[res$mejor]))
cat("\nCon margen >= 4:\n"); print(table(res$arquitectura[res$mejor & res$distinguible]))
