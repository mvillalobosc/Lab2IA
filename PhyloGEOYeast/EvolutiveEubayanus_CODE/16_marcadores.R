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
    num <- vapply(tb, function(z) mean(!is.na(suppressWarnings(as.numeric(z)))), numeric(1))
    cn <- which(num > .9)
    if (length(cn) < 2) log("  Formato de anotacion no reconocido.") else {
      ini <- suppressWarnings(as.numeric(tb[[cn[1]]])); fin <- suppressWarnings(as.numeric(tb[[cn[2]]]))
      nom <- tb[[which.max(vapply(tb, function(z) mean(grepl("^[A-Z]{2,4}[0-9]", z)), numeric(1)))]]
      crom <- tb[[which.max(vapply(tb, function(z) mean(z %in% unique(INFO$chrom)), numeric(1)))]]
      largo <- abs(fin - ini) + 1
      ok <- is.finite(ini) & is.finite(fin) & nzchar(nom)
      log("  Genes con coordenadas: ", sum(ok))
      if (sum(ok) > 10) {
        gi <- which(ok)
        dens <- nrow(marc) / max(sum(largo[gi], na.rm = TRUE), 1)
        cuenta <- integer(length(gi)); lug <- integer(length(gi))
        for (z in seq_along(gi)) {
          i2 <- gi[z]
          h <- marc$chrom == crom[i2] & marc$pos >= min(ini[i2], fin[i2]) &
               marc$pos <= max(ini[i2], fin[i2])
          cuenta[z] <- sum(h); lug[z] <- length(unique(marc$grupo[h]))
        }
        esp <- pmax(dens * largo[gi], 1e-9)
        genes <- data.frame(gen = nom[gi], chrom = crom[gi], largo_pb = largo[gi],
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
}

} else {
  marc <- NULL; res <- NULL; genes <- NULL
  log("Sin marcadores diagnosticos en esta escala. Los demas pasos siguen.")
}
saveRDS(list(marcadores = if (is.null(marc)) NULL else head(marc, 20000),
             resumen = res, genes = genes), paso("marcadores"))
log("\nSiguiente: 17_potencia.R")
cerrar_log(log)
