# =============================================================================
# PREPARE THE DATA OF THE YEASTFOREST APP (S. cerevisiae and S. eubayanus)
# Place this file next to the folders of the forest results
# (Bosque_cerevisiae and Bosque_eubayanus) and run it with source("preparar_app.R").
# It writes the data/ folder read by index.html (next to this script). It can be run again
# whenever the results change: it rebuilds only the species whose files changed,
# unless rehacer = TRUE.
# Date: 2026-10-05.
# =============================================================================
# INPUTS PER SPECIES (folder of the forest results, prefix of the species)
#   <prefix>_resumen.tsv                   required
#   <prefix>_arboles.nwk                   required (line 1 = genome-wide NJ)
#   <prefix>_RF.csv.gz                     required
#   <prefix>_concordancia.csv.gz           required
#   <prefix>_distancias_geneticas.csv.gz   required
#   <prefix>_clusters.tsv                  optional (from clusters_SCerevisiae.R or grupos_Eubayanus.R)
#   <prefix>_clusters_resumen.tsv          optional
#   <prefix>_enriquecimiento.tsv           optional (if missing, the app shows that it was not computed)
#   <prefix>_genes_sin_ubicar.tsv          optional (S. eubayanus only)
# OPTIONAL FILES SET IN CONFIG
#   cepas:  TSV: first column strain, then one column per categorical layer
#           (Lineage, Country, Locality, Host...). The name of each column is the one
#           shown by the app, so it is in English. The first layer colours the ring
#           by default; the others are chosen in the app. Strains not listed are
#           "Unlabelled". Names are normalised as in the forest (characters
#           outside A-Z a-z 0-9 _ . - become "_").
#   genes:  gene annotation for the gene card. Accepts SGD_features.tab,
#           NCBI gene_result.txt, gene_info.json (earlier app) or a TSV with
#           the columns orf, nombre, descripcion, enlace.
# OUTPUT: data/especies.js and, per species, data/<clave>/ with
#   arboles.js     one record per tree (summary metrics, cluster, projections)
#   vecinos.js     k nearest neighbours by RF, with concordance in both directions
#   grupos.js      MST-kNN clusters, medoid of each one and enrichment
#   cepas.js       strains, group of each one and genetically closest strains
#   genes.js       name, description and link of each annotated gene
#   omitidos.js    ORFs without a tree (with the reason) and genes not located
#   arboles/<tree_id>.js    one Newick per tree, with the support on the nodes
# Each file is JSON wrapped in a call BF.load("<clave>", <json>), so
# index.html loads them as <script> and works with a double click (file://), where the
# browser does not allow fetch(). The Newick of each tree is a JSON string.
# =============================================================================

CONFIG <- list(
  salida = "data",                    # data folder of the app (next to index.html)
  k_vecinos = 15L,                    # neighbours per tree
  k_cepas = 10L,                      # closest strains per strain (genetic distance)
  perplexity = 50,                    # t-SNE
  umap_vecinos = 15L,                 # UMAP
  semilla = 2026L,
  fdr_guardar = 0.25,                 # enrichment tests that are kept (plus the top 3 per cluster)
  hilos = 2L,
  rehacer = FALSE,                    # TRUE: rebuilds everything even without changes
  especies = list(
    list(clave = "cerevisiae", nombre = "Saccharomyces cerevisiae", corto = "S. cerevisiae",
         prefijo = "SCerevisiae", carpeta = "Bosque_cerevisiae",
         cepas = "cepas_cerevisiae.tsv",      # isolate, Population (Peter et al. 2018)
         genes = c("SGD_features.tab", "Bosque_cerevisiae/DATA/SGD_features.tab", "genes_cerevisiae.tsv"),  # uses the first one that exists
         enlace_gen = "https://www.yeastgenome.org/locus/{orf}",
         fuente = "1,011 isolates (Peter et al. 2018); VCF 1011Matrix; ORFs from SGD_features.tab"),
    list(clave = "eubayanus", nombre = "Saccharomyces eubayanus", corto = "S. eubayanus",
         prefijo = "Eubayanus", carpeta = "Bosque_eubayanus",
         cepas = "cepas_eubayanus.tsv",       # isolate, Lineage, Country, Locality, Host, Substrate, Continent (MetaData_SEu.csv)
         genes = c("gene_result_eubayanus.txt", "Bosque_eubayanus/DATA/gene_result.txt"),  # uses the first one that exists
         enlace_gen = "https://www.ncbi.nlm.nih.gov/gene/?term={orf}+Saccharomyces+eubayanus",
         fuente = "471 isolates; VCF filtered_eub on CBS 12357 (GCA_003327605.1); NCBI genes (FM1318) located by sequence")
  )
)

