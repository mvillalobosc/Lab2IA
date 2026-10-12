# =============================================================================
# ORF CLUSTERS BY TOPOLOGY (MST-kNN) AND FUNCTIONAL ENRICHMENT: S. cerevisiae
# Place this file in the folder that holds the forest results
# (SCerevisiae_RF.csv.gz and SCerevisiae_resumen.tsv) and run it with
# source("clusters_SCerevisiae.R"), with Rscript or as an RStudio Job.
# Date: 2026-10-04. It creates no folders or temporary files.
# =============================================================================
# WHAT IT DOES
# 1. Reads the normalised RF matrix of the forest (all against all) and groups
#    the ORF trees with MST-kNN (mstknnclust::mst.knn). The genome-wide NJ
#    (REF_TOTAL) is not clustered because it is not a gene; its RF to each
#    cluster is kept in the summary.
# 2. mst.knn leaves out of the solution the objects that end up alone (with RF
#    there are many ties and this happens often). Here each one returns as a 1-ORF cluster.
# 3. Trees without internal branches have no topology to group and their RF
#    to each other is 0/0 (undefined). They do not enter MST-kNN and remain as
#    flagged 1-ORF clusters. No ORF with a tree is left out of the table.
# 4. Enrichment of each cluster with 2 or more annotated genes: one-sided
#    hypergeometric test (excess of genes with the term) against GO
#    (BP, MF and CC, each gene with the ancestors of its terms, org.Sc.sgd.db) and
#    S. cerevisiae KEGG pathways (KEGGREST, organism 'sce').
#    Universe of each database = forest ORFs with at least one annotation in it.
#    Terms with 5 to 500 genes in the universe and at least one gene in the
#    cluster are tested. Benjamini-Hochberg FDR over all the tests of each
#    database. A 1-gene cluster is not tested: there is no group, only that gene.
#
# OUTPUT (in the same folder as this script)
#   SCerevisiae_clusters.tsv           one ORF per row: cluster, size, origin
#   SCerevisiae_clusters_resumen.tsv   one cluster per row: size, mean RF
#                                      within the cluster and to the genome-wide NJ,
#                                      and whether it has enriched terms and which
#   SCerevisiae_enriquecimiento.tsv    each test: cluster, database, term,
#                                      k of n in the cluster vs K of N, p and FDR
# =============================================================================

# -----------------------------------------------------------------------------
# 0. CONFIGURATION
# -----------------------------------------------------------------------------
CONFIG <- list(
  species = "SCerevisiae",          # prefix of the forest and output files
  forest_dir = NULL,                # NULL = the folder of this script
  install_packages = TRUE,
  suggested_k = NULL,               # NULL: mst.knn chooses k (the smallest that connects, capped at floor(log(n)))
  databases = c("GO_BP", "GO_MF", "GO_CC", "KEGG"),
  min_term_size = 5L,               # genes of the universe with the term
  max_term_size = 500L,
  fdr = 0.05,
  gene_ids = "sgd",                 # "sgd": the forest ORFs are already SGD systematic names
  annotation = NULL,                # only if gene_ids = "ortologos"
  orthologs_file = NULL             # only if gene_ids = "ortologos"
)

# -----------------------------------------------------------------------------
# 1. DEPENDENCIES AND UTILITIES
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
  if (length(absent)) stop("Missing packages: ", paste(absent, collapse = ", "))
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

# Folder of this script: source(), Rscript or, in RStudio Jobs, getwd().
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

# Shows each warning in the log as it happens.
with_logged_warnings <- function(expr) {
  seen <- character()
  withCallingHandlers(expr, warning = function(w) {
    msg <- conditionMessage(w)
    if (!msg %in% seen) { seen <<- c(seen, msg); logmsg("WARNING: ", msg) }
    invokeRestart("muffleWarning")
  })
}

