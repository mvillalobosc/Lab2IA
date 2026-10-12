# =============================================================================
# ANALYSES OF THE PHYLOGENETIC FOREST REPORTED IN THE PAPER (S. cerevisiae or S. eubayanus)
# Place this file in the folder of the forest results (where
# <prefix>_resumen.tsv, _arboles.nwk, _RF.csv.gz, _clusters.tsv and _enriquecimiento.tsv are)
# next to bosque_<species>.R, and run it with
# source("publicar_bosque.R"). The same file works in both folders: the
# species comes from the <prefix>_resumen.tsv it finds (SCerevisiae or Eubayanus) and,
# with it, the scripts, stages and files listed in ESPECIES (below). It runs the
# stages in CONFIG$etapas; each one writes its tables <prefix>_pub_*.tsv and can
# be repeated on its own. The strain TSV and the annotation are searched in this folder
# and in the one above (where preparar_app.R uses them). Date: 2026-10-10.
# =============================================================================
# STAGES
#  A resolution  Resolution as a confounder of the MST-kNN groups: SNPs, resolution,
#                RF to the reference and support per group; Kruskal-Wallis between groups.
#  B thresholds  MST-kNN repeated only with the ORFs above SNP and resolution
#                thresholds; how many groups remain and ARI against the full
#                clustering (over the ORFs that enter).
#  D conflict    Gene-genome map: branches with support >= conflicto_min_respaldo and at
#                least conflicto_min_cepas strains on their smaller side that are NOT in the
#                reference (conflict supported by other genes),
#                ordered by chromosome; runs of contiguous ORFs in conflict with an
#                empirical p from permutations within each chromosome; and which strain
#                groups those branches separate (if a strain file is available).
#  F earlier     Comparison with the earlier alignment-based forest (folder with
#                <ORF>.nwk): RF between the old and the new tree of the same ORF.
# DEFINITIONS: the same as in the forest. RF(A,B) = (sA+sB-2c)/(sA+sB). Support of a
# branch = % of the OTHER ORFs with that bipartition. Resolution = internal branches/(n-3).
# None of these stages recomputes the forest or reads the VCF.
# =============================================================================

CONFIG <- list(
  species = NULL,                          # prefix of the forest files; NULL = the one found in this folder
  # Whatever is left as NULL is taken from ESPECIES for the species:
  etapas = NULL,                           # stages to run (A, B, D, F)
  script_bosque = NULL,                    # forest functions (splits, NJ)
  cepas = NULL,                            # strain + layers; D uses the first layer
  anotacion = NULL,                        # coordinates for D: SGD_features.tab or gene_result.txt
  umbrales_snps = NULL,                    # B: minimum number of SNPs of the ORF
  umbrales_resolucion = c(0, 0.10, 0.25),  # B: minimum resolution
  nulo_semilla = 2026L,                    # D: seed of the permutations
  conflicto_min_respaldo = 5,              # D: % of the other ORFs needed to call a branch "supported"
  conflicto_min_cepas = 5L,                # D: minimum strains on the smaller side (drops pairs and trios of nearly identical strains)
  conflicto_min_tramo = 3L,                # D: contiguous ORFs in conflict needed to call it a run
  conflicto_permutaciones = 1000L,
  bosque_anterior = "Arboles",             # F: folder with one <ORF>.nwk per gene of the alignment-based forest
  hilos = 2L
)
# Values of each species, the same used for the tables of the paper. In
# cerevisiae D orders the ORFs by their systematic name (anotacion = NULL); in
# eubayanus it uses the coordinates of gene_result.txt (the first one it finds).
# F only applies to cerevisiae, the species with an earlier alignment-based forest.
ESPECIES <- list(
  SCerevisiae = list(etapas = c("A", "B", "D", "F"),
                     script_bosque = "bosque_SCerevisiae.R",
                     cepas = "cepas_cerevisiae.tsv", anotacion = NULL, umbrales_snps = c(0L, 30L, 100L)),
  Eubayanus = list(etapas = c("A", "B", "D"),
                   script_bosque = "bosque_Eubayanus.R",
                   cepas = "cepas_eubayanus.tsv", umbrales_snps = c(0L, 10L, 30L),
                   anotacion = c("gene_result.txt", "gene_result_eubayanus.txt", "DATA/gene_result.txt"))
)

