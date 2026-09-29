# =============================================================================
#  05_diferenciacion.R
#  FST pareado, distancia de Nei y aislamiento por distancia.
#
#  ESTIMADOR
#  FST de Hudson en su forma razon de promedios (Bhatia et al. 2013). Se elige
#  esa forma y no el promedio de razones porque es la que no se sesga cuando los
#  tamanos de muestra son desparejos, que es exactamente el caso aca.
#
#  INCERTIDUMBRE
#  Bootstrap de bloques, la misma unidad que en todo el pipeline. La version
#  anterior usaba jackknife sobre 16 cromosomas: correcto en principio, pero con
#  16 bloques el error estandar queda con 15 grados de libertad.
#
#  AISLAMIENTO POR DISTANCIA
#  Regresion de FST/(1-FST) contra log de la distancia, y prueba de Mantel por
#  permutacion de filas y columnas de la matriz. Sirve de control: si la
#  estructura fuera taxonomica y no espacial, IBD no aparece.
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
log <- nuevo_log("05_diferenciacion"); log("=== 05 DIFERENCIACION ===")
v <- exigir_paso("variantes", "02_variantes.R")

ALT <- v$ALT; TOT <- v$TOT; grupos <- v$grupos; K <- length(grupos)
log("Grupos: ", K, " | SNP: ", nrow(ALT))
log("Estimador: Hudson, razon de promedios (Bhatia et al. 2013)")

# CALCULO VECTORIZADO POR BLOQUES
#
# La version anterior recorria los pares con dos bucles anidados y adentro otro
# bucle de bootstrap. Con 400 grupos son 79.800 pares por 200 replicas: 16
# millones de pasadas sobre 66.000 SNP. En cerevisiae por sitio y linaje eso no
# termina nunca, y ahi se corto la corrida.
#
# Aca todo se expresa como productos cruzados de matrices, que R resuelve con
# BLAS. Las cantidades de Hudson y de Nei son sumas sobre sitios de productos
# entre columnas, y eso es exactamente crossprod:
#
#   suma_s p_is * p_js  =  crossprod(P)[i, j]
#
# El detalle que hay que cuidar es que cada par tiene su propio conjunto de
# sitios validos, los que tienen dato en AMBOS grupos. Se resuelve con una
# matriz indicadora V: multiplicando cada matriz por V antes del producto
# cruzado, los sitios sin dato aportan cero y quedan fuera de la suma.
#
# Ademas se acumula por BLOQUE. Cada bloque deja su numerador y su denominador
# guardados, de modo que una replica de bootstrap es una suma de bloques ya
# calculados y no un recalculo desde los genotipos. El costo del bootstrap pasa
# a ser despreciable.

# Las matrices auxiliares se arman DENTRO del bucle de bloques, no antes. Con
# 400 grupos y 66.000 sitios, cada matriz completa pesa 212 MB y hacen falta
# siete: 1,5 GB solo en intermedios, y el proceso muere por memoria. Por bloque
# son unos cientos de filas y el costo es despreciable.
ut <- which(upper.tri(matrix(0, K, K)))
ib <- split(seq_len(nrow(ALT)), v$bloque)
nb <- length(ib)
log("Bloques: ", nb, " | pares: ", length(ut))

# num y den de Hudson por bloque, guardados como triangulo superior
NUM <- matrix(0, nb, length(ut)); DEN <- matrix(0, nb, length(ut))
# componentes de Nei, acumuladas sobre todos los bloques
Sxy <- Sxx <- Syy <- Snn <- numeric(length(ut))

for (b in seq_len(nb)) {
  k <- ib[[b]]
  Ab <- ALT[k, , drop = FALSE]; Tb <- TOT[k, , drop = FALSE]
  Vb <- (Tb >= 1) * 1
  fb <- Ab / pmax(Tb, 1)
  Pb <- fb * Vb; Qb <- (1 - fb) * Vb
  P2b <- Pb * Pb * Vb; Q2b <- Qb * Qb * Vb
  Cb <- (fb * (1 - fb) / (pmax(Tb, 2) - 1)) * Vb

  PP <- crossprod(Pb)                    # suma p_i p_j sobre sitios validos
  QQ <- crossprod(Qb)
  PQ <- crossprod(Pb, Qb)
  P2V <- crossprod(P2b, Vb)              # suma p_i^2 restringida a validos del par
  Q2V <- crossprod(Q2b, Vb)
  CV  <- crossprod(Cb, Vb)               # suma de la correccion de i sobre validos
  VV  <- crossprod(Vb)                   # cantidad de sitios validos del par

  # (p_i - p_j)^2 = p_i^2 + p_j^2 - 2 p_i p_j
  num <- (P2V + t(P2V) - 2 * PP) - (CV + t(CV))
  den <- PQ + t(PQ)
  NUM[b, ] <- num[ut]; DEN[b, ] <- den[ut]

  # Nei: jxy = media de (p_i p_j + q_i q_j); jx = media de (p_i^2 + q_i^2)
  Sxy <- Sxy + (PP + QQ)[ut]
  Sxx <- Sxx + (P2V + Q2V)[ut]
  Syy <- Syy + t(P2V + Q2V)[ut]
  Snn <- Snn + VV[ut]
}

