# =============================================================================
#  07_psi.R
#  Indice de direccionalidad psi (Peter y Slatkin 2013).
#
#  IDEA
#  Bajo expansion, los alelos derivados suben de frecuencia hacia el frente por
#  surfing. psi_ij es la diferencia media de frecuencia del alelo derivado entre
#  dos grupos: positivo si i lo tiene mas bajo, o sea si i esta mas cerca de la
#  fuente. Es evidencia INDEPENDIENTE del gradiente de diversidad, y por eso
#  vale: que dos metodos distintos apunten al mismo lugar es el argumento fuerte.
#
#  LA POLARIZACION ES EL PUNTO DEBIL
#  psi necesita saber cual alelo es el derivado. Con grupo externo se sabe. Sin
#  el, se asume que el alelo mayoritario es el ancestral, y ese supuesto falla
#  justo en las poblaciones que pasaron por cuello de botella, que son las que
#  mas pesan en la inferencia. El pipeline soporta las tres opciones y DECLARA
#  cual se uso; 12_validar.R lo levanta como aviso mientras no haya outgroup.
#
#  Usar la referencia como ancestral es la peor opcion y esta puesta solo para
#  poder medir cuanto cambia el resultado: la referencia de eubayanus es
#  patagonica, asi que sesga hacia la Patagonia justamente lo que se quiere
#  probar.
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
log <- nuevo_log("07_psi"); log("=== 07 PSI ===")
v <- exigir_paso("variantes", "02_variantes.R")

# psi vive en la cola de frecuencias bajas, asi que usa el panel amplio si
# existe. Si no, el estricto, y se deja constancia.
if (!is.null(v$ALT_A)) {
  ALT <- v$ALT_A; TOT <- v$TOT_A; INFO <- v$INFO_A
  log("Panel amplio: ", nrow(ALT), " sitios")
} else {
  ALT <- v$ALT; TOT <- v$TOT; INFO <- v$INFO
  log("AVISO: sin panel amplio. psi se calcula sobre el panel estricto, que")
  log("  esta filtrado por frecuencia y le falta la cola donde vive la senal.")
}
gr_cols <- colnames(ALT); if (is.null(gr_cols)) gr_cols <- v$grupos
# Mismo umbral que el resto de los pasos que estiman por grupo. psi es una
# diferencia media de frecuencias: con una cepa la frecuencia es 0 o 1 en cada
# sitio y la diferencia sale sistematicamente extrema, de modo que un grupo de
# n = 1 encabeza el ranking sin que eso signifique nada.
n_por_grupo <- v$n_cepas[match(gr_cols, v$grupos)]
keep <- which(!is.na(n_por_grupo) & n_por_grupo >= N_MIN_GRUPO_EST)
if (length(keep) < 3) stop("Menos de 3 grupos superan n >= ", N_MIN_GRUPO_EST, call. = FALSE)
if (length(keep) < length(gr_cols))
  log("Grupos excluidos por n < ", N_MIN_GRUPO_EST, ": ",
      length(gr_cols) - length(keep), " de ", length(gr_cols))
ALT <- ALT[, keep, drop = FALSE]; TOT <- TOT[, keep, drop = FALSE]
grupos <- gr_cols[keep]; K <- length(grupos)
f <- ALT / pmax(TOT, 1)

# --- Polarizacion ------------------------------------------------------------
log("\nPolarizacion: ", POLARIZAR)
if (POLARIZAR == "outgroup") {
  if (!file.exists(ARCHIVO_OUTGROUP))
    stop("POLARIZAR = outgroup pero no existe ", ARCHIVO_OUTGROUP, call. = FALSE)
  og <- leer_tabla(ARCHIVO_OUTGROUP)
  key <- paste(INFO$chrom, INFO$pos)
  anc <- og$ancestral[match(key, paste(og$chrom, og$pos))]
  derivado_es_alt <- anc == INFO$ref
  log("  Sitios polarizados con grupo externo: ", sum(!is.na(derivado_es_alt)),
      " de ", nrow(ALT))
} else if (POLARIZAR == "referencia") {
  derivado_es_alt <- rep(TRUE, nrow(ALT))
  log("  AVISO: la referencia como ancestral sesga hacia la region de la cepa")
  log("  de referencia. Solo para medir sensibilidad, no para reportar.")
} else {
  f_media <- rowMeans(f, na.rm = TRUE)
  derivado_es_alt <- f_media <= 0.5
  log("  SUPUESTO: el alelo mayoritario entre grupos es el ancestral.")
  log("  Falla en poblaciones con cuello de botella. Sustituible por un archivo")
  log("  de estado ancestral en ", ARCHIVO_OUTGROUP)
}
ok <- !is.na(derivado_es_alt)
fd <- f[ok, , drop = FALSE]
fd[!derivado_es_alt[ok], ] <- 1 - fd[!derivado_es_alt[ok], ]
TOTd <- TOT[ok, , drop = FALSE]
bloq <- bloques_de(INFO$chrom, INFO$pos)[ok]
log("  Sitios usados: ", nrow(fd))