# -----------------------------------------------------------------------------
# 1. DEPENDENCIES AND UTILITIES
# -----------------------------------------------------------------------------
ensure_packages <- function() {
  pk <- c("data.table", "jsonlite", "ape", "Rtsne", "uwot", "R.utils")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) stop("Missing packages: ", paste(falta, collapse = ", "))
}
logmsg <- function(...) { cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = ""); flush.console() }
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
safe_names <- function(x) make.unique(gsub("[^A-Za-z0-9_.-]", "_", x), sep = "__")
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f) && length(f) == 1L && nzchar(f)) return(dirname(normalizePath(path.expand(f))))
  }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}
resolve_file <- function(base, file) {
  if (is.null(file) || !length(file)) return(NULL)
  path.expand(ifelse(grepl("^(~|/|[A-Za-z]:)", file), file, file.path(base, file)))
}
# Among several candidates, the first that exists (if none exists, the first, to report it).
first_existing <- function(files) { if (is.null(files)) return(NULL); ok <- files[file.exists(files)]; if (length(ok)) ok[1L] else files[1L] }
write_json <- function(x, file) jsonlite::write_json(x, file, auto_unbox = TRUE, na = "null",
                                                     digits = NA, null = "null", pretty = FALSE)
# App data file: JSON wrapped in BF.load("<clave>", ...), loadable as <script>.
write_js <- function(x, key, file) {
  js <- jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", digits = NA, null = "null", pretty = FALSE)
  writeLines(paste0('BF.load("', key, '",', js, ');'), file, useBytes = TRUE)
}
read_tsv <- function(f, ...) data.table::fread(f, sep = "\t", na.strings = c("NA", ""), ...)

# Square matrix from CSV.gz (first column = row ids; header = column ids).
leer_matriz <- function(path) {
  x <- data.table::fread(path, header = TRUE, check.names = FALSE)
  m <- as.matrix(x[, -1L, with = FALSE])
  dimnames(m) <- list(as.character(x[[1L]]), names(x)[-1L])
  rm(x); invisible(gc())
  if (!identical(rownames(m), colnames(m))) stop("The matrix ", basename(path), " does not have the same ids in rows and columns.")
  m
}

# Fingerprint of the inputs of a species: if it does not change, nothing is rebuilt.
huella <- function(files) {
  files <- files[file.exists(files)]
  i <- file.info(files)
  paste(basename(files), i$size, as.numeric(i$mtime), collapse = "|")
}

