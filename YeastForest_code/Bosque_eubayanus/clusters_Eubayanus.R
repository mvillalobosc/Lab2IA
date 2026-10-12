# =============================================================================
# CLUSTERS DE ORFs POR TOPOLOGIA (MST-kNN) Y ENRIQUECIMIENTO: S. eubayanus
# Manuel: deja este archivo en la carpeta donde estan los resultados del bosque
# (Eubayanus_RF.csv.gz y Eubayanus_resumen.tsv) y ejecutalo con
# source("clusters_Eubayanus_2026-10-04.R") o como Job.
# Fecha: 2026-10-04. No crea carpetas ni archivos temporales.
# =============================================================================
# QUE HACE
# 1. Lee la matriz RF normalizada del bosque (todos vs todos) y agrupa los
#    arboles de ORFs con MST-kNN (mstknnclust::mst.knn). El NJ global
#    (REF_TOTAL) no entra al clustering porque no es un gen; su RF a cada
#    cluster queda en el resumen.
# 2. mst.knn deja fuera de la solucion los objetos que quedan solos (con RF hay
#    muchos empates y pasa seguido). Aqui cada uno vuelve como cluster de 1 ORF.
# 3. Los arboles sin ramas internas no tienen topologia que agrupar y su RF
#    entre ellos es 0/0 (indefinida). No entran a MST-kNN y quedan como
#    clusters de 1 ORF, marcados. Ningun ORF con arbol queda fuera de la tabla.
# 4. Enriquecimiento de cada cluster con 2 o mas genes anotados: prueba
#    hipergeometrica de una cola (exceso de genes con el termino) contra GO
#    (BP, MF y CC, cada gen con los ancestros de sus terminos, org.Sc.sgd.db) y
#    rutas KEGG de S. cerevisiae (KEGGREST, organismo 'sce'). Cada gen de
#    S. eubayanus usa las anotaciones de su ORF de S. cerevisiae: primero la
#    tabla orthologs_file si la das, despues el nombre sistematico de SGD
#    escrito en la anotacion del bosque (YAL001C) y por ultimo su nombre de
#    gen (EMP46, o producto Emp46p) si apunta a un unico ORF de SGD. Los genes
#    sin ortologo siguen en sus clusters, pero no entran al universo.
#    Universo de cada base = ORFs del bosque con al menos una anotacion en ella.
#    Se prueban terminos con 5 a 500 genes en el universo y con al menos un gen
#    en el cluster. FDR de Benjamini-Hochberg sobre todas las pruebas de cada
#    base. Un cluster de 1 gen no se prueba: no hay grupo, solo ese gen.
#
# RESULTADOS (en la misma carpeta de este script)
#   Eubayanus_clusters.tsv           un ORF por fila: cluster, tamano, origen
#   Eubayanus_clusters_resumen.tsv   un cluster por fila: tamano, RF media
#                                      dentro del cluster y al NJ global, y si
#                                      tiene terminos enriquecidos y cuales
#   Eubayanus_enriquecimiento.tsv    cada prueba: cluster, base, termino,
#                                      k de n en el cluster vs K de N, p y FDR
# =============================================================================

# -----------------------------------------------------------------------------
# 0. CONFIGURACION
# -----------------------------------------------------------------------------
CONFIG <- list(
  species = "Eubayanus",            # prefijo de los archivos del bosque y de salida
  forest_dir = NULL,                # NULL = misma carpeta de este script
  install_packages = TRUE,
  suggested_k = NULL,               # NULL: mst.knn elige k (el menor que conecta, tope floor(log(n)))
  databases = c("GO_BP", "GO_MF", "GO_CC", "KEGG"),
  min_term_size = 5L,               # genes del universo con el termino
  max_term_size = 500L,
  fdr = 0.05,
  gene_ids = "ortologos",           # los genes se llevan a su ORF de S. cerevisiae
  annotation = "~/EvolutiveEubayanus/DATA/GCA_003327605.1_genomic.gff", # la del bosque
  orthologs_file = NULL             # opcional: TSV de dos columnas, gen y ORF de SGD
)

