# =============================================================================
#  17_potencia.R
#  Hasta donde alcanza este muestreo: potencia, identificabilidad, sensibilidad
#  y diseno optimo.
#
#  PARA QUE SIRVE
#  Los pasos anteriores estiman y ponen a prueba. Este responde una pregunta
#  distinta y previa: con la geometria y el tamano de muestra que hay, un origen
#  DE VERDAD seria recuperable. Si la respuesta es no, ningun resultado positivo
#  del gradiente puede creerse, y ningun resultado negativo puede interpretarse
#  como ausencia de expansion.
#
#  POTENCIA. Se simula un gradiente real de intensidad conocida desde un origen
#  conocido, con las coordenadas y los tamanos de muestra reales, y se mide en
#  que fraccion de las simulaciones el estimador recupera ese origen a menos de
#  300 y de 600 km. Se recorre un rango de intensidades para ver desde que
#  efecto el diseno empieza a detectar.
#
#  IDENTIFICABILIDAD. El piso del metodo: el error mediano en km al recuperar un
#  origen conocido, y si la region compatible queda acotada. Un diseno puede
#  tener potencia alta para detectar QUE hay gradiente y aun asi no poder decir
#  DONDE esta la fuente.
#
#  SENSIBILIDAD. Cuanto se mueve el origen estimado al cambiar decisiones del
#  analisis: ponderar o no por tamano de muestra, exigir mas cepas por grupo,
#  usar la diversidad rarefaccionada en vez de la observada. Si el resultado
#  depende de esas decisiones, hay que declararlo.
#
#  DISENO OPTIMO. Donde convendria colectar la proxima campana. Para cada punto
#  candidato se mide cuanto se achicaria la region compatible si hubiera un grupo
#  ahi. Es la salida mas util para planificar terreno.
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
log <- nuevo_log("17_potencia"); log("=== 17 POTENCIA Y ALCANCE ===")
dv <- exigir_paso("diversidad", "04_diversidad.R")
gr <- exigir_paso("gradiente", "06_gradiente.R")