# -----------------------------------------------------------------------------
# 1. UTILITIES
# -----------------------------------------------------------------------------
ensure_packages <- function() {
  pk <- c("data.table", "ape", "digest", "Matrix", "mstknnclust", "R.utils")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) stop("Missing packages: ", paste(falta, collapse = ", "))
}
logmsg <- function(...) { cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = ""); flush.console() }
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
safe_names <- function(x) make.unique(gsub("[^A-Za-z0-9_.-]", "_", x), sep = "__")
read_tsv <- function(f, ...) data.table::fread(f, sep = "\t", na.strings = c("NA", ""), ...)
write_tsv <- function(x, file) { data.table::fwrite(x, file, sep = "\t", na = "NA"); logmsg("  Saved ", basename(file)) }
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) { f <- sys.frame(i)$ofile; if (is.character(f) && length(f) == 1L && nzchar(f)) return(dirname(normalizePath(path.expand(f)))) }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}
resolve_file <- function(base, file) { if (is.null(file)) return(NULL); path.expand(if (grepl("^(~|/|[A-Za-z]:)", file)) file else file.path(base, file)) }
out_file <- function(ctx, sufijo) file.path(ctx$dir, paste0(ctx$pref, "_pub_", sufijo))
# First file that exists among the candidates, in this folder or in the one above.
buscar_archivo <- function(dir, archivos) {
  for (a in archivos) for (p in unique(c(resolve_file(dir, a), resolve_file(dirname(dir), a)))) if (file.exists(p)) return(p)
  NULL
}
# Species of the folder (the prefix with _resumen.tsv and _RF.csv.gz) and values of
# ESPECIES for everything that CONFIG leaves as NULL.
completar_config <- function(cfg, dir) {
  if (is.null(cfg$species)) {
    pref <- sub("_resumen\\.tsv$", "", list.files(dir, pattern = "_resumen\\.tsv$"))
    pref <- pref[file.exists(file.path(dir, paste0(pref, "_RF.csv.gz")))]
    if (length(pref) != 1L) stop("Could not tell the species in ", dir, ": set CONFIG$species (prefixes with _resumen.tsv and _RF.csv.gz: ",
                                 if (length(pref)) paste(pref, collapse = ", ") else "none", ")")
    cfg$species <- pref
  }
  base <- ESPECIES[[cfg$species]]
  if (is.null(base)) base <- list(etapas = c("A", "B", "D"), umbrales_snps = c(0L, 30L, 100L))   # another species: fill in CONFIG by hand
  for (k in names(base)) if (is.null(cfg[[k]])) cfg[k] <- list(base[[k]])
  cfg
}

# Loads the functions of another script without running it (PHYLO_LIBRARY_ONLY=1), in its own environment.
cargar_script <- function(path) {
  if (!file.exists(path)) stop("File not found: ", path)
  old <- Sys.getenv("PHYLO_LIBRARY_ONLY"); Sys.setenv(PHYLO_LIBRARY_ONLY = "1"); on.exit(Sys.setenv(PHYLO_LIBRARY_ONLY = old))
  env <- new.env(parent = globalenv()); sys.source(path, envir = env); env
}
leer_matriz <- function(path) {
  x <- data.table::fread(path, header = TRUE, check.names = FALSE)
  m <- as.matrix(x[, -1L, with = FALSE]); dimnames(m) <- list(as.character(x[[1L]]), names(x)[-1L]); rm(x)
  if (!identical(rownames(m), colnames(m))) stop("The matrix ", basename(path), " does not have the same ids in rows and columns.")
  m
}
# Adjusted Rand index between two partitions (label vectors of the same length).
rand_ajustado <- function(a, b) {
  tab <- table(a, b); n <- sum(tab)
  comb2 <- function(x) x * (x - 1) / 2
  sij <- sum(comb2(tab)); si <- sum(comb2(rowSums(tab))); sj <- sum(comb2(colSums(tab)))
  esperado <- si * sj / comb2(n); maximo <- (si + sj) / 2
  if (maximo == esperado) return(1)
  (sij - esperado) / (maximo - esperado)
}
# Bipartitions of a tree with their support (node.label), using tree_splits from the forest,
# and the size of the smaller side of each one.
splits_con_respaldo <- function(tree, labels, env) {
  s <- env$tree_splits(tree, labels)
  n <- length(labels)
  s[, respaldo := if (is.null(tree$node.label)) NA_real_ else suppressWarnings(as.numeric(tree$node.label[node - n]))]
  t <- ape::reorder.phylo(tree, "postorder"); size <- c(rep(1L, n), integer(t$Nnode))
  for (e in seq_len(nrow(t$edge))) size[t$edge[e, 1L]] <- size[t$edge[e, 1L]] + size[t$edge[e, 2L]]
  s[, lado_menor := pmin(size[node], n - size[node])]
  s
}

