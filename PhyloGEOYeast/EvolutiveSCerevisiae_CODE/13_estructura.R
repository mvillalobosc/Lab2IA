# =============================================================================
#  13_estructura.R
#  Estructura por componentes principales.
#
#  POR QUE VAN JUNTOS
#  Los dos describen relaciones entre grupos sin suponer un arbol. El PCA las
#  resume en pocos ejes; f3 pone a prueba una hipotesis concreta: que un grupo
#  sea mezcla de otros dos.
#
#  PCA
#  Sobre frecuencias alelicas centradas y sin escalar, por descomposicion propia
#  de la matriz de covarianza entre grupos. Se reporta la varianza explicada por
#  cada eje, que es lo que permite leer las posiciones en escala.
#
#  f3
#  f3(C; A, B) = E[(c-a)(c-b)], con correccion por la varianza de muestreo de C.
#  Negativo significa que las frecuencias de C caen ENTRE las de A y B mas de lo
#  que un arbol permitiria, o sea que C es mezcla de esos dos.
#
#  El error estandar va por bloques del genoma, con el mismo criterio que el
#  resto del pipeline, y Z < -3 es el umbral estandar (Patterson et al. 2012).
#  Sin error estandar el signo de f3 no prueba nada: cualquier ruido produce
#  valores negativos.
#
#  UNA ADVERTENCIA SOBRE LA ESCALA
#  Las fuentes de f3 son los grupos de la escala activa. En el escenario de
#  linaje son linajes, que es la unidad correcta. En los escenarios geograficos
#  una fuente es un agregado que puede contener varios linajes, y entonces f3
#  mezcla ancestria con estructura de muestreo. Ese caso se avisa en el log.
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
  if (!file.exists("00_config.R"))
    stop("No encuentro 00_config.R.", call. = FALSE)
})

source("00_config.R")
log <- nuevo_log("13_mezcla"); log("=== 13 ESTRUCTURA Y MEZCLA ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")

ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos; K <- length(grupos)
f <- ALT / pmax(TOT, 1)

# --- PCA ---------------------------------------------------------------------
ok_g <- which(v$n_cepas >= 2)
if (length(ok_g) < 3) {
  log("Menos de 3 grupos con n >= 2. Sin PCA.")
  PC <- NULL; var_expl <- numeric(0)
} else {
  X <- t(f[, ok_g, drop = FALSE])
  val <- apply(X, 2, function(z) all(is.finite(z)) && sd(z) > 0)
  X <- X[, val, drop = FALSE]
  log("PCA sobre ", nrow(X), " grupos y ", ncol(X), " sitios variables")
  Xc <- scale(X, center = TRUE, scale = FALSE)
  ev <- eigen(tcrossprod(Xc) / ncol(Xc), symmetric = TRUE)
  lam <- pmax(ev$values, 0)
  PC <- ev$vectors %*% diag(sqrt(lam))
  var_expl <- lam / sum(lam)
  log("  PC1 explica ", round(100 * var_expl[1], 2), "% | PC2 ",
      round(100 * var_expl[2], 2), "% | PC1 a PC5 ",
      round(100 * sum(var_expl[1:min(5, length(var_expl))]), 2), "%")
  pca <- data.frame(grupo = grupos[ok_g], n_cepas = v$n_cepas[ok_g],
                    lat = v$coord$lat[ok_g], lon = v$coord$lon[ok_g],
                    PC1 = round(PC[, 1], 5), PC2 = round(PC[, 2], 5),
                    PC3 = if (ncol(PC) >= 3) round(PC[, 3], 5) else NA_real_,
                    stringsAsFactors = FALSE)
  write.table(pca, file.path(OUT, "13_pca.tsv"), sep = "\t",
              row.names = FALSE, quote = FALSE)
}

# --- f3 ---------------------------------------------------------------------
# f3(C; A, B) = media sobre sitios de (c-a)(c-b), menos la correccion por la
# varianza de muestreo del objetivo C. Negativo significa que las frecuencias de
# C caen ENTRE las de A y B mas de lo que un arbol permitiria, o sea que C es
# mezcla de esas dos fuentes. Z bajo -3 es el umbral estandar (Patterson 2012).
#
# Fijado C, si se define d_k = c - a_k, entonces la suma sobre sitios de d_A d_B
# es exactamente crossprod(D)[A,B]: una sola multiplicacion de matrices da f3
# contra todos los pares de fuentes a la vez. Recorrer las ternas con bucles no
# termina con muchos grupos.
#
# Los sitios validos de cada terna se manejan con mascaras: d_k vale cero donde
# el grupo k no tiene dato o donde C tiene menos de dos alelos, asi que esos
# sitios no aportan al producto y quedan fuera sin filtrar terna por terna.
#
# Todo se acumula por bloque del genoma, de modo que el jackknife de dejar un
# bloque afuera es una resta sobre matrices ya calculadas y no un recalculo.
obj <- which(v$n_cepas >= max(N_MIN_GRUPO_EST, 4L))
log("\nf3: ", length(obj), " grupos pueden ser objetivo (n >= ",
    max(N_MIN_GRUPO_EST, 4L), "), ", K, " pueden ser fuente")
