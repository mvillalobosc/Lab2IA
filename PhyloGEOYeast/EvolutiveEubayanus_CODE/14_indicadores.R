# =============================================================================
#  14_indicadores.R
#  Indicadores por poblacion que necesitan el genotipo individual, y estadisticos
#  globales de estructura.
#
#  POR QUE ESTE PASO EXISTE APARTE
#  04_diversidad.R trabaja con frecuencias agregadas por grupo, que alcanzan para
#  pi. Todo lo que sigue necesita saber que alelos lleva CADA cepa:
#
#    Ho    heterocigosidad observada, o sea la proporcion de cepas heterocigotas.
#          Solo tiene sentido en diploides.
#    Fis   coeficiente de endogamia, 1 - Ho/He. Positivo indica deficit de
#          heterocigotos frente a lo esperado, que en levadura suele reflejar
#          autofecundacion o reproduccion clonal antes que estructura oculta.
#    LD    correlacion al cuadrado entre pares de sitios cercanos. Mide cuanto
#          recombina el grupo y calibra el adelgazado del panel.
#
#  Y agrega los indicadores que describen el grupo sin depender de la geografia:
#  alelos privados, sitios polimorficos, riqueza rarefaccionada, entropia de
#  Shannon, theta de Watterson y D de Tajima.
#
#  D DE TAJIMA. Compara dos estimadores de theta: pi, que pesa las frecuencias
#  intermedias, y Watterson, que solo cuenta sitios segregantes. Negativo indica
#  exceso de variantes raras, la firma de una expansion reciente. Es una linea de
#  evidencia independiente del gradiente y de psi, y por eso vale reportarla.
#
#  ADVERTENCIA SOBRE EL PANEL. Estos estadisticos se calculan sobre el panel
#  estricto, que esta filtrado por frecuencia minima. Ese filtro amputa
#  justamente la cola de variantes raras, asi que Tajima D y Watterson quedan
#  sesgados hacia arriba y no son comparables con valores calculados sobre todos
#  los sitios. Se reportan con esa salvedad declarada.
# =============================================================================

# --- Ubicacion del script -----------------------------------------------------
local({
  cand <- character(0)
  for (i in seq_len(sys.nframe())) {
    of <- get0("ofile", envir = sys.frames()[[i]], inherits = FALSE)
    if (!is.null(of) && is.character(of) && nzchar(of)) cand <- c(cand, of)
  }
  if (!length(cand) && requireNamespace("rstudioapi", quietly = TRUE) &&
      isTRUE(try(rstudioapi::isAvailable(), silent = TRUE))) {
    p <- try(rstudioapi::getSourceEditorContext()$path, silent = TRUE)
    if (!inherits(p, "try-error") && length(p) && nzchar(p)) cand <- p
  }
  for (p in cand) {
    d <- tryCatch(dirname(normalizePath(p, mustWork = FALSE)), error = function(e) "")
    if (nzchar(d) && file.exists(file.path(d, "00_config.R"))) {
      if (!identical(normalizePath(d), normalizePath(getwd()))) setwd(d)
      return(invisible(NULL))
    }
  }
  if (!file.exists("00_config.R")) stop("No encuentro 00_config.R.", call. = FALSE)
})

source("00_config.R")
log <- nuevo_log("14_indicadores"); log("=== 14 INDICADORES POR POBLACION ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")
dv <- exigir_paso("diversidad", "04_diversidad.R")
df <- tryCatch(exigir_paso("diferenciacion", "05_diferenciacion.R"), error = function(e) NULL)
mz <- tryCatch(exigir_paso("mezcla", "13_estructura.R"), error = function(e) NULL)

ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos; K <- length(grupos)
GT <- v$GT
hay_gt <- !is.null(GT) && nrow(GT) == nrow(ALT)
if (!hay_gt) {
  log("AVISO: paso_variantes.rds no trae la matriz de genotipos por cepa.")
  log("  Ho, Fis y el desequilibrio de ligamiento quedan sin calcular.")
  log("  Se resuelve volviendo a correr 02_variantes.R con la version actual.")
}
gm <- v$grupo_de_muestra
if (hay_gt && is.null(gm)) gm <- d1$grupo_de_cepa[colnames(GT)]

f <- ALT / pmax(TOT, 1)