# CALCULO VECTORIZADO POR BLOQUES
#
# psi_ij es la diferencia media de frecuencia del alelo derivado entre los sitios
# validos del par. La version con bucles anidados recorria los pares uno por uno
# y adentro repetia el bootstrap: con 74 grupos son 2.701 pares por 132.000
# sitios por 200 replicas, y no termina.
#
# El numerador se puede escribir como producto cruzado. Un sitio donde los dos
# grupos tienen el alelo fijo, todo cero o todo uno, aporta cero al numerador,
# asi que solo hay que descontarlo del CONTEO:
#
#   numerador_ij   = suma M_i f_j  -  suma f_i M_j
#   denominador_ij = suma M_i M_j  -  ambos cero  -  ambos uno
#
# con M la indicadora de sitio con dato. Todo eso son crossprod, y se acumula por
# bloque para que cada replica del bootstrap sea una suma y no un recalculo.
Mi <- (TOTd >= 2) * 1
Ai <- fd * Mi
Zi <- Mi * (fd == 0)      # alelo ausente en ese grupo
Oi <- Mi * (fd == 1)      # alelo fijo en ese grupo

ut <- which(upper.tri(matrix(0, K, K)))
ib <- split(seq_len(nrow(fd)), bloq)
nb <- length(ib)
log("Bloques para el remuestreo: ", nb, " | pares: ", length(ut))

NUM <- DEN <- matrix(0, nb, length(ut))
for (b in seq_len(nb)) {
  k <- ib[[b]]
  Mb <- Mi[k, , drop = FALSE]; Ab <- Ai[k, , drop = FALSE]
  MA <- crossprod(Mb, Ab)
  NUM[b, ] <- (MA - t(MA))[ut]
  DEN[b, ] <- (crossprod(Mb) - crossprod(Zi[k, , drop = FALSE]) -
               crossprod(Oi[k, , drop = FALSE]))[ut]
}

psi_de <- function(s) {
  num <- colSums(NUM[s, , drop = FALSE]); den <- colSums(DEN[s, , drop = FALSE])
  v2 <- ifelse(den >= MIN_SITIOS_PSI, num / den, 0)
  P <- matrix(0, K, K, dimnames = list(grupos, grupos))
  P[ut] <- v2; P[lower.tri(P)] <- -t(P)[lower.tri(P)]
  P
}
conteo_de <- function(s) {
  den <- colSums(DEN[s, , drop = FALSE])
  N <- matrix(0L, K, K); N[ut] <- as.integer(den)
  N[lower.tri(N)] <- t(N)[lower.tri(N)]; N
}

PSI <- psi_de(seq_len(nb)); NSIT <- conteo_de(seq_len(nb))
log("Sitios por par: mediana ", median(NSIT[upper.tri(NSIT)]),
    " | minimo ", min(NSIT[upper.tri(NSIT)]))

psi_med <- vapply(seq_len(K), function(i) mean(PSI[i, -i]), numeric(1))

# --- Soporte por bootstrap de bloques ---------------------------------------
# Responde si tomando otra parte del genoma el mismo grupo quedaria primero. El
# soporte es la fraccion de replicas en que lo hace.
set.seed(SEMILLA)
B <- min(N_BOOTSTRAP, 200L)
log("\nBootstrap de bloques: ", B, " replicas (suma de bloques, sin recalcular)")
BS <- vapply(seq_len(B), function(b) {
  r <- psi_de(sample.int(nb, nb, replace = TRUE))
  vapply(seq_len(K), function(i) mean(r[i, -i]), numeric(1))
}, numeric(K))
primero <- table(grupos[apply(BS, 2, which.max)])
soporte <- as.numeric(primero[grupos]) / ncol(BS); soporte[is.na(soporte)] <- 0
ic <- t(apply(BS, 1, quantile, c(0.025, 0.975), na.rm = TRUE))

rk <- data.frame(grupo = grupos, n_cepas = v$n_cepas[match(grupos, v$grupos)],
                 psi_medio = round(psi_med, 6),
                 psi_ic_bajo = round(ic[, 1], 6), psi_ic_alto = round(ic[, 2], 6),
                 soporte_primero = round(soporte, 3),
                 stringsAsFactors = FALSE)
rk <- rk[order(-rk$psi_medio), ]
rk$rango <- seq_len(nrow(rk))
write.table(rk, file.path(OUT, "07_psi.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

log("\nRanking rio arriba (psi medio, con soporte de bootstrap):")
for (i in seq_len(min(10, nrow(rk))))
  log(sprintf("  %2d %-28s n=%4d  psi=%+.5f [%+.5f, %+.5f]  soporte=%.2f",
              rk$rango[i], rk$grupo[i], rk$n_cepas[i], rk$psi_medio[i],
              rk$psi_ic_bajo[i], rk$psi_ic_alto[i], rk$soporte_primero[i]))
if (max(rk$soporte_primero) < 0.5)
  log("\n  Ningun grupo supera 0,5 de soporte como primero. El ranking de psi no",
      " distingue un origen unico con estos datos.")

saveRDS(list(PSI = PSI, N = NSIT, ranking = rk, bootstrap = BS,
             polarizacion = POLARIZAR), paso("psi"))
log("\nSiguiente: 08_arbol.R")
cerrar_log(log)
