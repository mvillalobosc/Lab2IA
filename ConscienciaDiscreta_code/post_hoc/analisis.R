## ============================================================================
## analisis.R
## ----------------------------------------------------------------------------
## Estadística post hoc del artículo sobre las salidas del servidor:
## parametrización (Friedman, Holm, A12, Kendall), convergencia en el corte,
## consistencia entre semillas, NSGA-III frente a búsqueda aleatoria (completa
## y recortada por nichado), frente conjunto, diseño con presupuesto de
## lecturas, sensibilidad, recuperación de modelos, Haarlem et al. y cobertura
## cruzada entre los lectores por eventos y periódico.
##
## Post hoc statistics of the paper on the server outputs: parametrisation
## (Friedman, Holm, A12, Kendall), convergence at the cutoff, consistency over
## seeds, NSGA-III against random search (full and reduced by niching), joint
## front, design within a reading budget, sensitivity, model recovery, Haarlem
## et al. and cross coverage between the event and periodic readers.
##
## Uso / usage (desde post_hoc/): Rscript analisis.R [../salida] [estadistica]
## Salidas / outputs: estadistica/resumen.txt y las tablas A_ a K_ en CSV
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
D <- if (length(args) > 0) args[1] else "../salida"
O <- if (length(args) > 1) args[2] else "estadistica"
dir.create(O, showWarnings = FALSE)
suppressPackageStartupMessages({ library(ecr) })
sink(file.path(O, "resumen.txt"), split = TRUE)
leer <- function(f) {   # admite el .csv.gz del repositorio
  ruta <- file.path(D, f); if (!file.exists(ruta) && file.exists(paste0(ruta, ".gz"))) ruta <- paste0(ruta, ".gz")
  read.csv(ruta, stringsAsFactors = FALSE)
}
ARQ <- c("continua", "continua_modulada", "periodica", "eventos")
A12 <- function(x, y) {          # Vargha y Delaney: P(X > Y) + 0.5 P(X = Y)
  m <- outer(x, y, "-"); (sum(m > 0) + 0.5 * sum(m == 0)) / length(m)
}
cat("=====================================================================\n")
cat("A. Parametrización: Friedman con bloques = arquitectura x semilla\n")
cat("=====================================================================\n")
pr <- leer("validation_parametrisation_runs.csv")
pr$config <- sprintf("N=%d pc=%.1f pm=%.2f", pr$popSize, pr$pcrossover, pr$pmutation)
pr$bloque <- paste(pr$arquitectura, pr$semilla)
M <- with(pr, tapply(hv_validacion, list(bloque, config), mean))
cat("bloques:", nrow(M), " configuraciones:", ncol(M), "\n")
ft <- friedman.test(M)
print(ft)
rk <- t(apply(-M, 1, rank))                  # rango 1 = mayor hipervolumen
rmed <- sort(colMeans(rk))
mejor <- names(rmed)[1]
pv <- sapply(colnames(M), function(cc) if (cc == mejor) NA else
  wilcox.test(M[, mejor], M[, cc], paired = TRUE, exact = FALSE)$p.value)
ph <- p.adjust(pv, "holm")
tabA <- data.frame(config = names(rmed), rango_medio = as.numeric(rmed),
                   p_wilcoxon_vs_mejor = pv[names(rmed)], p_holm = ph[names(rmed)],
                   a12_mejor_vs_config = sapply(names(rmed), function(cc) A12(M[, mejor], M[, cc])))
tabA$popSize <- as.integer(sub("N=(\\d+) .*", "\\1", tabA$config))
print(tabA, row.names = FALSE, digits = 3)
write.csv(tabA, file.path(O, "A_parametrizacion_rangos.csv"), row.names = FALSE)
## configuración elegida por el script principal (primera fila del resumen,
## ordenado por hipervolumen mediano)
ps <- leer("validation_parametrisation_summary.csv")
elegida <- sprintf("N=%d pc=%.1f pm=%.2f", ps$popSize[1], ps$pcrossover[1], ps$pmutation[1])
cat("\nElegida en el servidor (mediana):", elegida, " rango medio:", round(rmed[elegida], 2),
    " posición:", which(names(rmed) == elegida), " p Holm vs mejor:", signif(ph[elegida], 3), "\n")