# -----------------------------------------------------------------------------
# 1. DEPENDENCIAS Y UTILIDADES
# -----------------------------------------------------------------------------
ensure_packages <- function(install = TRUE) {
  cran <- c("data.table", "igraph", "mstknnclust", "R.utils")
  bioc <- c("AnnotationDbi", "org.Sc.sgd.db", "GO.db", "KEGGREST")
  missing <- function(x) x[!vapply(x, requireNamespace, logical(1), quietly = TRUE)]
  if (install && length(missing(cran)))
    install.packages(missing(cran), repos = "https://cloud.r-project.org")
  if (install && length(missing(bioc))) {
    if (!requireNamespace("BiocManager", quietly = TRUE))
      install.packages("BiocManager", repos = "https://cloud.r-project.org")
    BiocManager::install(missing(bioc), ask = FALSE, update = FALSE)
  }
  absent <- missing(c(cran, bioc))
  if (length(absent)) stop("Faltan paquetes: ", paste(absent, collapse = ", "))
}

logmsg <- function(...) {
  cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")
  flush.console()
}
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
resolve_file <- function(folder, file) {
  if (is.null(file)) return(NULL)
  path.expand(if (grepl("^(~|/|[A-Za-z]:)", file)) file else file.path(folder, file))
}
write_tsv <- function(x, file) data.table::fwrite(x, file, sep = "\t", na = "NA")

# Carpeta de este script: source(), Rscript o, en Jobs de RStudio, getwd().
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f) && length(f) == 1L && nzchar(f))
      return(dirname(normalizePath(path.expand(f))))
  }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}

# Muestra cada aviso en el registro en el momento.
with_logged_warnings <- function(expr) {
  seen <- character()
  withCallingHandlers(expr, warning = function(w) {
    msg <- conditionMessage(w)
    if (!msg %in% seen) { seen <<- c(seen, msg); logmsg("AVISO: ", msg) }
    invokeRestart("muffleWarning")
  })
}

