# =============================================================================
#  11_controles.R
#  Controles negativos y pruebas de robustez.
#
#  Este paso es el que decide si el resultado se puede publicar. Todo lo
#  anterior estima; aca se pone a prueba.
#
#  CONTROL 1: NULO POR PERMUTACION DE LA GEOGRAFIA
#  Se dejan los genotipos intactos y se barajan las coordenadas entre grupos.
#  Bajo el nulo no hay relacion entre genetica y geografia, asi que cualquier
#  gradiente que aparezca es lo que el metodo produce por construccion. Se
#  guarda la distribucion nula de DOS cosas:
#    del R2, que es lo que la version anterior ya medía
#    de la UBICACION estimada, que es lo que faltaba
#  Si el punto observado cae dentro de la nube de puntos permutados, el
#  estimador esta fabricando origenes.
#
#  CONTROL 2: SIN EXPANSION, CON LA MISMA GEOMETRIA
#  Se simula pi bajo aislamiento por distancia puro sobre las coordenadas
#  reales y con los tamanos de muestra reales, sin ninguna fuente. Si el
#  estimador igual encuentra un origen nitido, el resultado no vale. Se simula
#  directamente sobre pi y no sobre genotipos: alcanza para la pregunta, que es
#  si la geometria del muestreo por si sola produce un maximo convincente.
#
#  CONTROL 3: DEJANDO CAMPANAS AFUERA
#  Si una sola colecta domina el resultado, hay que saberlo. Se saca cada valor
#  de la columna de origen de los datos y se rehace la estimacion.
#
#  CONTROL 4: ROBUSTEZ A WAHLUND
#  Se rehace la estimacion excluyendo los grupos que reunen mas de un linaje. Si
#  el origen se mantiene, la objecion de que pi esta inflado por mezcla queda
#  respondida con datos.
#
#  CONTROL 5: ESTRATO ECOLOGICO
#  Se rehace la estimacion por estrato de ecologia. NO se filtra antes de
#  correr: filtrar por ecologia a priori meteria la hipotesis en el analisis y
#  ademas la etiqueta deriva de la misma asignacion de linajes que se quiere
#  evaluar. Aca entra como sensibilidad, que es donde corresponde.
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
log <- nuevo_log("11_controles"); log("=== 11 CONTROLES ===")
d1 <- exigir_paso("datos", "01_datos.R")
dv <- exigir_paso("diversidad", "04_diversidad.R")
gr <- exigir_paso("gradiente", "06_gradiente.R")

if (!isTRUE(gr$ok)) {
  log("06 no encontro gradiente. Nada que controlar.")
  cerrar_log(log)
  detener("11: sin gradiente que controlar", 0L)
}

div <- dv$div
ele <- div[div$elegible & !is.na(div$pi) & !is.na(div$lat), ]
n <- nrow(ele)
la <- ele$lat; lo <- ele$lon; y <- ele$pi
w <- if (PONDERAR) ele$peso else rep(1, n)
grilla <- gr$grilla
DG <- vapply(seq_len(n), function(j) dist_km(grilla$lat, grilla$lon, la[j], lo[j]),
             numeric(nrow(grilla)))

ajustar <- function(yy, ww, cols = seq_len(n)) {
  sw <- sum(ww); yc <- yy - sum(ww * yy) / sw
  D <- DG[, cols, drop = FALSE]; D <- D - as.vector(D %*% ww) / sw
  num <- as.vector(D %*% (ww * yc))
  den <- sqrt(as.vector((D^2) %*% ww) * sum(ww * yc^2))
  r <- ifelse(den > 0, num / den, NA_real_)
  r2 <- ifelse(!is.na(r) & r < 0, r^2, NA_real_)
  if (all(is.na(r2))) return(list(r2 = NA_real_, lat = NA_real_, lon = NA_real_))
  j <- which.max(r2)
  list(r2 = r2[j], lat = grilla$lat[j], lon = grilla$lon[j])
}

