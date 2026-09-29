# =============================================================================
#  06_gradiente.R
#  Origen por caida de la diversidad con la distancia.
#
#  IDEA
#  Bajo expansion con fundadores en serie, cada salto pierde diversidad, asi que
#  pi cae de forma ordenada al alejarse de la fuente. Se recorre una grilla de
#  origenes candidatos y se busca el punto que maximiza el R2 de esa caida,
#  exigiendo pendiente negativa.
#
#  LO QUE ESTE PASO NO PUEDE HACER SOLO
#  Un ajuste que maximiza R2 sobre una grilla SIEMPRE devuelve un maximo. Que
#  exista un maximo no prueba que haya habido expansion: aislamiento por
#  distancia sin expansion, o muestreo asimetrico, producen gradientes
#  parecidos. Por eso el resultado de aca no es una conclusion hasta que
#  10_modelos.R lo compare contra modelos alternativos y 11_controles.R lo
#  contraste con el nulo por permutacion de la geografia.
#
#  INCERTIDUMBRE, EN DOS NIVELES
#  Sobre bloques del genoma: recalcula pi dejando fuera ventanas y rehace la
#    busqueda. Responde si el origen depende de que parte del genoma se use.
#  Sobre grupos: remuestrea grupos con reemplazo. Responde si depende de que
#    sitios entraron.
#  La nube de puntos de las dos cosas es la region de confianza, y su tamano es
#  parte del resultado: cuando abarca decenas de grados, el punto no es
#  identificable y hay que decirlo en vez de reportar una coordenada.
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
log <- nuevo_log("06_gradiente"); log("=== 06 ORIGEN POR GRADIENTE ===")
v  <- exigir_paso("variantes", "02_variantes.R")
dv <- exigir_paso("diversidad", "04_diversidad.R")

div <- dv$div
# El mismo umbral de cepas que usan el arbol y los tiempos. Un grupo de una o
# dos cepas es un punto influyente construido sobre ruido: en el gradiente
# arrastra el maximo, y no tiene sentido excluirlo de un paso y admitirlo en
# otro. La corrida anterior lo dejaba entrar aca y en psi, y por eso el ranking
# quedaba encabezado por grupos de n = 1.
ele <- div[div$elegible & !is.na(div$pi) & !is.na(div$lat) &
             div$n_cepas >= N_MIN_GRUPO_EST, ]
chicos <- sum(div$elegible & !is.na(div$pi) & div$n_cepas < N_MIN_GRUPO_EST)
log("Grupos en la estimacion: ", nrow(ele), " de ", nrow(div),
    " | cepas: ", sum(ele$n_cepas), " de ", sum(div$n_cepas))
if (chicos) log("  Excluidos por n < ", N_MIN_GRUPO_EST, ": ", chicos, " grupos")
if (nrow(ele) < 4) stop("Menos de 4 grupos con pi y coordenada.", call. = FALSE)

la <- ele$lat; lo <- ele$lon
w  <- if (PONDERAR) ele$peso else rep(1, nrow(ele))

grilla <- expand.grid(
  lat = seq(min(la) - GRILLA_MARGEN, max(la) + GRILLA_MARGEN, by = GRILLA_PASO),
  lon = seq(min(lo) - GRILLA_MARGEN, max(lo) + GRILLA_MARGEN, by = GRILLA_PASO))
log("Grilla: ", nrow(grilla), " puntos, paso ", GRILLA_PASO, " grados")
DG <- vapply(seq_along(la), function(j) dist_km(grilla$lat, grilla$lon, la[j], lo[j]),
             numeric(nrow(grilla)))

# R2 ponderado vectorizado sobre toda la grilla, exigiendo pendiente negativa.
r2_grilla <- function(y, ww, cols = seq_along(la)) {
  sw <- sum(ww); yc <- y - sum(ww * y) / sw
  D <- DG[, cols, drop = FALSE]; D <- D - as.vector(D %*% ww) / sw
  num <- as.vector(D %*% (ww * yc))
  den <- sqrt(as.vector((D^2) %*% ww) * sum(ww * yc^2))
  r <- ifelse(den > 0, num / den, NA_real_)
  ifelse(!is.na(r) & r < 0, r^2, NA_real_)
}

