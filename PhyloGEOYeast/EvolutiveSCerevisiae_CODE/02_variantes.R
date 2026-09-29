# =============================================================================
#  02_variantes.R
#  VCF a conteos alelicos por grupo, y definicion de los bloques de remuestreo.
#
#  Es el unico paso caro: lee el VCF completo. Si su resultado ya existe se
#  saltea, salvo que se pida lo contrario.
#
#  DOS PANELES, POR UNA RAZON
#  Panel ESTRICTO (MIN_MAF, MIN_CALL, podado por MIN_DIST_LD): sirve para
#    estadisticos entre grupos, donde importa que los sitios sean informativos
#    y esten poco ligados. FST, Nei, PCA, arbol.
#  Panel AMPLIO (sin filtro de frecuencia): sirve para todo lo que depende de la
#    cola de alelos raros, que es donde vive la senal de expansion. Alelos
#    privados y psi.
#  Si el VCF de entrada ya viene filtrado por MAF aguas arriba, el panel amplio
#  no recupera nada y 03_diagnostico.R lo declara como limitacion dura.
#
#  BLOQUES DE REMUESTREO
#  Cada SNP recibe la ventana de TAM_BLOQUE pares de bases a la que pertenece.
#  Esa es la unidad de todo el remuestreo posterior. Ver la nota en 00_config.R
#  sobre por que no son SNPs sueltos ni cromosomas.
#
#  ADOPTAR UNA CORRIDA ANTERIOR
#  Si en OUT existe paso_conteos.rds de la version anterior del pipeline, se
#  adopta en vez de releer el VCF. Evita repetir horas de lectura cuando lo
#  unico que cambio esta aguas abajo. Se registra en el log que los conteos son
#  heredados y de que archivo.
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
log <- nuevo_log("02_variantes"); log("=== 02 VARIANTES ===")
d1 <- exigir_paso("datos", "01_datos.R")

REHACER <- getOption("filo.rehacer_variantes", FALSE)
heredado <- file.path(OUT, "paso_conteos.rds")