obs <- ajustar(y, w)
log("Observado: R2 = ", round(obs$r2, 3), " en ", round(obs$lat, 2), ", ",
    round(obs$lon, 2))

# --- Control 1: permutacion de la geografia ---------------------------------
set.seed(SEMILLA)
log("\n[1] Nulo por permutacion de la geografia (", N_PERMUTA, " replicas)")
perm <- t(vapply(seq_len(N_PERMUTA), function(b) {
  o <- sample.int(n)
  r <- ajustar(y[o], w[o])
  c(r$r2, r$lat, r$lon)
}, numeric(3)))
ok <- is.finite(perm[, 1])
p_r2 <- (1 + sum(perm[ok, 1] >= obs$r2)) / (1 + sum(ok))
log("  R2 permutado: mediana ", round(median(perm[ok, 1]), 3),
    " | percentil 95 ", round(quantile(perm[ok, 1], 0.95), 3))
log("  p del R2 = ", signif(p_r2, 3))
d_perm <- dist_km(obs$lat, obs$lon, perm[ok, 2], perm[ok, 3])
log("  Distancia del punto observado a los puntos permutados: mediana ",
    round(median(d_perm)), " km")
frac_cerca <- mean(d_perm < 500)
log("  Fraccion de permutaciones que cae a menos de 500 km del observado: ",
    round(frac_cerca, 3))
if (p_r2 > 0.05) {
  log("  EL GRADIENTE NO SUPERA AL NULO. Un ajuste igual de bueno aparece")
  log("  barajando las coordenadas. No hay evidencia de estructura geografica.")
} else if (frac_cerca > 0.2) {
  log("  El R2 supera al nulo, pero la UBICACION no: la geometria del muestreo")
  log("  empuja el maximo hacia esa zona con o sin senal. Reportar region.")
}

# --- Control 2: simulacion sin expansion ------------------------------------
# pi bajo IBD puro: se construye una variable espacialmente autocorrelacionada
# con la estructura de covarianza exp(-d/rango), sin ninguna fuente. La media y
# la varianza se igualan a las observadas para que la comparacion sea justa.
log("\n[2] Simulacion sin expansion, misma geometria (200 replicas)")
DD <- matrix(0, n, n)
for (i in 1:n) for (j in 1:n) DD[i, j] <- dist_km(la[i], lo[i], la[j], lo[j])
rango <- median(DD[upper.tri(DD)])
Sig <- exp(-DD / rango)
L <- tryCatch(chol(Sig + diag(1e-6, n)), error = function(e) NULL)
sim_r2 <- rep(NA_real_, 200)
if (!is.null(L)) {
  for (b in 1:200) {
    z <- as.vector(t(L) %*% rnorm(n))
    yy <- mean(y) + sd(y) * (z - mean(z)) / sd(z)
    sim_r2[b] <- ajustar(yy, w)$r2
  }
  ok2 <- is.finite(sim_r2)
  p_sim <- (1 + sum(sim_r2[ok2] >= obs$r2)) / (1 + sum(ok2))
  log("  R2 bajo IBD sin expansion: mediana ", round(median(sim_r2[ok2]), 3),
      " | percentil 95 ", round(quantile(sim_r2[ok2], 0.95), 3))
  log("  p contra IBD simulado = ", signif(p_sim, 3))
  if (p_sim > 0.05) {
    log("  El ajuste observado es indistinguible del que produce aislamiento")
    log("  por distancia SIN expansion. El gradiente no prueba una fuente.")
  }
} else {
  p_sim <- NA_real_
  log("  No se pudo factorizar la matriz de covarianza. Control omitido.")
}

