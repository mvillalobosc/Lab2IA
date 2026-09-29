# =============================================================================
#  09_tiempos.R
#  Orden de divergencia entre grupos, en unidades de deriva.
#
#  QUE SE REPORTA COMO RESULTADO PRIMARIO
#  Tiempo en unidades de deriva. Bajo deriva pura FST = 1 - exp(-t/(2Ne)), de
#  modo que t/(2Ne) = -log(1-FST). Es monotono en FST pero con la escala
#  correcta: un FST de 0,9 no es el doble de antiguo que 0,45, es mucho mas.
#
#  POR QUE LOS ANOS NO SON EL RESULTADO PRIMARIO
#  Convertir deriva a anos exige mu, generaciones por ano y Ne. Los tres tienen
#  incertidumbre y se multiplican. En la version anterior el rango iba de 1e5 a
#  9e8 anos: eso no es una estimacion con incertidumbre, es la senal de que no
#  hay modelo demografico abajo. Aca los anos se reportan como COTA, con el
#  rango completo visible, y nunca como valor central.
#
#  SOPORTE DEL ORDEN
#  Bootstrap de bloques sobre la matriz de FST, rehaciendo el agrupamiento en
#  cada replica. El soporte de un evento es la fraccion de replicas en las que
#  ese par de conjuntos se separa en el mismo lugar del orden.
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
log <- nuevo_log("09_tiempos"); log("=== 09 TIEMPOS Y ORDEN DE DIVERGENCIA ===")
v  <- exigir_paso("variantes", "02_variantes.R")
df <- exigir_paso("diferenciacion", "05_diferenciacion.R")
dv <- exigir_paso("diversidad", "04_diversidad.R")

usar <- which(v$n_cepas >= N_MIN_ARBOL)
gg <- v$grupos[usar]
log("Grupos: ", length(gg), " (umbral n >= ", N_MIN_ARBOL, ")")

deriva <- function(FST) {
  t <- -base::log(1 - pmin(FST, 0.999))
  t[!is.finite(t)] <- NA
  t
}

# UPGMA sobre el tiempo de deriva. Es ultrametrico, asi que la altura de cada
# nodo es directamente comparable y ordenable en el tiempo, que es justamente lo
# que se quiere leer.
upgma <- function(D, et) {
  n <- nrow(D); grupos <- lapply(seq_len(n), function(i) i)
  act <- seq_len(n); ev <- list()
  dist <- function(a, b) mean(D[grupos[[a]], grupos[[b]]], na.rm = TRUE)
  while (length(act) > 1) {
    mi <- Inf; ma <- 1; mb <- 2
    for (x in 1:(length(act) - 1)) for (y in (x + 1):length(act)) {
      dd <- dist(act[x], act[y])
      if (is.finite(dd) && dd < mi) { mi <- dd; ma <- x; mb <- y }
    }
    A <- act[ma]; B <- act[mb]
    ev[[length(ev) + 1L]] <- list(altura = mi, a = et[grupos[[A]]], b = et[grupos[[B]]])
    grupos[[A]] <- c(grupos[[A]], grupos[[B]])
    act <- act[-mb]
  }
  ev
}

TD <- deriva(df$FST[gg, gg])
ev <- upgma(TD, gg)
ord <- order(vapply(ev, function(e) -e$altura, numeric(1)))
ev <- ev[ord]
log("Eventos de divergencia: ", length(ev))

# --- Soporte del orden por bootstrap de bloques ------------------------------
# Mismo esquema que en 08: el numerador y el denominador de Hudson se acumulan
# una vez por bloque y cada replica es una suma de bloques, no un recalculo
# sobre los genotipos.
ALT <- v$ALT[, match(gg, v$grupos), drop = FALSE]
TOT <- v$TOT[, match(gg, v$grupos), drop = FALSE]
K2 <- ncol(ALT)
ut2 <- which(upper.tri(matrix(0, K2, K2)))
ib <- split(seq_len(nrow(ALT)), v$bloque)
nb <- length(ib)

