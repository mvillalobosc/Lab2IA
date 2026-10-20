# =============================================================================
#  16_marcadores.R
#  Marcadores diagnosticos por grupo y su anotacion en genes.
#
#  QUE ES UN MARCADOR DIAGNOSTICO
#  Un sitio cuya frecuencia alelica en un grupo se aparta mucho de la del resto.
#  Sirve para disenar un ensayo barato que distinga ese grupo sin secuenciar el
#  genoma completo. Se mide con delta, la diferencia absoluta de frecuencia entre
#  el grupo y todos los demas juntos, y con una prueba exacta de Fisher.
#
#  CORRECCION POR PRUEBAS MULTIPLES
#  Se evaluan decenas de miles de sitios por grupo, asi que los p sin corregir no
#  significan nada: con cien mil pruebas al cinco por ciento salen cinco mil
#  falsos positivos. Se corrige por tasa de descubrimiento falso.
#
#  ANOTACION Y PARALOGOS
#  Cada marcador se cruza contra la anotacion para saber en que gen cae, y se
#  reporta el enriquecimiento de cada gen: marcadores observados sobre esperados
#  segun su largo. Un valor alto NO es prueba de seleccion. La densidad tambien
#  sube por baja recombinacion, por estructura de linaje y, sobre todo, por error
#  de mapeo entre parologos. Los genes que pertenecen a familias multigenicas
#  quedan marcados, porque son los candidatos a artefacto.
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
log <- nuevo_log("16_marcadores"); log("=== 16 MARCADORES DIAGNOSTICOS ===")
v <- exigir_paso("variantes", "02_variantes.R")

ALT <- v$ALT; TOT <- v$TOT; INFO <- v$INFO; grupos <- v$grupos
usar <- which(v$n_cepas >= N_MIN_GRUPO_EST)
log("Grupos con n >= ", N_MIN_GRUPO_EST, ": ", length(usar), " de ", length(grupos))
sin_marcadores <- !length(usar)
if (sin_marcadores) log("Ningun grupo supera el umbral de cepas.")

tot_a <- rowSums(ALT); tot_n <- rowSums(TOT)
filas <- list()
for (k in usar) {
  a <- ALT[, k]; n <- TOT[, k]
  ok <- n >= 2 & (tot_n - n) >= 2
  if (!any(ok)) next
  p1 <- a[ok] / n[ok]
  p2 <- (tot_a[ok] - a[ok]) / (tot_n[ok] - n[ok])
  delta <- abs(p1 - p2)
  cand <- which(delta >= 0.5)
  if (!length(cand)) next
  ii <- which(ok)[cand]
  # Fisher exacto sobre la tabla 2x2 de conteos alelicos
  pv <- vapply(seq_along(ii), function(z) {
    m <- matrix(c(a[ii[z]], n[ii[z]] - a[ii[z]],
                  tot_a[ii[z]] - a[ii[z]],
                  (tot_n[ii[z]] - n[ii[z]]) - (tot_a[ii[z]] - a[ii[z]])), 2)
    if (any(m < 0)) return(NA_real_)
    tryCatch(fisher.test(round(m))$p.value, error = function(e) NA_real_)
  }, numeric(1))
  paj <- p.adjust(pv, method = "BH")
  filas[[length(filas) + 1L]] <- data.frame(
    grupo = grupos[k], chrom = INFO$chrom[ii], pos = INFO$pos[ii],
    ref = INFO$ref[ii], alt = INFO$alt[ii],
    frec_grupo = round(p1[cand], 4), frec_resto = round(p2[cand], 4),
    delta = round(delta[cand], 4), p = signif(pv, 3), p_ajustado = signif(paj, 3),
    stringsAsFactors = FALSE)
}
if (!sin_marcadores && !length(filas)) { log("Ningun sitio supero delta 0.5.")
  sin_marcadores <- TRUE }