# -----------------------------------------------------------------------------
# 2. RESULTADOS DEL BOSQUE
# -----------------------------------------------------------------------------
read_forest <- function(dir, name) {
  f_rf <- file.path(dir, paste0(name, "_RF.csv.gz"))
  f_res <- file.path(dir, paste0(name, "_resumen.tsv"))
  for (f in c(f_rf, f_res)) if (!file.exists(f)) stop("No encuentro ", f,
    ". Deja este script en la carpeta de los resultados del bosque o indica forest_dir.")
  res <- data.table::fread(f_res, colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  x <- data.table::fread(f_rf, header = TRUE, check.names = FALSE)
  rf <- as.matrix(x[, -1L, with = FALSE])
  dimnames(rf) <- list(as.character(x[[1L]]), names(x)[-1L])
  rm(x)
  if (!identical(rownames(rf), colnames(rf)))
    stop("La matriz RF no trae los mismos arboles en filas y columnas.")
  list(rf = rf, res = res)
}

# -----------------------------------------------------------------------------
# 3. MST-kNN SOBRE LA RF Y RESCATE DE LOS ORFs QUE QUEDAN SOLOS
# -----------------------------------------------------------------------------
cluster_trees <- function(rf, res, cfg) {
  genes <- res[tree_id != "REF_TOTAL" & status == "ok"]
  missing_rows <- setdiff(genes$tree_id, rownames(rf))
  if (length(missing_rows)) stop(length(missing_rows), " arboles del resumen no estan en la matriz RF (ej. ",
                                 missing_rows[1L], ").")
  no_splits <- genes[n_splits == 0L, tree_id]
  ids <- setdiff(genes$tree_id, no_splits)
  logmsg("Arboles de ORFs: ", fmt_n(nrow(genes)), " | entran a MST-kNN: ", fmt_n(length(ids)),
         " | sin ramas internas: ", fmt_n(length(no_splits)))
  D <- rf[ids, ids, drop = FALSE]
  diag(D) <- 0
  if (anyNA(D)) stop("Hay RF indefinidas entre arboles con ramas internas; revisar la matriz.")
  cl <- integer()
  if (length(ids) >= 2L) {
    logmsg("MST-kNN sobre ", fmt_n(length(ids)), " arboles (puede tardar con miles)")
    msgs <- utils::capture.output(r <- if (is.null(cfg$suggested_k)) mstknnclust::mst.knn(D)
                                       else mstknnclust::mst.knn(D, cfg$suggested_k))
    # Si todo sale suelto, mst.knn arma un solo grupo con todos: se descarta.
    if (!any(grepl("Only singletons", msgs))) cl <- r$cluster
  }
  member <- data.table::data.table(tree_id = names(cl), raw = as.integer(cl), origen = "MST-kNN")
  solos <- setdiff(ids, member$tree_id)
  if (length(solos)) logmsg("mst.knn dejo fuera ", fmt_n(length(solos)),
                            " arboles que quedaron solos: vuelven como clusters de 1 ORF")
  extra <- function(x, why) data.table::data.table(tree_id = x, raw = rep(NA_integer_, length(x)),
                                                   origen = rep(why, length(x)))
  member <- data.table::rbindlist(list(member, extra(solos, "solo en MST-kNN"),
                                       extra(no_splits, "sin ramas internas (RF indefinida)")))
  # Cada solitario recibe su propio numero; luego se numera por tamano.
  free <- is.na(member$raw)
  member$raw[free] <- max(c(0L, member$raw), na.rm = TRUE) + seq_len(sum(free))
  member[, tamano_cluster := .N, by = raw]
  member[, pos := match(tree_id, genes$tree_id)]
  ord <- member[, .(size = .N, first = min(pos), solo = all(origen != "MST-kNN"),
                    sin_ramas = all(origen == "sin ramas internas (RF indefinida)")), by = raw]
  data.table::setorder(ord, sin_ramas, solo, -size, first)
  member[, cluster := match(raw, ord$raw)]
  member <- merge(member, genes[, .(tree_id, orf, n_snps, n_splits, RF_al_global = RF_to_total)],
                  by = "tree_id", sort = FALSE)
  data.table::setorder(member, cluster, pos)
  if (nrow(member) != nrow(genes) || anyDuplicated(member$tree_id))
    stop("La tabla de clusters no cubre exactamente los ORFs del bosque.")
  member[, c("raw", "pos") := NULL]
  data.table::setcolorder(member, c("tree_id", "orf", "cluster", "tamano_cluster", "origen"))
  member
}

# RF media dentro de cada cluster (pares distintos) y al NJ global.
cluster_rf <- function(member, rf) {
  member[, .(RF_media_dentro = if (.N < 2L) NA_real_ else {
              m <- rf[tree_id, tree_id, drop = FALSE]; mean(m[upper.tri(m)], na.rm = TRUE) },
             RF_media_al_global = mean(RF_al_global, na.rm = TRUE)), by = cluster]
}

# -----------------------------------------------------------------------------
# 4. ANOTACIONES: GO (org.Sc.sgd.db + GO.db) Y KEGG (KEGGREST)
# -----------------------------------------------------------------------------
sgd_valid_orfs <- function() AnnotationDbi::keys(org.Sc.sgd.db::org.Sc.sgd.db, keytype = "ORF")

sgd_go <- function(orfs) {
  orfs <- intersect(unique(orfs), sgd_valid_orfs())
  if (!length(orfs)) return(NULL)
  go <- suppressMessages(AnnotationDbi::select(org.Sc.sgd.db::org.Sc.sgd.db, keys = orfs,
          keytype = "ORF", columns = c("GOALL", "ONTOLOGYALL")))
  go <- unique(data.table::as.data.table(go)[!is.na(GOALL),
          .(gene = ORF, term = GOALL, database = paste0("GO_", ONTOLOGYALL))])
  desc <- suppressMessages(AnnotationDbi::select(GO.db::GO.db, keys = unique(go$term),
            keytype = "GOID", columns = "TERM"))
  go[, description := desc$TERM[match(term, desc$GOID)]]
  go
}

kegg_pathways <- function(orfs) {
  links <- KEGGREST::keggLink("pathway", "sce")
  paths <- KEGGREST::keggList("pathway", "sce")
  kg <- data.table::data.table(gene = sub("^sce:", "", names(links)), term = sub("^path:", "", unname(links)))
  kg[, description := sub(" - Saccharomyces cerevisiae.*$", "",
                          unname(paths)[match(term, sub("^path:", "", names(paths)))])]
  unique(kg[gene %in% orfs])[, database := "KEGG"]
}

sgd_annotations <- function(orfs, cfg) {
  out <- list()
  if (any(grepl("^GO_", cfg$databases))) {
    logmsg("Anotaciones GO desde org.Sc.sgd.db")
    out$go <- sgd_go(orfs)
  }
  if ("KEGG" %in% cfg$databases) {
    logmsg("Rutas KEGG de S. cerevisiae desde KEGG (requiere internet)")
    out$kegg <- tryCatch(kegg_pathways(orfs), error = function(e) {
      logmsg("AVISO: no pude descargar KEGG (", conditionMessage(e), "); sigo sin KEGG."); NULL })
  }
  ann <- data.table::rbindlist(out, use.names = TRUE)
  if (nrow(ann)) ann <- ann[database %in% cfg$databases]
  ann
}

# -----------------------------------------------------------------------------
# 5. ORTOLOGOS EN S. cerevisiae (solo cuando los genes no son ORFs de SGD)
# -----------------------------------------------------------------------------
# Nombre estandar de SGD -> ORF, solo nombres que apuntan a un unico ORF.
sgd_name_table <- function() {
  db <- org.Sc.sgd.db::org.Sc.sgd.db
  kt <- intersect(c("GENENAME", "COMMON"), AnnotationDbi::keytypes(db))
  if (!length(kt)) return(data.table::data.table(name = character(), orf = character()))
  x <- suppressMessages(AnnotationDbi::select(db, keys = AnnotationDbi::keys(db, keytype = kt[1L]),
         keytype = kt[1L], columns = "ORF"))
  x <- unique(data.table::as.data.table(x)[!is.na(ORF), .(name = toupper(get(kt[1L])), orf = ORF)])
  x[, n := data.table::uniqueN(orf), by = name][n == 1L, .(name, orf)]
}

# Texto de la anotacion por gen: GFF (atributos por locus_tag, como en el bosque)
# o tabla (gene_result.txt de NCBI: GeneID, Symbol, Aliases, descripcion).
annotation_text <- function(path) {
  if (!file.exists(path)) stop("No existe la anotacion: ", path)
  txt <- readLines(path, warn = FALSE)
  dec <- function(x) vapply(x, function(s) tryCatch(utils::URLdecode(s), error = function(e) s),
                            "", USE.NAMES = FALSE)
  if (any(grepl("^##gff-version", head(txt, 20)))) {
    txt <- txt[!grepl("^#|^$", txt)]
    f <- strsplit(txt, "\t", fixed = TRUE)
    f <- f[lengths(f) == 9L & vapply(f, `[`, "", 3L) %in% c("gene", "mRNA", "CDS", "transcript", "pseudogene")]
    a <- vapply(f, `[`, "", 9L)
    get_attr <- function(key) {
      rx <- regexpr(paste0("(^|;)", key, "=[^;]*"), a)
      out <- rep(NA_character_, length(a))
      out[rx > 0] <- dec(sub(paste0("^;?", key, "="), "", regmatches(a, rx)))
      out
    }
    # Misma etiqueta que usa el bosque: locus_tag, si no Name, si no ID.
    loc <- get_attr("locus_tag"); nm <- get_attr("Name"); id <- get_attr("ID")
    key <- ifelse(!is.na(loc), loc, ifelse(!is.na(nm), nm, id))
    names_ <- paste(get_attr("gene"), get_attr("Name"), get_attr("gene_synonym"), get_attr("product"))
    dt <- data.table::data.table(gene = key, text = dec(a), names = names_)
  } else {
    x <- data.table::fread(path, quote = "\"", colClasses = "character")
    need <- c("GeneID", "Symbol")
    if (!all(need %in% names(x))) stop("La anotacion no es GFF ni trae GeneID y Symbol: ", path)
    extra <- intersect(c("Aliases", "description", "other_designations"), names(x))
    dt <- data.table::data.table(gene = x$GeneID,
      text = do.call(paste, c(list(x$Symbol), lapply(extra, function(k) x[[k]]))),
      names = paste(x$Symbol, if ("Aliases" %in% names(x)) gsub(",", " ", x$Aliases) else ""))
  }
  dt[!is.na(gene), .(text = paste(text, collapse = " "), names = paste(names, collapse = " ")), by = gene]
}

map_orthologs <- function(genes, cfg, folder) {
  map <- data.table::data.table(gene = genes, orf_sgd = NA_character_, como = NA_character_)
  valid <- sgd_valid_orfs()
  if (!is.null(cfg$orthologs_file)) {
    o <- data.table::fread(resolve_file(folder, cfg$orthologs_file), colClasses = "character")
    if (ncol(o) < 2L) stop("orthologs_file necesita dos columnas: gen y ORF de SGD.")
    o <- unique(o[, 1:2]); data.table::setnames(o, c("gene", "orf_sgd"))
    o <- o[orf_sgd %in% valid][, if (.N == 1L) .SD, by = gene]
    j <- match(map$gene, o$gene)
    map[!is.na(j), `:=`(orf_sgd = o$orf_sgd[j[!is.na(j)]], como = "tabla de ortologos")]
  }
  if (!is.null(cfg$annotation) && anyNA(map$orf_sgd)) {
    at <- annotation_text(resolve_file(folder, cfg$annotation))
    logmsg("  ORFs del bosque que aparecen en la anotacion: ", fmt_n(sum(genes %in% at$gene)),
           " de ", fmt_n(length(genes)))
    at <- at[gene %in% map$gene[is.na(map$orf_sgd)]]
    # Nombre sistematico de S. cerevisiae escrito en la anotacion (YAL001C, Q0045...).
    sys <- regmatches(at$text, gregexpr("\\b(Y[A-P][LR][0-9]{3}[WC](-[A-Z])?|Q[0-9]{4})\\b", at$text))
    at[, por_sistematico := vapply(sys, function(z) {
      z <- intersect(unique(z), valid); if (length(z) == 1L) z else NA_character_ }, "")]
    # Nombre estandar (gene=, Name=, producto tipo Emp46p) -> ORF unico en SGD.
    nt <- sgd_name_table()
    # Solo palabras con forma de nombre de gen de levadura (EMP46, MAL11, EMP46p).
    at[, por_nombre := vapply(strsplit(toupper(gsub("[^A-Za-z0-9-]+", " ", names)), " +"),
      function(z) { z <- sub("P$", "", z[grepl("^[A-Z]{3}[0-9]+P?$", z)])
                    o <- unique(nt$orf[match(unique(z), nt$name, nomatch = 0L)])
                    if (length(o) == 1L) o else NA_character_ }, "")]
    j <- match(map$gene, at$gene)
    s <- !is.na(j) & is.na(map$orf_sgd) & !is.na(at$por_sistematico[j])
    map[s, `:=`(orf_sgd = at$por_sistematico[j[s]], como = "nombre sistematico en la anotacion")]
    s <- !is.na(j) & is.na(map$orf_sgd) & !is.na(at$por_nombre[j])
    map[s, `:=`(orf_sgd = at$por_nombre[j[s]], como = "nombre de gen en la anotacion")]
  }
  n_ok <- sum(!is.na(map$orf_sgd))
  logmsg("Genes llevados a un ORF de S. cerevisiae: ", fmt_n(n_ok), " de ", fmt_n(nrow(map)),
         " (", sprintf("%.1f", 100*n_ok/max(1, nrow(map))), "%)",
         if (n_ok) paste0(" | ", paste(sprintf("%s: %s", names(table(map$como)), table(map$como)),
                                       collapse = " | ")))
  map
}

# -----------------------------------------------------------------------------
# 6. ENRIQUECIMIENTO: HIPERGEOMETRICA DE UNA COLA Y BENJAMINI-HOCHBERG POR BASE
# -----------------------------------------------------------------------------
enrich_clusters <- function(member, ann, cfg) {
  out <- list()
  for (db in intersect(cfg$databases, unique(ann$database))) {
    a <- unique(ann[database == db & gene %in% member$gene, .(gene, term)])
    if (!nrow(a)) next
    N_univ <- data.table::uniqueN(a$gene)
    tsize <- a[, .(K = .N), by = term][K >= cfg$min_term_size & K <= cfg$max_term_size]
    a <- a[term %in% tsize$term]
    m <- member[gene %in% unique(ann[database == db, gene])]
    nsz <- m[, .(n = .N), by = cluster][n >= 2L]
    if (!nrow(a) || !nrow(nsz)) next
    hits <- merge(a, m[cluster %in% nsz$cluster, .(gene, cluster)], by = "gene")
    hits <- hits[, .(k = .N, genes = paste(sort(gene), collapse = ";")), by = .(cluster, term)]
    hits <- merge(merge(hits, tsize, by = "term"), nsz, by = "cluster")
    hits[, `:=`(N = N_univ, p = stats::phyper(k - 1L, K, N_univ - K, n, lower.tail = FALSE))]
    hits[, `:=`(fdr = stats::p.adjust(p, "BH"), razon = (k/n)/(K/N_univ), base = db)]
    desc <- unique(ann[database == db, .(term, description)], by = "term")
    hits[, descripcion := desc$description[match(term, desc$term)]]
    logmsg("  ", db, ": universo ", fmt_n(N_univ), " genes | terminos probables ", fmt_n(nrow(tsize)),
           " | pruebas ", fmt_n(nrow(hits)), " | con FDR < ", cfg$fdr, ": ", fmt_n(sum(hits$fdr < cfg$fdr)))
    out[[db]] <- hits
  }
  res <- data.table::rbindlist(out, use.names = TRUE)
  if (!nrow(res)) return(res)
  data.table::setorder(res, fdr, p)
  res[, .(cluster, base, termino = term, descripcion, k_en_cluster = k, n_cluster_anotados = n,
          K_en_universo = K, N_universo = N, razon_enriquecimiento = razon, p, fdr, genes)]
}

summarize_clusters <- function(member, enr, rfc, cfg, ann) {
  # Un cluster se puede probar si en alguna base tiene 2 o mas genes anotados.
  per_db <- unique(ann[, .(gene, database)])[member[, .(gene, cluster)], on = "gene", nomatch = 0L]
  testable <- unique(per_db[, .N, by = .(cluster, database)][N >= 2L, cluster])
  s <- member[, .(tamano = .N, origen = origen[1L],
                  genes_anotados = sum(gene %in% ann$gene)), by = cluster]
  s <- merge(s, rfc, by = "cluster")
  sig <- if (nrow(enr)) enr[fdr < cfg$fdr] else enr
  top <- if (nrow(sig)) sig[order(fdr), .(terminos_FDR = .N,
           principales = paste(utils::head(sprintf("%s %s (FDR %.2g)", base, descripcion, fdr), 3L),
                               collapse = " | ")), by = cluster] else
           data.table::data.table(cluster = integer(), terminos_FDR = integer(), principales = character())
  s <- merge(s, top, by = "cluster", all.x = TRUE)
  s[is.na(terminos_FDR), terminos_FDR := 0L]
  s[, enriquecido := ifelse(tamano < 2L, "no aplica (1 gen)",
                     ifelse(!cluster %in% testable, "no aplica (menos de 2 genes anotados)",
                     ifelse(terminos_FDR > 0L, "si", "no")))]
  data.table::setorder(s, cluster)
  s
}

# -----------------------------------------------------------------------------
# 7. EJECUCION
# -----------------------------------------------------------------------------
run_clusters <- function(cfg = CONFIG) {
  started <- Sys.time(); name <- cfg$species
  out_dir <- normalizePath(script_dir())
  forest_dir <- if (is.null(cfg$forest_dir)) out_dir else normalizePath(path.expand(cfg$forest_dir))
  files <- stats::setNames(file.path(out_dir, paste0(name, c("_clusters.tsv", "_clusters_resumen.tsv",
                           "_enriquecimiento.tsv"))), c("clusters", "resumen", "enriquecimiento"))
  logmsg(name, " | bosque en ", forest_dir, " | resultados en ", out_dir)
  with_logged_warnings({
    logmsg("PREPARACION: comprobando/instalando paquetes requeridos")
    ensure_packages(cfg$install_packages)
    data.table::setDTthreads(0L)
    f <- read_forest(forest_dir, name)
    member <- cluster_trees(f$rf, f$res, cfg)
    rfc <- cluster_rf(member, f$rf)
    n_cl <- data.table::uniqueN(member$cluster)
    logmsg("Clusters: ", fmt_n(n_cl), " | con 2 o mas ORFs: ", fmt_n(sum(table(member$cluster) >= 2L)),
           " | de 1 ORF: ", fmt_n(sum(table(member$cluster) == 1L)))
    # La unidad de la prueba es el gen del bosque; sus anotaciones vienen de su ORF de SGD.
    if (identical(cfg$gene_ids, "sgd")) {
      member[, orf_sgd := orf]
    } else {
      logmsg("Ortologos en S. cerevisiae")
      map <- map_orthologs(member$orf, cfg, out_dir)
      member[, `:=`(orf_sgd = map$orf_sgd[match(orf, map$gene)], como_se_mapeo = map$como[match(orf, map$gene)])]
    }
    write_tsv(member, files[["clusters"]])
    logmsg("Guardado ", basename(files[["clusters"]]))
    if (all(is.na(member$orf_sgd))) stop("Ningun gen se pudo llevar a un ORF de S. cerevisiae: la anotacion",
      " no trae nombres de SGD. Los clusters quedaron guardados; para el enriquecimiento indica en",
      " orthologs_file una tabla de dos columnas (gen, ORF de SGD).")
    member[, gene := orf]
    ann_sgd <- sgd_annotations(unique(stats::na.omit(member$orf_sgd)), cfg)
    if (!nrow(ann_sgd)) stop("Ningun gen tiene anotaciones en las bases pedidas; no hay enriquecimiento que probar.")
    ann <- merge(member[!is.na(orf_sgd), .(gene, orf_sgd)], ann_sgd, by.x = "orf_sgd", by.y = "gene",
                 allow.cartesian = TRUE)[, orf_sgd := NULL]
    logmsg("Enriquecimiento por cluster")
    enr <- enrich_clusters(member[, .(gene, cluster)], ann, cfg)
    summ <- summarize_clusters(member, enr, rfc, cfg, ann)
    write_tsv(summ, files[["resumen"]])
    write_tsv(enr, files[["enriquecimiento"]])
    logmsg("Clusters probados: ", fmt_n(sum(summ$enriquecido %in% c("si", "no"))),
           " | con algun termino FDR < ", cfg$fdr, ": ", fmt_n(sum(summ$enriquecido == "si")))
  })
  logmsg("TERMINADO ", name, " | tiempo total ",
         format(round(difftime(Sys.time(), started, units = "mins"), 1)))
  for (f in files) logmsg("  ", basename(f))
  invisible(files)
}

if (Sys.getenv("PHYLO_LIBRARY_ONLY") != "1") RESULTADOS_CLUSTERS <- run_clusters(CONFIG)

# =============================================================================
# LECTURA DE RESULTADOS EN R (ejemplo)
# cl  <- data.table::fread("Eubayanus_clusters.tsv")
# res <- data.table::fread("Eubayanus_clusters_resumen.tsv")
# enr <- data.table::fread("Eubayanus_enriquecimiento.tsv")
# res[enriquecido == "si"]                 # clusters con terminos enriquecidos
# enr[fdr < 0.05][order(cluster, fdr)]     # los terminos de cada uno
# =============================================================================