if (length(COL_GRUPO) == 1 && !identical(COL_GRUPO, COL_LINAJE))
  log("  AVISO: en esta escala una fuente es un agregado geografico que puede\n",
      "  contener varios linajes. f3 mezcla ancestria con estructura de muestreo.")

orden <- order(-v$n_cepas)
obj <- head(intersect(orden, obj), N_OBJ_F3)
fuentes <- head(orden, N_FUENTES_F3)
log("  Se prueban ", length(obj), " objetivos contra ",
    choose(max(length(fuentes) - 1, 2), 2), " pares de fuentes")

ib <- split(seq_len(nrow(ALT)), v$bloque)
nb <- length(ib)
filas <- list()
for (ic in obj) {
  ff <- setdiff(fuentes, ic); Kf <- length(ff)
  if (Kf < 2) next
  SD <- SG <- SN <- array(0, c(nb, Kf, Kf))
  for (b in seq_len(nb)) {
    k <- ib[[b]]
    nC <- TOT[k, ic]; aC <- ALT[k, ic]
    vC <- (nC >= 2) * 1
    cc <- ifelse(nC > 0, aC / pmax(nC, 1), 0)
    g <- ifelse(nC >= 2, aC * (nC - aC) / (nC * pmax(nC - 1, 1)) / nC, 0)
    Tf <- TOT[k, ff, drop = FALSE]; Af <- ALT[k, ff, drop = FALSE]
    M <- (Tf >= 1) * vC
    Dm <- (cc - Af / pmax(Tf, 1)) * M
    SD[b, , ] <- crossprod(Dm)
    SG[b, , ] <- crossprod(M * g, M)
    SN[b, , ] <- crossprod(M)
  }
  tD <- colSums(SD); tG <- colSums(SG); tN <- colSums(SN)
  f3m <- ifelse(tN >= 100, (tD - tG) / pmax(tN, 1), NA_real_)
  ut <- which(upper.tri(matrix(0, Kf, Kf)))
  neg <- ut[which(is.finite(f3m[ut]) & f3m[ut] < 0)]
  if (!length(neg)) next
  TH <- vapply(seq_len(nb), function(b) {
    n2 <- (tN - SN[b, , ])[neg]
    ifelse(n2 >= 100, ((tD - SD[b, , ])[neg] - (tG - SG[b, , ])[neg]) / pmax(n2, 1), NA_real_)
  }, numeric(length(neg)))
  if (is.null(dim(TH))) TH <- matrix(TH, nrow = length(neg))
  se <- apply(TH, 1, function(z) { z <- z[is.finite(z)]; g2 <- length(z)
    if (g2 < 8) NA_real_ else sqrt((g2 - 1) / g2 * sum((z - mean(z))^2)) })
  ij <- arrayInd(neg, c(Kf, Kf))
  filas[[length(filas) + 1L]] <- data.frame(
    objetivo = grupos[ic], fuente_a = grupos[ff[ij[, 1]]], fuente_b = grupos[ff[ij[, 2]]],
    f3 = round(f3m[neg], 6), f3_se = round(se, 6),
    z = round(ifelse(is.finite(se) & se > 0, f3m[neg] / se, NA_real_), 3),
    n_objetivo = v$n_cepas[ic], stringsAsFactors = FALSE)
}

sig <- NULL; f3t <- NULL
if (length(filas)) {
  f3t <- do.call(rbind, filas)
  f3t <- f3t[order(f3t$z), ]
  write.table(f3t, file.path(OUT, "13_f3.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  sig <- f3t[!is.na(f3t$z) & f3t$z < -3, ]
  log("Combinaciones con f3 negativo: ", nrow(f3t))
  log("Con Z < -3, evidencia formal de mezcla: ", nrow(sig))
  if (nrow(sig)) {
    mej <- sig[!duplicated(sig$objetivo), ]
    log("\nGrupos con evidencia de mezcla:")
    for (i in seq_len(min(12, nrow(mej))))
      log(sprintf("  %-24s = mezcla de %-18s y %-18s  f3=%.5f  Z=%.2f",
          substr(mej$objetivo[i], 1, 24), substr(mej$fuente_a[i], 1, 18),
          substr(mej$fuente_b[i], 1, 18), mej$f3[i], mej$z[i]))
  }
} else log("Ninguna combinacion dio f3 negativo. Sin evidencia de mezcla.")

saveRDS(list(pca = if (exists("pca")) pca else NULL, PC = PC,
             var_expl = var_expl, f3 = f3t, f3_sig = sig), paso("mezcla"))
log("\nSiguiente: 14_indicadores.R")
cerrar_log(log)