# --- Ho, Fis y LD ------------------------------------------------------------
Ho <- Fis <- ld <- rep(NA_real_, K)
if (hay_gt) {
  log("Genotipos: ", nrow(GT), " sitios x ", ncol(GT), " cepas")
  for (k in seq_len(K)) {
    cols <- which(gm == grupos[k])
    if (length(cols) < 2) next
    G <- GT[, cols, drop = FALSE]
    het <- rowMeans(G == 1, na.rm = TRUE)      # 1 = heterocigoto en codigo 0/1/2
    Ho[k] <- mean(het, na.rm = TRUE)
    he <- dv$div$pi[match(grupos[k], dv$div$grupo)]
    Fis[k] <- if (!is.na(he) && he > 0) 1 - Ho[k] / he else NA_real_
    # LD: r2 entre pares de sitios consecutivos del mismo cromosoma, sobre una
    # muestra de sitios para que el costo no crezca con el cuadrado del panel
    idx <- seq_len(min(4000L, nrow(G)))
    x <- G[idx, , drop = FALSE]
    mismo <- v$INFO$chrom[idx][-1] == v$INFO$chrom[idx][-length(idx)]
    r2 <- suppressWarnings(vapply(which(mismo), function(i) {
      a <- x[i, ]; b <- x[i + 1L, ]
      o <- !is.na(a) & !is.na(b)
      if (sum(o) < 5 || sd(a[o]) == 0 || sd(b[o]) == 0) return(NA_real_)
      cor(a[o], b[o])^2
    }, numeric(1)))
    ld[k] <- mean(r2, na.rm = TRUE)
  }
  log("Ho mediana: ", round(median(Ho, na.rm = TRUE), 4),
      " | Fis mediana: ", round(median(Fis, na.rm = TRUE), 4),
      " | LD r2 mediano: ", round(median(ld, na.rm = TRUE), 4))
  fp <- median(Fis, na.rm = TRUE)
  if (!is.na(fp) && fp > 0.5)
    log("  Fis alto: deficit fuerte de heterocigotos, esperable con",
        " autofecundacion o clonalidad.")
}

# --- Alelos privados, sitios polimorficos, Shannon, Watterson, Tajima --------
privados <- polim <- shannon <- watt <- tajima <- riqueza <- rep(NA_real_, K)
n_sitios <- nrow(ALT)
for (k in seq_len(K)) {
  n <- TOT[, k]; a <- ALT[, k]
  ok <- n >= 2
  if (!any(ok)) next
  p <- a[ok] / n[ok]
  seg <- p > 0 & p < 1
  polim[k] <- mean(seg)
  # privado: el grupo tiene el alelo y ningun otro grupo lo tiene
  otros <- rowSums(ALT[ok, -k, drop = FALSE]) 
  privados[k] <- sum(a[ok] > 0 & otros == 0)
  # entropia de Shannon promediada sobre sitios, en bits
  q <- p[seg]
  shannon[k] <- if (length(q)) mean(-(q * base::log2(q) + (1 - q) * base::log2(1 - q))) else 0
  # Watterson: S / a1, con a1 la suma armonica del numero de alelos
  nn <- round(mean(n[ok]))
  a1 <- if (nn > 1) sum(1 / seq_len(nn - 1)) else NA_real_
  watt[k] <- if (is.finite(a1) && a1 > 0) sum(seg) / a1 / length(p) else NA_real_
  pi_k <- dv$div$pi[match(grupos[k], dv$div$grupo)]
  tajima[k] <- if (is.finite(watt[k]) && watt[k] > 0) (pi_k - watt[k]) / watt[k] else NA_real_
  riqueza[k] <- mean(1 / (p^2 + (1 - p)^2))   # numero efectivo de alelos
}
log("\nSitios polimorficos por grupo: mediana ", round(median(polim, na.rm = TRUE), 3))
log("Alelos privados: total ", sum(privados, na.rm = TRUE),
    " | grupos con al menos uno: ", sum(privados > 0, na.rm = TRUE))
log("D de Tajima: mediana ", round(median(tajima, na.rm = TRUE), 3))
log("  El panel esta filtrado por frecuencia minima, asi que la cola de variantes")
log("  raras esta amputada y Tajima D sale sesgado hacia arriba. No es comparable")
log("  con valores calculados sobre todos los sitios.")

pob <- data.frame(grupo = grupos, n_cepas = v$n_cepas,
                  lat = v$coord$lat, lon = v$coord$lon, elegible = v$elegible,
                  He = round(dv$div$pi[match(grupos, dv$div$grupo)], 6),
                  He_rar = round(dv$div$pi_rar[match(grupos, dv$div$grupo)], 6),
                  He_se = round(dv$div$pi_se[match(grupos, dv$div$grupo)], 6),
                  Ho = round(Ho, 6), Fis = round(Fis, 5),
                  ld_r2_medio = round(ld, 5),
                  privados = privados, prop_polimorficos = round(polim, 5),
                  sitios_polimorficos = round(polim * n_sitios),
                  shannon_bits = round(shannon, 5),
                  n_alelos_efectivo = round(riqueza, 4),
                  theta_watterson = signif(watt, 5),
                  tajima_D = round(tajima, 4),
                  stringsAsFactors = FALSE)