cat("Configuraciones distinguibles de la mejor (Holm < 0.05):", sum(ph < 0.05, na.rm = TRUE), "de", length(ph) - 1, "\n")
## rango medio por tamaño de población (promediando cruces y mutaciones)
cat("\nRango medio por tamaño de población:\n")
print(tapply(tabA$rango_medio, tabA$popSize, mean))
## Kendall W
k <- ncol(M); n <- nrow(M)
W <- unname(ft$statistic) / (n * (k - 1))
cat("Kendall W =", round(W, 3), "\n")
## efecto del tamaño de población por separado: Friedman sobre la media por tamaño
Mp <- sapply(split(colnames(M), sub(" .*", "", colnames(M))), function(cc) rowMeans(M[, cc, drop = FALSE]))
print(friedman.test(Mp))
cat("rango medio por tamaño (bloques):\n"); print(colMeans(t(apply(-Mp, 1, rank))))
## Tiempo medio por corrida en la parametrización
cat("\nMinutos por corrida (media) en la parametrización:", round(mean(pr$minutos), 2), "\n")

cat("\n=====================================================================\n")
cat("B. Convergencia\n")
cat("=====================================================================\n")
cc <- leer("validation_convergence_cutoff.csv")
print(aggregate(cbind(generation_95pct, generation_99pct, generation_999pct) ~ arquitectura, data = cc, FUN = median))
print(aggregate(cbind(generation_95pct, generation_99pct, generation_999pct) ~ arquitectura, data = cc, FUN = function(v) paste(range(v), collapse = "-")))
cat("mediana global g99:", median(cc$generation_99pct), "\n")
cv <- leer("validation_convergence_curve.csv")
## corte elegido por el script principal
G <- leer("validation_convergence_chosen_cutoff.csv")$generations_main_runs[1]
cat("corte de las corridas principales:", G, "generaciones\n")
gcorte <- cv[cv$generation == G, c("arquitectura", "semilla", "hv_running_max")]
fin <- cc[, c("arquitectura", "semilla", "hv_final")]
gg <- merge(gcorte, fin)
gg$frac <- gg$hv_running_max / gg$hv_final
cat("\nFracción del HV final alcanzada en la generación", G, "(min, mediana, max):\n")
print(aggregate(frac ~ arquitectura, data = gg, FUN = function(v) round(c(min = min(v), med = median(v), max = max(v)), 4)))
cat("Eventos en el corte (min):", round(min(gg$hv_running_max[gg$arquitectura == "eventos"]), 4),
    " Periódica al final (max):", round(max(fin$hv_final[fin$arquitectura == "periodica"]), 4), "\n")
write.csv(gg, file.path(O, "B_convergencia_corte.csv"), row.names = FALSE)

cat("\n=====================================================================\n")
cat("C. Consistencia entre semillas (NSGA-III) y comparación con random\n")
cat("=====================================================================\n")
sr <- leer("validation_seed_runs.csv")
for (me in c("NSGA-III", "random")) for (a in ARQ) {
  x <- sr$hv_validation[sr$method == me & sr$arquitectura == a]
  sw <- shapiro.test(x)
  cat(sprintf("%-9s %-18s n=%2d media=%.4f sd=%.4f CV=%.2f%%  Shapiro W=%.3f p=%.3f\n",
              me, a, length(x), mean(x), sd(x), 100 * sd(x) / mean(x), sw$statistic, sw$p.value))
}
ns <- sr[sr$method == "NSGA-III", ]
Mn <- with(ns, tapply(hv_validation, list(semilla, arquitectura), mean))[, ARQ]
cat("\nFriedman entre arquitecturas (bloques = semillas), HV de validación:\n"); print(friedman.test(Mn))
cat("rango medio:\n"); print(colMeans(t(apply(-Mn, 1, rank))))
pares <- combn(ARQ, 2)
tabC <- do.call(rbind, lapply(seq_len(ncol(pares)), function(j) {
  a <- pares[1, j]; b <- pares[2, j]
  w <- wilcox.test(Mn[, a], Mn[, b], paired = TRUE, exact = TRUE)
  data.frame(A = a, B = b, p = w$p.value, a12 = A12(Mn[, a], Mn[, b]))
}))
tabC$p_holm <- p.adjust(tabC$p, "holm")
print(tabC, row.names = FALSE, digits = 3)
write.csv(tabC, file.path(O, "C_arquitecturas_hv.csv"), row.names = FALSE)
## fracción del frente combinado por semilla
cf <- leer("validation_seed_combined_front.csv")
Mc <- with(cf, tapply(share_combined_front, list(semilla, arquitectura), mean))[, ARQ]
cat("\nFracción del frente combinado por semilla: media (min-max)\n")
print(apply(Mc, 2, function(v) sprintf("%.3f (%.3f-%.3f)", mean(v), min(v), max(v))))
cat("Friedman sobre la fracción del frente combinado:\n"); print(friedman.test(Mc))
cat("rango medio:\n"); print(colMeans(t(apply(-Mc, 1, rank))))
cat("semillas en que eventos tiene la mayor fracción:", sum(apply(Mc, 1, which.max) == 4), "de", nrow(Mc), "\n")
tabC2 <- do.call(rbind, lapply(seq_len(ncol(pares)), function(j) {
  a <- pares[1, j]; b <- pares[2, j]
  w <- wilcox.test(Mc[, a], Mc[, b], paired = TRUE, exact = FALSE)
  data.frame(A = a, B = b, p = w$p.value, a12 = A12(Mc[, a], Mc[, b]))
}))
tabC2$p_holm <- p.adjust(tabC2$p, "holm")
print(tabC2, row.names = FALSE, digits = 3)
write.csv(tabC2, file.path(O, "C_arquitecturas_fraccion.csv"), row.names = FALSE)

