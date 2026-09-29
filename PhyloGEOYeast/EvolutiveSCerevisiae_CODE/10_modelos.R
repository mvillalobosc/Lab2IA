# =============================================================================
#  10_modelos.R
#  El origen como comparacion de modelos, no como ajuste.
#
#  EL PROBLEMA QUE RESUELVE
#  06_gradiente.R recorre una grilla y devuelve el punto de mejor ajuste. Eso
#  SIEMPRE devuelve un punto: la existencia de un maximo no prueba que haya
#  habido expansion desde un origen. Aislamiento por distancia sin expansion,
#  muestreo asimetrico o dos refugios producen gradientes parecidos.
#
#  MODELOS COMPARADOS, todos sobre los mismos datos y la misma variable
#  respuesta (pi por grupo):
#    M0 nulo            pi ~ 1
#                       la diversidad no depende de la geografia
#    M1 fundador serial pi ~ distancia al mejor origen de la grilla
#                       una sola fuente, caida monotona
#    M2 IBD             pi ~ latitud + longitud
#                       tendencia espacial suave sin fuente privilegiada
#    M3 dos refugios    pi ~ distancia al mas cercano de dos origenes
#                       dos fuentes, se buscan por grilla
#
#  COMO SE COMPARAN
#  Los modelos tienen distinto numero de parametros y M1 y M3 ademas eligieron
#  su origen mirando los datos, asi que comparar R2 crudo los premia. Se usan
#  dos criterios:
#    AIC con los grados de libertad efectivos, contando los parametros del
#      origen (2 por origen buscado en la grilla).
#    Validacion cruzada dejando un grupo afuera, que es lo que de verdad castiga
#      el sobreajuste: el origen se vuelve a buscar en cada pliegue sin ver el
#      grupo que se va a predecir.
#  La validacion cruzada es el criterio que manda. Si M1 no le gana a M2, no hay
#  base para afirmar expansion desde un origen unico.
# =============================================================================

# --- Ubicacion del script -----------------------------------------------------
# RStudio no cambia el directorio de trabajo al apretar Source, asi que
# source("00_config.R") falla si la sesion esta parada en otra carpeta. Este
# bloque encuentra la carpeta del propio archivo y se para ahi. Tres vias, en
# orden de fiabilidad:
#   1. sys.frames(): cuando el archivo se ejecuta con source(), R guarda su ruta
#      en ofile. Funciona con el boton Source de RStudio y no necesita paquetes.
#   2. rstudioapi: para cuando se ejecutan lineas sueltas desde el editor, donde
#      no hay ofile. Se usa solo si el paquete esta instalado.
#   3. El directorio actual, si ya contiene 00_config.R.
# Con Rscript ninguna de las tres hace falta y el bloque no toca nada.
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
    q <- try(rstudioapi::getActiveProject(), silent = TRUE)
    if (!length(cand) && !inherits(q, "try-error") && length(q) && nzchar(q))
      cand <- file.path(q, "x")
  }
  for (p in cand) {
    d <- tryCatch(dirname(normalizePath(p, mustWork = FALSE)), error = function(e) "")
    if (nzchar(d) && file.exists(file.path(d, "00_config.R"))) {
      if (!identical(normalizePath(d), normalizePath(getwd()))) {
        setwd(d); message("Directorio de trabajo: ", d)
      }
      return(invisible(NULL))
    }
  }
  if (!file.exists("00_config.R"))
    stop("No encuentro 00_config.R. Abri la carpeta del pipeline como proyecto ",
         "en RStudio, o corre setwd() a mano.", call. = FALSE)
})

source("00_config.R")
log <- nuevo_log("10_modelos"); log("=== 10 COMPARACION DE MODELOS ===")
dv <- exigir_paso("diversidad", "04_diversidad.R")
gr <- exigir_paso("gradiente", "06_gradiente.R")

div <- dv$div
ele <- div[div$elegible & !is.na(div$pi) & !is.na(div$lat), ]
n <- nrow(ele)
log("Grupos: ", n)
if (n < 8) stop("Se necesitan al menos 8 grupos para comparar modelos.", call. = FALSE)

la <- ele$lat; lo <- ele$lon; y <- ele$pi
w <- if (PONDERAR) ele$peso else rep(1, n)
grilla <- gr$grilla