if (!isTRUE(gr$ok)) {
  log("06 no encontro gradiente. Sin base para medir potencia.")
  saveRDS(list(), paso("potencia")); cerrar_log(log)
} else {

div <- dv$div
ele <- div[div$elegible & !is.na(div$pi) & !is.na(div$lat) &
             div$n_cepas >= N_MIN_GRUPO_EST, ]
n <- nrow(ele)
la <- ele$lat; lo <- ele$lon; w0 <- ele$peso
grilla <- gr$grilla
log("Grupos: ", n, " | grilla: ", nrow(grilla), " puntos")
if (n < 6) { log("Menos de 6 grupos. No se puede medir potencia.")
  saveRDS(list(), paso("potencia")); cerrar_log(log); pocos <- TRUE } else pocos <- FALSE
if (!pocos) {

DG <- vapply(seq_len(n), function(j) dist_km(grilla$lat, grilla$lon, la[j], lo[j]),
             numeric(nrow(grilla)))

# Busca el origen que maximiza el ajuste, exigiendo pendiente negativa.
buscar <- function(y, ww, cols = seq_len(n)) {
  sw <- sum(ww); yc <- y - sum(ww * y) / sw
  D <- DG[, cols, drop = FALSE]; D <- D - as.vector(D %*% ww) / sw
  nu <- as.vector(D %*% (ww * yc))
  de <- sqrt(as.vector((D^2) %*% ww) * sum(ww * yc^2))
  r <- ifelse(de > 0, nu / de, NA_real_)
  r2 <- ifelse(!is.na(r) & r < 0, r^2, NA_real_)
  if (all(is.na(r2))) return(NULL)
  j <- which.max(r2)
  list(lat = grilla$lat[j], lon = grilla$lon[j], r2 = r2[j])
}

sd_pi <- sd(ele$pi, na.rm = TRUE)
med_pi <- mean(ele$pi, na.rm = TRUE)
# el ruido de cada grupo baja con la raiz de su muestra, como corresponde a una
# frecuencia estimada con n alelos
ruido <- sd_pi / sqrt(pmax(ele$n_cepas, 1)) * sqrt(median(ele$n_cepas))

# --- Potencia ----------------------------------------------------------------
set.seed(SEMILLA)
N_SIM <- if (RAPIDO) 40L else 200L
# origenes verdaderos de prueba: puntos de la grilla dentro del area muestreada
dentro <- which(grilla$lat >= min(la) & grilla$lat <= max(la) &
                grilla$lon >= min(lo) & grilla$lon <= max(lo))
if (!length(dentro)) dentro <- seq_len(nrow(grilla))
efectos <- c(0, 0.25, 0.5, 1, 2)
log("\nPotencia: ", N_SIM, " simulaciones por nivel de efecto")
filas <- list()
for (ef in efectos) {
  d300 <- d600 <- r2s <- err <- numeric(0)
  for (b in seq_len(N_SIM)) {
    g0 <- dentro[sample.int(length(dentro), 1)]
    d0 <- DG[g0, ]
    # gradiente decreciente de intensidad ef, mas ruido proporcional a 1/sqrt(n)
    y <- med_pi - ef * sd_pi * (d0 - mean(d0)) / (sd(d0) + 1e-9) + rnorm(n, 0, ruido)
    r <- buscar(y, w0)
    if (is.null(r)) next
    e <- dist_km(grilla$lat[g0], grilla$lon[g0], r$lat, r$lon)
    err <- c(err, e); r2s <- c(r2s, r$r2)
    d300 <- c(d300, e < 300); d600 <- c(d600, e < 600)
  }
  filas[[length(filas) + 1L]] <- data.frame(
    efecto = ef, n_sim = length(err),
    pot_300km = round(mean(d300), 3), pot_600km = round(mean(d600), 3),
    error_mediano_km = round(median(err)), r2_medio = round(mean(r2s), 4),
    stringsAsFactors = FALSE)
  log(sprintf("  efecto %.2f  ->  %.0f%% a menos de 300 km  |  %.0f%% a 600 km  |  error mediano %s km",
      ef, 100 * mean(d300), 100 * mean(d600), format(round(median(err)), big.mark = " ")))
}
pot <- do.call(rbind, filas)
write.table(pot, file.path(OUT, "17_potencia.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

# --- Identificabilidad -------------------------------------------------------
ref <- pot[pot$efecto == 1, ]
ident <- list(
  error_mediano_km = if (nrow(ref)) ref$error_mediano_km else NA_real_,
  punto_recuperable = if (nrow(ref)) ref$pot_600km >= 0.5 else NA,
  region_acotada = !is.na(gr$ext_lat) && max(gr$ext_lat, gr$ext_lon, na.rm = TRUE) <= 20,
  ext_lon_observada = round(gr$ext_lon, 2),
  ext_lat_observada = round(gr$ext_lat, 2),
  efecto_minimo_detectable = {
    k <- which(pot$pot_600km >= 0.5)
    if (length(k)) pot$efecto[min(k)] else NA_real_
  })
log("\nIdentificabilidad:")
log("  Error mediano al recuperar un origen conocido con efecto 1: ",
    format(ident$error_mediano_km, big.mark = " "), " km")
log("  Efecto minimo detectable (50% a 600 km): ", ident$efecto_minimo_detectable)
log("  Region compatible acotada: ", ident$region_acotada)
if (!isTRUE(ident$punto_recuperable))
  log("  ESTE MUESTREO NO PERMITE UBICAR UNA FUENTE aunque exista. Un resultado",
      " positivo del gradiente no seria creible, y uno negativo no prueba",
      " ausencia de expansion.")

# --- Sensibilidad ------------------------------------------------------------
log("\nSensibilidad a las decisiones del analisis:")
cfg <- list(
  list(nombre = "base", y = ele$pi, w = w0, idx = seq_len(n)),
  list(nombre = "sin ponderar", y = ele$pi, w = rep(1, n), idx = seq_len(n)),
  list(nombre = "pi rarefaccionado", y = ele$pi_rar, w = w0, idx = seq_len(n)),
  list(nombre = "n >= 5", y = ele$pi, w = w0, idx = which(ele$n_cepas >= 5)),
  list(nombre = "n >= 10", y = ele$pi, w = w0, idx = which(ele$n_cepas >= 10)))
base_r <- buscar(ele$pi, w0)
fs <- list()
for (cf in cfg) {
  i2 <- cf$idx
  if (length(i2) < 5 || all(is.na(cf$y[i2]))) next
  r <- buscar(cf$y[i2], cf$w[i2], cols = i2)
  if (is.null(r)) next
  fs[[length(fs) + 1L]] <- data.frame(config = cf$nombre, n_grupos = length(i2),
    lat = round(r$lat, 2), lon = round(r$lon, 2), r2 = round(r$r2, 4),
    km_del_base = round(dist_km(base_r$lat, base_r$lon, r$lat, r$lon)),
    stringsAsFactors = FALSE)
}
sens <- do.call(rbind, fs)
write.table(sens, file.path(OUT, "17_sensibilidad.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
for (i in seq_len(nrow(sens)))
  log(sprintf("  %-20s n=%3d  R2=%.3f  a %5s km del base",
      sens$config[i], sens$n_grupos[i], sens$r2[i],
      format(sens$km_del_base[i], big.mark = " ")))
mx <- max(sens$km_del_base, na.rm = TRUE)
if (mx > 1000) log("  El origen se mueve mas de 1000 km segun la decision. Declararlo.")

# --- Diseno optimo -----------------------------------------------------------
# Para cada punto candidato se agrega un grupo hipotetico ahi, con diversidad
# predicha por el gradiente ajustado, y se mide cuanto se achica la extension de
# la region compatible. Es donde conviene colectar la proxima campana.
log("\nDiseno optimo: donde colectar para achicar la region compatible")
# La grilla completa puede tener decenas de miles de puntos, y aca se recorre
# una vez por candidato y por replica de bootstrap. Para comparar candidatos
# entre si alcanza con una grilla gruesa: lo que interesa es cual reduce mas la
# region, no la coordenada exacta de cada replica. Sin este recorte el paso no
# termina con muchos grupos.
gr_sub <- if (nrow(grilla) > 4000L)
  sort(sample.int(nrow(grilla), 4000L)) else seq_len(nrow(grilla))
DGs <- DG[gr_sub, , drop = FALSE]
grs <- grilla[gr_sub, ]
log("  Grilla para el diseno: ", length(gr_sub), " de ", nrow(grilla), " puntos")

cand <- dentro[seq(1, length(dentro), length.out = min(40L, length(dentro)))]
d_base <- dist_km(base_r$lat, base_r$lon, la, lo)
fit <- lm(ele$pi ~ d_base, weights = w0)
B <- if (RAPIDO) 20L else 60L
ext_base <- max(gr$ext_lat, gr$ext_lon, na.rm = TRUE)
fs2 <- list()
for (g0 in cand) {
  dn <- dist_km(grilla$lat[g0], grilla$lon[g0], base_r$lat, base_r$lon)
  yn <- unname(coef(fit)[1] + coef(fit)[2] * dn)
  y2 <- c(ele$pi, yn); w2 <- c(w0, median(w0))
  DG2 <- cbind(DGs, dist_km(grs$lat, grs$lon, grilla$lat[g0], grilla$lon[g0]))
  set.seed(SEMILLA)
  pts <- matrix(NA_real_, B, 2)
  for (b in seq_len(B)) {
    s <- sample.int(n + 1L, n + 1L, replace = TRUE)
    if (length(unique(s)) < 5) next
    sw <- sum(w2[s]); yc <- y2[s] - sum(w2[s] * y2[s]) / sw
    Dm <- DG2[, s, drop = FALSE]; Dm <- Dm - as.vector(Dm %*% w2[s]) / sw
    nu <- as.vector(Dm %*% (w2[s] * yc))
    de <- sqrt(as.vector((Dm^2) %*% w2[s]) * sum(w2[s] * yc^2))
    r <- ifelse(de > 0, nu / de, NA_real_)
    r2 <- ifelse(!is.na(r) & r < 0, r^2, NA_real_)
    if (all(is.na(r2))) next
    j <- which.max(r2); pts[b, ] <- c(grs$lat[j], grs$lon[j])
  }
  ok <- stats::complete.cases(pts)
  if (sum(ok) < 10) next
  ext <- max(diff(quantile(pts[ok, 1], c(.025, .975))),
             diff(quantile(pts[ok, 2], c(.025, .975))))
  fs2[[length(fs2) + 1L]] <- data.frame(
    lat = grilla$lat[g0], lon = grilla$lon[g0],
    ext_resultante = round(ext, 2),
    reduccion = round(ext_base - ext, 2), stringsAsFactors = FALSE)
}
dis <- do.call(rbind, fs2)
if (!is.null(dis)) {
  dis <- dis[order(-dis$reduccion), ]
  write.table(dis, file.path(OUT, "17_diseno_optimo.tsv"), sep = "\t",
              row.names = FALSE, quote = FALSE)
  log("  Extension actual de la region: ", round(ext_base, 1), " grados")
  for (i in seq_len(min(6, nrow(dis))))
    log(sprintf("  %7.2f, %7.2f  ->  %.1f grados  (reduce %.1f)",
        dis$lat[i], dis$lon[i], dis$ext_resultante[i], dis$reduccion[i]))
  if (max(dis$reduccion, na.rm = TRUE) <= 0)
    log("  Ningun punto unico achica la region: el problema es la geometria")
    log("  global del muestreo, no un hueco puntual.")
}

saveRDS(list(potencia = pot, identificabilidad = ident, sensibilidad = sens,
             diseno_optimo = dis), paso("potencia"))
log("\nSiguiente: 12_validar.R")
cerrar_log(log)
}
}