cat("\n--- NSGA-III frente a búsqueda aleatoria (mismo presupuesto) ---\n")
rn <- sr[sr$method == "random", ]
Mr <- with(rn, tapply(hv_validation, list(semilla, arquitectura), mean))[, ARQ]
tabD <- do.call(rbind, lapply(ARQ, function(a) {
  w <- wilcox.test(Mn[, a], Mr[, a], paired = TRUE, exact = TRUE)
  data.frame(arquitectura = a, hv_nsga = mean(Mn[, a]), sd_nsga = sd(Mn[, a]), hv_random = mean(Mr[, a]), sd_random = sd(Mr[, a]),
             p = w$p.value, a12_nsga_vs_random = A12(Mn[, a], Mr[, a]),
             frente_nsga = mean(ns$n_front[ns$arquitectura == a]), frente_random = mean(rn$n_front[rn$arquitectura == a]))
}))
tabD$p_holm <- p.adjust(tabD$p, "holm")
vt <- leer("validation_tests.csv")
tabD <- merge(tabD, vt[vt$comparison == "NSGA-III vs random search", c("arquitectura", "coverage_nsga_over_random", "coverage_random_over_nsga")])
tabD <- tabD[match(ARQ, tabD$arquitectura), ]
print(tabD, row.names = FALSE, digits = 4)