# -----------------------------------------------------------------------------
# 2. CONTEXT: summary, clusters, trees, strains
# -----------------------------------------------------------------------------
abrir_contexto <- function(cfg) {
  dir <- script_dir(); pref <- cfg$species
  f <- function(s) file.path(dir, paste0(pref, s))
  for (s in c("_resumen.tsv", "_arboles.nwk", "_RF.csv.gz")) if (!file.exists(f(s))) stop("File not found: ", f(s))
  res <- read_tsv(f("_resumen.tsv"), colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  ok <- res[status == "ok"][order(newick_line)]
  cl <- if (file.exists(f("_clusters.tsv"))) read_tsv(f("_clusters.tsv"), colClasses = list(character = c("tree_id", "orf", "origen"))) else NULL
  enr <- if (file.exists(f("_enriquecimiento.tsv"))) read_tsv(f("_enriquecimiento.tsv"), colClasses = list(character = c("base", "termino", "descripcion", "genes"))) else NULL
  cepas <- NULL; fc <- buscar_archivo(dir, cfg$cepas)
  if (!is.null(fc) && file.exists(fc)) {
    t <- read_tsv(fc, colClasses = "character", encoding = "UTF-8")
    cepas <- data.table::data.table(cepa = safe_names(trimws(t[[1L]])), grupo = trimws(t[[2L]]))
    cepas[is.na(grupo) | !nzchar(grupo), grupo := NA_character_]
    logmsg("  Strains with ", names(t)[2L], ": ", sum(!is.na(cepas$grupo)), " of ", nrow(cepas))
  }
  env_bosque <- if (!is.null(cfg$script_bosque) && file.exists(resolve_file(dir, cfg$script_bosque))) cargar_script(resolve_file(dir, cfg$script_bosque)) else NULL
  logmsg("Forest ", pref, ": ", fmt_n(nrow(ok) - 1L), " ORFs with a tree | groups: ", if (is.null(cl)) "none" else data.table::uniqueN(cl$cluster),
         " | enrichment tests: ", if (is.null(enr)) "none" else fmt_n(nrow(enr)), "")
  list(dir = dir, pref = pref, cfg = cfg, res = res, ok = ok, cl = cl, enr = enr, cepas = cepas, env = env_bosque,
       f_rf = f("_RF.csv.gz"), f_nwk = f("_arboles.nwk"))
}
# RF and trees are read only when a stage needs them (they are large).
ctx_rf <- function(ctx) { if (is.null(ctx$rf)) { logmsg("  Reading the all-against-all RF"); ctx$rf <- leer_matriz(ctx$f_rf)[ctx$ok$tree_id, ctx$ok$tree_id] }; ctx }
ctx_arboles <- function(ctx) {
  if (is.null(ctx$arboles)) {
    logmsg("  Reading ", basename(ctx$f_nwk), " (", fmt_n(nrow(ctx$ok)), " trees)")
    tr <- ape::read.tree(ctx$f_nwk)
    if (length(tr) != nrow(ctx$ok)) stop("The .nwk has ", length(tr), " trees and the summary ", nrow(ctx$ok))
    names(tr) <- ctx$ok$tree_id; ctx$arboles <- tr; ctx$labels <- sort(tr[[1L]]$tip.label)
  }
  ctx
}

# -----------------------------------------------------------------------------
# A. RESOLUTION AS A CONFOUNDER OF THE GROUPS
# -----------------------------------------------------------------------------
etapa_A <- function(ctx) {
  if (is.null(ctx$cl)) { logmsg("A: no clusters, skipped"); return(ctx) }
  m <- merge(ctx$cl[, .(tree_id, cluster, tamano_cluster)],
             ctx$ok[, .(tree_id, n_snps, n_splits, resolution, RF_to_total, forest_branch_mean_pct)], by = "tree_id")
  por <- m[, .(orfs = .N, snps_mediana = as.numeric(median(n_snps)), snps_q1 = as.numeric(quantile(n_snps, .25)), snps_q3 = as.numeric(quantile(n_snps, .75)),
               resolucion_mediana = median(resolution), pct_resolucion_bajo_10 = 100 * mean(resolution < 0.10),
               rf_ref_mediana = median(RF_to_total), respaldo_mediana = median(forest_branch_mean_pct)), by = cluster][order(cluster)]
  multi <- m[tamano_cluster >= 2L]
  kw <- function(v) if (data.table::uniqueN(multi$cluster) >= 2L) stats::kruskal.test(multi[[v]], factor(multi$cluster))$p.value else NA_real_
  pruebas <- data.table::data.table(
    variable = c("n_snps", "resolution", "RF_to_total", "forest_branch_mean_pct"),
    p_kruskal_entre_grupos = c(kw("n_snps"), kw("resolution"), kw("RF_to_total"), kw("forest_branch_mean_pct")),
    rho_spearman_tamano_grupo = c(stats::cor(multi$tamano_cluster, multi$n_snps, method = "spearman"),
                                  stats::cor(multi$tamano_cluster, multi$resolution, method = "spearman"),
                                  stats::cor(multi$tamano_cluster, multi$RF_to_total, method = "spearman"),
                                  stats::cor(multi$tamano_cluster, multi$forest_branch_mean_pct, method = "spearman")))
  # Kruskal eta squared (how much of the variance the group explains), to report effect size and not only p
  eta <- function(v) { h <- stats::kruskal.test(multi[[v]], factor(multi$cluster))$statistic; k <- data.table::uniqueN(multi$cluster); n <- nrow(multi); max(0, (h - k + 1) / (n - k)) }
  pruebas[, eta2_kruskal := c(eta("n_snps"), eta("resolution"), eta("RF_to_total"), eta("forest_branch_mean_pct"))]
  write_tsv(por, out_file(ctx, "A_resolucion_por_grupo.tsv"))
  write_tsv(pruebas, out_file(ctx, "A_resolucion_pruebas.tsv"))
  logmsg("A: eta2 of resolution between groups = ", sprintf("%.3f", pruebas$eta2_kruskal[2]),
         " | largest group: median SNPs ", por$snps_mediana[1L], ", ", sprintf("%.0f", por$pct_resolucion_bajo_10[1L]), "% with resolution < 10%")
  ctx
}

# -----------------------------------------------------------------------------
# B. MST-kNN WITH SNP AND RESOLUTION THRESHOLDS
# -----------------------------------------------------------------------------
mstknn_subconjunto <- function(rf, ids) {
  D <- rf[ids, ids, drop = FALSE]; diag(D) <- 0
  if (anyNA(D)) stop("Undefined RF values in the subset")
  msgs <- utils::capture.output(r <- mstknnclust::mst.knn(D))
  cl <- if (any(grepl("Only singletons", msgs))) integer() else r$cluster
  member <- data.table::data.table(tree_id = names(cl), cluster = as.integer(cl))
  solos <- setdiff(ids, member$tree_id)   # as in the clustering script: each singleton is a group
  if (length(solos)) member <- rbind(member, data.table::data.table(tree_id = solos, cluster = max(c(0L, member$cluster)) + seq_along(solos)))
  member[, tamano := .N, by = cluster]
  ord <- member[, .(tamano = tamano[1L]), by = cluster][order(-tamano, cluster)]
  member[, cluster := match(cluster, ord$cluster)][]
}
etapa_B <- function(ctx) {
  if (is.null(ctx$cl)) { logmsg("B: no clusters, skipped"); return(ctx) }
  ctx <- ctx_rf(ctx); cfg <- ctx$cfg
  genes <- ctx$ok[tree_id != "REF_TOTAL"]
  completo <- ctx$cl$cluster; names(completo) <- ctx$cl$tree_id
  filas <- list(); miembros <- list()
  for (s in cfg$umbrales_snps) for (r in cfg$umbrales_resolucion) {
    ids <- genes[n_snps >= s & resolution >= r, tree_id]
    if (length(ids) < 10L) { logmsg("  SNPs>=", s, " res>=", r, ": only ", length(ids), " ORFs, skipped"); next }
    logmsg("  MST-kNN with SNPs >= ", s, " and resolution >= ", r, ": ", fmt_n(length(ids)), " ORFs")
    m <- if (s == 0 && r == 0) data.table::data.table(tree_id = ctx$cl$tree_id, cluster = ctx$cl$cluster)[, tamano := .N, by = cluster][tree_id %in% ids]
         else mstknn_subconjunto(ctx$rf, ids)
    ari <- rand_ajustado(m$cluster, completo[m$tree_id])
    tam <- m[, .(tamano = .N), by = cluster][order(-tamano)]
    # which group of the full clustering each new group overlaps most (the 5 largest)
    top <- m[cluster %in% tam$cluster[seq_len(min(5L, nrow(tam)))]][, .(n = .N, completo = names(which.max(table(completo[tree_id]))),
      pct_en_completo = 100 * max(table(completo[tree_id])) / .N), by = cluster][order(-n)]
    filas[[length(filas) + 1L]] <- data.table::data.table(umbral_snps = s, umbral_resolucion = r, orfs = length(ids),
      grupos = nrow(tam), grupos_2mas = sum(tam$tamano >= 2L), grupo_mayor = tam$tamano[1L], pct_en_grupo_mayor = 100 * tam$tamano[1L] / length(ids),
      ari_vs_completo = ari, mayores = paste(sprintf("G%d(%d)=G%s %.0f%%", top$cluster, top$n, top$completo, top$pct_en_completo), collapse = "; "))
    miembros[[length(miembros) + 1L]] <- data.table::data.table(umbral_snps = s, umbral_resolucion = r, tree_id = m$tree_id,
      orf = genes$orf[match(m$tree_id, genes$tree_id)], cluster = m$cluster, cluster_completo = unname(completo[m$tree_id]))
  }
  tabla <- data.table::rbindlist(filas); write_tsv(tabla, out_file(ctx, "B_umbrales.tsv"))
  write_tsv(data.table::rbindlist(miembros), out_file(ctx, "B_umbrales_miembros.tsv"))
  logmsg("B: ARI against the full clustering per threshold: ", paste(sprintf("SNPs>=%d/res>=%.2f: %.2f", tabla$umbral_snps, tabla$umbral_resolucion, tabla$ari_vs_completo), collapse = " | "))
  ctx
}

# -----------------------------------------------------------------------------
# D. GENE-GENOME MAP: SUPPORTED BRANCHES THAT CONTRADICT THE REFERENCE
# -----------------------------------------------------------------------------
# Position of each ORF: annotation (SGD_features.tab or gene_result.txt) or, without one,
# the S. cerevisiae systematic name (Y + chromosome A..P + arm L/R + number).
posiciones_orfs <- function(ctx) {
  orfs <- ctx$ok[tree_id != "REF_TOTAL", orf]
  f <- buscar_archivo(ctx$dir, ctx$cfg$anotacion)
  if (!is.null(f) && file.exists(f)) {
    if (grepl("SGD_features", basename(f), ignore.case = TRUE)) {
      txt <- readLines(f, warn = FALSE); txt <- txt[!grepl("^#|^$", txt)]
      x <- data.table::fread(text = paste(txt, collapse = "\n"), header = FALSE, sep = "\t", quote = "", fill = TRUE)[toupper(V2) == "ORF"]
      pos <- data.table::data.table(orf = as.character(x$V4), chr = as.character(x$V9), inicio = pmin(as.numeric(x$V10), as.numeric(x$V11)))
    } else {
      x <- data.table::fread(f, quote = "\"", colClasses = "character")
      sym <- x$Symbol; id <- ifelse(is.na(sym) | !nzchar(sym), x$GeneID, sym); dup <- id %in% id[duplicated(id)]; id[dup] <- paste0(id[dup], "_", x$GeneID[dup])
      pos <- data.table::data.table(orf = id, chr = x$chromosome, inicio = suppressWarnings(as.numeric(x$start_position_on_the_genomic_accession)))
    }
    pos <- unique(pos[orf %in% orfs & !is.na(inicio)], by = "orf")
    logmsg("  Positions from ", basename(f), ": ", nrow(pos), " of ", length(orfs), " ORFs")
    return(pos)
  }
  m <- regmatches(orfs, regexec("^Y([A-P])([LR])([0-9]{3})[WC]", orfs))
  ok <- lengths(m) == 4L
  if (!any(ok)) stop("D: no annotation and the names are not S. cerevisiae systematic names; set CONFIG$anotacion")
  chr <- vapply(m[ok], `[`, "", 2L); brazo <- vapply(m[ok], `[`, "", 3L); num <- as.integer(vapply(m[ok], `[`, "", 4L))
  pos <- data.table::data.table(orf = orfs[ok], chr = paste0("chr", as.roman(match(chr, LETTERS[1:16]))), inicio = ifelse(brazo == "L", -num, num))
  logmsg("  Positions from the systematic name: ", nrow(pos), " of ", length(orfs), " ORFs (relative order within the chromosome)")
  pos
}
etapa_D <- function(ctx) {
  if (is.null(ctx$env)) stop("D needs CONFIG$script_bosque to compute bipartitions")
  ctx <- ctx_arboles(ctx); cfg <- ctx$cfg; env <- ctx$env; labels <- ctx$labels; n <- length(labels)
  logmsg("  Bipartitions of the reference and of each ORF (takes a few minutes)")
  ref <- splits_con_respaldo(ctx$arboles[["REF_TOTAL"]], labels, env); en_ref <- ref$key
  grupo_de <- if (!is.null(ctx$cepas)) ctx$cepas$grupo[match(labels, ctx$cepas$cepa)] else NULL
  filas <- list(); ramas <- list(); started <- Sys.time()
  genes <- ctx$ok[tree_id != "REF_TOTAL"]
  for (i in seq_len(nrow(genes))) {
    id <- genes$tree_id[i]; tr <- ctx$arboles[[id]]
    s <- splits_con_respaldo(tr, labels, env)
    s[, en_referencia := key %in% en_ref]
    resp <- s[!is.na(respaldo) & respaldo >= cfg$conflicto_min_respaldo & lado_menor >= cfg$conflicto_min_cepas]
    conf <- resp[en_referencia == FALSE]
    fila <- data.table::data.table(tree_id = id, orf = genes$orf[i], n_snps = genes$n_snps[i], n_ramas = nrow(s),
      ramas_respaldadas_total = sum(!is.na(s$respaldo) & s$respaldo >= cfg$conflicto_min_respaldo),
      ramas_respaldadas = nrow(resp), ramas_respaldadas_en_ref = sum(resp$en_referencia), ramas_conflicto = nrow(conf),
      max_respaldo_conflicto = if (nrow(conf)) max(conf$respaldo) else NA_real_, RF_to_total = genes$RF_to_total[i])
    if (nrow(conf)) {
      # smaller side of each branch in conflict and which strain group dominates that side
      t <- ape::reorder.phylo(tr, "postorder"); desc <- vector("list", n + t$Nnode)
      for (k in seq_len(n)) desc[[k]] <- match(t$tip.label[k], labels)
      for (e in seq_len(nrow(t$edge))) desc[[t$edge[e, 1]]] <- c(desc[[t$edge[e, 1]]], desc[[t$edge[e, 2]]])
      for (q in seq_len(nrow(conf))) {
        lado <- desc[[conf$node[q]]]; if (length(lado) > n / 2) lado <- setdiff(seq_len(n), lado)
        comp <- if (!is.null(grupo_de)) table(grupo_de[lado], useNA = "no") else NULL
        ramas[[length(ramas) + 1L]] <- data.table::data.table(tree_id = id, orf = genes$orf[i], respaldo = conf$respaldo[q], cepas_lado_menor = length(lado),
          grupo_dominante = if (length(comp)) names(which.max(comp)) else NA_character_,
          pct_grupo_dominante = if (length(comp)) 100 * max(comp) / length(lado) else NA_real_,
          grupos_presentes = if (length(comp)) sum(comp > 0) else NA_integer_,
          cepas = paste(sort(labels[lado]), collapse = ";"))
      }
    }
    filas[[i]] <- fila
    if (i %% 500L == 0L) logmsg("    ", i, "/", nrow(genes), " ORFs | ", format(round(difftime(Sys.time(), started, units = "mins"), 1)))
  }
  tabla <- data.table::rbindlist(filas)
  pos <- posiciones_orfs(ctx)
  tabla <- merge(tabla, pos, by = "orf", all.x = TRUE)
  data.table::setorder(tabla, chr, inicio, na.last = TRUE)
  tabla[, conflicto := ramas_conflicto >= 1L]
  # runs of contiguous ORFs in conflict within each chromosome
  tramos <- list(); n_tramos_obs <- 0L
  contar_tramos <- function(flag) { r <- rle(flag); sum(r$values & r$lengths >= cfg$conflicto_min_tramo) }
  for (ch in unique(stats::na.omit(tabla$chr))) {
    t <- tabla[chr == ch & !is.na(inicio)]
    r <- rle(t$conflicto); fin <- cumsum(r$lengths); ini <- fin - r$lengths + 1L
    for (j in which(r$values & r$lengths >= cfg$conflicto_min_tramo))
      tramos[[length(tramos) + 1L]] <- data.table::data.table(chr = ch, desde = t$orf[ini[j]], hasta = t$orf[fin[j]], orfs = r$lengths[j],
        max_respaldo = max(t$max_respaldo_conflicto[ini[j]:fin[j]], na.rm = TRUE), genes = paste(t$orf[ini[j]:fin[j]], collapse = ";"))
    n_tramos_obs <- n_tramos_obs + contar_tramos(t$conflicto)
  }
  # empirical p: permute the conflict flag within each chromosome
  set.seed(cfg$nulo_semilla); nulo <- integer(cfg$conflicto_permutaciones)
  por_chr <- split(tabla[!is.na(inicio)]$conflicto, tabla[!is.na(inicio)]$chr)
  for (b in seq_len(cfg$conflicto_permutaciones)) nulo[b] <- sum(vapply(por_chr, function(v) contar_tramos(sample(v)), integer(1)))
  p_tramos <- (1 + sum(nulo >= n_tramos_obs)) / (cfg$conflicto_permutaciones + 1)
  tramos_dt <- if (length(tramos)) data.table::rbindlist(tramos)[order(-orfs, -max_respaldo)] else data.table::data.table(chr = character(), desde = character(), hasta = character(), orfs = integer(), max_respaldo = numeric(), genes = character())
  ramas_dt <- if (length(ramas)) data.table::rbindlist(ramas)[order(-respaldo)] else NULL
  write_tsv(tabla, out_file(ctx, "D_conflicto_por_orf.tsv"))
  write_tsv(tramos_dt, out_file(ctx, "D_conflicto_tramos.tsv"))
  if (!is.null(ramas_dt)) {
    write_tsv(ramas_dt, out_file(ctx, "D_conflicto_ramas.tsv"))
    if (!is.null(grupo_de)) {
      porg <- ramas_dt[!is.na(grupo_dominante), .(ramas_en_conflicto = .N, orfs = data.table::uniqueN(orf), respaldo_mediana = median(respaldo),
        pct_dominante_mediana = median(pct_grupo_dominante)), by = grupo_dominante][order(-ramas_en_conflicto)]
      write_tsv(porg, out_file(ctx, "D_conflicto_por_grupo_cepas.tsv"))
    }
  }
  resumen <- data.table::data.table(orfs = nrow(tabla), orfs_con_ramas_respaldadas = sum(tabla$ramas_respaldadas > 0),
    orfs_en_conflicto = sum(tabla$conflicto), tramos_observados = n_tramos_obs, tramos_esperados_media = mean(nulo), p_empirico_tramos = p_tramos,
    min_respaldo = cfg$conflicto_min_respaldo, min_cepas_lado_menor = cfg$conflicto_min_cepas, min_tramo = cfg$conflicto_min_tramo)
  write_tsv(resumen, out_file(ctx, "D_conflicto_resumen.tsv"))
  logmsg("D: ORFs in conflict (some branch with support >= ", cfg$conflicto_min_respaldo, "%, smaller side >= ", cfg$conflicto_min_cepas, " strains, absent from the reference): ", sum(tabla$conflicto),
         " of ", nrow(tabla), " | runs of >= ", cfg$conflicto_min_tramo, " ORFs: ", n_tramos_obs, " (expected ", sprintf("%.1f", mean(nulo)), ", p = ", sprintf("%.3f", p_tramos), ")")
  ctx
}

# -----------------------------------------------------------------------------
# F. COMPARISON WITH THE EARLIER FOREST (ALIGNMENTS)
# -----------------------------------------------------------------------------
etapa_F <- function(ctx) {
  if (is.null(ctx$env)) stop("F needs CONFIG$script_bosque to compute bipartitions")
  dir_old <- resolve_file(ctx$dir, ctx$cfg$bosque_anterior)
  if (is.null(dir_old) || !dir.exists(dir_old)) { logmsg("F: the folder of the earlier forest does not exist (", dir_old, "), skipped"); return(ctx) }
  ctx <- ctx_arboles(ctx); env <- ctx$env; labels <- ctx$labels
  viejos <- sub("\\.nwk$", "", list.files(dir_old, pattern = "\\.nwk$"))
  genes <- ctx$ok[tree_id != "REF_TOTAL" & orf %in% viejos]
  logmsg("  F: ", fmt_n(length(viejos)), " earlier trees, ", fmt_n(nrow(genes)), " ORFs shared with the new forest")
  ref <- env$tree_splits(ctx$arboles[["REF_TOTAL"]], labels)$key
  filas <- list(); started <- Sys.time()
  for (i in seq_len(nrow(genes))) {
    o <- genes$orf[i]
    told <- tryCatch(ape::read.tree(file.path(dir_old, paste0(o, ".nwk"))), error = function(e) NULL)
    if (is.null(told) || !setequal(told$tip.label, labels)) { filas[[i]] <- data.table::data.table(orf = o, motivo = "different strains or unreadable file"); next }
    told <- ape::unroot(told)
    so <- env$tree_splits(told, labels)$key; sn <- env$tree_splits(ctx$arboles[[genes$tree_id[i]]], labels)$key
    c_on <- sum(so %in% sn); c_or <- sum(so %in% ref)
    filas[[i]] <- data.table::data.table(orf = o, motivo = "", n_snps = genes$n_snps[i], ramas_anterior = length(so), ramas_nuevo = length(sn), compartidas = c_on,
      rf_anterior_vs_nuevo = if (length(so) + length(sn)) (length(so) + length(sn) - 2 * c_on) / (length(so) + length(sn)) else NA_real_,
      pct_ramas_nuevo_en_anterior = if (length(sn)) 100 * c_on / length(sn) else NA_real_,
      rf_anterior_vs_referencia = if (length(so) + length(ref)) (length(so) + length(ref) - 2 * c_or) / (length(so) + length(ref)) else NA_real_,
      rf_nuevo_vs_referencia = genes$RF_to_total[i])
    if (i %% 500L == 0L) logmsg("    ", i, "/", nrow(genes), " | ", format(round(difftime(Sys.time(), started, units = "mins"), 1)))
  }
  tabla <- data.table::rbindlist(filas, fill = TRUE)
  ok <- tabla[motivo == ""]
  resumen <- data.table::data.table(orfs_comparados = nrow(ok), rf_anterior_vs_nuevo_mediana = median(ok$rf_anterior_vs_nuevo, na.rm = TRUE),
    rf_anterior_vs_nuevo_q1 = quantile(ok$rf_anterior_vs_nuevo, .25, na.rm = TRUE), rf_anterior_vs_nuevo_q3 = quantile(ok$rf_anterior_vs_nuevo, .75, na.rm = TRUE),
    rho_rf_vs_snps = suppressWarnings(stats::cor(ok$rf_anterior_vs_nuevo, ok$n_snps, method = "spearman", use = "complete.obs")),
    rho_rf_referencia_anterior_vs_nuevo = suppressWarnings(stats::cor(ok$rf_anterior_vs_referencia, ok$rf_nuevo_vs_referencia, method = "spearman", use = "complete.obs")),
    pct_ramas_nuevo_en_anterior_mediana = median(ok$pct_ramas_nuevo_en_anterior, na.rm = TRUE))
  write_tsv(tabla, out_file(ctx, "F_bosque_anterior_por_orf.tsv")); write_tsv(resumen, out_file(ctx, "F_bosque_anterior_resumen.tsv"))
  logmsg("F: RF earlier vs new (median) = ", sprintf("%.3f", resumen$rf_anterior_vs_nuevo_mediana),
         " | rho(RF, SNPs) = ", sprintf("%.3f", resumen$rho_rf_vs_snps), " | rho of the RF to the reference between forests = ", sprintf("%.3f", resumen$rho_rf_referencia_anterior_vs_nuevo))
  ctx
}

# -----------------------------------------------------------------------------
# RUN
# -----------------------------------------------------------------------------
publicar <- function(cfg = CONFIG) {
  inicio <- Sys.time(); ensure_packages(); data.table::setDTthreads(cfg$hilos)
  cfg <- completar_config(cfg, script_dir())
  logmsg("Species ", cfg$species, " | stages: ", paste(cfg$etapas, collapse = ", "))
  ctx <- abrir_contexto(cfg)
  fallas <- character()
  for (e in cfg$etapas) {
    logmsg("== Stage ", e)
    # If a stage fails (for example because an input is missing), it is logged and the others continue.
    ctx <- tryCatch(switch(e, A = etapa_A(ctx), B = etapa_B(ctx), D = etapa_D(ctx), F = etapa_F(ctx), stop("Unknown stage: ", e)),
                    error = function(err) { logmsg("ERROR in stage ", e, ": ", conditionMessage(err)); fallas <<- c(fallas, e); ctx })
  }
  if (length(fallas)) logmsg("Stages with errors: ", paste(fallas, collapse = ", "))
  logmsg("FINISHED ", cfg$species, " | ", format(round(difftime(Sys.time(), inicio, units = "mins"), 1)))
  invisible(ctx)
}
if (Sys.getenv("PUBLICAR_LIBRARY_ONLY") != "1") RESULTADO_PUB <- publicar(CONFIG)