# -----------------------------------------------------------------------------
# 2. FOREST RESULTS
# -----------------------------------------------------------------------------
read_forest <- function(dir, name) {
  f_rf <- file.path(dir, paste0(name, "_RF.csv.gz"))
  f_res <- file.path(dir, paste0(name, "_resumen.tsv"))
  for (f in c(f_rf, f_res)) if (!file.exists(f)) stop("File not found: ", f,
    ". Place this script in the folder of the forest results or set forest_dir.")
  res <- data.table::fread(f_res, colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  x <- data.table::fread(f_rf, header = TRUE, check.names = FALSE)
  rf <- as.matrix(x[, -1L, with = FALSE])
  dimnames(rf) <- list(as.character(x[[1L]]), names(x)[-1L])
  rm(x)
  if (!identical(rownames(rf), colnames(rf)))
    stop("The RF matrix does not list the same trees in rows and columns.")
  list(rf = rf, res = res)
}

# -----------------------------------------------------------------------------
# 3. MST-kNN ON THE RF AND RECOVERY OF THE ORFs LEFT ALONE
# -----------------------------------------------------------------------------
cluster_trees <- function(rf, res, cfg) {
  genes <- res[tree_id != "REF_TOTAL" & status == "ok"]
  missing_rows <- setdiff(genes$tree_id, rownames(rf))
  if (length(missing_rows)) stop(length(missing_rows), " summary trees are not in the RF matrix (e.g. ",
                                 missing_rows[1L], ").")
  no_splits <- genes[n_splits == 0L, tree_id]
  ids <- setdiff(genes$tree_id, no_splits)
  logmsg("ORF trees: ", fmt_n(nrow(genes)), " | entering MST-kNN: ", fmt_n(length(ids)),
         " | without internal branches: ", fmt_n(length(no_splits)))
  D <- rf[ids, ids, drop = FALSE]
  diag(D) <- 0
  if (anyNA(D)) stop("There are undefined RF values between trees with internal branches; check the matrix.")
  cl <- integer()
  if (length(ids) >= 2L) {
    logmsg("MST-kNN on ", fmt_n(length(ids)), " trees (may take a while with thousands)")
    msgs <- utils::capture.output(r <- if (is.null(cfg$suggested_k)) mstknnclust::mst.knn(D)
                                       else mstknnclust::mst.knn(D, cfg$suggested_k))
    # If everything comes out unconnected, mst.knn builds a single group with all: it is discarded.
    if (!any(grepl("Only singletons", msgs))) cl <- r$cluster
  }
  member <- data.table::data.table(tree_id = names(cl), raw = as.integer(cl), origen = "MST-kNN")
  solos <- setdiff(ids, member$tree_id)
  if (length(solos)) logmsg("mst.knn left out ", fmt_n(length(solos)),
                            " trees that ended up alone: they return as 1-ORF clusters")
  extra <- function(x, why) data.table::data.table(tree_id = x, raw = rep(NA_integer_, length(x)),
                                                   origen = rep(why, length(x)))
  member <- data.table::rbindlist(list(member, extra(solos, "solo en MST-kNN"),
                                       extra(no_splits, "sin ramas internas (RF indefinida)")))
  # Each singleton gets its own number; clusters are then numbered by size.
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
    stop("The cluster table does not cover exactly the ORFs of the forest.")
  member[, c("raw", "pos") := NULL]
  data.table::setcolorder(member, c("tree_id", "orf", "cluster", "tamano_cluster", "origen"))
  member
}

# Mean RF within each cluster (distinct pairs) and to the genome-wide NJ.
cluster_rf <- function(member, rf) {
  member[, .(RF_media_dentro = if (.N < 2L) NA_real_ else {
              m <- rf[tree_id, tree_id, drop = FALSE]; mean(m[upper.tri(m)], na.rm = TRUE) },
             RF_media_al_global = mean(RF_al_global, na.rm = TRUE)), by = cluster]
}

# -----------------------------------------------------------------------------
# 4. ANNOTATIONS: GO (org.Sc.sgd.db + GO.db) AND KEGG (KEGGREST)
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
    logmsg("GO annotations from org.Sc.sgd.db")
    out$go <- sgd_go(orfs)
  }
  if ("KEGG" %in% cfg$databases) {
    logmsg("S. cerevisiae KEGG pathways from KEGG (requires internet)")
    out$kegg <- tryCatch(kegg_pathways(orfs), error = function(e) {
      logmsg("WARNING: could not download KEGG (", conditionMessage(e), "); continuing without KEGG."); NULL })
  }
  ann <- data.table::rbindlist(out, use.names = TRUE)
  if (nrow(ann)) ann <- ann[database %in% cfg$databases]
  ann
}