leer_vcf <- function(d1) {
  if (!file.exists(ARCHIVO_VCF)) stop("No existe el VCF: ", ARCHIVO_VCF, call. = FALSE)
  log("Leyendo el VCF (", round(file.size(ARCHIVO_VCF) / 1e9, 2), " GB)...")

  # Cabecera: la linea #CHROM trae los nombres de muestra.
  con <- gzfile(ARCHIVO_VCF, "rt")
  repeat {
    l <- readLines(con, n = 1)
    if (!length(l)) stop("El VCF no tiene linea #CHROM.", call. = FALSE)
    if (startsWith(l, "#CHROM")) break
  }
  close(con)
  muestras <- trimws(strsplit(sub("\r$", "", l), "\t", fixed = TRUE)[[1]][-(1:9)])
  if (length(RENOMBRAR)) {
    hit <- muestras %in% names(RENOMBRAR)
    muestras[hit] <- unname(RENOMBRAR[muestras[hit]])
  }
  log("Muestras en el VCF: ", length(muestras))

  # El grupo de cada muestra sale de 01_datos.R, no se recalcula aca. Asi la
  # unidad de analisis queda definida en un solo lugar.
  grupo <- unname(d1$grupo_de_cepa[muestras])
  sin_meta <- muestras[is.na(grupo)]
  if (length(sin_meta))
    log("Muestras del VCF sin grupo en la metadata: ", length(sin_meta), " (",
        paste(head(sin_meta, 6), collapse = ", "), ")")
  grupos <- d1$grupos
  usar <- which(!is.na(grupo) & grupo %in% grupos)
  if (!length(usar)) stop("Ninguna muestra del VCF cruza con los grupos.", call. = FALSE)
  log("Muestras usadas: ", length(usar), " de ", length(muestras))

  # Matriz indicadora muestra x grupo: multiplicar por ella agrega los conteos
  # individuales al nivel de grupo en una sola operacion.
  G <- outer(grupo[usar], grupos, "==") * 1

  aE <- tE <- iE <- gE <- list()   # panel estricto
  aA <- tA <- iA <- list()   # panel amplio
  n_leidas <- 0L; ultimo <- ""; ult_pos <- -Inf

  con <- gzfile(ARCHIVO_VCF, "rt")
  repeat { l <- readLines(con, n = 1); if (!length(l)) break; if (startsWith(l, "#CHROM")) break }
  repeat {
    lineas <- readLines(con, n = CHUNK)
    if (!length(lineas)) break
    n_leidas <- n_leidas + length(lineas)
    p <- strsplit(lineas, "\t", fixed = TRUE)
    p <- p[lengths(p) == length(muestras) + 9L]
    if (!length(p)) next
    mat <- matrix(unlist(p, use.names = FALSE), ncol = length(muestras) + 9L, byrow = TRUE)
    ch <- mat[, 1]; po <- as.integer(mat[, 2])
    rf <- toupper(mat[, 4]); al <- toupper(mat[, 5])
    # Solo bialelicos simples. Los bloques de referencia sin variante quedan
    # fuera porque su ALT no es una base.
    keep <- rf %in% c("A", "C", "G", "T") & al %in% c("A", "C", "G", "T") &
      !grepl(CONTIG_EXCLUIR, ch, fixed = TRUE)
    if (!any(keep)) next
    mat <- mat[keep, , drop = FALSE]; ch <- ch[keep]; po <- po[keep]

    campos <- mat[, 9 + usar, drop = FALSE]
    gt <- matrix(sub(":.*$", "", campos), nrow = nrow(campos))
    v <- as.vector(gt); sp <- regexpr("[/|]", v)
    a1 <- ifelse(sp > 0L, substring(v, 1L, sp - 1L), v)
    a2 <- ifelse(sp > 0L, sub("[/|].*$", "", substring(v, sp + 1L)), NA_character_)
    i1 <- suppressWarnings(as.integer(a1)); i2 <- suppressWarnings(as.integer(a2))
    i1[!is.na(i1) & i1 > 1L] <- NA_integer_; i2[!is.na(i2) & i2 > 1L] <- NA_integer_
    A  <- matrix(ifelse(is.na(i1), 0L, ifelse(is.na(i2), i1, i1 + i2)), nrow = nrow(campos))
    T_ <- matrix(ifelse(is.na(i1), 0L, ifelse(is.na(i2), 1L, 2L)), nrow = nrow(campos))

    ag <- A %*% G; tg <- T_ %*% G
    tot <- rowSums(tg); alt <- rowSums(ag)
    f <- ifelse(tot > 0, alt / tot, NA_real_)
    llam <- rowSums(T_ > 0) / length(usar)

    # Panel amplio. El submuestreo es aleatorio y proporcional, no truncado:
    # cortar al llegar a un tope se quedaria solo con los primeros cromosomas
    # del archivo y sesgaria todo lo que dependa de este panel, ademas de
    # romper el remuestreo por bloques.
    okA <- !is.na(f) & pmin(f, 1 - f) >= MAF_AMPLIO & llam >= CALL_AMPLIO
    if (any(okA)) {
      sel <- which(okA)
      if (!is.na(FRAC_AMPLIO) && FRAC_AMPLIO < 1) {
        set.seed(SEMILLA + n_leidas)
        sel <- sel[runif(length(sel)) < FRAC_AMPLIO]
      }
      if (length(sel)) {
        aA[[length(aA) + 1L]] <- ag[sel, , drop = FALSE]
        tA[[length(tA) + 1L]] <- tg[sel, , drop = FALSE]
        iA[[length(iA) + 1L]] <- data.frame(chrom = ch[sel], pos = po[sel],
                                            ref = mat[sel, 4], alt = mat[sel, 5],
                                            stringsAsFactors = FALSE)
      }
    }

    # Panel estricto: MAF alta, buen llamado y adelgazado por distancia para
    # que los sitios esten aproximadamente en equilibrio de ligamiento.
    okE <- !is.na(f) & pmin(f, 1 - f) >= MIN_MAF & llam >= MIN_CALL
    if (any(okE)) {
      ks <- which(okE); selE <- logical(length(ks))
      for (i in seq_along(ks)) {
        if (ch[ks[i]] != ultimo || po[ks[i]] - ult_pos >= MIN_DIST_LD) {
          selE[i] <- TRUE; ultimo <- ch[ks[i]]; ult_pos <- po[ks[i]]
        }
      }
      if (any(selE)) {
        k2 <- ks[selE]
        aE[[length(aE) + 1L]] <- ag[k2, , drop = FALSE]
        tE[[length(tE) + 1L]] <- tg[k2, , drop = FALSE]
        iE[[length(iE) + 1L]] <- data.frame(chrom = ch[k2], pos = po[k2],
                                            ref = mat[k2, 4], alt = mat[k2, 5],
                                            stringsAsFactors = FALSE)
        # Genotipos por cepa del panel estricto, codificados 0/1/2 y NA. Sin esto
        # no se pueden calcular Ho, Fis, desequilibrio de ligamiento, asignacion
        # de cepas ni marcadores diagnosticos: todos ellos necesitan el individuo
        # y no la frecuencia agregada del grupo. Se guarda como entero pequeno
        # para que la matriz quepa en memoria.
        gE[[length(gE) + 1L]] <- {
          g0 <- A[k2, , drop = FALSE]
          g0[T_[k2, , drop = FALSE] == 0L] <- NA_integer_
          storage.mode(g0) <- "integer"; g0
        }
      }
    }
  }
  close(con)
  if (!length(aE)) stop("Ningun SNP paso el filtro estricto.", call. = FALSE)

  ALT <- do.call(rbind, aE); TOT <- do.call(rbind, tE); INFO <- do.call(rbind, iE)
  GT <- do.call(rbind, gE); colnames(GT) <- muestras[usar]
  colnames(ALT) <- colnames(TOT) <- grupos
  ALT_A <- if (length(aA)) do.call(rbind, aA) else NULL
  TOT_A <- if (length(tA)) do.call(rbind, tA) else NULL
  INFO_A <- if (length(iA)) do.call(rbind, iA) else NULL
  if (!is.null(ALT_A)) colnames(ALT_A) <- colnames(TOT_A) <- grupos

  log("Variantes leidas: ", n_leidas)
  log("Panel ESTRICTO: ", nrow(ALT), " SNP (1 cada ", MIN_DIST_LD, " pb, MAF >= ",
      MIN_MAF, ", llamado >= ", MIN_CALL, ")")
  log("Panel AMPLIO:   ", if (is.null(ALT_A)) 0 else nrow(ALT_A),
      " SNP (sin adelgazar, MAF >= ", MAF_AMPLIO, ", llamado >= ", CALL_AMPLIO,
      if (!is.na(FRAC_AMPLIO) && FRAC_AMPLIO < 1)
        paste0(", submuestreo aleatorio ", round(100 * FRAC_AMPLIO), "%") else "", ")")

  log("Genotipos por cepa: ", nrow(GT), " x ", ncol(GT), " (",
      round(object.size(GT) / 1e6), " MB)")
  list(ALT = ALT, TOT = TOT, INFO = INFO, GT = GT,
       ALT_A = ALT_A, TOT_A = TOT_A, INFO_A = INFO_A,
       grupos = grupos, muestras_usadas = muestras[usar],
       grupo_de_muestra = setNames(grupo[usar], muestras[usar]),
       sin_metadata = sin_meta)
}