## Comparación con el mismo tamaño de archivo: el frente validado de la
## búsqueda aleatoria se recorta al tamaño del frente de NSGA-III de la misma
## semilla con el nichado por puntos de referencia de NSGA-III (Deb y Jain).
cat("\nRecorte por nichado del frente aleatorio al tamaño del frente NSGA-III:\n")
sf <- leer("validation_seed_fronts.csv")
OBJ <- c("error", "umbral", "latencia", "costo")
REF <- c(error = 1, umbral = 200 * 1.5, latencia = 600, costo = 3)
hv_fijo <- function(F) {
  M <- as.matrix(F[, OBJ]); if (nrow(M) == 0) return(0)
  M[, "costo"] <- log10(pmax(M[, "costo"], 1))
  Z <- pmin(pmax(sweep(M, 2, REF, "/"), 0), 1)
  ecr::computeHV(t(Z), ref.point = rep(1.1, 4))
}
das_dennis <- function(M, p) {
  g <- expand.grid(rep(list(0:p), M - 1)); g <- g[rowSums(g) <= p, , drop = FALSE]
  W <- cbind(as.matrix(g), p - rowSums(g)) / p; unname(W)
}
REFS <- das_dennis(4, 7)        # 120 puntos, como en las corridas principales
nichado <- function(F, K, semilla = 1) {
  M <- as.matrix(F[, OBJ]); M[, "costo"] <- log10(pmax(M[, "costo"], 1))
  n <- nrow(M); if (n <= K) return(seq_len(n))
  zmin <- apply(M, 2, min); zmax <- apply(M, 2, max); rng <- pmax(zmax - zmin, 1e-12)
  Z <- sweep(sweep(M, 2, zmin, "-"), 2, rng, "/")
  Wn <- REFS / sqrt(rowSums(REFS^2))
  proy <- Z %*% t(Wn)                                   # n x R
  d2 <- rowSums(Z^2) - proy^2                           # distancia perpendicular al cuadrado
  asoc <- max.col(-d2, ties.method = "first"); dist <- d2[cbind(seq_len(n), asoc)]
  set.seed(semilla)
  rho <- integer(nrow(REFS)); elegido <- logical(n); activo <- rep(TRUE, nrow(REFS))
  while (sum(elegido) < K) {
    cand_ref <- which(activo); rmin <- min(rho[cand_ref])
    j <- cand_ref[rho[cand_ref] == rmin]; j <- if (length(j) > 1) sample(j, 1) else j
    libres <- which(asoc == j & !elegido)
    if (length(libres) == 0) { activo[j] <- FALSE; next }
    k <- if (rho[j] == 0) libres[which.min(dist[libres])] else (if (length(libres) > 1) sample(libres, 1) else libres)
    elegido[k] <- TRUE; rho[j] <- rho[j] + 1L
  }
  which(elegido)
}
tabE <- do.call(rbind, lapply(ARQ, function(a) do.call(rbind, lapply(sort(unique(sf$semilla)), function(s) {
  fn <- sf[sf$arquitectura == a & sf$semilla == s & sf$metodo == "NSGA-III", ]
  fr <- sf[sf$arquitectura == a & sf$semilla == s & sf$metodo == "random", ]
  idx <- nichado(fr, nrow(fn), semilla = s)
  data.frame(arquitectura = a, semilla = s, n_nsga = nrow(fn), n_random = nrow(fr), n_random_recortado = length(idx),
             hv_nsga = hv_fijo(fn), hv_random = hv_fijo(fr), hv_random_recortado = hv_fijo(fr[idx, ]))
}))))
write.csv(tabE, file.path(O, "E_random_recortado.csv"), row.names = FALSE)
cmpE <- do.call(rbind, lapply(ARQ, function(a) {
  d <- tabE[tabE$arquitectura == a, ]
  w1 <- wilcox.test(d$hv_nsga, d$hv_random, paired = TRUE, exact = TRUE)
  w2 <- if (any(d$hv_nsga != d$hv_random_recortado)) wilcox.test(d$hv_nsga, d$hv_random_recortado, paired = TRUE, exact = TRUE)$p.value else NA
  data.frame(arquitectura = a, hv_nsga = mean(d$hv_nsga), hv_random = mean(d$hv_random), hv_random_recortado = mean(d$hv_random_recortado),
             p_completo = w1$p.value, p_recortado = w2,
             a12_vs_completo = A12(d$hv_nsga, d$hv_random), a12_vs_recortado = A12(d$hv_nsga, d$hv_random_recortado))
}))
cmpE$p_holm_completo <- p.adjust(cmpE$p_completo, "holm")
cmpE$p_holm_recortado <- p.adjust(cmpE$p_recortado, "holm")
print(cmpE, row.names = FALSE, digits = 4)
write.csv(merge(tabD, cmpE[, c("arquitectura", "hv_random_recortado", "p_recortado", "p_holm_recortado", "a12_vs_recortado")]),
          file.path(O, "D_nsga_vs_random.csv"), row.names = FALSE)