# Distancias de cada punto de la grilla a cada grupo, una sola vez.
DG <- vapply(seq_len(n), function(j) dist_km(grilla$lat, grilla$lon, la[j], lo[j]),
             numeric(nrow(grilla)))

# Busca el origen que maximiza el ajuste sobre el subconjunto idx, exigiendo
# pendiente negativa. Devuelve la fila de la grilla.
buscar_origen <- function(idx) {
  yy <- y[idx]; ww <- w[idx]; D <- DG[, idx, drop = FALSE]
  sw <- sum(ww); yc <- yy - sum(ww * yy) / sw
  Dc <- D - as.vector(D %*% ww) / sw
  num <- as.vector(Dc %*% (ww * yc))
  den <- sqrt(as.vector((Dc^2) %*% ww) * sum(ww * yc^2))
  r <- ifelse(den > 0, num / den, NA_real_)
  r2 <- ifelse(!is.na(r) & r < 0, r^2, NA_real_)
  if (all(is.na(r2))) return(NA_integer_)
  which.max(r2)
}

# Dos refugios: la distancia al mas cercano de dos puntos como predictor.
#
# Buscar el mejor PAR sobre la grilla completa es inviable: con miles de puntos
# son millones de pares por pliegue. Se acota de dos maneras.
#   1. El conjunto candidato son N_CAND_REFUGIO puntos de la grilla, elegidos
#      por su ajuste de un solo origen y separados entre si al menos
#      SEP_CAND_KM, para que no sean todos vecinos del mismo maximo.
#   2. El R2 ponderado se calcula de forma cerrada, sin lm().
# El conjunto candidato se arma UNA VEZ sobre todos los datos y se reutiliza en
# los pliegues de validacion cruzada. Es una fuga de informacion menor y hay que
# declararla: lo que el pliegue no ve es cual de los candidatos se elige, que es
# donde esta el sobreajuste que interesa castigar.
r2_cerrado <- function(d, yy, ww) {
  sw <- sum(ww); yc <- yy - sum(ww * yy) / sw; dc <- d - sum(ww * d) / sw
  num <- sum(ww * dc * yc)
  den <- sqrt(sum(ww * dc^2) * sum(ww * yc^2))
  if (!is.finite(den) || den <= 0) return(NA_real_)
  r <- num / den
  if (r >= 0) NA_real_ else r^2      # se exige pendiente negativa
}

candidatos_refugio <- local({
  r1 <- vapply(seq_len(nrow(grilla)), function(g) r2_cerrado(DG[g, ], y, w), numeric(1))
  o <- order(-r1); o <- o[is.finite(r1[o])]
  sel <- integer(0)
  for (g in o) {
    if (length(sel) >= N_CAND_REFUGIO) break
    if (!length(sel) ||
        min(dist_km(grilla$lat[g], grilla$lon[g],
                    grilla$lat[sel], grilla$lon[sel])) >= SEP_CAND_KM) sel <- c(sel, g)
  }
  sel
})
log("Candidatos para el modelo de dos refugios: ", length(candidatos_refugio),
    " puntos separados al menos ", SEP_CAND_KM, " km")

buscar_dos <- function(idx) {
  yy <- y[idx]; ww <- w[idx]; cand <- candidatos_refugio
  if (length(cand) < 2) return(c(NA_integer_, NA_integer_))
  mejor <- c(NA_integer_, NA_integer_); mejor_r2 <- -Inf
  for (ii in seq_along(cand)) {
    di <- DG[cand[ii], idx]
    for (jj in seq_along(cand)) {
      if (jj <= ii) next
      r2 <- r2_cerrado(pmin(di, DG[cand[jj], idx]), yy, ww)
      if (is.finite(r2) && r2 > mejor_r2) { mejor_r2 <- r2; mejor <- c(cand[ii], cand[jj]) }
    }
  }
  mejor
}

# --- Ajuste completo ---------------------------------------------------------
m0 <- lm(y ~ 1, weights = w)
o1 <- buscar_origen(seq_len(n))
d1 <- DG[o1, ]
m1 <- lm(y ~ d1, weights = w)
m2 <- lm(y ~ la + lo, weights = w)
o3 <- buscar_dos(seq_len(n))
d3 <- pmin(DG[o3[1], ], DG[o3[2], ])
m3 <- lm(y ~ d3, weights = w)