if (!REHACER && file.exists(heredado)) {
  log("Conteos heredados de ", heredado)
  v <- readRDS(heredado)
  log("  ALT: ", nrow(v$ALT), " SNP x ", ncol(v$ALT), " grupos")
  log("  Panel amplio: ", if (is.null(v$ALT_A)) "ausente" else paste(nrow(v$ALT_A), "SNP"))
} else {
  v <- leer_vcf(d1)
}

ALT <- v$ALT; TOT <- v$TOT; INFO <- v$INFO

# Modo rapido: submuestreo aleatorio del panel para que el resto del pipeline
# corra en minutos. Aleatorio y no los primeros N, porque cortar por el
# principio se quedaria con los primeros cromosomas y rompe el remuestreo.
if (RAPIDO) {
  set.seed(SEMILLA)
  k <- sort(sample.int(nrow(ALT), max(2000L, round(nrow(ALT) * FRAC_RAPIDO))))
  ALT <- ALT[k, , drop = FALSE]; TOT <- TOT[k, , drop = FALSE]; INFO <- INFO[k, ]
  # los genotipos se recortan con el MISMO indice: si quedan desalineados con
  # ALT, todo lo que cruza individuo y frecuencia deja de tener sentido
  if (!is.null(v$GT)) v$GT <- v$GT[k, , drop = FALSE]
  log("MODO RAPIDO: panel estricto reducido a ", nrow(ALT), " SNP")
  if (!is.null(v$ALT_A)) {
    ka <- sort(sample.int(nrow(v$ALT_A), max(2000L, round(nrow(v$ALT_A) * FRAC_RAPIDO))))
    v$ALT_A <- v$ALT_A[ka, , drop = FALSE]; v$TOT_A <- v$TOT_A[ka, , drop = FALSE]
    v$INFO_A <- v$INFO_A[ka, ]
    log("MODO RAPIDO: panel amplio reducido a ", nrow(v$ALT_A), " SNP")
  }
}