## comprobación: el HV recalculado coincide con el del servidor
chk <- merge(tabE, sr[, c("method", "arquitectura", "semilla", "hv_validation")][sr$method == "NSGA-III", ], by = c("arquitectura", "semilla"))
cat("máx |HV recalculado - HV del servidor| (NSGA-III):", signif(max(abs(chk$hv_nsga - chk$hv_validation)), 3), "\n")
## frente combinado NSGA-III + random por arquitectura: quién aporta
cat("\nFracción del frente conjunto (NSGA-III + random, misma semilla) que aporta cada método:\n")
## Frente conjunto rápido: cada frente validado ya es no dominado dentro de su
## método, así que basta ver qué puntos de uno domina el otro. Se recorre el
## conjunto más chico y se compara contra el grande de forma vectorizada.
dominados_por <- function(A, B) {   # para cada fila de B: ¿la domina alguna fila de A?
  A <- as.matrix(A); B <- as.matrix(B); res <- logical(nrow(B)); d <- ncol(B)
  if (nrow(A) == 0 || nrow(B) == 0) return(res)
  if (nrow(A) <= nrow(B)) {
    for (i in seq_len(nrow(A))) { a <- matrix(A[i, ], nrow(B), d, byrow = TRUE)
      res <- res | (rowSums(a <= B) == d & rowSums(a < B) > 0) }
  } else {
    for (k in seq_len(nrow(B))) { b <- matrix(B[k, ], nrow(A), d, byrow = TRUE)
      res[k] <- any(rowSums(A <= b) == d & rowSums(A < b) > 0) }
  }
  res
}
tabJ <- do.call(rbind, lapply(ARQ, function(a) do.call(rbind, lapply(sort(unique(sf$semilla)), function(s) {
  fn <- as.matrix(sf[sf$arquitectura == a & sf$semilla == s & sf$metodo == "NSGA-III", OBJ])
  fr <- as.matrix(sf[sf$arquitectura == a & sf$semilla == s & sf$metodo == "random", OBJ])
  kn <- !dominados_por(fr, fn); kr <- !dominados_por(fn, fr)
  data.frame(arquitectura = a, semilla = s, frac_nsga = sum(kn) / (sum(kn) + sum(kr)), n_conjunto = sum(kn) + sum(kr))
}))))
print(aggregate(cbind(frac_nsga, n_conjunto) ~ arquitectura, data = tabJ, FUN = mean))
write.csv(tabJ, file.path(O, "J_frente_conjunto.csv"), row.names = FALSE)

cat("\n=====================================================================\n")
cat("F. Diseño (pregunta 1): mejores valores por objetivo y error con presupuesto de costo\n")
cat("=====================================================================\n")
fv <- leer("frentes_validados.csv")
fvf <- fv[fv$funcional, ]
cat("Mínimos por objetivo, frente funcional:\n")
print(aggregate(cbind(error, umbral, latencia, costo) ~ arquitectura + regimen, data = fvf, FUN = min), digits = 4)
presup <- c(2, 5, 10, 20, 50, 100, 200, 500, 1000)
tabF <- do.call(rbind, lapply(split(fvf, list(fvf$arquitectura, fvf$regimen), drop = TRUE), function(d)
  data.frame(arquitectura = d$arquitectura[1], regimen = d$regimen[1], presupuesto = presup,
             error_min = sapply(presup, function(b) { e <- d$error[d$costo <= b]; if (length(e)) min(e) else NA }),
             umbral_min = sapply(presup, function(b) { e <- d$umbral[d$costo <= b]; if (length(e)) min(e) else NA }),
             latencia_min = sapply(presup, function(b) { e <- d$latencia[d$costo <= b]; if (length(e)) min(e) else NA }))))
print(tabF[tabF$regimen == "limpio", ], row.names = FALSE, digits = 4)
write.csv(tabF, file.path(O, "F_presupuesto.csv"), row.names = FALSE)
## soluciones con umbral mínimo (15 ms) y costo mínimo, por arquitectura
cat("\nCosto mínimo entre soluciones funcionales con umbral 15 ms y error <= 0.25:\n")
print(aggregate(costo ~ arquitectura + regimen, data = fvf[fvf$umbral <= 15 & fvf$error <= 0.25, ], FUN = min))
cat("\nIntervalos entre lecturas en el frente funcional:\n")
iv <- rbind(data.frame(arquitectura = "periodica", regimen = fvf$regimen[fvf$arquitectura == "periodica"], intervalo = fvf$T[fvf$arquitectura == "periodica"]),
            data.frame(arquitectura = "eventos", regimen = fvf$regimen[fvf$arquitectura == "eventos"], intervalo = fvf$r[fvf$arquitectura == "eventos"]),
            data.frame(arquitectura = "continua_modulada", regimen = fvf$regimen[fvf$arquitectura == "continua_modulada"], intervalo = fvf$T_mod[fvf$arquitectura == "continua_modulada"]))
print(do.call(rbind, lapply(split(iv, list(iv$arquitectura, iv$regimen), drop = TRUE), function(d) data.frame(
  arquitectura = d$arquitectura[1], regimen = d$regimen[1], n = nrow(d), mediana = median(d$intervalo),
  q25 = quantile(d$intervalo, 0.25), q75 = quantile(d$intervalo, 0.75),
  en_alfa_80_125 = mean(d$intervalo >= 80 & d$intervalo <= 125), sobre_125 = mean(d$intervalo > 125), bajo_80 = mean(d$intervalo < 80)))), row.names = FALSE, digits = 3)
