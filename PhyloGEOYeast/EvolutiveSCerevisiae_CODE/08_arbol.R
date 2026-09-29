# =============================================================================
#  08_arbol.R
#  Arbol de grupos por neighbor-joining, CON SOPORTE.
#
#  POR QUE SOBRE GRUPOS Y NO SOBRE CEPAS
#  Un arbol sobre cepas obliga a cada una a colgar de una sola rama, lo cual es
#  falso para las cepas de ancestria mezclada, y con recombinacion un arbol
#  unico sobre cepas no es una genealogia sino un resumen de distancias. Sobre
#  grupos, construido desde covarianza de frecuencias alelicas, el objeto es
#  honesto: un resumen de distancias entre grupos.
#
#  LO QUE ESTE ARBOL NO ES
#  No es una filogenia enraizada. Sin grupo externo no hay direccion temporal:
#  se puede leer quien se parece a quien, no quien viene de quien. El enraizado
#  que se ofrece es por criterios internos y se reportan los tres para que se
#  vea si coinciden.
#
#  SOPORTE
#  Bootstrap de bloques del genoma. El soporte de una particion es la fraccion
#  de replicas en las que aparece. Remuestrear SNPs sueltos daria soporte
#  inflado porque estan ligados. Un arbol sin soporte no es publicable, y la
#  version anterior no lo tenia.
#
#  ESCRITURA A NEWICK
#  El serializador lleva registro de nodos emitidos. Sin ese registro la arista
#  final se recorre desde sus dos extremos y el subarbol se escribe dos veces:
#  eso paso de verdad y llego hasta la revision. Ademas se valida el numero de
#  hojas antes de devolver.
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
log <- nuevo_log("08_arbol"); log("=== 08 ARBOL DE GRUPOS ===")
v  <- exigir_paso("variantes", "02_variantes.R")
df <- exigir_paso("diferenciacion", "05_diferenciacion.R")

# Solo entran grupos con suficientes cepas: con una o dos, las frecuencias son
# ruido y el ruido se lee como rama larga y tiempo de deriva alto.
usar <- which(v$n_cepas >= N_MIN_ARBOL)
fuera <- v$grupos[v$n_cepas < N_MIN_ARBOL]
log("Grupos en el arbol: ", length(usar), " de ", length(v$grupos),
    " (umbral n >= ", N_MIN_ARBOL, ")")
if (length(fuera)) log("  Excluidos: ", paste(head(fuera, 10), collapse = ", "),
                       if (length(fuera) > 10) "..." else "")
if (length(usar) < 4) stop("Menos de 4 grupos superan el umbral.", call. = FALSE)

gg <- v$grupos[usar]
D <- df$NEI[gg, gg]
D[is.na(D)] <- max(D, na.rm = TRUE)

sanear <- function(x) gsub("[(),:;]", "_", x)

# --- Neighbor-joining --------------------------------------------------------
nj <- function(D) {
  n <- nrow(D); et <- rownames(D)
  act <- seq_len(n); M <- D; sig <- n + 1L; aristas <- list()
  while (length(act) > 2) {
    m <- length(act); S <- M[act, act, drop = FALSE]
    u <- rowSums(S) / (m - 2)
    Q <- S - outer(u, u, "+"); diag(Q) <- Inf
    ij <- which(Q == min(Q), arr.ind = TRUE)[1, ]
    a <- act[ij[1]]; b <- act[ij[2]]; dab <- M[a, b]
    la <- dab / 2 + (u[ij[1]] - u[ij[2]]) / 2; lb <- dab - la
    aristas[[length(aristas) + 1L]] <- c(sig, a, max(la, 0))
    aristas[[length(aristas) + 1L]] <- c(sig, b, max(lb, 0))
    nu <- (M[act, a] + M[act, b] - dab) / 2
    M <- rbind(cbind(M, 0), 0); M[sig, act] <- nu; M[act, sig] <- nu; M[sig, sig] <- 0
    act <- c(setdiff(act, c(a, b)), sig); sig <- sig + 1L
  }
  a <- act[1]; b <- act[2]; dfin <- max(M[a, b], 0); raiz <- sig
  aristas[[length(aristas) + 1L]] <- c(raiz, a, dfin / 2)
  aristas[[length(aristas) + 1L]] <- c(raiz, b, dfin / 2)
  AR <- do.call(rbind, aristas)
  list(AR = AR, raiz = raiz, et = et, n = n)
}