# -----------------------------------------------------------------------------
# 2. SUMMARY, TREES AND STRAINS
# -----------------------------------------------------------------------------
leer_resumen <- function(dir, prefijo) {
  f <- file.path(dir, paste0(prefijo, "_resumen.tsv"))
  if (!file.exists(f)) stop("File not found: ", f)
  r <- read_tsv(f, colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  r[is.na(reason), reason := ""]
  r
}

# One Newick file per tree. Returns the strains (tips) of the genome-wide NJ.
escribir_arboles <- function(dir, prefijo, resumen, out) {
  f <- file.path(dir, paste0(prefijo, "_arboles.nwk"))
  if (!file.exists(f)) stop("File not found: ", f)
  lineas <- readLines(f, warn = FALSE)
  ok <- resumen[status == "ok" & !is.na(newick_line)]
  if (max(ok$newick_line) > length(lineas)) stop("The summary points to lines that are not in ", basename(f))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  clave <- basename(dirname(out))
  for (i in seq_len(nrow(ok))) writeLines(paste0('BF.load("', clave, '/arboles/', ok$tree_id[i], '",',
    jsonlite::toJSON(trimws(lineas[ok$newick_line[i]]), auto_unbox = TRUE), ');'),
    file.path(out, paste0(ok$tree_id[i], ".js")), useBytes = TRUE)
  ref <- ape::read.tree(text = lineas[ok$newick_line[ok$tree_id == "REF_TOTAL"]])
  # All trees have the same strains as the genome-wide one; this is checked on a sample.
  muestra <- ok$newick_line[sample.int(nrow(ok), min(25L, nrow(ok)))]
  for (ln in muestra) {
    tr <- ape::read.tree(text = lineas[ln])
    if (!setequal(tr$tip.label, ref$tip.label)) stop("The tree on line ", ln, " does not have the same strains as the genome-wide tree.")
  }
  logmsg("  ", fmt_n(nrow(ok)), " trees written to ", out, " | strains: ", length(ref$tip.label))
  sort(ref$tip.label)
}

leer_cepas <- function(tips, file) {
  # First column = strain; each following column is a categorical layer (lineage,
  # country, locality...). The first layer colours the ring by default.
  capas <- list()
  if (!is.null(file) && file.exists(file)) {
    t <- read_tsv(file, colClasses = "character", encoding = "UTF-8")
    if (ncol(t) < 2L) stop("The strain file needs the strain column and at least one layer: ", file)
    nombres <- safe_names(trimws(t[[1L]]))
    j <- match(tips, nombres)
    extra <- sum(!nombres %in% tips)
    for (k in 2:ncol(t)) {
      g <- trimws(t[[k]])[j]; g[is.na(g) | !nzchar(g)] <- NA_character_
      grupos <- sort(unique(stats::na.omit(g)))
      capas[[length(capas) + 1L]] <- list(nombre = names(t)[k], grupos = grupos,
                                          grupo = ifelse(is.na(g), -1L, match(g, grupos) - 1L))
    }
    logmsg("  Strains with ", capas[[1L]]$nombre, ": ", sum(capas[[1L]]$grupo >= 0L), " of ", length(tips),
           " | layers: ", paste(vapply(capas, `[[`, "", "nombre"), collapse = ", "),
           if (extra) paste0(" | in the file but not in the tree: ", extra))
  } else logmsg("  No strain file", if (!is.null(file)) paste0(" (missing ", file, ")"), ": all strains stay without a group")
  if (!length(capas)) capas <- list(list(nombre = "Group", grupos = character(), grupo = rep(-1L, length(tips))))
  list(nombres = tips, capas = capas)
}

# Closest strains by genetic distance (genome-wide NJ).
vecinos_cepas <- function(dir, prefijo, tips, k) {
  f <- file.path(dir, paste0(prefijo, "_distancias_geneticas.csv.gz"))
  if (!file.exists(f)) stop("File not found: ", f)
  d <- leer_matriz(f)
  if (!setequal(rownames(d), tips)) stop("The strains of the distance matrix do not match the genome-wide tree.")
  d <- d[tips, tips]
  out <- vector("list", length(tips))
  for (i in seq_along(tips)) {
    o <- unname(order(d[i, ], tips)); o <- o[o != i][seq_len(min(k, length(tips) - 1L))]
    out[[i]] <- lapply(o, function(j) list(j - 1L, round(unname(d[i, j]), 5)))
  }
  list(vecinos = out, media = unname(round(rowMeans(d), 5)))
}

# -----------------------------------------------------------------------------
# 3. NEIGHBOURS, PROJECTIONS AND MEDOIDS FROM THE FOREST MATRICES
# -----------------------------------------------------------------------------
calcular_vecinos <- function(rf, cc, ids, k) {
  n <- length(ids); es_ref <- ids == "REF_TOTAL"
  out <- vector("list", n)
  for (i in seq_len(n)) {
    r <- rf[i, ]; cab <- cc[i, ]
    cand <- which(!is.na(r) & seq_len(n) != i)
    if (!es_ref[i]) cand <- cand[!es_ref[cand]]      # the RF to the genome-wide tree is already in the summary
    o <- unname(cand[order(r[cand], -cab[cand], ids[cand])][seq_len(min(k, length(cand)))])
    out[[i]] <- lapply(o, function(j) list(j - 1L, round(unname(r[j]), 4), round(unname(cab[j]), 2), round(unname(cc[j, i]), 2)))
  }
  out
}

proyecciones <- function(rf, cfg) {
  n <- nrow(rf)
  D <- rf; D[is.na(D)] <- 1; diag(D) <- 0
  set.seed(cfg$semilla)
  logmsg("  t-SNE (perplexity ", cfg$perplexity, ") on ", fmt_n(n), " trees")
  ts <- Rtsne::Rtsne(D, is_distance = TRUE, dims = 2L, perplexity = min(cfg$perplexity, floor((n - 1)/3)),
                     theta = 0.5, max_iter = 1000L, check_duplicates = FALSE, verbose = FALSE,
                     num_threads = cfg$hilos)$Y
  logmsg("  UMAP (", cfg$umap_vecinos, " neighbours)")
  set.seed(cfg$semilla)
  um <- uwot::umap(stats::as.dist(D), n_neighbors = min(cfg$umap_vecinos, n - 1L), min_dist = 0.1,
                   n_threads = cfg$hilos, verbose = FALSE)
  logmsg("  Classical MDS (PCoA)")
  md <- suppressWarnings(stats::cmdscale(D, k = 2L))
  esc <- function(m) { m <- sweep(m, 2L, colMeans(m)); m <- m / max(abs(m)) * 100; round(m, 2) }
  list(tsne = unname(esc(ts)), umap = unname(esc(um)), mds = unname(esc(md)))
}

leer_clusters <- function(dir, prefijo, ids) {
  f_cl <- file.path(dir, paste0(prefijo, "_clusters.tsv"))
  f_rs <- file.path(dir, paste0(prefijo, "_clusters_resumen.tsv"))
  f_en <- file.path(dir, paste0(prefijo, "_enriquecimiento.tsv"))
  if (!file.exists(f_cl)) { logmsg("  No clusters (", basename(f_cl), " is missing)"); return(NULL) }
  cl <- read_tsv(f_cl, colClasses = list(character = c("tree_id", "orf", "origen")))
  faltan <- setdiff(ids[ids != "REF_TOTAL"], cl$tree_id)
  if (length(faltan)) stop(length(faltan), " summary trees are not in ", basename(f_cl), " (e.g. ", faltan[1L], ")")
  sobran <- setdiff(cl$tree_id, ids)
  if (length(sobran)) stop(length(sobran), " trees of ", basename(f_cl), " are not in the forest (e.g. ", sobran[1L], ")")
  rs <- if (file.exists(f_rs)) read_tsv(f_rs, colClasses = list(character = c("origen", "principales", "enriquecido"))) else NULL
  en <- if (file.exists(f_en)) read_tsv(f_en, colClasses = list(character = c("base", "termino", "descripcion", "genes"))) else NULL
  estado <- if (!is.null(en)) "ok" else "pendiente"
  logmsg("  Clusters: ", data.table::uniqueN(cl$cluster), " | enrichment: ", estado,
         if (!is.null(en)) paste0(" (", fmt_n(nrow(en)), " tests)"))
  list(miembros = cl, resumen = rs, enriquecimiento = en, estado = estado)
}

medoides <- function(rf, ids, cl) {
  grupos <- split(cl$tree_id, cl$cluster)
  vapply(grupos, function(g) {
    if (length(g) == 1L) return(match(g, ids) - 1L)
    m <- rf[g, g, drop = FALSE]; diag(m) <- 0
    match(g[which.min(rowMeans(m, na.rm = TRUE))], ids) - 1L
  }, integer(1))
}

# -----------------------------------------------------------------------------
# 4. GENE ANNOTATION (gene card): SGD_features.tab, gene_result.txt, gene_info.json or TSV
# -----------------------------------------------------------------------------
gene_result_ids <- function(symbol, gene_id) {   # same rule as the S. eubayanus forest
  id <- ifelse(is.na(symbol) | !nzchar(symbol), gene_id, symbol)
  dup <- id %in% id[duplicated(id)]
  id[dup] <- paste0(id[dup], "_", gene_id[dup])
  id
}

leer_genes <- function(file, orfs) {
  vacio <- data.table::data.table(orf = character(), nombre = character(), descripcion = character(), enlace = character())
  if (is.null(file)) return(vacio)
  if (!file.exists(file)) { logmsg("  WARNING: gene annotation not found ", file, "; the gene card will have no description"); return(vacio) }
  bn <- basename(file)
  if (grepl("SGD_features", bn, ignore.case = TRUE)) {
    txt <- readLines(file, warn = FALSE); txt <- txt[!grepl("^#|^$", txt)]
    x <- data.table::fread(text = paste(txt, collapse = "\n"), header = FALSE, sep = "\t", quote = "", fill = TRUE)
    x <- x[toupper(V2) == "ORF"]
    g <- data.table::data.table(orf = as.character(x$V4), nombre = as.character(x$V5),
                                descripcion = as.character(x$V16),
                                enlace = paste0("https://www.yeastgenome.org/locus/", x$V1))
  } else if (grepl("gene_result", bn, ignore.case = TRUE)) {
    x <- data.table::fread(file, quote = "\"", colClasses = "character")
    if (!all(c("GeneID", "Symbol") %in% names(x))) stop(bn, " has no GeneID and Symbol")
    desc <- if ("description" %in% names(x)) x$description else ""
    ali <- if ("Aliases" %in% names(x)) x$Aliases else ""
    g <- data.table::data.table(orf = gene_result_ids(x$Symbol, x$GeneID),
                                nombre = ifelse(is.na(ali) | !nzchar(ali), "", ali),
                                descripcion = desc, enlace = paste0("https://www.ncbi.nlm.nih.gov/gene/", x$GeneID))
  } else if (grepl("\\.json$", bn, ignore.case = TRUE)) {
    j <- jsonlite::fromJSON(file, simplifyVector = FALSE)
    g <- data.table::rbindlist(lapply(names(j), function(k) data.table::data.table(
      orf = k, nombre = if (is.null(j[[k]]$standard_name)) "" else j[[k]]$standard_name,
      descripcion = if (is.null(j[[k]]$description)) "" else j[[k]]$description,
      enlace = if (is.null(j[[k]]$link)) "" else j[[k]]$link)))
  } else {
    g <- read_tsv(file, colClasses = "character")
    names(g) <- tolower(names(g))
    if (!all(c("orf", "descripcion") %in% names(g))) stop("The gene TSV needs the columns orf and descripcion: ", file)
    if (!"nombre" %in% names(g)) g[, nombre := ""]
    if (!"enlace" %in% names(g)) g[, enlace := ""]
    g <- g[, .(orf, nombre, descripcion, enlace)]
  }
  g[is.na(nombre), nombre := ""]; g[is.na(descripcion), descripcion := ""]; g[is.na(enlace), enlace := ""]
  g <- unique(g[orf %in% orfs], by = "orf")
  logmsg("  Genes with a card: ", fmt_n(nrow(g)), " of ", fmt_n(length(orfs)))
  g
}

# -----------------------------------------------------------------------------
# 5. ONE COMPLETE SPECIES
# -----------------------------------------------------------------------------
# Reasons shown by the app (in English, like the rest of the interface).
motivo_corto <- function(reason) {
  ifelse(grepl("SNPs compartidos|shared SNPs", reason), "At least one pair of isolates with no shared called SNP in the ORF (undefined distance)",
  ifelse(grepl("Menos de|Fewer than", reason), "No retained SNP within the ORF", reason))
}
# Reasons of the genes not located, as written by bosque_Eubayanus.R (earlier runs wrote them in Spanish).
motivo_ubicar <- function(m) {
  m <- sub("^extremo inicial repetido o ausente en ", "Gene start repeated or absent in ", m)
  m <- sub("^extremo final repetido o ausente en ", "Gene end repeated or absent in ", m)
  m <- sub("^extremos en contigs, hebras o distancias que no calzan$", "Gene ends on different contigs or strands, or at an inconsistent distance", m)
  sub("^sin coordenadas en ", "No coordinates in ", m)
}

preparar_especie <- function(sp, cfg, base, salida) {
  dir <- resolve_file(base, sp$carpeta); pref <- sp$prefijo
  out <- file.path(salida, sp$clave)
  entradas <- c(file.path(dir, paste0(pref, c("_resumen.tsv", "_arboles.nwk", "_RF.csv.gz", "_concordancia.csv.gz",
                                               "_distancias_geneticas.csv.gz", "_clusters.tsv", "_clusters_resumen.tsv",
                                               "_enriquecimiento.tsv", "_genes_sin_ubicar.tsv"))),
                resolve_file(base, sp$cepas), resolve_file(base, sp$genes))
  f_cepas <- first_existing(resolve_file(base, sp$cepas)); f_genes <- first_existing(resolve_file(base, sp$genes))
  h <- huella(entradas); f_h <- file.path(out, "huella.txt")
  if (!cfg$rehacer && file.exists(f_h) && identical(readLines(f_h, warn = FALSE)[1L], h) &&
      file.exists(file.path(out, "arboles.js"))) {
    logmsg(sp$nombre, ": inputs unchanged, keeping ", out)
    return(jsonlite::fromJSON(file.path(out, "meta.json")))
  }
  logmsg("== ", sp$nombre, " | results in ", dir)
  unlink(out, recursive = TRUE); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  res <- leer_resumen(dir, pref)
  ok <- res[status == "ok"]
  data.table::setorder(ok, newick_line)
  ids <- ok$tree_id
  if (ids[1L] != "REF_TOTAL") stop("The first tree of the summary must be REF_TOTAL")
  tips <- escribir_arboles(dir, pref, res, file.path(out, "arboles"))
  cepas <- leer_cepas(tips, f_cepas)
  vc <- vecinos_cepas(dir, pref, tips, cfg$k_cepas)

  logmsg("  Reading RF and concordance (all against all)")
  rf <- leer_matriz(file.path(dir, paste0(pref, "_RF.csv.gz")))
  if (!all(ids %in% rownames(rf))) stop("Summary trees that are not in the RF matrix")
  rf <- rf[ids, ids]
  cc <- leer_matriz(file.path(dir, paste0(pref, "_concordancia.csv.gz")))[ids, ids]
  vecinos <- calcular_vecinos(rf, cc, ids, cfg$k_vecinos)
  rm(cc); invisible(gc())
  proy <- proyecciones(rf, cfg)

  cl <- leer_clusters(dir, pref, ids)
  cluster <- rep(NA_integer_, length(ids)); grupos_json <- list(estado = "sin clusters", clusters = list(), enriquecimiento = list())
  if (!is.null(cl)) {
    cluster <- cl$miembros$cluster[match(ids, cl$miembros$tree_id)]
    med <- medoides(rf, ids, cl$miembros)
    tam <- cl$miembros[, .(tamano = .N), by = cluster]
    rs <- cl$resumen
    clusters <- lapply(sort(unique(cl$miembros$cluster)), function(k) {
      r <- if (!is.null(rs)) rs[cluster == k] else NULL
      g <- cl$miembros[cluster == k]
      m <- rf[g$tree_id, g$tree_id, drop = FALSE]
      list(id = k, tamano = nrow(g), origen = g$origen[1L],
           medoide = unname(med[as.character(k)]),
           rf_dentro = if (nrow(g) > 1L) round(mean(m[upper.tri(m)], na.rm = TRUE), 4) else NA,
           rf_ref = round(mean(rf[g$tree_id, "REF_TOTAL"], na.rm = TRUE), 4),
           anotados = if (!is.null(r) && nrow(r)) r$genes_anotados else NA,
           enriquecido = if (!is.null(r) && nrow(r)) r$enriquecido else cl$estado,
           n_terminos = if (!is.null(r) && nrow(r) && !is.na(r$terminos_FDR)) r$terminos_FDR else 0L)
    })
    enr <- list()
    if (!is.null(cl$enriquecimiento) && nrow(cl$enriquecimiento)) {
      e <- cl$enriquecimiento
      data.table::setorder(e, cluster, p)
      e[, top := seq_len(.N), by = cluster]
      e <- e[fdr < cfg$fdr_guardar | top <= 3L]
      enr <- lapply(seq_len(nrow(e)), function(i) list(
        cluster = e$cluster[i], base = e$base[i], termino = e$termino[i], descripcion = e$descripcion[i],
        k = e$k_en_cluster[i], n = e$n_cluster_anotados[i], K = e$K_en_universo[i], N = e$N_universo[i],
        razon = round(e$razon_enriquecimiento[i], 3), p = signif(e$p[i], 3), fdr = signif(e$fdr[i], 3),
        genes = strsplit(e$genes[i], ";", fixed = TRUE)[[1L]]))
      logmsg("  Enrichment tests kept: ", fmt_n(nrow(e)), " (FDR < ", cfg$fdr_guardar, " or top 3 per cluster)")
    }
    grupos_json <- list(estado = cl$estado, n_clusters = length(clusters), clusters = clusters, enriquecimiento = enr)
  }
  write_js(grupos_json, paste0(sp$clave, "/grupos"), file.path(out, "grupos.js"))

  # Record per tree: everything from the summary that the app uses, plus cluster and projections.
  m <- ok[match(ids, tree_id)]
  arboles <- list(
    especie = sp$clave, ref = "REF_TOTAL", n = length(ids),
    id = ids, orf = m$orf,
    n_snps = m$n_snps, n_splits = m$n_splits, resolucion = round(m$resolution, 4),
    respaldo_medio = round(m$forest_branch_mean_pct, 3), respaldo_mediana = round(m$forest_branch_median_pct, 3),
    rf_media = round(m$mean_RF_other_trees, 4), conc_media = round(m$mean_pair_concordance_pct, 3),
    rf_ref = round(m$RF_to_total, 4), propios_en_ref = round(m$own_splits_in_total_pct, 2),
    ref_en_propio = round(m$total_splits_in_own_pct, 2),
    cluster = cluster,
    proy = proy
  )
  write_js(arboles, paste0(sp$clave, "/arboles"), file.path(out, "arboles.js"))
  write_js(list(k = cfg$k_vecinos, vecinos = vecinos), paste0(sp$clave, "/vecinos"), file.path(out, "vecinos.js"))
  write_js(list(nombres = cepas$nombres, capas = cepas$capas,
                vecinos = vc$vecinos, distancia_media = vc$media), paste0(sp$clave, "/cepas"), file.path(out, "cepas.js"))

  genes <- leer_genes(f_genes, unique(res$orf))
  gl <- stats::setNames(lapply(seq_len(nrow(genes)), function(i) list(genes$nombre[i], genes$descripcion[i], genes$enlace[i])), genes$orf)
  write_js(gl, paste0(sp$clave, "/genes"), file.path(out, "genes.js"))

  om <- res[status != "ok", .(orf, motivo = motivo_corto(reason), n_snps)]
  su <- NULL; f_su <- file.path(dir, paste0(pref, "_genes_sin_ubicar.tsv"))
  if (file.exists(f_su)) { s <- read_tsv(f_su, colClasses = "character"); su <- s[, .(orf, motivo = motivo_ubicar(motivo))] }
  write_js(list(sin_arbol = om, sin_ubicar = su), paste0(sp$clave, "/omitidos"), file.path(out, "omitidos.js"))
  logmsg("  ORFs without a tree: ", fmt_n(nrow(om)), if (!is.null(su)) paste0(" | genes not located: ", fmt_n(nrow(su))))

  meta <- list(clave = sp$clave, nombre = sp$nombre, corto = sp$corto, fuente = sp$fuente, enlace_gen = sp$enlace_gen,
               n_arboles = length(ids) - 1L, n_cepas = length(tips), n_grupos_cepas = length(cepas$capas[[1L]]$grupos),
               capas = vapply(cepas$capas, `[[`, "", "nombre"),
               n_sin_arbol = nrow(om), n_sin_ubicar = if (is.null(su)) 0L else nrow(su),
               n_clusters = if (is.null(cl)) 0L else data.table::uniqueN(cl$miembros$cluster),
               enriquecimiento = grupos_json$estado, snps_ref = ok$n_snps[ok$tree_id == "REF_TOTAL"],
               splits_ref = ok$n_splits[ok$tree_id == "REF_TOTAL"], k_vecinos = cfg$k_vecinos,
               fecha = format(Sys.Date()))
  write_json(meta, file.path(out, "meta.json"))
  writeLines(h, f_h)
  rm(rf); invisible(gc())
  meta
}

# -----------------------------------------------------------------------------
# 6. RUN
# -----------------------------------------------------------------------------
preparar_app <- function(cfg = CONFIG) {
  inicio <- Sys.time()
  ensure_packages()
  data.table::setDTthreads(cfg$hilos)
  base <- script_dir()
  salida <- resolve_file(base, cfg$salida)
  dir.create(salida, recursive = TRUE, showWarnings = FALSE)
  metas <- lapply(cfg$especies, preparar_especie, cfg = cfg, base = base, salida = salida)
  write_js(metas, "especies", file.path(salida, "especies.js"))
  logmsg("FINISHED | ", length(metas), " species in ", salida, " | ",
         format(round(difftime(Sys.time(), inicio, units = "mins"), 1)))
  invisible(metas)
}

if (Sys.getenv("PREPARAR_APP_LIBRARY_ONLY") != "1") preparar_app(CONFIG)
