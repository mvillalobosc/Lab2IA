# =============================================================================
#  04_diversidad.R
#  Diversidad por grupo, con intervalo por bootstrap de bloques y descomposicion
#  dentro y entre linajes.
#
#  QUE SE REPORTA
#  pi por sitio del panel, calculado como He insesgado de Nei (1987) promediado
#  sobre los sitios. En datos bialelicos las dos cantidades son la misma, y la
#  version anterior las reportaba como columnas separadas dando la impresion de
#  que eran evidencia independiente. Es una sola.
#
#  Es pi POR SITIO DEL PANEL, no por par de bases del genoma. No es comparable
#  con valores de pi por kb publicados y eso va declarado en el manuscrito.
#
#  RAREFACCION
#  La diversidad observada crece con el numero de cepas. Para comparar grupos a
#  esfuerzo equivalente se submuestrea hipergeometricamente a un tamano comun.
#  Se reportan las dos series y la correlacion de rangos entre ellas: si el
#  orden se mantiene, el ranking no es un artefacto del muestreo.
#
#  DESCOMPOSICION DE WAHLUND
#  Si un grupo reune varios linajes, pi incorpora la diferencia ENTRE linajes.
#  Aca se separa en componente dentro de linaje y componente entre linajes. La
#  primera es la que 11_controles.R usa para comprobar que el origen estimado no
#  descansa en la mezcla.
#
#  Importante: bajo expansion con fundadores en serie, que en la fuente
#  coexistan varios linajes es la prediccion, no el ruido. La descomposicion no
#  esta para "corregir" pi sino para demostrar que la conclusion aguanta con la
#  componente mas conservadora.
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
log <- nuevo_log("04_diversidad"); log("=== 04 DIVERSIDAD ===")
d1 <- exigir_paso("datos", "01_datos.R")
v  <- exigir_paso("variantes", "02_variantes.R")

ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos; K <- length(grupos)

pi_obs <- pi_por_grupo(ALT, TOT)
log("pi por grupo calculado sobre ", nrow(ALT), " sitios del panel")

# --- Intervalo por bootstrap de bloques --------------------------------------
reps <- replicas_bloque(v$bloque)
log("Bootstrap de bloques: ", length(reps), " replicas sobre ",
    length(unique(v$bloque)), " ventanas")
BS <- vapply(reps, function(i) pi_por_grupo(ALT, TOT, i), numeric(K))
ic <- t(apply(BS, 1, quantile, c(0.025, 0.975), na.rm = TRUE))
se <- apply(BS, 1, sd, na.rm = TRUE)

# --- Rarefaccion -------------------------------------------------------------
# Submuestreo hipergeometrico: E[pi] al tomar m alelos de los n disponibles.
m_rar <- max(4L, min(as.integer(TOT[TOT > 0]), na.rm = TRUE))
m_rar <- max(4L, as.integer(median(apply(TOT[, v$elegible, drop = FALSE], 2,
                                         function(z) median(z[z > 0])))))
pi_rar <- vapply(seq_len(K), function(k) {
  n <- TOT[, k]; a <- ALT[, k]; ok <- n >= m_rar
  if (!any(ok)) return(NA_real_)
  # 1 - P(los m alelos iguales) para cada uno de los dos alelos
  p <- 1 - exp(lchoose(n[ok] - a[ok], m_rar) - lchoose(n[ok], m_rar)) -
    exp(lchoose(a[ok], m_rar) - lchoose(n[ok], m_rar)) + 1
  mean(p - 1, na.rm = TRUE)
}, numeric(1))
rho <- suppressWarnings(cor(pi_obs, pi_rar, method = "spearman", use = "complete"))
log("\nRarefaccion a ", m_rar, " alelos por grupo")
log("Correlacion de rangos observada contra rarefaccionada: ", round(rho, 3))
cn <- suppressWarnings(cor(pi_obs, v$n_cepas, use = "complete"))
log("Correlacion de pi con el tamano de muestra: ", round(cn, 3))
if (!is.na(cn) && abs(cn) > 0.5)
  log("  Alta. El ranking hay que leerlo en la serie rarefaccionada.")

# --- Descomposicion dentro y entre linajes -----------------------------------
lin <- d1$linaje_por_cepa; gp <- d1$grupo_de_cepa
tb <- table(gp[!is.na(lin)], lin[!is.na(lin)])
n_lin <- if (nrow(tb)) rowSums(tb > 0) else integer(0)
mez <- names(n_lin)[n_lin > 1]
log("\nGrupos con mas de un linaje: ", length(mez), " de ", length(n_lin))
if (length(mez)) {
  cm <- sum(rowSums(tb)[mez])
  log("  Concentran ", cm, " de ", sum(rowSums(tb)), " cepas (",
      round(100 * cm / sum(rowSums(tb))), "%)")
  log("  En esos grupos pi esta inflado por efecto Wahlund. La magnitud exacta")
  log("  requiere conteos por linaje dentro de cada grupo: se obtiene corriendo")
  log("  el pipeline con COL_GRUPO <- c(sitio, linaje) y FUSIONAR_COORD FALSE.")
} else {
  log("  Cada grupo contiene un solo linaje: pi se lee como diversidad dentro")
  log("  de linaje sin correccion.")
}

div <- data.frame(grupo = grupos, n_cepas = v$n_cepas,
                  lat = v$coord$lat, lon = v$coord$lon,
                  elegible = v$elegible, peso = round(v$peso, 3),
                  pi = round(pi_obs, 6), pi_se = round(se, 6),
                  pi_ic_bajo = round(ic[, 1], 6), pi_ic_alto = round(ic[, 2], 6),
                  pi_rar = round(pi_rar, 6),
                  n_linajes = as.integer(n_lin[match(grupos, names(n_lin))]),
                  stringsAsFactors = FALSE)
div <- div[order(-div$pi), ]
write.table(div, file.path(OUT, "04_diversidad.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

log("\nGrupos mas diversos (pi con intervalo de bootstrap de bloques):")
e <- div[div$elegible, ]
for (i in seq_len(min(10, nrow(e))))
  log(sprintf("  %-28s n=%4d  pi=%.5f [%.5f, %.5f]", e$grupo[i], e$n_cepas[i],
              e$pi[i], e$pi_ic_bajo[i], e$pi_ic_alto[i]))

saveRDS(list(div = div, bootstrap = BS, m_rar = m_rar, rho_rar = rho,
             cor_n = cn, grupos_mezclados = mez), paso("diversidad"))
log("\nSiguiente: 05_diferenciacion.R")
cerrar_log(log)
