# =============================================================================
#  18_origen_cepa.R
#  De donde viene CADA cepa.
#
#  Los pasos anteriores trabajan con grupos. Este baja al individuo, que es lo
#  que se pregunta cuando uno mira una cepa concreta y quiere saber su historia.
#  Cuatro analisis, todos sobre la matriz de genotipos que guarda 02_variantes.R.
#
#  1. ANCESTRIA POR CEPA
#  Descompone cada genoma en proporciones de K componentes ancestrales. Es la
#  version en R de lo que hacen STRUCTURE o ADMIXTURE: se factoriza la matriz de
#  genotipos en dos matrices no negativas, una de componentes por sitio y otra de
#  proporciones por cepa. Una cepa con proporcion cercana a uno en un componente
#  es de ancestria simple; una repartida entre varios es mezclada.
#
#  Se usa factorizacion no negativa por minimos cuadrados alternados, que es
#  determinista dada la semilla y no necesita paquetes externos. NO es lo mismo
#  que un modelo de verosimilitud tipo ADMIXTURE: no hay intervalos de confianza
#  y la asignacion de un componente a una poblacion real es interpretacion del
#  usuario, no del metodo. Eso va declarado.
#
#  2. VECINO MAS CERCANO GENETICO
#  Para cada cepa, las cepas mas parecidas y donde fueron colectadas. Responde el
#  caso individual: esta cepa de Coyhaique se parece a las de Magallanes. Cuando
#  el vecino esta lejos geograficamente, hay migracion, error de etiqueta o
#  transporte humano.
#
#  3. DISTANCIA AL CENTRO DE CADA GRUPO
#  Cuan tipica es la cepa dentro de su propio grupo. Las atipicas son las
#  candidatas a migrante y las que conviene revisar a mano.
#
#  4. ALELOS PRIVADOS RAREFACCIONADOS
#  Los alelos exclusivos de un grupo caen al alejarse de la fuente, igual que la
#  diversidad, pero es una senal distinta y menos sensible al efecto Wahlund. Sin
#  rarefaccion no son comparables entre grupos de distinto tamano, porque un
#  grupo grande acumula privados solo por tener mas cepas. Aca se submuestrea
#  todos los grupos al mismo numero de alelos.
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
log <- nuevo_log("18_origen_cepa"); log("=== 18 ORIGEN DE CADA CEPA ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")