NUM <- DEN <- matrix(0, nb, length(ut2))
for (b in seq_len(nb)) {
  k <- ib[[b]]
  Ab <- ALT[k, , drop = FALSE]; Tb <- TOT[k, , drop = FALSE]
  Vb <- (Tb >= 1) * 1
  fb <- Ab / pmax(Tb, 1)
  Pb <- fb * Vb; Qb <- (1 - fb) * Vb
  Cb <- (fb * (1 - fb) / (pmax(Tb, 2) - 1)) * Vb
  P2V <- crossprod(Pb * Pb * Vb, Vb); CV <- crossprod(Cb, Vb)
  NUM[b, ] <- ((P2V + t(P2V) - 2 * crossprod(Pb)) - (CV + t(CV)))[ut2]
  DEN[b, ] <- (crossprod(Pb, Qb) + t(crossprod(Pb, Qb)))[ut2]
}
log("Bloques para el soporte: ", nb, " | pares: ", length(ut2))

# Identidad de un evento: el par de conjuntos de grupos que se separan. Sirve
# para contar en cuantas replicas reaparece el mismo evento observado.
clave <- function(e) paste(paste(sort(e$a), collapse = ","), "|",
                           paste(sort(e$b), collapse = ","))
obs_claves <- vapply(ev, clave, character(1))

fst_de_bloques <- function(s) {
  num <- colSums(NUM[s, , drop = FALSE]); den <- colSums(DEN[s, , drop = FALSE])
  f <- ifelse(den > 0, pmax(0, num / den), NA_real_)
  M <- matrix(NA_real_, K2, K2, dimnames = list(gg, gg))
  M[ut2] <- f; M[lower.tri(M)] <- t(M)[lower.tri(M)]
  M
}

set.seed(SEMILLA)
B <- min(N_BOOTSTRAP, 200L)
log("Bootstrap de bloques: ", B, " replicas (suma de bloques, sin recalcular)")
cuenta <- setNames(integer(length(obs_claves)), obs_claves)
alturas <- matrix(NA_real_, length(ev), B)
val <- 0L
for (b in seq_len(B)) {
  Mb <- tryCatch(fst_de_bloques(sample.int(nb, nb, replace = TRUE)),
                 error = function(e) NULL)
  if (is.null(Mb)) next
  evb <- tryCatch(upgma(deriva(Mb), gg), error = function(e) NULL)
  if (is.null(evb)) next
  val <- val + 1L
  cb <- vapply(evb, clave, character(1))
  hit <- intersect(obs_claves, cb)
  cuenta[hit] <- cuenta[hit] + 1L
  m <- match(obs_claves, cb)
  alturas[, b] <- vapply(seq_along(m), function(i)
    if (is.na(m[i])) NA_real_ else evb[[m[i]]]$altura, numeric(1))
}
sop <- if (val > 0) cuenta / val else cuenta * NA
log("Replicas validas: ", val)

ic <- t(apply(alturas, 1, quantile, c(0.025, 0.975), na.rm = TRUE))

# --- Cota temporal, declarada como cota --------------------------------------
# Ne se estima de theta = 4*Ne*mu con theta tomado como la mediana de pi entre
# los grupos con muestra suficiente. Cada supuesto entra por separado para que
# el rango final se pueda auditar.
# pi de 04 esta medido POR SITIO DEL PANEL. theta se define POR PAR DE BASES.
# Usar uno por el otro infla Ne en varios ordenes de magnitud, que es lo que
# pasaba antes: daba 2.3e8 para levadura. La conversion multiplica por la
# densidad de sitios del panel en el genoma llamable.
#
# El panel estricto esta filtrado por MAF y adelgazado por distancia, asi que
# subestima la densidad real de variantes. Se usa el panel amplio cuando existe,
# corrigiendo por el submuestreo aleatorio con que se construyo.
pig <- dv$div$pi[dv$div$elegible & dv$div$n_cepas >= 10]
pi_panel <- if (length(pig)) median(pig, na.rm = TRUE) else median(dv$div$pi, na.rm = TRUE)
if (!is.null(v$ALT_A)) {
  n_sitios <- nrow(v$ALT_A) / max(FRAC_AMPLIO, 1e-9)
  fuente <- paste0("panel amplio, ", nrow(v$ALT_A), " sitios / ", FRAC_AMPLIO)
} else {
  n_sitios <- nrow(v$ALT)
  fuente <- paste0("panel estricto, ", nrow(v$ALT), " sitios (subestima)")
}
densidad <- n_sitios / LARGO_GENOMA
theta <- pi_panel * densidad
Ne_ref <- theta / (4 * MU_REF)
log("\nCalibracion temporal, declarada como cota:")
log("  pi por sitio del panel = ", signif(pi_panel, 4))
log("  sitios variables       = ", format(round(n_sitios), big.mark = " "),
    " (", fuente, ")")
