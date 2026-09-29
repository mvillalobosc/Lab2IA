# =============================================================================
#  03_diagnostico.R
#  Condiciones previas. Lo que este paso reporta decide que se puede afirmar
#  despues, asi que corre antes de cualquier estimacion.
#
#  CUATRO COMPROBACIONES
#  1. Espectro de frecuencias. Si la cola de alelos raros no existe, el VCF vino
#     filtrado por MAF aguas arriba y la senal de expansion esta amputada. Es la
#     limitacion mas seria que puede tener este analisis y hay que declararla.
#  2. Geometria del muestreo. Si los sitios se alinean en una franja, muchos
#     origenes distintos encajan igual de bien y el punto no es identificable.
#     Se mide con la razon de los ejes principales de las coordenadas.
#  3. Cobertura del rango. La inferencia solo puede senalar lugares donde
#     alguien colecto. Lo no muestreado no queda descartado, queda sin evaluar.
#  4. Clones. Cepas casi identicas de la misma campana no son observaciones
#     independientes: inflan la diversidad local y la diferenciacion.
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
log <- nuevo_log("03_diagnostico"); log("=== 03 DIAGNOSTICO ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")

ALT <- v$ALT; TOT <- v$TOT; K <- ncol(ALT)
log("SNP en el panel estricto: ", nrow(ALT), " | grupos: ", K)

# --- 1. Espectro de frecuencias ---------------------------------------------
espectro <- function(A, T2, etiqueta) {
  f <- rowSums(A) / pmax(rowSums(T2), 1)
  maf <- pmin(f, 1 - f)
  n <- length(maf)
  log("\nEspectro de frecuencias, ", etiqueta, " (", n, " SNP):")
  for (u in c(0.01, 0.02, 0.05, 0.10))
    log(sprintf("  MAF < %.2f : %7d  (%.1f%%)", u, sum(maf < u), 100 * mean(maf < u)))
  mean(maf < 0.02)
}
frac_raros <- espectro(ALT, TOT, "panel estricto")
if (!is.null(v$ALT_A)) frac_raros <- espectro(v$ALT_A, v$TOT_A, "panel amplio")

amputado <- frac_raros < 0.05
if (amputado) {
  log("\n  LIMITACION DURA: casi no hay alelos raros.")
  log("  El VCF de entrada ya venia filtrado por frecuencia, asi que bajar")
  log("  MAF_AMPLIO no los recupera. Consecuencias concretas:")
  log("    - los alelos privados no son utilizables como linea de evidencia")
  log("    - psi pierde la parte del espectro donde el efecto fundador serial")
  log("      deja su firma mas clara")
  log("  Para habilitarlas hace falta volver al VCF sin filtrar.")
}

# --- 2. Geometria del muestreo ----------------------------------------------
ele <- which(v$elegible & !is.na(v$coord$lat))
la <- v$coord$lat[ele]; lo <- v$coord$lon[ele]
log("\nGeometria del muestreo sobre ", length(ele), " grupos elegibles:")
log("  Latitud  ", round(min(la), 2), " a ", round(max(la), 2),
    " | Longitud ", round(min(lo), 2), " a ", round(max(lo), 2))
if (length(ele) >= 3) {
  xy <- cbind(lo * cos(mean(la) * pi / 180), la) * 111
  ev <- eigen(cov(xy))$values
  razon <- sqrt(max(ev) / max(min(ev), 1e-9))
  log("  Razon de ejes principales: ", round(razon, 2))
  if (razon > 3) {
    log("  El muestreo es alargado. Sobre el eje largo la posicion se resuelve")
    log("  bien, sobre el corto no: la region compatible va a salir estirada y")
    log("  el punto puede no ser identificable. Eso no es un defecto del")
    log("  estimador, es la geometria de lo que se colecto.")
  }
}

# --- 3. Cobertura del rango --------------------------------------------------
if (COL_CONT %in% names(d1$meta)) {
  tc <- table(d1$meta[[COL_CONT]])
  log("\nCepas por continente: ", paste(names(tc), tc, sep = "=", collapse = ", "))
  log("  Un continente sin muestreo no queda descartado como origen, queda")
  log("  SIN EVALUAR. Esa distincion va en el texto del manuscrito.")
}

# --- 4. Clones ---------------------------------------------------------------
# Se mide sobre las frecuencias por grupo, que es lo que hay tras agregar. Un
# grupo con diversidad casi nula y varias cepas es candidato a estar formado por
# clones. La deteccion cepa a cepa exige genotipos individuales.
pi_g <- pi_por_grupo(ALT, TOT)
sosp <- which(v$n_cepas >= 3 & pi_g < quantile(pi_g, 0.05, na.rm = TRUE))
log("\nGrupos con n >= 3 y diversidad en el 5% mas bajo: ", length(sosp))
if (length(sosp)) {
  for (i in head(sosp[order(pi_g[sosp])], 6))
    log(sprintf("  %-28s n=%3d  pi=%.5f", v$grupos[i], v$n_cepas[i], pi_g[i]))
  log("  Candidatos a estar formados por clones o por un cuello de botella")
  log("  fuerte. Distinguirlos exige los genotipos individuales.")
}

saveRDS(list(frac_raros = frac_raros, amputado = amputado,
             pi_grupo = pi_g, sospechosos = v$grupos[sosp]),
        paso("diagnostico"))
log("\nSiguiente: 04_diversidad.R")
cerrar_log(log)