# Particiones del arbol, para medir soporte. Cada nodo interno define un
# subconjunto de hojas; el soporte es cuantas replicas producen el mismo.
particiones <- function(tr) {
  hijos <- split(tr$AR[, 2], tr$AR[, 1])
  hojas <- function(nd) {
    h <- hijos[[as.character(nd)]]
    if (is.null(h)) return(tr$et[nd])
    unlist(lapply(h, hojas), use.names = FALSE)
  }
  ps <- lapply(as.integer(names(hijos)), function(nd) sort(hojas(nd)))
  unique(vapply(ps, paste, character(1), collapse = "\u0001"))
}

a_newick <- function(tr) {
  vis <- logical(max(tr$AR[, 1]))
  esc <- function(nd, largo) {
    if (vis[nd]) stop("Nodo emitido dos veces al escribir el Newick.", call. = FALSE)
    vis[nd] <<- TRUE
    h <- which(tr$AR[, 1] == nd)
    txt <- if (!length(h)) sanear(tr$et[nd])
    else paste0("(", paste(vapply(h, function(k) esc(tr$AR[k, 2], tr$AR[k, 3]),
                                  character(1)), collapse = ","), ")")
    if (is.null(largo)) txt else paste0(txt, ":", signif(largo, 6))
  }
  nwk <- paste0(esc(tr$raiz, NULL), ";")
  h <- regmatches(nwk, gregexpr("[(,][^(),:]+:", nwk))[[1]]
  h <- sub("^[(,]", "", sub(":$", "", h))
  if (length(h) != tr$n) stop("El Newick trae ", length(h), " hojas y hay ",
                              tr$n, " grupos.", call. = FALSE)
  if (anyDuplicated(h)) stop("Hojas repetidas: ",
                             paste(unique(h[duplicated(h)]), collapse = ", "), call. = FALSE)
  falta <- setdiff(sanear(tr$et), h)
  if (length(falta)) stop("Grupos ausentes del Newick: ",
                          paste(falta, collapse = ", "), call. = FALSE)
  nwk
}

tr <- nj(D)
nwk <- a_newick(tr)
p_obs <- particiones(tr)
log("Arbol construido: ", tr$n, " hojas, ", length(p_obs), " particiones")

# --- Soporte por bootstrap de bloques ---------------------------------------
# Se recalcula la matriz de Nei sobre cada replica de bloques y se rehace el NJ.
# El soporte exige rehacer el arbol sobre cada replica de bloques, y eso exige
# la matriz de Nei de cada replica. Recalcularla desde los genotipos en cada una
# es lo que hacia inviable el paso con muchos grupos.
#
# En vez de eso se acumulan por bloque las cuatro sumas que definen la distancia
# de Nei, con los mismos productos cruzados de 05. Una replica pasa a ser una
# suma de bloques ya calculados: el bootstrap deja de depender del numero de
# SNP y solo depende del numero de bloques.
ALT <- v$ALT[, match(gg, v$grupos), drop = FALSE]
TOT <- v$TOT[, match(gg, v$grupos), drop = FALSE]
K2 <- ncol(ALT)
ut2 <- which(upper.tri(matrix(0, K2, K2)))
ib <- split(seq_len(nrow(ALT)), v$bloque)
nb <- length(ib)