if (!sin_marcadores) {
marc <- do.call(rbind, filas)
marc <- marc[order(-marc$delta), ]
sig <- marc[!is.na(marc$p_ajustado) & marc$p_ajustado < 0.05, ]
log("Sitios con delta >= 0.5: ", nrow(marc))
log("Significativos tras corregir por pruebas multiples: ", nrow(sig))
write.table(head(marc, 20000), file.path(OUT, "16_marcadores.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)

res <- aggregate(delta ~ grupo, marc, function(x) c(n = length(x), mx = max(x)))
res <- data.frame(grupo = res$grupo, marcadores = res$delta[, "n"],
                  delta_max = round(res$delta[, "mx"], 4), stringsAsFactors = FALSE)
res$n_cepas <- v$n_cepas[match(res$grupo, grupos)]
res <- res[order(-res$marcadores), ]
write.table(res, file.path(OUT, "16_resumen_grupos.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
log("\nGrupos con mas marcadores:")
for (i in seq_len(min(8, nrow(res))))
  log(sprintf("  %-30s %6d marcadores  delta max %.3f",
              substr(res$grupo[i], 1, 30), res$marcadores[i], res$delta_max[i]))

# --- Anotacion en genes ------------------------------------------------------
genes <- NULL
ann <- c(file.path(DATA, "SGD_features.tab"), file.path(DATA, "gene_result.txt"))
ann <- ann[file.exists(ann)][1]
if (is.na(ann)) {
  log("\nSin archivo de anotacion en ", DATA, ". No se anotan genes.")
} else {
  log("\nAnotacion: ", basename(ann))
  tb <- tryCatch(read.table(ann, sep = "\t", quote = "", comment.char = "#",
                            fill = TRUE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(tb)) log("  No se pudo leer la anotacion.") else {
    # se detectan las columnas de cromosoma, inicio, fin y nombre por contenido
    # Los nombres de cromosoma casi nunca coinciden entre la anotacion y el VCF.
    # gene_result.txt de NCBI usa numeros romanos, SGD_features.tab usa chrI, y
    # el VCF de eubayanus usa CBS12357_Chr01_polished. Cruzar por texto no
    # funciona y deja la tabla de genes vacia sin avisar, que es lo que pasaba.
    # Se normaliza todo a un numero de cromosoma.
    ROMANOS <- c(I=1,II=2,III=3,IV=4,V=5,VI=6,VII=7,VIII=8,IX=9,X=10,
                 XI=11,XII=12,XIII=13,XIV=14,XV=15,XVI=16)
    num_crom <- function(z) {
      z <- toupper(trimws(as.character(z)))
      # Primero el numero que sigue a "CHR", porque el nombre del contig suele
      # traer otros digitos antes: en CBS12357_CHR01_POLISHED el 12357 es la cepa
      # y el cromosoma es el 01. Tomar el primer numero da 12357 y no cruza nada.
      a1 <- suppressWarnings(as.integer(
        ifelse(grepl("CHR[^0-9]*[0-9]+", z), sub(".*CHR[^0-9]*([0-9]+).*", "\\1", z), NA)))
      r  <- unname(ROMANOS[sub("^CHR[^IVX]*", "", z)])
      a2 <- suppressWarnings(as.integer(
        ifelse(grepl("^[0-9]+$", z), z, NA)))
      out <- ifelse(!is.na(a1), a1, ifelse(!is.na(r), r, a2))
      out[!is.na(out) & (out < 1 | out > 32)] <- NA
      out
    }
    crom_vcf <- num_crom(INFO$chrom)
    log("  Cromosomas del VCF reconocidos: ",
        length(unique(na.omit(crom_vcf))), " de ", length(unique(INFO$chrom)))

    num <- vapply(tb, function(z) mean(!is.na(suppressWarnings(as.numeric(z)))), numeric(1))
    # Inicio y fin del gen: se busca el PAR de columnas numericas cuya diferencia
    # cae en el rango de un gen de levadura. Elegir las dos columnas de mayor
    # rango agarra GeneID y taxid, que son numeros grandes sin relacion con
    # coordenadas, y entonces cada gen abarca medio genoma.
    numc <- which(vapply(tb, function(z)
      mean(!is.na(suppressWarnings(as.numeric(z)))) > .9, logical(1)))
    mejor <- NULL; mejor_p <- -1
    for (i1 in numc) for (j1 in numc) {
      if (j1 <= i1) next
      v1 <- suppressWarnings(as.numeric(tb[[i1]])); v2 <- suppressWarnings(as.numeric(tb[[j1]]))
      d1 <- abs(v2 - v1)
      p <- mean(d1 >= 100 & d1 <= 5e4, na.rm = TRUE)
      if (is.finite(p) && p > mejor_p) { mejor_p <- p; mejor <- c(i1, j1) }
    }
    if (is.null(mejor) || mejor_p < .5) {
      log("  No se reconocieron columnas de coordenadas de gen (mejor ajuste ",
          round(100 * max(mejor_p, 0)), "%). No se anotan genes.")
      mejor <- c(NA, NA)
    }
    ini_g <- if (is.na(mejor[1])) rep(NA_real_, nrow(tb)) else suppressWarnings(as.numeric(tb[[mejor[1]]]))
    fin_g <- if (is.na(mejor[2])) rep(NA_real_, nrow(tb)) else suppressWarnings(as.numeric(tb[[mejor[2]]]))
    if (!is.na(mejor[1]))
      log("  Columnas de coordenadas: ", mejor[1], " y ", mejor[2],
          " (", round(100 * mejor_p), "% de los genes con largo plausible)")
    # Nombre del gen: se prefiere el simbolo corto tipo PDR5 o SNC2 sobre el
    # identificador de locus tipo DI49_0078, que no dice nada al leerlo.
    nom <- tb[[which.max(vapply(tb, function(z)
      mean(grepl("^[A-Z]{2,4}[0-9]{1,3}$", toupper(trimws(z)))), numeric(1)))]]
    # la columna de cromosoma es la que mas valores traduce a 1..16
    puntaje <- vapply(tb, function(z) mean(num_crom(z) %in% 1:16, na.rm = TRUE), numeric(1))
    crom_ann <- num_crom(tb[[which.max(puntaje)]])
    log("  Genes con cromosoma reconocido: ", sum(!is.na(crom_ann)))
    largo <- abs(fin_g - ini_g) + 1
    ok <- is.finite(ini_g) & is.finite(fin_g) & nzchar(nom) & !is.na(crom_ann)
    log("  Genes con coordenadas: ", sum(ok))
    if (sum(ok) > 10) {
      gi <- which(ok)
      # Un mismo SITIO puede ser marcador de varios grupos y aparece una vez por
      # grupo. Para la densidad en genes hay que contar SITIOS unicos, o el mismo
      # SNP se cuenta tantas veces como grupos lo declaren y el enriquecimiento
      # se dispara sin significar nada.
      sitios_u <- !duplicated(marc[, c("chrom", "pos")])
      mu2 <- marc[sitios_u, ]
      marc_crom <- num_crom(mu2$chrom)
      log("  Sitios marcadores unicos: ", nrow(mu2), " de ", nrow(marc), " filas")
      dens <- nrow(mu2) / max(sum(largo[gi], na.rm = TRUE), 1)
      cuenta <- integer(length(gi)); lug <- integer(length(gi))
      for (z in seq_along(gi)) {
        i2 <- gi[z]
        h <- !is.na(marc_crom) & marc_crom == crom_ann[i2] &
             mu2$pos >= min(ini_g[i2], fin_g[i2]) & mu2$pos <= max(ini_g[i2], fin_g[i2])
        cuenta[z] <- sum(h)
        lug[z] <- length(unique(marc$grupo[
          marc$chrom %in% mu2$chrom[h] & marc$pos %in% mu2$pos[h]]))
      }
      esp <- pmax(dens * largo[gi], 1e-9)
        genes <- data.frame(gen = nom[gi], chrom = crom_ann[gi], largo_pb = largo[gi],
          n_marcadores = cuenta, n_grupos = lug,
          enriquecimiento = round(cuenta / esp, 3),
          p_poisson = signif(ppois(cuenta - 1, esp, lower.tail = FALSE), 3),
          stringsAsFactors = FALSE)
        genes$p_poisson_aj <- signif(p.adjust(genes$p_poisson, "BH"), 3)
        # familia multigenica: prefijo de letras y numero, con tres o mas miembros
        pre <- ifelse(grepl("^[A-Za-z]+[0-9]+$", genes$gen),
                      sub("[0-9]+$", "", genes$gen), NA_character_)
        tt <- table(pre[!is.na(pre)])
        genes$familia <- ifelse(!is.na(pre) & pre %in% names(tt)[tt >= 3], pre, NA_character_)
        genes <- genes[genes$n_marcadores > 0, ]
        genes <- genes[order(-genes$enriquecimiento), ]
        write.table(genes, file.path(OUT, "16_genes.tsv"), sep = "\t",
                    row.names = FALSE, quote = FALSE)
        nf <- sum(!is.na(genes$familia))
        log("  Genes con al menos un marcador: ", nrow(genes))
        log("  En familias multigenicas: ", nf, " de ", nrow(genes),
            " | entre los 20 de mayor enriquecimiento: ",
            sum(!is.na(head(genes$familia, 20))))
        log("  El pipeline no filtra por mapeo multiple: esos genes son")
        log("  candidatos a artefacto de parologo antes que a senal biologica.")
        for (i in seq_len(min(8, nrow(genes))))
          log(sprintf("  %-14s %6d marcadores  %6.1fx  %s", genes$gen[i],
                      genes$n_marcadores[i], genes$enriquecimiento[i],
                      ifelse(is.na(genes$familia[i]), "", "familia multigenica")))
    }
  }
}

} else {
  marc <- NULL; res <- NULL; genes <- NULL
  log("Sin marcadores diagnosticos en esta escala. Los demas pasos siguen.")
}
saveRDS(list(marcadores = if (is.null(marc)) NULL else head(marc, 20000),
             resumen = res, genes = genes), paso("marcadores"))
log("\nSiguiente: 17_potencia.R")
cerrar_log(log)