r2 <- r2_grilla(ele$pi, w)
if (all(is.na(r2))) {
  log("Ningun punto de la grilla da gradiente decreciente.")
  log("No hay senal compatible con expansion desde un origen unico.")
  saveRDS(list(ok = FALSE), paso("gradiente")); cerrar_log(log)
  detener("06: ningun punto de la grilla da gradiente decreciente", 0L)
}
mejor <- which.max(r2)
o_lat <- grilla$lat[mejor]; o_lon <- grilla$lon[mejor]
dd <- dist_km(o_lat, o_lon, la, lo)
fit <- lm(ele$pi ~ dd, weights = w)
log("\nORIGEN POR GRADIENTE: ", round(o_lat, 2), ", ", round(o_lon, 2))
log("R2 = ", round(r2[mejor], 3), " | pendiente = ", signif(coef(fit)[2], 3),
    " pi/km | p de la regresion = ", signif(summary(fit)$coefficients[2, 4], 3))
log("  El p de la regresion NO es la prueba de que exista un origen: la grilla")
log("  ya eligio el punto que maximiza el ajuste. La prueba esta en 11.")

# --- Incertidumbre sobre bloques del genoma ----------------------------------
kcol <- match(ele$grupo, v$grupos)
reps <- replicas_bloque(v$bloque, B = min(N_BOOTSTRAP, 200L))
log("\nBootstrap de bloques: ", length(reps), " replicas")
bs_gen <- t(vapply(reps, function(idx) {
  pb <- pi_por_grupo(v$ALT, v$TOT, idx)[kcol]
  rb <- r2_grilla(pb, w)
  if (all(is.na(rb))) return(c(NA_real_, NA_real_))
  j <- which.max(rb); c(grilla$lat[j], grilla$lon[j])
}, numeric(2)))
val <- stats::complete.cases(bs_gen)
log("  Replicas validas: ", sum(val), " de ", nrow(bs_gen))
if (sum(val) > 10) {
  log("  Latitud  IC95: ", paste(round(quantile(bs_gen[val, 1], c(.025, .975)), 2), collapse = " a "))
  log("  Longitud IC95: ", paste(round(quantile(bs_gen[val, 2], c(.025, .975)), 2), collapse = " a "))
}

# --- Incertidumbre sobre grupos ----------------------------------------------
set.seed(SEMILLA)
bs_gr <- t(vapply(seq_len(N_BOOTSTRAP), function(b) {
  s <- sample.int(nrow(ele), nrow(ele), replace = TRUE)
  if (length(unique(s)) < 4) return(c(NA_real_, NA_real_))
  rb <- r2_grilla(ele$pi[s], w[s], cols = s)
  if (all(is.na(rb))) return(c(NA_real_, NA_real_))
  j <- which.max(rb); c(grilla$lat[j], grilla$lon[j])
}, numeric(2)))
val2 <- stats::complete.cases(bs_gr)
log("\nBootstrap sobre grupos: ", sum(val2), " replicas validas de ", N_BOOTSTRAP)
ext_lat <- ext_lon <- NA_real_
if (sum(val2) > 10) {
  ql <- quantile(bs_gr[val2, 1], c(.025, .975)); qo <- quantile(bs_gr[val2, 2], c(.025, .975))
  ext_lat <- diff(ql); ext_lon <- diff(qo)
  log("  Latitud  IC95: ", paste(round(ql, 2), collapse = " a "), "  (", round(ext_lat, 1), " grados)")
  log("  Longitud IC95: ", paste(round(qo, 2), collapse = " a "), "  (", round(ext_lon, 1), " grados)")
  if (max(ext_lat, ext_lon, na.rm = TRUE) > 20) {
    log("  La region compatible abarca mas de 20 grados. El punto NO es")
    log("  identificable con este muestreo. Reportar la region, no la coordenada.")
  }
}

# --- Superficie para el mapa -------------------------------------------------
sup <- data.frame(lat = grilla$lat, lon = grilla$lon, r2 = round(r2, 5))
write.table(sup[!is.na(sup$r2), ], file.path(OUT, "06_superficie.tsv"),
            sep = "\t", row.names = FALSE, quote = FALSE)

saveRDS(list(ok = TRUE, lat = o_lat, lon = o_lon, r2 = r2[mejor],
             pendiente = unname(coef(fit)[2]),
             grilla = grilla, r2_grilla = r2,
             bs_genoma = bs_gen, bs_grupos = bs_gr,
             ext_lat = ext_lat, ext_lon = ext_lon,
             grupos = ele$grupo, pi = ele$pi, peso = w),
        paso("gradiente"))
log("\nSiguiente: 07_psi.R")
cerrar_log(log)