# -----------------------------------------------------------------------------
# 5. ORTHOLOGUES IN S. cerevisiae (only when the genes are not SGD ORFs)
# -----------------------------------------------------------------------------
# SGD standard name -> ORF, only names that point to a single ORF.
sgd_name_table <- function() {
  db <- org.Sc.sgd.db::org.Sc.sgd.db
  kt <- intersect(c("GENENAME", "COMMON"), AnnotationDbi::keytypes(db))
  if (!length(kt)) return(data.table::data.table(name = character(), orf = character()))
  x <- suppressMessages(AnnotationDbi::select(db, keys = AnnotationDbi::keys(db, keytype = kt[1L]),
         keytype = kt[1L], columns = "ORF"))
  x <- unique(data.table::as.data.table(x)[!is.na(ORF), .(name = toupper(get(kt[1L])), orf = ORF)])
  x[, n := data.table::uniqueN(orf), by = name][n == 1L, .(name, orf)]
}

# Annotation text per gene: GFF (attributes by locus_tag, as in the forest)
# or table (NCBI gene_result.txt: GeneID, Symbol, Aliases, description).
annotation_text <- function(path) {
  if (!file.exists(path)) stop("Annotation not found: ", path)
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
    # Same label as the forest: locus_tag, otherwise Name, otherwise ID.
    loc <- get_attr("locus_tag"); nm <- get_attr("Name"); id <- get_attr("ID")
    key <- ifelse(!is.na(loc), loc, ifelse(!is.na(nm), nm, id))
    names_ <- paste(get_attr("gene"), get_attr("Name"), get_attr("gene_synonym"), get_attr("product"))
    dt <- data.table::data.table(gene = key, text = dec(a), names = names_)
  } else {
    x <- data.table::fread(path, quote = "\"", colClasses = "character")
    need <- c("GeneID", "Symbol")
    if (!all(need %in% names(x))) stop("The annotation is neither a GFF nor a table with GeneID and Symbol: ", path)
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
    if (ncol(o) < 2L) stop("orthologs_file needs two columns: gene and SGD ORF.")
    o <- unique(o[, 1:2]); data.table::setnames(o, c("gene", "orf_sgd"))
    o <- o[orf_sgd %in% valid][, if (.N == 1L) .SD, by = gene]
    j <- match(map$gene, o$gene)
    map[!is.na(j), `:=`(orf_sgd = o$orf_sgd[j[!is.na(j)]], como = "tabla de ortologos")]
  }
  if (!is.null(cfg$annotation) && anyNA(map$orf_sgd)) {
    at <- annotation_text(resolve_file(folder, cfg$annotation))
    logmsg("  Forest ORFs found in the annotation: ", fmt_n(sum(genes %in% at$gene)),
           " of ", fmt_n(length(genes)))
    at <- at[gene %in% map$gene[is.na(map$orf_sgd)]]
    # S. cerevisiae systematic name written in the annotation (YAL001C, Q0045...).
    sys <- regmatches(at$text, gregexpr("\\b(Y[A-P][LR][0-9]{3}[WC](-[A-Z])?|Q[0-9]{4})\\b", at$text))
    at[, por_sistematico := vapply(sys, function(z) {
      z <- intersect(unique(z), valid); if (length(z) == 1L) z else NA_character_ }, "")]
    # Standard name (gene=, Name=, product such as Emp46p) -> single ORF in SGD.
    nt <- sgd_name_table()
    # Only words shaped like yeast gene names (EMP46, MAL11, EMP46p).
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
  logmsg("Genes mapped to an S. cerevisiae ORF: ", fmt_n(n_ok), " of ", fmt_n(nrow(map)),
         " (", sprintf("%.1f", 100*n_ok/max(1, nrow(map))), "%)",
         if (n_ok) paste0(" | ", paste(sprintf("%s: %s", names(table(map$como)), table(map$como)),
                                       collapse = " | ")))
  map
}

# -----------------------------------------------------------------------------
# 6. ENRICHMENT: ONE-SIDED HYPERGEOMETRIC TEST AND BENJAMINI-HOCHBERG PER DATABASE
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
    logmsg("  ", db, ": universe ", fmt_n(N_univ), " genes | testable terms ", fmt_n(nrow(tsize)),
           " | tests ", fmt_n(nrow(hits)), " | with FDR < ", cfg$fdr, ": ", fmt_n(sum(hits$fdr < cfg$fdr)))
    out[[db]] <- hits
  }
  res <- data.table::rbindlist(out, use.names = TRUE)
  if (!nrow(res)) return(res)
  data.table::setorder(res, fdr, p)
  res[, .(cluster, base, termino = term, descripcion, k_en_cluster = k, n_cluster_anotados = n,
          K_en_universo = K, N_universo = N, razon_enriquecimiento = razon, p, fdr, genes)]
}

