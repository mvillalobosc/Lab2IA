## ============================================================================
## analisis_complementario.R
## ----------------------------------------------------------------------------
## Cifras del diseño, de los intervalos entre lecturas y de la sensibilidad que
## el artículo cita y que no calcula analisis.R: fronteras de Pareto en dos
## dimensiones (cobertura entre arquitecturas), mejores valores con presupuesto
## de lecturas, parámetros elegidos por el optimizador, periodos en la banda
## alfa y resumen por condición del análisis de sensibilidad.
##
## Numbers of the design, of the intervals between reads and of the
## sensitivity analysis that the paper cites and that analisis.R does not
## compute: two-dimensional Pareto frontiers (coverage between architectures),
## best values within a reading budget, parameters chosen by the optimiser,
## periods in the alpha band and summary per condition of the sensitivity
## analysis.
##
## Uso / usage (desde post_hoc/): Rscript analisis_complementario.R [../salida] [estadistica]
## Salida / output: estadistica/resumen_complementario.txt
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
D <- if (length(args) > 0) args[1] else "../salida"
O <- if (length(args) > 1) args[2] else "estadistica"
dir.create(O, showWarnings = FALSE)
sink(file.path(O, "resumen_complementario.txt"), split = TRUE)
leer <- function(f) {   # admite el .csv.gz del repositorio
  ruta <- file.path(D, f); if (!file.exists(ruta) && file.exists(paste0(ruta, ".gz"))) ruta <- paste0(ruta, ".gz")
  read.csv(ruta, stringsAsFactors = FALSE)
}
OBJ <- c("error", "umbral", "latencia", "costo")
ARQ <- c("continua", "continua_modulada", "periodica", "eventos")

## Frontera de Pareto en dos dimensiones (minimizar x e y)
frontera_2d <- function(x, y) {
  o <- order(x, y); x <- x[o]; y <- y[o]
  keep <- y < cummin(c(Inf, head(y, -1)))
  data.frame(x = x[keep], y = y[keep])
}
## C(A, B) en dos dimensiones: fracción de los puntos de B dominados o igualados por A
cob2 <- function(A, B) mean(sapply(seq_len(nrow(B)), function(k) any(A$x <= B$x[k] & A$y <= B$y[k])))

fv <- leer("frentes_validados.csv")
fvf <- fv[fv$funcional, ]

cat("=====================================================================\n")
cat("1. Fronteras de Pareto 2D contra el costo (agentes funcionales)\n")
cat("=====================================================================\n")
for (g in c("limpio", "rafagas")) for (v in c("error", "umbral", "latencia")) {
  d <- fvf[fvf$regimen == g, ]
  fe <- frontera_2d(d$costo[d$arquitectura == "eventos"], d[[v]][d$arquitectura == "eventos"])
  fp <- frontera_2d(d$costo[d$arquitectura == "periodica"], d[[v]][d$arquitectura == "periodica"])
  cat(sprintf("%-8s %-9s C(E2d, P2d) = %.3f   C(P2d, E2d) = %.3f   (puntos E %d, P %d)\n",
              g, v, cob2(fe, fp), cob2(fp, fe), nrow(fe), nrow(fp)))
}

cat("\n=====================================================================\n")
cat("2. Diseño: error mínimo, costo al que se alcanza y latencias\n")
cat("=====================================================================\n")
for (g in c("limpio", "rafagas")) {
  d <- fvf[fvf$regimen == g, ]
  cat("\nRégimen", g, "\n")
  for (a in ARQ) {
    x <- d[d$arquitectura == a, ]
    e0 <- min(x$error); c0 <- min(x$costo[x$error == e0])
    cat(sprintf("  %-18s error mínimo %.4f con costo mínimo %.2f; latencia mínima %.2f ms (costo %.2f); umbral mínimo %.2f\n",
                a, e0, c0, min(x$latencia), x$costo[which.min(x$latencia)], min(x$umbral)))
  }
  ev <- d[d$arquitectura == "eventos", ]; pe <- d[d$arquitectura == "periodica", ]
  e_ev <- min(ev$error)
  cat(sprintf("  Periódica: costo mínimo para error <= %.4f (error mínimo de eventos): %s\n", e_ev,
              if (any(pe$error <= e_ev)) sprintf("%.2f", min(pe$costo[pe$error <= e_ev])) else "no lo alcanza"))
  cat(sprintf("  Periódica: error mínimo %.4f, alcanzado con costo %.2f\n", min(pe$error), min(pe$costo[pe$error == min(pe$error)])))
  cat(sprintf("  Eventos: costo mínimo con latencia < 10 ms: %s\n",
              if (any(ev$latencia < 10)) sprintf("%.2f", min(ev$costo[ev$latencia < 10])) else "ninguna"))
  cat("  Costo mínimo con umbral <= 15 ms y error <= 0.25, por arquitectura:\n")
  print(sapply(ARQ, function(a) { x <- d[d$arquitectura == a & d$umbral <= 15 & d$error <= 0.25, ]; if (nrow(x)) min(x$costo) else NA }))
}