fst_de <- function(num, den) ifelse(den > 0, pmax(0, num / den), NA_real_)
fst_v <- fst_de(colSums(NUM), colSums(DEN))

jxy <- Sxy / pmax(Snn, 1); jx <- Sxx / pmax(Snn, 1); jy <- Syy / pmax(Snn, 1)
nei_v <- ifelse(Snn >= 100 & jx > 0 & jy > 0,
                pmax(0, -base::log(jxy / sqrt(jx * jy))), NA_real_)

FST <- matrix(NA_real_, K, K, dimnames = list(grupos, grupos))
NEI <- matrix(0, K, K, dimnames = list(grupos, grupos))
FST[ut] <- fst_v; FST <- pmax(FST, t(FST), na.rm = TRUE)
diag(FST) <- NA
NEI[ut] <- nei_v; NEI[lower.tri(NEI)] <- t(NEI)[lower.tri(NEI)]
diag(NEI) <- 0

# --- Error estandar: cada replica es una suma de bloques ya calculados -------
set.seed(SEMILLA)
B <- min(N_BOOTSTRAP, 200L)
log("Bootstrap de bloques: ", B, " replicas (suma de bloques, sin recalcular)")
BS <- matrix(NA_real_, B, length(ut))
for (r in seq_len(B)) {
  s <- sample.int(nb, nb, replace = TRUE)
  BS[r, ] <- fst_de(colSums(NUM[s, , drop = FALSE]), colSums(DEN[s, , drop = FALSE]))
}
se_v <- apply(BS, 2, sd, na.rm = TRUE)
SE <- matrix(NA_real_, K, K, dimnames = list(grupos, grupos))
SE[ut] <- se_v; SE[lower.tri(SE)] <- t(SE)[lower.tri(SE)]

idx <- which(upper.tri(matrix(0, K, K)), arr.ind = TRUE)
ok <- !is.na(fst_v)
tb <- data.frame(a = grupos[idx[ok, 1]], b = grupos[idx[ok, 2]],
                 fst = round(fst_v[ok], 5), fst_se = round(se_v[ok], 5),
                 nei_D = round(nei_v[ok], 5),
                 n_a = v$n_cepas[idx[ok, 1]], n_b = v$n_cepas[idx[ok, 2]],
                 stringsAsFactors = FALSE)
la <- v$coord$lat; lo <- v$coord$lon
tb$dist_km <- round(dist_km(la[idx[ok, 1]], lo[idx[ok, 1]],
                            la[idx[ok, 2]], lo[idx[ok, 2]]), 1)
tb <- tb[order(-tb$fst), ]
write.table(tb, file.path(OUT, "05_pares.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("Pares con FST: ", nrow(tb), " de ", K * (K - 1) / 2)
log("FST: minimo ", round(min(tb$fst), 4), " | mediana ", round(median(tb$fst), 4),
    " | maximo ", round(max(tb$fst), 4))

# --- Aislamiento por distancia ----------------------------------------------
ok <- !is.na(tb$dist_km) & tb$dist_km > 0 & !is.na(tb$fst) & tb$fst < 1
ibd_r <- NA_real_; ibd_p <- NA_real_; pend <- NA_real_
if (sum(ok) >= 10) {
  y <- tb$fst[ok] / (1 - tb$fst[ok]); x <- base::log(tb$dist_km[ok])
  fit <- lm(y ~ x); pend <- unname(coef(fit)[2])
  ibd_r <- suppressWarnings(cor(x, y))
  # Mantel: se permutan los rotulos de los grupos, no los pares sueltos. Los
  # pares comparten grupos y no son intercambiables entre si.
  set.seed(SEMILLA)
  M <- FST; D <- matrix(NA_real_, K, K)
  for (i in 1:K) for (j in 1:K) if (i != j) D[i, j] <- dist_km(la[i], lo[i], la[j], lo[j])
  obs <- suppressWarnings(cor(M[upper.tri(M)], base::log(D[upper.tri(D)]), use = "complete"))
  perm <- vapply(seq_len(N_PERMUTA), function(b) {
    o <- sample.int(K)
    suppressWarnings(cor(M[upper.tri(M)], base::log(D[o, o][upper.tri(D)]), use = "complete"))
  }, numeric(1))
  ibd_p <- (1 + sum(perm >= obs, na.rm = TRUE)) / (1 + sum(is.finite(perm)))
  log("\nAislamiento por distancia:")
  log("  r = ", round(ibd_r, 3), " | pendiente = ", signif(pend, 3),
      " | Mantel p = ", signif(ibd_p, 3), " (", N_PERMUTA, " permutaciones)")
  if (!is.na(ibd_p) && ibd_p > 0.05)
    log("  Sin IBD detectable. La estructura no es principalmente espacial, y")
    log("  eso limita lo que un gradiente geografico puede afirmar.")
}

saveRDS(list(FST = FST, SE = SE, NEI = NEI, tabla = tb,
             ibd_r = ibd_r, ibd_p = ibd_p, ibd_pendiente = pend),
        paso("diferenciacion"))
log("\nSiguiente: 06_gradiente.R")
cerrar_log(log)