# --- Control 3: dejando campanas afuera --------------------------------------
log("\n[3] Dejando campanas afuera")
camp <- NULL
for (cl in c("Source", "Fuente", "Study", "Estudio")) {
  if (cl %in% names(d1$meta)) { camp <- cl; break }
}
tab_camp <- NULL
if (is.null(camp)) {
  log("  Sin columna de origen de los datos en la metadata. Control omitido.")
} else {
  cepa_camp <- setNames(d1$meta[[camp]], d1$meta$.CEPA)
  gr_camp <- split(d1$grupo_de_cepa, cepa_camp[names(d1$grupo_de_cepa)])
  filas <- list()
  for (cc in names(gr_camp)) {
    quitar <- unique(gr_camp[[cc]])
    idx <- which(!(ele$grupo %in% quitar))
    if (length(idx) < 5) next
    r <- ajustar(y[idx], w[idx], cols = idx)
    filas[[length(filas) + 1L]] <- data.frame(
      campana = cc, grupos_fuera = length(quitar), n_usados = length(idx),
      r2 = round(r$r2, 4), lat = round(r$lat, 2), lon = round(r$lon, 2),
      km_del_observado = round(dist_km(obs$lat, obs$lon, r$lat, r$lon)),
      stringsAsFactors = FALSE)
  }
  if (length(filas)) {
    tab_camp <- do.call(rbind, filas)
    tab_camp <- tab_camp[order(-tab_camp$km_del_observado), ]
    for (i in seq_len(nrow(tab_camp)))
      log(sprintf("  sin %-28s n=%3d  R2=%.3f  a %5.0f km del observado",
                  substr(tab_camp$campana[i], 1, 28), tab_camp$n_usados[i],
                  tab_camp$r2[i], tab_camp$km_del_observado[i]))
    if (max(tab_camp$km_del_observado, na.rm = TRUE) > 1000)
      log("  Al menos una campana mueve el origen mas de 1000 km. El resultado",
          " depende de una sola colecta.")
  }
}

# --- Control 4: robustez a Wahlund -------------------------------------------
log("\n[4] Robustez a la mezcla de linajes")
mez <- dv$grupos_mezclados
if (!length(mez)) {
  log("  Ningun grupo reune mas de un linaje. Control no aplica.")
  wah <- NULL
} else {
  idx <- which(!(ele$grupo %in% mez))
  log("  Grupos con un solo linaje: ", length(idx), " de ", n)
  if (length(idx) < 5) {
    log("  Quedan menos de 5 grupos. No se puede rehacer la estimacion.")
    wah <- NULL
  } else {
    wah <- ajustar(y[idx], w[idx], cols = idx)
    km <- dist_km(obs$lat, obs$lon, wah$lat, wah$lon)
    log("  Origen sin grupos mezclados: ", round(wah$lat, 2), ", ",
        round(wah$lon, 2), " | R2 = ", round(wah$r2, 3))
    log("  A ", round(km), " km del observado.")
    if (km > 1000)
      log("  Se mueve mucho: pi inflado por Wahlund SI estaba sosteniendo el",
          " resultado. Hay que reportarlo.")
    else
      log("  El origen se mantiene. La objecion de Wahlund queda respondida.")
  }
}

# --- Control 6: efecto de borde ----------------------------------------------
# Kemppainen, Schembri y Momigliano (2024, Mol Biol Evol 41:msae091) mostraron
# que en metapoblaciones EN EQUILIBRIO la deriva es mas fuerte en los bordes del
# rango, y eso produce clinas de diversidad y de psi indistinguibles de las de
# una expansion real. La tasa de falsos positivos es alta. Es la critica mas
# seria que existe contra este tipo de analisis y hay que responderla.
#
# Dos comprobaciones:
#   a) Si el origen estimado cae sobre el borde del area muestreada, el efecto
#      de borde es la explicacion mas simple y hay que declararlo.
#   b) Si la diversidad predice mejor la distancia al BORDE que la distancia al
#      origen estimado, entonces lo que se esta midiendo es el borde y no una
#      fuente. Es la prueba directa.
log("\n[6] Efecto de borde (Kemppainen et al. 2024)")
centro <- c(mean(range(la)), mean(range(lo)))
# distancia de cada grupo al borde del casco que envuelve al muestreo, aproximado
# por la distancia al punto mas lejano de la nube
d_borde <- vapply(seq_len(n), function(i)
  min(dist_km(la[i], lo[i], c(min(la), max(la), la[i], la[i]),
              c(lo[i], lo[i], min(lo), max(lo)))), numeric(1))