summarize_clusters <- function(member, enr, rfc, cfg, ann) {
  # A cluster can be tested if it has 2 or more annotated genes in some database.
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
# 7. RUN
# -----------------------------------------------------------------------------
run_clusters <- function(cfg = CONFIG) {
  started <- Sys.time(); name <- cfg$species
  out_dir <- normalizePath(script_dir())
  forest_dir <- if (is.null(cfg$forest_dir)) out_dir else normalizePath(path.expand(cfg$forest_dir))
  files <- stats::setNames(file.path(out_dir, paste0(name, c("_clusters.tsv", "_clusters_resumen.tsv",
                           "_enriquecimiento.tsv"))), c("clusters", "resumen", "enriquecimiento"))
  logmsg(name, " | forest in ", forest_dir, " | results in ", out_dir)
  with_logged_warnings({
    logmsg("SETUP: checking/installing the required packages")
    ensure_packages(cfg$install_packages)
    data.table::setDTthreads(0L)
    f <- read_forest(forest_dir, name)
    member <- cluster_trees(f$rf, f$res, cfg)
    rfc <- cluster_rf(member, f$rf)
    n_cl <- data.table::uniqueN(member$cluster)
    logmsg("Clusters: ", fmt_n(n_cl), " | with 2 or more ORFs: ", fmt_n(sum(table(member$cluster) >= 2L)),
           " | with 1 ORF: ", fmt_n(sum(table(member$cluster) == 1L)))
    # The unit of the test is the forest gene; its annotations come from its SGD ORF.
    if (identical(cfg$gene_ids, "sgd")) {
      member[, orf_sgd := orf]
    } else {
      logmsg("Orthologues in S. cerevisiae")
      map <- map_orthologs(member$orf, cfg, out_dir)
      member[, `:=`(orf_sgd = map$orf_sgd[match(orf, map$gene)], como_se_mapeo = map$como[match(orf, map$gene)])]
    }
    write_tsv(member, files[["clusters"]])
    logmsg("Saved ", basename(files[["clusters"]]))
    if (all(is.na(member$orf_sgd))) stop("No gene could be mapped to an S. cerevisiae ORF: the annotation",
      " has no SGD names. The clusters were saved; for the enrichment, give in",
      " orthologs_file a two-column table (gene, SGD ORF).")
    member[, gene := orf]
    ann_sgd <- sgd_annotations(unique(stats::na.omit(member$orf_sgd)), cfg)
    if (!nrow(ann_sgd)) stop("No gene has annotations in the requested databases; there is no enrichment to test.")
    ann <- merge(member[!is.na(orf_sgd), .(gene, orf_sgd)], ann_sgd, by.x = "orf_sgd", by.y = "gene",
                 allow.cartesian = TRUE)[, orf_sgd := NULL]
    logmsg("Enrichment per cluster")
    enr <- enrich_clusters(member[, .(gene, cluster)], ann, cfg)
    summ <- summarize_clusters(member, enr, rfc, cfg, ann)
    write_tsv(summ, files[["resumen"]])
    write_tsv(enr, files[["enriquecimiento"]])
    logmsg("Clusters tested: ", fmt_n(sum(summ$enriquecido %in% c("si", "no"))),
           " | with some term at FDR < ", cfg$fdr, ": ", fmt_n(sum(summ$enriquecido == "si")))
  })
  logmsg("FINISHED ", name, " | total time ",
         format(round(difftime(Sys.time(), started, units = "mins"), 1)))
  for (f in files) logmsg("  ", basename(f))
  invisible(files)
}

if (Sys.getenv("PHYLO_LIBRARY_ONLY") != "1") RESULTADOS_CLUSTERS <- run_clusters(CONFIG)

# =============================================================================
# READING THE RESULTS IN R (example)
# cl  <- data.table::fread("SCerevisiae_clusters.tsv")
# res <- data.table::fread("SCerevisiae_clusters_resumen.tsv")
# enr <- data.table::fread("SCerevisiae_enriquecimiento.tsv")
# res[enriquecido == "si"]                 # clusters with enriched terms
# enr[fdr < 0.05][order(cluster, fdr)]     # the terms of each one
# =============================================================================