log("  genoma llamable        = ", format(LARGO_GENOMA, big.mark = " "), " pb")
log("  theta por par de bases = ", signif(theta, 4))
log("  Ne de referencia       = ", format(round(Ne_ref), big.mark = " "))
plausible(Ne_ref, "Ne", 1e4, 5e7, "individuos", log)
plausible(theta, "theta por pb", 1e-4, 5e-2, "", log)
log("  mu de ", MU_MIN, " a ", MU_MAX, " por sitio y generacion")
log("  generaciones por ano de ", GEN_ANO_MIN, " a ", GEN_ANO_MAX)

anos <- function(td, mu, gen) td * 2 * (theta / (4 * mu)) / gen  # t = td * 2Ne generaciones
tabla <- data.frame(
  evento = seq_along(ev),
  tiempo_deriva = round(vapply(ev, function(e) e$altura, numeric(1)), 5),
  deriva_ic_bajo = round(ic[, 1], 5), deriva_ic_alto = round(ic[, 2], 5),
  soporte = round(as.numeric(sop), 3),
  grupo_a = vapply(ev, function(e) paste(e$a, collapse = ", "), character(1)),
  grupo_b = vapply(ev, function(e) paste(e$b, collapse = ", "), character(1)),
  n_a = vapply(ev, function(e) length(e$a), integer(1)),
  n_b = vapply(ev, function(e) length(e$b), integer(1)),
  stringsAsFactors = FALSE)
tabla$anos_cota_baja <- signif(anos(tabla$tiempo_deriva, MU_MAX, GEN_ANO_MAX), 3)
tabla$anos_cota_alta <- signif(anos(tabla$tiempo_deriva, MU_MIN, GEN_ANO_MIN), 3)
write.table(tabla, file.path(OUT, "09_eventos.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

log("\nOrden de divergencia, del mas antiguo al mas reciente:")
for (i in seq_len(min(10, nrow(tabla))))
  log(sprintf("  %2d  deriva=%.4f [%.4f, %.4f]  soporte=%.2f  %s  vs  %s",
              tabla$evento[i], tabla$tiempo_deriva[i], tabla$deriva_ic_bajo[i],
              tabla$deriva_ic_alto[i], tabla$soporte[i],
              substr(tabla$grupo_a[i], 1, 26), substr(tabla$grupo_b[i], 1, 26)))
log("\nCota en anos del evento mas antiguo: ", tabla$anos_cota_baja[1], " a ",
    tabla$anos_cota_alta[1])
log("  Ese rango es la cota, no una estimacion. Reportar deriva.")
sop_med <- median(tabla$soporte, na.rm = TRUE)
log("Soporte mediano del orden: ", round(sop_med, 2))
if (!is.na(sop_med) && sop_med < 0.5)
  log("  El orden de divergencia no es estable frente al remuestreo del genoma.")

saveRDS(list(eventos = tabla, theta = theta, Ne_ref = Ne_ref,
             alturas_bootstrap = alturas), paso("tiempos"))
log("\nSiguiente: 10_modelos.R")
cerrar_log(log)