d_orig <- dist_km(obs$lat, obs$lon, la, lo)
r_borde <- suppressWarnings(cor(y, d_borde, use = "complete"))
r_orig  <- suppressWarnings(cor(y, d_orig,  use = "complete"))
log("  Correlacion de pi con la distancia al borde  : ", round(r_borde, 3))
log("  Correlacion de pi con la distancia al origen : ", round(r_orig, 3))
en_borde_obs <- min(dist_km(obs$lat, obs$lon,
                            c(min(la), max(la), obs$lat, obs$lat),
                            c(obs$lon, obs$lon, min(lo), max(lo)))) < 100
log("  El origen estimado cae sobre el borde del muestreo: ", en_borde_obs)
if (abs(r_borde) >= abs(r_orig)) {
  log("  LA DISTANCIA AL BORDE EXPLICA LA DIVERSIDAD IGUAL O MEJOR que la")
  log("  distancia al origen. El patron es compatible con efecto de borde en una")
  log("  metapoblacion en equilibrio, sin expansion. No se puede afirmar origen.")
} else {
  log("  La distancia al origen explica mejor que la distancia al borde: el")
  log("  patron no se reduce a efecto de borde.")
}
borde <- list(r_borde = r_borde, r_origen = r_orig, origen_en_borde = en_borde_obs,
              domina_borde = abs(r_borde) >= abs(r_orig))

# --- Control 5: por estrato ecologico ----------------------------------------
log("\n[5] Por estrato ecologico")
tab_ecol <- NULL
if (all(is.na(d1$meta$.ECOL))) {
  log("  Sin columna de ecologia. Control omitido.")
} else {
  ecol_gr <- tapply(d1$meta$.ECOL, d1$meta$.GRUPO,
                    function(z) names(sort(table(z), decreasing = TRUE))[1])
  e_de <- ecol_gr[ele$grupo]
  tb <- sort(table(e_de), decreasing = TRUE)
  filas <- list()
  for (ee in names(tb)[tb >= 5]) {
    idx <- which(e_de == ee)
    r <- ajustar(y[idx], w[idx], cols = idx)
    filas[[length(filas) + 1L]] <- data.frame(
      estrato = ee, n_grupos = length(idx), r2 = round(r$r2, 4),
      lat = round(r$lat, 2), lon = round(r$lon, 2),
      km_del_observado = round(dist_km(obs$lat, obs$lon, r$lat, r$lon)),
      stringsAsFactors = FALSE)
  }
  if (length(filas)) {
    tab_ecol <- do.call(rbind, filas)
    for (i in seq_len(nrow(tab_ecol)))
      log(sprintf("  %-22s %3d grupos  R2=%.3f  a %5.0f km del observado",
                  substr(tab_ecol$estrato[i], 1, 22), tab_ecol$n_grupos[i],
                  tab_ecol$r2[i], tab_ecol$km_del_observado[i]))
  } else log("  Ningun estrato con al menos 5 grupos.")
}

saveRDS(list(observado = obs, permutacion = perm, p_r2 = p_r2, borde = borde,
             frac_cerca = frac_cerca, sim_r2 = sim_r2,
             campanas = tab_camp, wahlund = wah, ecologia = tab_ecol),
        paso("controles"))
if (!is.null(tab_camp)) write.table(tab_camp, file.path(OUT, "11_campanas.tsv"),
                                    sep = "\t", row.names = FALSE, quote = FALSE)
log("\nSiguiente: 12_validar.R")
cerrar_log(log)