## costo de la lectura periódica en el frente funcional
cat("\nCosto (lecturas/s) de los lectores por eventos en el frente funcional, cuantiles:\n")
print(tapply(fvf$costo[fvf$arquitectura == "eventos"], fvf$regimen[fvf$arquitectura == "eventos"], quantile, probs = c(0, 0.25, 0.5, 0.75, 1)))

cat("\n=====================================================================\n")
cat("G. Sensibilidad\n")
cat("=====================================================================\n")
sm <- leer("sensibilidad_metricas.csv"); sc <- leer("sensibilidad_cobertura.csv")
for (sub in c("completo", "funcional")) {
  cat("\n", sub, ": fracción del frente combinado\n")
  w <- reshape(sm[sm$subconjunto == sub, c("condicion", "arquitectura", "fraccion_frente_combinado")],
               idvar = "condicion", timevar = "arquitectura", direction = "wide")
  print(w, row.names = FALSE, digits = 3)
}
cat("\nC(eventos, periódica) y C(periódica, eventos) por condición (funcional):\n")
x <- sc[sc$subconjunto == "funcional" & ((sc$A == "eventos" & sc$B == "periodica") | (sc$A == "periodica" & sc$B == "eventos")), ]
print(reshape(x, idvar = "condicion", timevar = "A", direction = "wide", drop = c("subconjunto", "B")), row.names = FALSE, digits = 3)
cat("\nn funcional por condición y arquitectura:\n")
print(reshape(sm[sm$subconjunto == "funcional", c("condicion", "arquitectura", "n_frente")], idvar = "condicion", timevar = "arquitectura", direction = "wide"), row.names = FALSE)

cat("\n=====================================================================\n")
cat("H. Recuperación de modelos y ajuste\n")
cat("=====================================================================\n")
ap <- leer("ajuste_participantes.csv")
rc <- leer("recuperacion_modelos.csv")
sint <- rc[grepl("^sintetico", rc$dataset), ]
gen <- sub("sintetico_", "", sint$dataset)
diag_ok <- sum(sapply(seq_len(nrow(sint)), function(i) sint[i, gen[i]]))
tot <- sum(sint[, ARQ])
cat("recuperados:", diag_ok, "de", tot, sprintf("(%.1f%%)", 100 * diag_ok / tot), "\n")
print(binom.test(diag_ok, tot, p = 0.25, alternative = "greater"))
rc4 <- leer("recuperacion_modelos_margen4.csv")
s4 <- rc4[grepl("^sintetico", rc4$dataset), ]
d4 <- sum(sapply(seq_len(nrow(s4)), function(i) s4[i, gen[i]])); t4 <- sum(s4[, ARQ])
cat("con margen >= 4: decididos", t4, "de", tot, "; correctos", d4, "\n")
## fallas de anidamiento: modulada peor que continua más allá del ruido
w <- reshape(ap[, c("dataset", "participante", "arquitectura", "loglik", "aic")], idvar = c("dataset", "participante"), timevar = "arquitectura", direction = "wide")
w$dll <- w$loglik.continua_modulada - w$loglik.continua
cat("\nLog-verosimilitud modulada - continua (anidada), por dataset: mediana y fracción < -2\n")
print(aggregate(dll ~ dataset, data = w, FUN = function(v) round(c(mediana = median(v), frac_menor_menos2 = mean(v < -2)), 3)))
cat("Fracción global con modulada peor por más de 2 unidades:", round(mean(w$dll < -2), 3), "\n")
## parámetros ajustados en los datos periódicos sintéticos: T ajustado vs verdadero
cat("\nDeodato y Melcher (lectura de inicio a inicio, servidor):\n")
dm <- ap[ap$dataset == "deodato_melcher_2024", ]
print(table(dm$arquitectura[dm$mejor]))
print(aggregate(cbind(aic, delta_aic) ~ arquitectura, data = dm, FUN = function(v) round(c(media = mean(v), mediana = median(v)), 2)))
cat("margen de AIC del mejor modelo (mediana, rango):", median(dm$margen_aic[dm$mejor]), range(dm$margen_aic[dm$mejor]), "\n")
## Akaike weights sumados por arquitectura
dm$w <- ave(dm$aic, dm$participante, FUN = function(a) { e <- exp(-0.5 * (a - min(a))); e / sum(e) })
cat("peso de Akaike medio por arquitectura:\n"); print(round(tapply(dm$w, dm$arquitectura, mean), 3))
cat("AIC total por arquitectura (suma sobre participantes):\n"); print(round(tapply(dm$aic, dm$arquitectura, sum), 1))