write.table(pob, file.path(OUT, "14_indicadores_poblacion.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

# --- Estadisticos globales ---------------------------------------------------
gl <- list()
if (!is.null(df)) {
  gl$fst_global <- round(mean(df$tabla$fst, na.rm = TRUE), 5)
  gl$ibd_r <- df$ibd_r; gl$ibd_pendiente <- df$ibd_pendiente
  gl$mantel_r <- df$ibd_r; gl$mantel_p <- df$ibd_p
}
if (!is.null(mz) && length(mz$var_expl)) {
  gl$pca_var_pc1 <- round(100 * mz$var_expl[1], 2)
  gl$pca_var_pc2 <- round(100 * mz$var_expl[2], 2)
  gl$pca_var_pc1a5 <- round(100 * sum(mz$var_expl[1:min(5, length(mz$var_expl))]), 2)
}
gl$cor_He_n <- round(suppressWarnings(cor(pob$He, pob$n_cepas, use = "complete")), 4)
gl$cor_He_privados <- round(suppressWarnings(cor(pob$He, pob$privados, use = "complete")), 4)
gl$cor_He_shannon <- round(suppressWarnings(cor(pob$He, pob$shannon_bits, use = "complete")), 4)
gl$cor_He_riqueza <- round(suppressWarnings(cor(pob$He, pob$n_alelos_efectivo, use = "complete")), 4)

# Particion de varianza estilo AMOVA sobre las frecuencias por grupo: cuanto de
# la variacion total esta entre regiones, entre grupos dentro de region y dentro
# de grupo. Es la lectura jerarquica de la estructura.
reg <- d1$meta[[COL_CONT]][match(grupos, d1$meta$.GRUPO)]
if (sum(!is.na(reg)) > 3 && length(unique(na.omit(reg))) > 1) {
  X <- t(f); ok <- apply(X, 2, function(z) all(is.finite(z)) && sd(z) > 0)
  X <- X[, ok, drop = FALSE]
  gtot <- colMeans(X)
  sct <- sum((sweep(X, 2, gtot))^2)
  mreg <- do.call(rbind, lapply(split(seq_len(nrow(X)), reg), function(i)
    colMeans(X[i, , drop = FALSE])))
  nreg <- table(reg)[rownames(mreg)]
  scr <- sum(as.numeric(nreg) * rowSums((sweep(mreg, 2, gtot))^2))
  scg <- sct - scr
  gl$var_entre_regiones <- round(100 * scr / sct, 2)
  gl$var_entre_sitios_en_region <- round(100 * scg / sct, 2)
  gl$var_dentro_sitio <- NA_real_
  log("\nParticion de varianza: entre regiones ", gl$var_entre_regiones,
      "% | entre grupos dentro de region ", gl$var_entre_sitios_en_region, "%")
}

# Procrustes: cuanto se parece la estructura genetica al mapa. Se rota y escala
# el PCA para que calce lo mejor posible con las coordenadas y se mide el ajuste
# (Wang et al. 2010). Alto significa que la genetica reproduce la geografia.
if (!is.null(mz) && !is.null(mz$pca) && nrow(mz$pca) > 4) {
  P <- as.matrix(mz$pca[, c("PC1", "PC2")])
  G <- as.matrix(mz$pca[, c("lon", "lat")])
  ok <- stats::complete.cases(P, G)
  if (sum(ok) > 4) {
    P <- scale(P[ok, ], scale = FALSE); G <- scale(G[ok, ], scale = FALSE)
    P <- P / sqrt(sum(P^2)); G <- G / sqrt(sum(G^2))
    sv <- svd(crossprod(G, P))
    t0 <- sum(sv$d)
    gl$procrustes_t0 <- round(t0, 4)
    gl$procrustes_n <- sum(ok)
    # significancia por permutacion de las coordenadas
    set.seed(SEMILLA)
    nulo <- vapply(seq_len(N_PERMUTA), function(b) {
      o <- sample.int(nrow(G)); sum(svd(crossprod(G[o, ], P))$d)
    }, numeric(1))
    gl$procrustes_p <- signif((1 + sum(nulo >= t0)) / (1 + length(nulo)), 3)
    log("Procrustes: t0 = ", gl$procrustes_t0, " | p = ", gl$procrustes_p,
        " (", N_PERMUTA, " permutaciones)")
    if (gl$procrustes_p <= 0.05)
      log("  La estructura genetica reproduce la geografia mas de lo esperable por azar.")
  }
}

glt <- data.frame(indicador = names(gl), valor = unlist(lapply(gl, function(x)
  if (is.null(x)) NA else x)), stringsAsFactors = FALSE)
write.table(glt, file.path(OUT, "14_indicadores_globales.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

saveRDS(list(poblacion = pob, globales = gl), paso("indicadores"))
log("\nSiguiente: 15_asignacion.R")
cerrar_log(log)
