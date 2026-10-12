# =============================================================================
# MST-kNN GROUPS OF S. eubayanus WITHOUT ENRICHMENT (THOSE REPORTED IN THE PAPER)
# Place this file in the folder of the forest results
# (Eubayanus_RF.csv.gz and Eubayanus_resumen.tsv) and
# run it with source("grupos_Eubayanus.R"). It groups the trees with the same
# MST-kNN functions as clusters_SCerevisiae.R (singletons return as 1-ORF groups)
# and does not test functional enrichment, which the paper does not report for
# S. eubayanus. It writes
# Eubayanus_clusters.tsv and Eubayanus_clusters_resumen.tsv; in the summary,
# enriquecido = "pendiente" is the flag that preparar_app.R and the app read as
# "not computed".
# Date: 2026-10-10.
# =============================================================================

CONFIG <- list(
  species = "Eubayanus",            # prefix of the forest and output files
  install_packages = TRUE,
  suggested_k = NULL                # NULL: mst.knn chooses k (the smallest that connects, capped at floor(log(n)))
)

logmsg <- function(...) {
  cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")
  flush.console()
}
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
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

local({
  dir <- script_dir()
  pk <- c("data.table", "igraph", "mstknnclust")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta) && CONFIG$install_packages) install.packages(falta, repos = "https://cloud.r-project.org")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) stop("Missing packages: ", paste(falta, collapse = ", "))
  cfg <- CONFIG
  bosque <- read_forest(dir, cfg$species)
  member <- cluster_trees(bosque$rf, bosque$res, cfg)
  rfc <- cluster_rf(member, bosque$rf)
  member[, orf_sgd := NA_character_]
  member[, como_se_mapeo := NA_character_]
  logmsg("Groups: ", data.table::uniqueN(member$cluster), " | with 2 or more ORFs: ", sum(table(member$cluster) >= 2L),
         " | with 1 ORF: ", sum(table(member$cluster) == 1L))
  write_tsv(member, file.path(dir, paste0(cfg$species, "_clusters.tsv")))
  # summary with the same columns as summarize_clusters in clusters_SCerevisiae.R
  s <- member[, .(tamano = .N, origen = origen[1L], genes_anotados = NA_integer_), by = cluster]
  s <- merge(s, rfc, by = "cluster")
  s[, `:=`(terminos_FDR = NA_integer_, principales = NA_character_, enriquecido = "pendiente")]
  data.table::setorder(s, cluster)
  write_tsv(s, file.path(dir, paste0(cfg$species, "_clusters_resumen.tsv")))
  logmsg("done")
})