cat("\n=====================================================================\n")
cat("I. Haarlem\n")
cat("=====================================================================\n")
hp <- leer("haarlem_participantes.csv")
cat("n =", nrow(hp), " umbral medio:", round(mean(hp$umbral_ms), 2), "sd", round(sd(hp$umbral_ms), 2), " rango", range(hp$umbral_ms), "\n")
cat("IAF reposo media:", round(mean(hp$iaf_reposo), 2), "sd", round(sd(hp$iaf_reposo), 2), " rango", range(hp$iaf_reposo), "\n")
cat("periodo alfa medio:", round(mean(hp$periodo_reposo_ms), 1), " rango", round(range(hp$periodo_reposo_ms), 1), "\n")
print(cor.test(hp$umbral_ms, hp$iaf_reposo))
l <- lm(umbral_ms ~ periodo_reposo_ms, data = hp); print(summary(l)$coefficients); print(confint(l))
cat("Spearman umbral vs IAF:", round(cor(hp$umbral_ms, hp$iaf_reposo, method = "spearman"), 3), "\n")
## influencia: correlación sin el participante de mayor periodo alfa
o <- which.max(hp$periodo_reposo_ms)
cat("sin", hp$participante[o], "(periodo", round(hp$periodo_reposo_ms[o], 1), "): r =", round(cor(hp$umbral_ms[-o], hp$periodo_reposo_ms[-o]), 3),
    " p =", signif(cor.test(hp$umbral_ms[-o], hp$periodo_reposo_ms[-o])$p.value, 3), "\n")
cd <- cooks.distance(l); cat("distancias de Cook > 4/n:", hp$participante[cd > 4 / nrow(hp)], "\n")

cat("\n=====================================================================\n")
cat("K. Cobertura cruzada entre eventos y periódica con ambos optimizadores\n")
cat("=====================================================================\n")
## solo agentes funcionales (umbral bajo la penalización de 300 ms)
sfk <- sf[sf$umbral < 300, ]
cob <- function(A, B) {   # C(A, B): fracción de B dominada o igualada por A
  A <- as.matrix(A); B <- as.matrix(B); if (!nrow(B)) return(NA); if (!nrow(A)) return(0)
  d <- ncol(B); res <- logical(nrow(B))
  if (nrow(A) <= nrow(B)) {
    for (i in seq_len(nrow(A))) { a <- matrix(A[i, ], nrow(B), d, byrow = TRUE); res <- res | rowSums(a <= B) == d }
  } else {
    for (k in seq_len(nrow(B))) { b <- matrix(B[k, ], nrow(A), d, byrow = TRUE); res[k] <- any(rowSums(A <= b) == d) }
  }
  mean(res)
}
tabK <- do.call(rbind, lapply(sort(unique(sfk$semilla)), function(s) {
  d <- sfk[sfk$semilla == s, ]
  g <- function(a, m) d[d$arquitectura == a & d$metodo == m, OBJ]
  data.frame(semilla = s,
    ev_nsga_sobre_per_nsga = cob(g("eventos", "NSGA-III"), g("periodica", "NSGA-III")),
    ev_nsga_sobre_per_rand = cob(g("eventos", "NSGA-III"), g("periodica", "random")),
    ev_rand_sobre_per_rand = cob(g("eventos", "random"), g("periodica", "random")),
    ev_rand_sobre_per_nsga = cob(g("eventos", "random"), g("periodica", "NSGA-III")),
    per_rand_sobre_ev_nsga = cob(g("periodica", "random"), g("eventos", "NSGA-III")),
    per_nsga_sobre_ev_nsga = cob(g("periodica", "NSGA-III"), g("eventos", "NSGA-III")),
    per_rand_sobre_ev_rand = cob(g("periodica", "random"), g("eventos", "random")),
    per_nsga_sobre_ev_rand = cob(g("periodica", "NSGA-III"), g("eventos", "random")))
}))
print(tabK, digits = 3)
cat("\nmedia por columna:\n"); print(round(colMeans(tabK[, -1]), 3))
cat("min por columna:\n"); print(round(apply(tabK[, -1], 2, min), 3))
cat("max por columna:\n"); print(round(apply(tabK[, -1], 2, max), 3))
write.csv(tabK, file.path(O, "K_cobertura_cruzada.csv"), row.names = FALSE)
sink()
