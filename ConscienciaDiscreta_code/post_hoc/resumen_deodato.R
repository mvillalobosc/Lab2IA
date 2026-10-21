## ============================================================================
## resumen_deodato.R
## ----------------------------------------------------------------------------
## Resumen del reajuste de Deodato y Melcher con el ISI leído como pausa.
##
## Summary of the refit of Deodato and Melcher with the ISI read as a blank
## gap, and comparison with the onset-to-onset reading of the server run.
##
## Uso / usage (desde post_hoc/): Rscript resumen_deodato.R [../salida/ajuste_participantes.csv]
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
ruta_servidor <- if (length(args) > 0) args[1] else "../salida/ajuste_participantes.csv"
aj <- read.csv("resultados/ajuste_deodato_pausa.csv")
cat("participantes:", length(unique(aj$participante)), " filas:", nrow(aj), "\n")
cat("mejor por AIC:\n"); print(table(factor(aj$arquitectura[aj$mejor], levels = c("continua", "eventos", "continua_modulada", "periodica"))))
cat("decisivos (margen >= 4):\n"); print(table(factor(aj$arquitectura[aj$mejor & aj$distinguible], levels = c("continua", "eventos", "continua_modulada", "periodica"))))
cat("total decisivos:", sum(aj$mejor & aj$distinguible), "\n")
aj$w <- ave(aj$aic, aj$participante, FUN = function(a) { e <- exp(-0.5 * (a - min(a))); e / sum(e) })
cat("peso de Akaike medio:\n"); print(round(tapply(aj$w, aj$arquitectura, mean), 3))
cat("AIC total:\n"); print(round(tapply(aj$aic, aj$arquitectura, sum), 1))
cat("margen del mejor: mediana", round(median(aj$margen_aic[aj$mejor]), 2), " rango", round(range(aj$margen_aic[aj$mejor]), 2), "\n")
w <- reshape(aj[, c("participante", "arquitectura", "loglik")], idvar = "participante", timevar = "arquitectura", direction = "wide")
cat("modulada peor que continua por > 2 unidades:", round(mean(w$loglik.continua_modulada - w$loglik.continua < -2), 3), "\n")
## comparación con la lectura de inicio a inicio (servidor)
ap <- read.csv(ruta_servidor); dm <- ap[ap$dataset == "deodato_melcher_2024", ]
m1 <- aj[aj$mejor, c("participante", "arquitectura")]; m2 <- dm[dm$mejor, c("participante", "arquitectura")]
mm <- merge(m1, m2, by = "participante", suffixes = c("_pausa", "_inicio"))
cat("misma arquitectura ganadora en ambas lecturas:", sum(mm$arquitectura_pausa == mm$arquitectura_inicio), "de", nrow(mm), "\n")
## periodo ajustado del lector periódico
per <- aj[aj$arquitectura == "periodica", ]
cat("T ajustado (periódica): mediana", round(median(per$T_ajustado), 1), " rango", round(range(per$T_ajustado), 1), "\n")
cat("T ajustado en banda alfa (80-125):", sum(per$T_ajustado >= 80 & per$T_ajustado <= 125), "de", nrow(per), "\n")
ev <- aj[aj$arquitectura == "eventos", ]; cat("r ajustado (eventos): mediana", round(median(ev$r_ajustado), 1), "\n")
