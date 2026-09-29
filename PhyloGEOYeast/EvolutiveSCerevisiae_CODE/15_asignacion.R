# =============================================================================
#  15_asignacion.R
#  Asignacion de cada cepa al grupo con el que comparte mas identidad genetica.
#
#  QUE HACE
#  Compara el genotipo de cada cepa contra las frecuencias alelicas de cada grupo
#  y se queda con el de mayor verosimilitud. La columna resultante NO dice donde
#  se colecto la cepa: dice con que grupo comparte mas identidad. Cuando las dos
#  cosas no coinciden, lo esperable es una cepa migrante, mal etiquetada o de
#  ancestria mezclada.
#
#  EL DETALLE QUE HACE HONESTO EL NUMERO
#  Al evaluar una cepa contra su propio grupo hay que restar antes sus propios
#  alelos de las frecuencias de ese grupo. Sin esa correccion la cepa se compara
#  consigo misma y la exactitud sale inflada, tanto mas cuanto mas chico es el
#  grupo. Es el error mas comun de este tipo de analisis.
#
#  El margen es la diferencia de log-verosimilitud entre el primer y el segundo
#  grupo. Un margen chico significa que la asignacion es un empate y no debe
#  interpretarse aunque sea correcta.
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
log <- nuevo_log("15_asignacion"); log("=== 15 ASIGNACION DE CEPAS ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")

GT <- v$GT
if (!is.null(GT) && nrow(GT) != nrow(v$ALT)) {
  log("Los genotipos no estan alineados con el panel: ", nrow(GT), " contra ",
      nrow(v$ALT), " filas. Se descartan.")
  GT <- NULL
}
if (is.null(GT)) {
  log("paso_variantes.rds no trae genotipos por cepa. Volve a correr 02_variantes.R.")
  saveRDS(list(asignacion = NULL, exactitud = NA_real_, n_grupos = 0),
          paso("asignacion"))
  cerrar_log(log)
  GT <- NULL
}
if (!is.null(GT)) {
gm <- v$grupo_de_muestra; if (is.null(gm)) gm <- d1$grupo_de_cepa[colnames(GT)]
ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos
usar <- which(v$n_cepas >= max(2L, N_MIN_GRUPO_EST - 1L))
gg <- grupos[usar]
log("Grupos candidatos: ", length(gg), " de ", length(grupos))
log("Cepas a asignar: ", ncol(GT))

# frecuencia alelica de cada grupo, acotada para que el logaritmo no explote
P <- (ALT[, usar, drop = FALSE] + .5) / (TOT[, usar, drop = FALSE] + 1)
P[!is.finite(P)] <- .5
lP <- base::log(P); lQ <- base::log(1 - P)   # base:: porque `log` es el registro

filas <- vector("list", ncol(GT))
for (j in seq_len(ncol(GT))) {
  g <- GT[, j]
  ok <- !is.na(g)
  if (!any(ok)) next
  gj <- gm[j]
  # dosis del alelo alternativo, 0 a 2, y del de referencia
  A2 <- g[ok]; R2 <- 2L - A2
  ll <- as.vector(crossprod(lP[ok, , drop = FALSE], A2) +
                  crossprod(lQ[ok, , drop = FALSE], R2))
  # correccion: al evaluar contra su propio grupo se le restan sus alelos
  k <- match(gj, gg)
  if (!is.na(k)) {
    a0 <- ALT[ok, usar[k]] - A2; t0 <- TOT[ok, usar[k]] - 2L
    p0 <- (pmax(a0, 0) + .5) / (pmax(t0, 0) + 1)
    ll[k] <- sum(A2 * base::log(p0) + R2 * base::log(1 - p0))
  }
  o <- order(-ll)
  filas[[j]] <- data.frame(cepa = colnames(GT)[j], lugar_real = gj,
    asignado = gg[o[1]], segundo = gg[o[2]],
    ll_asignado = round(ll[o[1]], 2), ll_segundo = round(ll[o[2]], 2),
    margen = round(ll[o[1]] - ll[o[2]], 2),
    correcto = identical(gg[o[1]], gj),
    n_cepas_origen = v$n_cepas[usar][match(gj, gg)],
    stringsAsFactors = FALSE)
}
asig <- do.call(rbind, filas)
write.table(asig, file.path(OUT, "15_asignacion.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

ev <- asig[!is.na(asig$lugar_real) & asig$lugar_real %in% gg, ]
exact <- mean(ev$correcto)
log("\nExactitud: ", round(100 * exact, 1), "% sobre ", nrow(ev), " cepas evaluables")
log("Azar esperable: ", round(100 / length(gg), 1), "%")
log("Margen mediano: ", round(median(ev$margen), 1),
    " | asignaciones con margen bajo 5: ", sum(ev$margen < 5))

por <- aggregate(correcto ~ lugar_real, ev, function(x) c(e = mean(x), n = length(x)))
por <- data.frame(lugar = por$lugar_real,
                  exactitud = round(por$correcto[, "e"], 4),
                  n = por$correcto[, "n"], stringsAsFactors = FALSE)
por <- por[order(por$exactitud), ]
write.table(por, file.path(OUT, "15_exactitud_por_grupo.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nGrupos peor asignados:")
for (i in seq_len(min(8, nrow(por))))
  log(sprintf("  %-30s %5.1f%%  n=%d", substr(por$lugar[i], 1, 30),
              100 * por$exactitud[i], por$n[i]))

saveRDS(list(asignacion = asig, por_grupo = por, exactitud = exact,
             n_grupos = length(gg)), paso("asignacion"))
log("\nSiguiente: 16_marcadores.R")
cerrar_log(log)
}