# AIC penalizando los parametros del origen: 2 por cada origen buscado.
aic_ef <- function(mod, extra) {
  ll <- as.numeric(logLik(mod))
  k <- length(coef(mod)) + 1 + extra
  -2 * ll + 2 * k
}
res <- data.frame(
  modelo = c("M0 nulo", "M1 fundador serial", "M2 IBD", "M3 dos refugios"),
  r2 = round(c(0, summary(m1)$r.squared, summary(m2)$r.squared,
               summary(m3)$r.squared), 4),
  par_extra = c(0, 2, 0, 4),
  aic = round(c(aic_ef(m0, 0), aic_ef(m1, 2), aic_ef(m2, 0), aic_ef(m3, 4)), 2),
  stringsAsFactors = FALSE)

# --- Validacion cruzada dejando un grupo afuera ------------------------------
# El origen se vuelve a buscar en cada pliegue. Esto es lo que castiga de verdad
# el sobreajuste de haber elegido el origen mirando los datos.
log("\nValidacion cruzada dejando un grupo afuera (", n, " pliegues)...")
t_cv <- Sys.time()
err <- matrix(NA_real_, n, 4, dimnames = list(NULL, res$modelo))
for (k in seq_len(n)) {
  tr <- setdiff(seq_len(n), k)
  err[k, 1] <- y[k] - weighted.mean(y[tr], w[tr])
  ok <- buscar_origen(tr)
  if (!is.na(ok)) {
    f <- lm(y[tr] ~ DG[ok, tr], weights = w[tr])
    err[k, 2] <- y[k] - (coef(f)[1] + coef(f)[2] * DG[ok, k])
  }
  f2 <- lm(y[tr] ~ la[tr] + lo[tr], weights = w[tr])
  err[k, 3] <- y[k] - (coef(f2)[1] + coef(f2)[2] * la[k] + coef(f2)[3] * lo[k])
  o <- buscar_dos(tr)
  if (k %% max(1L, floor(n / 10)) == 0 || k == n)
    log(sprintf("  pliegue %d de %d  (%.0f s)", k, n,
                as.numeric(difftime(Sys.time(), t_cv, units = "secs"))))
  if (!any(is.na(o))) {
    dtr <- pmin(DG[o[1], tr], DG[o[2], tr])
    f3 <- lm(y[tr] ~ dtr, weights = w[tr])
    dk <- min(DG[o[1], k], DG[o[2], k])
    err[k, 4] <- y[k] - (coef(f3)[1] + coef(f3)[2] * dk)
  }
}
res$rmse_cv <- round(sqrt(colMeans(err^2, na.rm = TRUE)), 6)
res$delta_aic <- round(res$aic - min(res$aic), 2)
res <- res[order(res$rmse_cv), ]
write.table(res, file.path(OUT, "10_modelos.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

log("\nComparacion de modelos (ordenado por error de validacion cruzada):")
for (i in seq_len(nrow(res)))
  log(sprintf("  %-20s R2=%.3f  AIC=%9.2f  dAIC=%7.2f  RMSE_cv=%.6f",
              res$modelo[i], res$r2[i], res$aic[i], res$delta_aic[i], res$rmse_cv[i]))

gana <- res$modelo[1]
log("\nGana por validacion cruzada: ", gana)
if (gana != "M1 fundador serial") {
  log("  El modelo de fundador serial desde un origen unico NO es el que mejor")
  log("  predice. La coordenada de 06_gradiente.R existe porque la grilla")
  log("  siempre devuelve un maximo, no porque los datos la respalden.")
} else {
  ventaja <- res$rmse_cv[2] / res$rmse_cv[1]
  log("  Predice mejor que la alternativa mas cercana por un factor de ",
      round(ventaja, 3), " en RMSE.")
  if (ventaja < 1.05)
    log("  La ventaja es marginal: los modelos son practicamente indistinguibles.")
}

saveRDS(list(tabla = res, origen_M1 = grilla[o1, ], origen_M3 = grilla[o3, ],
             errores_cv = err), paso("modelos"))
log("\nSiguiente: 11_controles.R")
cerrar_log(log)