# Los conteos vienen indexados por los grupos con los que se corrio el paso 01
# de esa corrida. Si 01_datos.R definio otros grupos, hay que releer el VCF: no
# se puede reagrupar conteos ya agregados sin volver a los genotipos.
g_conteos <- colnames(ALT)
if (is.null(g_conteos)) g_conteos <- v$grupos
comunes <- intersect(g_conteos, d1$grupos)
if (length(comunes) < length(d1$grupos)) {
  log("\nAVISO: los conteos heredados cubren ", length(comunes), " de los ",
      length(d1$grupos), " grupos definidos en 01_datos.R.")
  log("  Los conteos agregados no se pueden reagrupar. Para esta agrupacion")
  log("  hay que releer el VCF con options(filo.rehacer_variantes = TRUE).")
}
orden <- match(comunes, g_conteos)
ALT <- ALT[, orden, drop = FALSE]; TOT <- TOT[, orden, drop = FALSE]
colnames(ALT) <- colnames(TOT) <- comunes

# --- Bloques de remuestreo ---------------------------------------------------
bloq <- bloques_de(INFO$chrom, INFO$pos)
nb <- length(unique(bloq))
log("\nBloques de remuestreo: ", nb, " ventanas de ", TAM_BLOQUE, " pb")
log("  SNP por bloque: mediana ", median(table(bloq)), " | minimo ", min(table(bloq)))
if (nb < 30) {
  log("  AVISO: menos de 30 bloques. El soporte por bootstrap va a ser grueso.")
  log("  Bajar TAM_BLOQUE, sin quedar por debajo de la caida del LD.")
}

sub <- list(grupos = comunes,
            n_cepas = d1$n_cepas[match(comunes, d1$grupos)],
            coord = d1$coord[match(comunes, d1$grupos), ],
            peso = d1$peso[match(comunes, d1$grupos)],
            elegible = d1$elegible[match(comunes, d1$grupos)])

saveRDS(list(ALT = ALT, TOT = TOT, INFO = INFO, GT = v$GT,
             muestras = v$muestras_usadas, grupo_de_muestra = v$grupo_de_muestra,
             ALT_A = v$ALT_A, TOT_A = v$TOT_A, INFO_A = v$INFO_A,
             bloque = bloq, grupos = comunes, n_cepas = sub$n_cepas,
             coord = sub$coord, peso = sub$peso, elegible = sub$elegible,
             heredado = (!REHACER && file.exists(heredado))),
        paso("variantes"))
log("\nSiguiente: 03_diagnostico.R")
cerrar_log(log)
