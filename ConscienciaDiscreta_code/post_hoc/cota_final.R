## ============================================================================
## cota_final.R
## ----------------------------------------------------------------------------
## Cota final: mínimo validado entre el GA y la rejilla para cada T, con una
## regresión isotónica (no decreciente en T). Periodo máximo compatible con el
## umbral de cada participante de Haarlem et al. y resumen para el texto.
##
## Final bound: lowest validated threshold of GA and of the grid for each T,
## with an isotonic regression (non-decreasing in T). Longest period
## compatible with the threshold of each participant of Haarlem et al. and
## summary for the text.
##
## Uso / usage (desde post_hoc/): Rscript cota_final.R [../salida/haarlem_participantes.csv]
## Salida / output: resultados/cota_haarlem_final.csv
## ============================================================================
ga <- read.csv("resultados/haarlem_cota_periodica_10_120.csv")
rj <- if (file.exists("resultados/haarlem_rejilla_30_120.csv")) read.csv("resultados/haarlem_rejilla_30_120.csv") else NULL
d <- data.frame(T = ga$T, ga = ga$umbral_validado)
d$rejilla <- if (!is.null(rj)) rj$umbral_rejilla_validado[match(d$T, rj$T)] else NA
d$umbral_validado <- pmin(d$ga, d$rejilla, na.rm = TRUE)
d$fuente <- ifelse(!is.na(d$rejilla) & d$rejilla < d$ga, "rejilla", "GA")
d$censurado <- !is.finite(d$umbral_validado)   # no llega al 75 % con ISI de hasta 150 ms
d$umbral_validado[d$censurado] <- NA
ok <- !d$censurado
d$umbral_cota <- NA_real_
d$umbral_cota[ok] <- isoreg(d$T[ok], d$umbral_validado[ok])$yf
write.csv(d, "resultados/cota_haarlem_final.csv", row.names = FALSE)
d <- d[ok, ]
print(d, digits = 4)
args <- commandArgs(trailingOnly = TRUE)
hp <- read.csv(if (length(args) > 0) args[1] else "../salida/haarlem_participantes.csv")
hp$T_max <- approx(d$umbral_cota, d$T, xout = hp$umbral_ms, ties = max, rule = 2)$y
cota_alfa <- approx(d$T, d$umbral_cota, xout = hp$periodo_reposo_ms, rule = 2)$y
cat("\nT_max: rango", round(range(hp$T_max), 1), " mediana", round(median(hp$T_max), 1), " media", round(mean(hp$T_max), 1), "\n")
cat("frecuencia mínima (1000/T_max): rango", round(range(1000 / hp$T_max), 1), " mediana", round(median(1000 / hp$T_max), 1), "\n")
cat("participantes con periodo alfa > T_max:", sum(hp$periodo_reposo_ms > hp$T_max), "de", nrow(hp), "\n")
cat("cota en el periodo alfa de cada participante: rango", round(range(cota_alfa), 1), " (umbral observado máximo", max(hp$umbral_ms), ")\n")
cat("cota en T = 80, 100, 120:", round(approx(d$T, d$umbral_cota, xout = c(80, 100, 120))$y, 1), "\n")
cat("razón cota/umbral observado en el periodo alfa: mediana", round(median(cota_alfa / hp$umbral_ms), 2), "\n")
cat("pendiente de la cota entre 80 y 120 ms:", round(coef(lm(umbral_cota ~ T, data = d[d$T >= 80, ]))[2], 2), "\n")