GT <- v$GT
if (is.null(GT) || nrow(GT) != nrow(v$ALT)) {
  log("Sin matriz de genotipos alineada con el panel. Volve a correr 02_variantes.R.")
  saveRDS(list(), paso("origen_cepa")); cerrar_log(log)
} else {

gm <- v$grupo_de_muestra; if (is.null(gm)) gm <- d1$grupo_de_cepa[colnames(GT)]
cepas <- colnames(GT); nC <- length(cepas)
ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos
lat <- setNames(v$coord$lat, grupos); lon <- setNames(v$coord$lon, grupos)
log("Cepas: ", nC, " | sitios: ", nrow(GT))

# matriz centrada de dosis alelica, con los faltantes en la media del sitio
X <- GT / 2
mu <- rowMeans(X, na.rm = TRUE)
for (i in which(rowSums(is.na(X)) > 0)) X[i, is.na(X[i, ])] <- mu[i]
val <- is.finite(mu) & apply(X, 1, sd) > 0
X <- X[val, , drop = FALSE]
log("Sitios utilizables: ", nrow(X))

# --- 1. Ancestria por cepa ---------------------------------------------------
K_ANC <- max(2L, min(as.integer(getOption("filo.K", K_ANCESTRIA)),
                     length(unique(na.omit(gm)))))
log("\nAncestria: K = ", K_ANC, " componentes")
set.seed(SEMILLA)
W <- matrix(runif(nrow(X) * K_ANC), nrow(X), K_ANC)   # componentes por sitio
H <- matrix(runif(K_ANC * nC), K_ANC, nC)             # proporciones por cepa
for (it in seq_len(if (RAPIDO) 30L else 120L)) {
  H <- H * (crossprod(W, X) / pmax(crossprod(W, W %*% H), 1e-9))
  W <- W * ((X %*% t(H)) / pmax(W %*% tcrossprod(H, H), 1e-9))
}
Q <- t(H); Q <- Q / pmax(rowSums(Q), 1e-9)            # proporciones que suman 1
colnames(Q) <- paste0("K", seq_len(K_ANC))
anc <- data.frame(cepa = cepas, grupo = unname(gm), stringsAsFactors = FALSE)
anc <- cbind(anc, round(Q, 4))
anc$componente_dominante <- colnames(Q)[max.col(Q)]
anc$proporcion_dominante <- round(apply(Q, 1, max), 4)
anc$mezclada <- anc$proporcion_dominante < 0.7
write.table(anc, file.path(OUT, "18_ancestria.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("  Cepas de ancestria simple (dominante >= 0.7): ", sum(!anc$mezclada),
    " de ", nC)
log("  Mezcladas: ", sum(anc$mezclada))
tt <- table(anc$grupo, anc$componente_dominante)
if (nrow(tt) > 1) {
  puros <- rownames(tt)[apply(tt, 1, function(z) max(z) == sum(z))]
  log("  Grupos con un solo componente dominante: ", length(puros), " de ", nrow(tt))
}
log("  ADVERTENCIA: es una factorizacion no negativa, no un modelo de")
log("  verosimilitud. No tiene intervalos y la lectura de cada componente como")
log("  poblacion real es interpretacion, no resultado del metodo.")

# --- 2. Vecino mas cercano ---------------------------------------------------
# distancia euclidea entre cepas sobre la matriz centrada
Xc <- X - rowMeans(X)
G2 <- crossprod(Xc)                       # producto interno entre cepas
d2 <- outer(diag(G2), diag(G2), "+") - 2 * G2
diag(d2) <- Inf
NV <- min(5L, nC - 1L)
vec <- vector("list", nC)
for (j in seq_len(nC)) {
  o <- order(d2[, j])[seq_len(NV)]
  vec[[j]] <- data.frame(
    cepa = cepas[j], grupo = unname(gm[j]),
    vecino = cepas[o[1]], grupo_vecino = unname(gm[o[1]]),
    distancia = round(sqrt(max(d2[o[1], j], 0)), 4),
    mismo_grupo = identical(unname(gm[j]), unname(gm[o[1]])),
    km_al_vecino = {
      a <- unname(gm[j]); b <- unname(gm[o[1]])
      if (is.na(a) || is.na(b) || is.na(lat[a]) || is.na(lat[b])) NA_real_
      else round(dist_km(lat[a], lon[a], lat[b], lon[b]))
    },
    vecinos = paste(cepas[o], collapse = ", "),
    grupos_vecinos = paste(unname(gm[o]), collapse = ", "),
    stringsAsFactors = FALSE)
}
nn <- do.call(rbind, vec)
write.table(nn, file.path(OUT, "18_vecino_cercano.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nVecino mas cercano:")
log("  Cepas cuyo vecino esta en su mismo grupo: ", sum(nn$mismo_grupo), " de ", nC)
lejos <- nn[!nn$mismo_grupo & !is.na(nn$km_al_vecino) & nn$km_al_vecino > 500, ]
lejos <- lejos[order(-lejos$km_al_vecino), ]
log("  Cepas cuyo pariente mas cercano esta a mas de 500 km: ", nrow(lejos))
for (i in seq_len(min(10, nrow(lejos))))
  log(sprintf("    %-16s (%s) -> %-16s (%s)  %s km",
      substr(lejos$cepa[i], 1, 16), substr(lejos$grupo[i], 1, 20),
      substr(lejos$vecino[i], 1, 16), substr(lejos$grupo_vecino[i], 1, 20),
      format(lejos$km_al_vecino[i], big.mark = " ")))
if (nrow(lejos)) log("  Candidatas a migrante, etiqueta equivocada o transporte humano.")

# --- 3. Cuan tipica es cada cepa en su grupo ---------------------------------
cen <- rep(NA_real_, nC)
for (g in unique(na.omit(gm))) {
  k <- which(gm == g)
  if (length(k) < 3) next
  m <- rowMeans(Xc[, k, drop = FALSE])
  cen[k] <- sqrt(colSums((Xc[, k, drop = FALSE] - m)^2))
}
z <- rep(NA_real_, nC)
for (g in unique(na.omit(gm))) {
  k <- which(gm == g & is.finite(cen))
  if (length(k) < 3) next
  z[k] <- (cen[k] - mean(cen[k])) / max(sd(cen[k]), 1e-9)
}
tip <- data.frame(cepa = cepas, grupo = unname(gm),
                  distancia_al_centro = round(cen, 3), z = round(z, 2),
                  atipica = !is.na(z) & z > 2, stringsAsFactors = FALSE)
tip <- tip[order(-tip$z), ]
write.table(tip, file.path(OUT, "18_atipicas.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nCepas atipicas dentro de su grupo (z > 2): ", sum(tip$atipica, na.rm = TRUE))
for (i in seq_len(min(8, sum(tip$atipica, na.rm = TRUE))))
  log(sprintf("    %-16s %-24s z=%.1f", substr(tip$cepa[i], 1, 16),
              substr(tip$grupo[i], 1, 24), tip$z[i]))

# --- 4. Alelos privados rarefaccionados --------------------------------------
# Sin rarefaccion un grupo grande acumula privados solo por tener mas cepas.
# Se submuestrea todos al mismo numero de alelos: la probabilidad de que un
# alelo aparezca en el grupo al tomar m de sus n alelos es 1 - C(n-a,m)/C(n,m).
m_r <- max(4L, as.integer(median(apply(TOT[, v$elegible, drop = FALSE], 2,
                                       function(z) median(z[z > 0])), na.rm = TRUE)))
priv <- rep(NA_real_, length(grupos))
for (k in seq_along(grupos)) {
  n <- TOT[, k]; a <- ALT[, k]
  otros <- rowSums(ALT[, -k, drop = FALSE])
  ok <- n >= m_r & otros == 0 & a > 0
  if (!any(ok)) { priv[k] <- 0; next }
  p <- 1 - exp(lchoose(n[ok] - a[ok], m_r) - lchoose(n[ok], m_r))
  priv[k] <- sum(p, na.rm = TRUE)
}
pr <- data.frame(grupo = grupos, n_cepas = v$n_cepas,
                 lat = v$coord$lat, lon = v$coord$lon,
                 privados_rar = round(priv, 2),
                 privados_por_cepa = round(priv / pmax(v$n_cepas, 1), 3),
                 stringsAsFactors = FALSE)
pr <- pr[order(-pr$privados_rar), ]
write.table(pr, file.path(OUT, "18_privados_rarefaccionados.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nAlelos privados rarefaccionados a ", m_r, " alelos por grupo:")
for (i in seq_len(min(8, nrow(pr))))
  log(sprintf("    %-28s %8.1f  (n=%d)", substr(pr$grupo[i], 1, 28),
              pr$privados_rar[i], pr$n_cepas[i]))
cc <- suppressWarnings(cor(pr$privados_rar, pr$n_cepas, use = "complete"))
log("  Correlacion con el tamano de muestra tras rarefaccionar: ", round(cc, 3))
if (!is.na(cc) && abs(cc) > 0.5)
  log("  Sigue alta: la rarefaccion no elimino el efecto del muestreo.")

saveRDS(list(ancestria = anc, vecinos = nn, atipicas = tip,
             privados_rar = pr, K = K_ANC, m_rarefaccion = m_r),
        paso("origen_cepa"))
log("\nSiguiente: 12_validar.R")
cerrar_log(log)
}