cat("\n=====================================================================\n")
cat("3. Parámetros elegidos por el optimizador (agentes funcionales)\n")
cat("=====================================================================\n")
for (g in c("limpio", "rafagas")) {
  d <- fvf[fvf$regimen == g, ]
  cat("\nRégimen", g, "\n")
  cat("  mediana de tau por arquitectura:\n"); print(round(tapply(d$tau, d$arquitectura, median), 2))
  ev <- d[d$arquitectura == "eventos", ]
  cat(sprintf("  eventos: mediana theta_g %.3f, mediana theta_p %.3f, mediana r %.2f ms\n", median(ev$theta_g), median(ev$theta_p), median(ev$r)))
  pe <- d[d$arquitectura == "periodica", ]
  cat(sprintf("  periódica: mediana w/T %.2f (q25 %.2f, q75 %.2f)\n", median(pe$w / pe$T), quantile(pe$w / pe$T, 0.25), quantile(pe$w / pe$T, 0.75)))
  mo <- d[d$arquitectura == "continua_modulada", ]
  cat(sprintf("  continua modulada: fracción con A < 0.1 = %.3f (n = %d)\n", mean(mo$A_mod < 0.1), nrow(mo)))
}

cat("\n=====================================================================\n")
cat("4. Intervalos entre lecturas y banda alfa (80 a 125 ms)\n")
cat("=====================================================================\n")
for (g in c("limpio", "rafagas")) {
  d <- fvf[fvf$regimen == g, ]
  pe <- d[d$arquitectura == "periodica", ]; ev <- d[d$arquitectura == "eventos", ]
  alfa <- pe$T >= 80 & pe$T <= 125
  cat(sprintf("%-8s periódica n=%d: T mediana %.1f (q25 %.1f, q75 %.1f), rango %.1f a %.1f; en alfa %.3f; < 80 ms %.3f; > 125 ms %.3f\n",
              g, nrow(pe), median(pe$T), quantile(pe$T, 0.25), quantile(pe$T, 0.75), min(pe$T), max(pe$T), mean(alfa), mean(pe$T < 80), mean(pe$T > 125)))
  if (any(alfa)) cat(sprintf("         diseños en alfa: costo mediano %.1f, umbral mediano %.1f, latencia mediana %.1f, error mediano %.3f\n",
                             median(pe$costo[alfa]), median(pe$umbral[alfa]), median(pe$latencia[alfa]), median(pe$error[alfa])))
  cat(sprintf("         eventos n=%d: r mediana %.2f (q25 %.2f, q75 %.2f), en alfa %.3f, máximo %.1f\n",
              nrow(ev), median(ev$r), quantile(ev$r, 0.25), quantile(ev$r, 0.75), mean(ev$r >= 80 & ev$r <= 125), max(ev$r)))
}
pe <- fvf[fvf$arquitectura == "periodica", ]
cat(sprintf("Ambos regímenes: periódica en alfa %.3f, < 80 ms %.3f\n", mean(pe$T >= 80 & pe$T <= 125), mean(pe$T < 80)))