SXY <- SXX <- SYY <- SNN <- matrix(0, nb, length(ut2))
for (b in seq_len(nb)) {
  k <- ib[[b]]
  Ab <- ALT[k, , drop = FALSE]; Tb <- TOT[k, , drop = FALSE]
  Vb <- (Tb >= 1) * 1
  fb <- Ab / pmax(Tb, 1)
  Pb <- fb * Vb; Qb <- (1 - fb) * Vb
  P2V <- crossprod(Pb * Pb * Vb, Vb); Q2V <- crossprod(Qb * Qb * Vb, Vb)
  SXY[b, ] <- (crossprod(Pb) + crossprod(Qb))[ut2]
  SXX[b, ] <- (P2V + Q2V)[ut2]
  SYY[b, ] <- t(P2V + Q2V)[ut2]
  SNN[b, ] <- crossprod(Vb)[ut2]
}
log("Bloques para el soporte: ", nb, " | pares: ", length(ut2))

nei_de_bloques <- function(s) {
  jxy <- colSums(SXY[s, , drop = FALSE]); jx <- colSums(SXX[s, , drop = FALSE])
  jy <- colSums(SYY[s, , drop = FALSE]);  nn <- colSums(SNN[s, , drop = FALSE])
  d <- ifelse(nn >= 100 & jx > 0 & jy > 0,
              pmax(0, -base::log((jxy / nn) / sqrt((jx / nn) * (jy / nn)))), NA_real_)
  M <- matrix(0, K2, K2, dimnames = list(gg, gg))
  M[ut2] <- d; M[lower.tri(M)] <- t(M)[lower.tri(M)]
  M[is.na(M)] <- max(M, na.rm = TRUE); diag(M) <- 0
  M
}

set.seed(SEMILLA)
B <- min(N_BOOTSTRAP, 200L)
log("Bootstrap de bloques: ", B, " replicas (suma de bloques, sin recalcular)")
cuenta <- setNames(integer(length(p_obs)), p_obs)
val <- 0L
for (r in seq_len(B)) {
  Mb <- tryCatch(nei_de_bloques(sample.int(nb, nb, replace = TRUE)),
                 error = function(e) NULL)
  if (is.null(Mb)) next
  trb <- tryCatch(nj(Mb), error = function(e) NULL)
  if (is.null(trb)) next
  val <- val + 1L
  pb <- particiones(trb)
  hit <- intersect(p_obs, pb)
  cuenta[hit] <- cuenta[hit] + 1L
}
sop <- if (val > 0) cuenta / val else cuenta * NA
log("Replicas validas: ", val)

tab_sop <- data.frame(
  particion = vapply(names(sop), function(x)
    paste(head(strsplit(x, "\u0001")[[1]], 6), collapse = ", "), character(1)),
  n_hojas = vapply(names(sop), function(x) length(strsplit(x, "\u0001")[[1]]), integer(1)),
  soporte = round(as.numeric(sop), 3), stringsAsFactors = FALSE)
tab_sop <- tab_sop[tab_sop$n_hojas > 1 & tab_sop$n_hojas < tr$n, ]
tab_sop <- tab_sop[order(-tab_sop$soporte), ]
write.table(tab_sop, file.path(OUT, "08_soporte.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nSoporte de las particiones internas:")
log("  mediana ", round(median(tab_sop$soporte), 2),
    " | por encima de 0,7: ", sum(tab_sop$soporte >= 0.7), " de ", nrow(tab_sop))
for (i in seq_len(min(8, nrow(tab_sop))))
  log(sprintf("  %.2f  (%d hojas) %s", tab_sop$soporte[i], tab_sop$n_hojas[i],
              substr(tab_sop$particion[i], 1, 70)))
if (median(tab_sop$soporte) < 0.5)
  log("\n  La mayoria de las particiones tiene soporte por debajo de 0,5. La",
      " topologia no esta resuelta y no se debe interpretar rama por rama.")

writeLines(nwk, file.path(OUT, "08_arbol.nwk"))
log("\nArbol escrito en 08_arbol.nwk. Es un arbol SIN RAIZ: sin grupo externo")
log("no hay direccion temporal.")

saveRDS(list(newick = nwk, D = D, grupos = gg, soporte = tab_sop,
             replicas_validas = val, excluidos = fuera), paso("arbol"))
log("\nSiguiente: 09_tiempos.R")
cerrar_log(log)