cat("\n=====================================================================\n")
cat("5. Sensibilidad (régimen limpio, agentes funcionales)\n")
cat("=====================================================================\n")
sf <- leer("sensibilidad_frentes.csv"); sf <- sf[sf$funcional, ]
for (cnd in unique(sf$condicion)) {
  d <- sf[sf$condicion == cnd, ]
  cat("\nCondición", cnd, "\n")
  cat("  n funcionales por arquitectura:\n"); print(table(factor(d$arquitectura, levels = ARQ)))
  for (a in ARQ) {
    x <- d[d$arquitectura == a, ]; if (!nrow(x)) next
    e0 <- min(x$error)
    cat(sprintf("  %-18s error mínimo %.4f con costo %.2f\n", a, e0, min(x$costo[x$error == e0])))
  }
  fe <- frontera_2d(d$costo[d$arquitectura == "eventos"], d$error[d$arquitectura == "eventos"])
  fp <- frontera_2d(d$costo[d$arquitectura == "periodica"], d$error[d$arquitectura == "periodica"])
  if (nrow(fe) && nrow(fp)) cat(sprintf("  frontera error-costo: C(E2d, P2d) = %.3f, C(P2d, E2d) = %.3f\n", cob2(fe, fp), cob2(fp, fe)))
}
sc <- leer("sensibilidad_cobertura.csv")
x <- sc[sc$subconjunto == "funcional" & ((sc$A == "eventos" & sc$B == "periodica") | (sc$A == "periodica" & sc$B == "eventos")), ]
cat("\nCobertura 4D eventos/periódica por condición (funcionales):\n"); print(x, row.names = FALSE, digits = 3)
sm <- leer("sensibilidad_metricas.csv")
cat("\nFracción del frente combinado (funcionales):\n")
print(reshape(sm[sm$subconjunto == "funcional", c("condicion", "arquitectura", "fraccion_frente_combinado")],
              idvar = "condicion", timevar = "arquitectura", direction = "wide"), row.names = FALSE, digits = 3)
cat("\nFracción del frente combinado (todas las soluciones):\n")
print(reshape(sm[sm$subconjunto == "completo", c("condicion", "arquitectura", "fraccion_frente_combinado")],
              idvar = "condicion", timevar = "arquitectura", direction = "wide"), row.names = FALSE, digits = 3)
cat("\nPeriodo del lector periódico por condición:\n"); print(leer("sensibilidad_periodo_periodico.csv"), row.names = FALSE, digits = 3)

cat("\n=====================================================================\n")
cat("6. NSGA-III frente a búsqueda aleatoria en dos dimensiones (11 semillas juntas, funcionales)\n")
cat("=====================================================================\n")
vf <- leer("validation_seed_fronts.csv"); vf <- vf[vf$umbral < 300, ]
for (a in ARQ) for (v in c("costo", "latencia")) {
  d <- vf[vf$arquitectura == a, ]
  fn <- frontera_2d(d[[v]][d$metodo == "NSGA-III"], d$error[d$metodo == "NSGA-III"])
  fr <- frontera_2d(d[[v]][d$metodo == "random"], d$error[d$metodo == "random"])
  cat(sprintf("%-18s error-%-8s C(N,R) = %.3f  C(R,N) = %.3f  error mínimo N %.4f  R %.4f  (puntos N %d, R %d)\n",
              a, v, cob2(fn, fr), cob2(fr, fn), min(fn$y), min(fr$y), nrow(fn), nrow(fr)))
}

cat("\n=====================================================================\n")
cat("7. Agentes por eventos muy ralos (costo < 1 lectura por segundo, funcionales)\n")
cat("=====================================================================\n")
for (g in c("limpio", "rafagas")) {
  x <- fvf[fvf$regimen == g & fvf$arquitectura == "eventos" & fvf$costo < 1, ]
  cat(sprintf("%-8s n = %d, umbral mínimo %.1f ms, error mínimo %.4f, error mínimo entre los de umbral 15 ms: %s\n", g, nrow(x),
              if (nrow(x)) min(x$umbral) else NA, if (nrow(x)) min(x$error) else NA,
              if (any(x$umbral <= 15)) sprintf("%.4f", min(x$error[x$umbral <= 15])) else "ninguno"))
}
sink()
