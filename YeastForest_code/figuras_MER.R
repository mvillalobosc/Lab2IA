# =============================================================================
# NUMBERS AND FIGURES OF THE MANUSCRIPT FOR MOLECULAR ECOLOGY RESOURCES
# Place this file next to preparar_app.R and the folders
# Bosque_cerevisiae and Bosque_eubayanus, and run it with source("figuras_MER.R")
# once the groups (clusters_SCerevisiae.R, grupos_Eubayanus.R), the
# tables of publicar_bosque.R in both folders and the data/ folder of
# preparar_app.R are ready. It reads those data and writes to figs/ Figures 1 to 5 (.pdf and
# .png), the supporting tables and cifras.tsv with every number used in the text.
# Figures in base R. Figure 6 shows screenshots of YeastForest and is not produced here.
# Date: 2026-10-10.
# =============================================================================
local({ pk <- c("data.table", "jsonlite", "ape", "igraph"); falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
        if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org") })
suppressPackageStartupMessages({ library(data.table); library(jsonlite); library(ape); library(igraph) })
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) { f <- sys.frame(i)$ofile; if (is.character(f) && length(f) == 1L && nzchar(f)) return(dirname(normalizePath(path.expand(f)))) }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}
BASE <- script_dir()
APP <- file.path(BASE, "data")                                   # data/ of YeastForest (preparar_app.R)
PUB <- list(cer = file.path(BASE, "Bosque_cerevisiae"), eub = file.path(BASE, "Bosque_eubayanus"))   # forest results and *_pub_* tables
GENES_EUB <- c(file.path(PUB$eub, "gene_result.txt"), file.path(BASE, "gene_result_eubayanus.txt"),
               file.path(PUB$eub, "DATA", "gene_result.txt"))   # coordinates of the eubayanus genes: the first file that exists
PREF <- list(cer = "SCerevisiae", eub = "Eubayanus")
OUT <- file.path(BASE, "figs"); dir.create(OUT, showWarnings = FALSE)
cifras <- list(); cifra <- function(k, v) cifras[[k]] <<- v

leer_js <- function(path, simplificar = TRUE) { s <- readLines(path, warn = FALSE, encoding = "UTF-8"); s <- paste(s, collapse = "\n"); s <- sub("^BF\\.load\\(\"[^\"]+\",", "", s); s <- sub("\\);\\s*$", "", s); fromJSON(s, simplifyVector = simplificar) }
leer_especie <- function(k) {
  d <- file.path(APP, if (k == "cer") "cerevisiae" else "eubayanus")
  A <- leer_js(file.path(d, "arboles.js")); G <- leer_js(file.path(d, "grupos.js")); C <- leer_js(file.path(d, "cepas.js"))
  dt <- data.table(id = A$id, orf = A$orf, n_snps = A$n_snps, n_splits = A$n_splits, resolucion = A$resolucion, respaldo_medio = A$respaldo_medio,
                   rf_ref = A$rf_ref, propios_en_ref = A$propios_en_ref, ref_en_propio = A$ref_en_propio, cluster = A$cluster)
  list(A = dt, G = G, C = C, ref = dt[id == "REF_TOTAL"], genes = dt[id != "REF_TOTAL"])
}
sp <- list(cer = leer_especie("cer"), eub = leer_especie("eub"))
res <- list(cer = fread(file.path(PUB$cer, "SCerevisiae_resumen.tsv")), eub = fread(file.path(PUB$eub, "Eubayanus_resumen.tsv")))
pubt <- function(k, s) fread(file.path(PUB[[k]], paste0(PREF[[k]], "_pub_", s)))

# -----------------------------------------------------------------------------
# 1. Summary numbers (Table 1)
# -----------------------------------------------------------------------------
ref_tree <- lapply(c(cer = "cerevisiae", eub = "eubayanus"), function(e) read.tree(text = leer_js(file.path(APP, e, "arboles", "REF_TOTAL.js"))))
for (k in c("cer", "eub")) {
  g <- sp[[k]]$genes; r <- sp[[k]]$ref; rs <- res[[k]]
  sup <- suppressWarnings(as.numeric(ref_tree[[k]]$node.label)); sup <- sup[!is.na(sup)]
  cifra(paste0(k, "_cepas"), length(ref_tree[[k]]$tip.label)); cifra(paste0(k, "_orfs_anotados"), nrow(rs) - 1L)
  cifra(paste0(k, "_orfs_arbol"), nrow(g)); cifra(paste0(k, "_pct_arbol"), round(100 * nrow(g) / (nrow(rs) - 1L)))
  cifra(paste0(k, "_sin_arbol_sin_snps"), sum(grepl("Menos de|Fewer than", rs$reason))); cifra(paste0(k, "_sin_arbol_pares"), sum(grepl("compartidos|shared SNPs", rs$reason)))
  cifra(paste0(k, "_snps_ref"), r$n_snps); cifra(paste0(k, "_splits_ref"), r$n_splits)
  cifra(paste0(k, "_snps_mediana"), median(g$n_snps)); cifra(paste0(k, "_snps_q1"), quantile(g$n_snps, .25)); cifra(paste0(k, "_snps_q3"), quantile(g$n_snps, .75))
  cifra(paste0(k, "_resol_mediana"), round(100 * median(g$resolucion))); cifra(paste0(k, "_rf_ref_mediana"), round(median(g$rf_ref), 3))
  cifra(paste0(k, "_propios_en_ref_mediana"), round(median(g$propios_en_ref, na.rm = TRUE), 1))   # % of the branches of an ORF tree that are in the reference
  cifra(paste0(k, "_pct_rf1"), round(100 * mean(g$rf_ref >= 0.9999), 1)); cifra(paste0(k, "_n_rf1"), sum(g$rf_ref >= 0.9999))
  cifra(paste0(k, "_respaldo_mediana"), round(median(g$respaldo_medio), 2)); cifra(paste0(k, "_respaldo_ref"), round(r$respaldo_medio, 2))
  cifra(paste0(k, "_ref_ramas_5"), sum(sup >= 5)); cifra(paste0(k, "_ref_ramas_25"), sum(sup >= 25)); cifra(paste0(k, "_ref_ramas_50"), sum(sup >= 50)); cifra(paste0(k, "_ref_ramas_0"), sum(sup == 0))
  cifra(paste0(k, "_ref_ramas_max"), max(sup))
  cl <- sp[[k]]$G$clusters; cifra(paste0(k, "_clusters"), nrow(cl)); cifra(paste0(k, "_clusters_2mas"), sum(cl$tamano >= 2)); cifra(paste0(k, "_cluster_mayor"), max(cl$tamano))
  cifra(paste0(k, "_pct_cluster_mayor"), round(100 * max(cl$tamano) / nrow(g)))
  cifra(paste0(k, "_rho_snps_rfref"), round(cor(g$n_snps, g$rf_ref, method = "spearman"), 2))
  cifra(paste0(k, "_rho_snps_resol"), round(cor(g$n_snps, g$resolucion, method = "spearman"), 2))
  cifra(paste0(k, "_rho_snps_respaldo"), round(cor(g$n_snps, g$respaldo_medio, method = "spearman"), 2))
}
cifra("cer_clusters_enriquecidos", sum(sp$cer$G$clusters$enriquecido == "si"))
cifra("cer_terminos_fdr05", sum(sp$cer$G$enriquecimiento$fdr < 0.05))
cifra("eub_sin_ubicar", nrow(fread(file.path(PUB$eub, "Eubayanus_genes_sin_ubicar.tsv"))))
# k of the first MST-kNN step: the smallest k that connects the kNN graph of all trees,
# capped at floor(ln n), with the same tie-breaking as mstknnclust (order() by row over the
# RF matrix in file order, without REF_TOTAL).
k_primer_nivel <- function(f) {
  x <- fread(f); ids <- x[[1]]; m <- as.matrix(x[, -1, with = FALSE]); rm(x)
  keep <- ids != "REF_TOTAL"; m <- m[keep, keep]; n <- nrow(m); diag(m) <- Inf; tope <- max(1L, floor(log(n)))
  nb <- t(apply(m, 1, function(r) order(r)[seq_len(tope)])); rm(m)
  for (k in seq_len(tope)) {
    g <- simplify(graph_from_edgelist(cbind(rep(seq_len(n), k), as.integer(nb[, seq_len(k)])), directed = FALSE))
    if (vcount(g) < n) g <- add_vertices(g, n - vcount(g))
    if (is_connected(g)) return(c(n = n, tope = tope, k = k))
  }
  c(n = n, tope = tope, k = tope)
}
for (k in c("cer", "eub")) {
  kk <- k_primer_nivel(file.path(PUB[[k]], paste0(PREF[[k]], "_RF.csv.gz")))
  cifra(paste0(k, "_mstknn_n"), kk[["n"]]); cifra(paste0(k, "_mstknn_tope_ln_n"), kk[["tope"]]); cifra(paste0(k, "_mstknn_k_primer_paso"), kk[["k"]])
}

# -----------------------------------------------------------------------------
# 2. Genomic positions and linkage of the groups
# -----------------------------------------------------------------------------
pos_cer <- {
  g <- sp$cer$genes; m <- regmatches(g$orf, regexec("^Y([A-P])([LR])([0-9]{3})[WC]", g$orf)); ok <- lengths(m) == 4L
  data.table(orf = g$orf[ok], chr = match(vapply(m[ok], `[`, "", 2L), LETTERS[1:16]), brazo = vapply(m[ok], `[`, "", 3L), num = as.integer(vapply(m[ok], `[`, "", 4L)))[, pos := ifelse(brazo == "L", -num, num)][order(chr, pos)]
}
pos_eub <- {
  f_genes <- Filter(file.exists, path.expand(GENES_EUB))[1]
  if (is.na(f_genes)) stop("gene_result.txt of S. eubayanus not found; check GENES_EUB at the top of the script")
  x <- fread(f_genes, quote = "\"", colClasses = "character")
  sym <- x$Symbol; id <- ifelse(is.na(sym) | !nzchar(sym), x$GeneID, sym); dup <- id %in% id[duplicated(id)]; id[dup] <- paste0(id[dup], "_", x$GeneID[dup])
  roman <- c("I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI")
  d <- data.table(orf = id, chr = match(x$chromosome, roman), pos = suppressWarnings(as.numeric(x$start_position_on_the_genomic_accession)))[!is.na(chr) & !is.na(pos)]
  d[orf %in% sp$eub$genes$orf][order(chr, pos)]
}
# a) contiguous neighbours in the same group vs. chance (permutation of the group label)
ligamiento_adyacente <- function(pos, genes, B = 1000L, semilla = 2026L) {
  set.seed(semilla)
  d <- merge(pos, genes[, .(orf, cluster)], by = "orf")[order(chr, pos)]
  pares <- d[, .(a = cluster[-.N], b = cluster[-1L]), by = chr]
  obs <- mean(pares$a == pares$b)
  nulo <- replicate(B, { d2 <- copy(d); d2[, cluster := sample(cluster)]; p <- d2[, .(a = cluster[-.N], b = cluster[-1L]), by = chr]; mean(p$a == p$b) })
  list(obs = obs, esperado = mean(nulo), razon = obs / mean(nulo), p = (1 + sum(nulo >= obs)) / (B + 1), pares = nrow(pares))
}
lig <- list(cer = ligamiento_adyacente(pos_cer, sp$cer$genes), eub = ligamiento_adyacente(pos_eub, sp$eub$genes))
for (k in c("cer", "eub")) { cifra(paste0(k, "_ady_obs"), round(100 * lig[[k]]$obs, 1)); cifra(paste0(k, "_ady_esp"), round(100 * lig[[k]]$esperado, 1)); cifra(paste0(k, "_ady_razon"), round(lig[[k]]$razon, 1)); cifra(paste0(k, "_ady_p"), lig[[k]]$p) }
# b) per group: fraction on the dominant arm and permutation test (groups with >= 10 ORFs)
ligamiento_grupos <- function(pos, genes, B = 2000L, semilla = 2026L) {
  set.seed(semilla)
  d <- merge(pos, genes[, .(orf, cluster)], by = "orf")
  d[, brazo_id := if ("brazo" %in% names(d)) paste0(chr, brazo) else as.character(chr)]
  tam <- d[, .N, by = cluster][N >= 10L]
  out <- lapply(tam$cluster, function(k) {
    g <- d[cluster == k]; n <- nrow(g); tb <- table(g$brazo_id); fmax <- max(tb) / n; dom <- names(which.max(tb))
    nulo <- replicate(B, { s <- d[sample.int(nrow(d), n)]; max(table(s$brazo_id)) / n })
    rango <- g[brazo_id == dom, range(pos)]
    data.table(cluster = k, orfs = n, brazo_dominante = dom, pct_brazo = round(100 * fmax, 1), pct_esperado = round(100 * mean(nulo), 1),
               p_perm = (1 + sum(nulo >= fmax)) / (B + 1), desde = rango[1], hasta = rango[2])
  })
  rbindlist(out)[order(-pct_brazo)]
}
ligg <- list(cer = ligamiento_grupos(pos_cer, sp$cer$genes), eub = ligamiento_grupos(pos_eub, sp$eub$genes))
for (k in c("cer", "eub")) { ligg[[k]][, fdr := p.adjust(p_perm, "BH")]; ligg[[k]][, ligado := fdr < 0.05 & pct_brazo >= 50]
  cifra(paste0(k, "_grupos_probados"), nrow(ligg[[k]])); cifra(paste0(k, "_grupos_ligados"), sum(ligg[[k]]$ligado)); cifra(paste0(k, "_orfs_en_ligados"), sum(ligg[[k]][ligado == TRUE, orfs])) }
fwrite(ligg$cer, file.path(OUT, "ligamiento_grupos_cerevisiae.tsv"), sep = "\t"); fwrite(ligg$eub, file.path(OUT, "ligamiento_grupos_eubayanus.tsv"), sep = "\t")
# enriched and linked groups
enr_cl <- sp$cer$G$clusters[sp$cer$G$clusters$enriquecido == "si", ]
mejor <- as.data.table(sp$cer$G$enriquecimiento)[fdr < 0.05][order(fdr)][, .SD[1L], by = cluster]
tabla2 <- merge(data.table(cluster = enr_cl$id, orfs = enr_cl$tamano, rf_ref = enr_cl$rf_ref), mejor[, .(cluster, base, descripcion, k, n, fdr)], by = "cluster")
tabla2 <- merge(tabla2, ligg$cer[, .(cluster, brazo_dominante, pct_brazo, p_perm, ligado)], by = "cluster", all.x = TRUE)
tabla2 <- merge(tabla2, pubt("cer", "A_resolucion_por_grupo.tsv")[, .(cluster, snps_mediana, resolucion_mediana)], by = "cluster")[order(fdr)]
fwrite(tabla2, file.path(OUT, "tabla2_enriquecidos.tsv"), sep = "\t")
cifra("cer_enriquecidos_ligados", sum(tabla2$ligado, na.rm = TRUE)); cifra("cer_enriquecidos_no_ligados", sum(!tabla2$ligado, na.rm = TRUE))

# -----------------------------------------------------------------------------
# 3. Resolution as a confounder (A, B), conflict (D) and comparison with the earlier forest (F)
# -----------------------------------------------------------------------------
A <- list(cer = pubt("cer", "A_resolucion_pruebas.tsv"), eub = pubt("eub", "A_resolucion_pruebas.tsv"))
Ag <- list(cer = pubt("cer", "A_resolucion_por_grupo.tsv"), eub = pubt("eub", "A_resolucion_por_grupo.tsv"))
B <- list(cer = pubt("cer", "B_umbrales.tsv"), eub = pubt("eub", "B_umbrales.tsv"))
for (k in c("cer", "eub")) {
  cifra(paste0(k, "_eta2_resol"), round(A[[k]][variable == "resolution", eta2_kruskal], 2)); cifra(paste0(k, "_eta2_snps"), round(A[[k]][variable == "n_snps", eta2_kruskal], 2))
  cifra(paste0(k, "_G1_snps_mediana"), Ag[[k]][cluster == 1, snps_mediana]); cifra(paste0(k, "_G1_pct_resol10"), round(Ag[[k]][cluster == 1, pct_resolucion_bajo_10]))
  cifra(paste0(k, "_G1_rf_ref"), round(Ag[[k]][cluster == 1, rf_ref_mediana], 3)); cifra(paste0(k, "_G1_resol"), round(100 * Ag[[k]][cluster == 1, resolucion_mediana]))
  cifra(paste0(k, "_G2_rf_ref"), round(Ag[[k]][cluster == 2, rf_ref_mediana], 3)); cifra(paste0(k, "_G3_rf_ref"), round(Ag[[k]][cluster == 3, rf_ref_mediana], 3))
  b <- B[[k]]; cifra(paste0(k, "_ari_res25"), round(b[umbral_snps == 0 & umbral_resolucion == 0.25, ari_vs_completo], 2)); cifra(paste0(k, "_ari_res10"), round(b[umbral_snps == 0 & umbral_resolucion == 0.10, ari_vs_completo], 2))
  cifra(paste0(k, "_orfs_res25"), b[umbral_snps == 0 & umbral_resolucion == 0.25, orfs]); cifra(paste0(k, "_grupos_res25"), b[umbral_snps == 0 & umbral_resolucion == 0.25, grupos])
}
cifra("cer_ari_snps30", round(B$cer[umbral_snps == 30 & umbral_resolucion == 0, ari_vs_completo], 2)); cifra("cer_ari_snps100", round(B$cer[umbral_snps == 100 & umbral_resolucion == 0, ari_vs_completo], 2))
cifra("eub_ari_snps10", round(B$eub[umbral_snps == 10 & umbral_resolucion == 0, ari_vs_completo], 2)); cifra("eub_ari_snps30", round(B$eub[umbral_snps == 30 & umbral_resolucion == 0, ari_vs_completo], 2))
# where G1 ends up with resolution >= 0.25 (cerevisiae)
mb <- pubt("cer", "B_umbrales_miembros.tsv")[umbral_snps == 0 & umbral_resolucion == 0.25]
g1 <- mb[cluster_completo == 1]; cifra("cer_G1_sobrevive_res25", nrow(g1)); cifra("cer_G1_mayor_destino_pct", if (nrow(g1)) round(100 * max(table(g1$cluster)) / nrow(g1)) else NA)
# mechanism of the ribosomal group: the 15 nearest neighbours (RF) of each tree, stored by the app in vecinos.js
# (one list per tree, in the order of arboles.js, 0-based indices). If the neighbours of G1 are poorly
# resolved trees, G1 is formed by low resolution and not by a shared history.
V <- leer_js(file.path(APP, "cerevisiae", "vecinos.js"), simplificar = FALSE)$vecinos
A_cer <- sp$cer$A; stopifnot(length(V) == nrow(A_cer)); bajo <- A_cer$resolucion < 0.25
frac_bajo <- vapply(seq_along(V), function(i) { nb <- vapply(V[[i]], function(v) v[[1]], 0) + 1; nb <- nb[A_cer$id[nb] != "REF_TOTAL"]; mean(bajo[nb]) }, 0)
cifra("cer_pct_resol25_bosque", round(100 * mean(sp$cer$genes$resolucion < 0.25)))
for (g in c(1L, 2L, 6L)) cifra(paste0("cer_G", g, "_vecinos_resol25"), round(100 * median(frac_bajo[A_cer$id != "REF_TOTAL" & A_cer$cluster %in% g])))
# conflict
D <- list(cer = pubt("cer", "D_conflicto_por_orf.tsv"), eub = pubt("eub", "D_conflicto_por_orf.tsv"))
Dr <- list(cer = pubt("cer", "D_conflicto_ramas.tsv"), eub = pubt("eub", "D_conflicto_ramas.tsv"))
Ds <- list(cer = pubt("cer", "D_conflicto_resumen.tsv"), eub = pubt("eub", "D_conflicto_resumen.tsv"))
top_conf <- list()
for (k in c("cer", "eub")) {
  cifra(paste0(k, "_conf_orfs"), Ds[[k]]$orfs_en_conflicto); cifra(paste0(k, "_conf_pct"), round(100 * Ds[[k]]$orfs_en_conflicto / Ds[[k]]$orfs))
  cifra(paste0(k, "_conf_tramos_obs"), Ds[[k]]$tramos_observados); cifra(paste0(k, "_conf_tramos_esp"), round(Ds[[k]]$tramos_esperados_media, 1)); cifra(paste0(k, "_conf_tramos_p"), round(Ds[[k]]$p_empirico_tramos, 2))
  cifra(paste0(k, "_orfs_con_respaldada"), Ds[[k]]$orfs_con_ramas_respaldadas)
  # distinct bipartitions in conflict, ordered by how many ORFs carry them
  Dr[[k]][, clave := vapply(strsplit(cepas, ";", fixed = TRUE), function(z) paste(sort(z), collapse = ";"), "")]
  r <- Dr[[k]][, .(orfs = .N, respaldo = respaldo[1L], cepas_lado_menor = cepas_lado_menor[1L], grupo_dominante = grupo_dominante[1L], pct_dominante = pct_grupo_dominante[1L], grupos_presentes = grupos_presentes[1L], cepas = clave[1L]), by = clave][order(-orfs)]
  cifra(paste0(k, "_conf_biparticiones_distintas"), nrow(r)); top_conf[[k]] <- r[1:min(10L, nrow(r))]
  fwrite(top_conf[[k]][, .(orfs, respaldo, cepas_lado_menor, grupo_dominante, pct_dominante, grupos_presentes, cepas)], file.path(OUT, paste0("conflicto_top_", k, ".tsv")), sep = "\t")
}
# Each bipartition in conflict on its own.
# (a) Relation with the reference: the smallest clade of the reference (one side of one of its bipartitions)
#     that contains all its strains; if 1 or 2 strains are left over, the bipartition is that clade without one or two members.
# (b) Runs: contiguous ORFs (>= 3) that carry that bipartition, against 1,000 permutations within each
#     chromosome, with Benjamini-Hochberg FDR over the bipartitions of the species. The count of publicar_bosque.R
#     (stage D) pools all bipartitions; in cerevisiae two thirds of the ORFs carry one and that pooled
#     count does not separate runs, so here they are tested one by one.
set.seed(2026L)
conf_bip <- list()
for (k in c("cer", "eub")) {
  tr <- ref_tree[[k]]; tips <- tr$tip.label; nt <- length(tips)
  lados <- lapply(prop.part(tr), function(ix) tips[ix]); lados <- c(lados, lapply(lados, function(x) setdiff(tips, x)))
  lados <- lados[lengths(lados) >= 2L & lengths(lados) <= nt - 2L]
  po <- D[[k]][!is.na(inicio)][order(chr, inicio)]; por_chr <- split(seq_len(nrow(po)), po$chr)
  n_tramos <- function(flag) sum(vapply(por_chr, function(ix) { r <- rle(flag[ix]); sum(r$values & r$lengths >= 3L) }, integer(1)))
  claves <- Dr[[k]][, .(orfs = .N), by = clave][order(-orfs)]
  conf_bip[[k]] <- rbindlist(lapply(seq_len(nrow(claves)), function(i) {
    S <- strsplit(claves$clave[i], ";", fixed = TRUE)[[1]]
    menor <- min(lengths(lados[vapply(lados, function(x) all(S %in% x), TRUE)]))
    flag <- po$orf %in% Dr[[k]][clave == claves$clave[i], orf]; obs <- n_tramos(flag)
    nulo <- replicate(1000L, sum(vapply(por_chr, function(ix) { r <- rle(sample(flag[ix])); sum(r$values & r$lengths >= 3L) }, integer(1))))
    data.table(orfs = claves$orfs[i], cepas = length(S), clado_ref_menor = menor, cepas_de_mas_en_ref = menor - length(S), cromosomas = uniqueN(po$chr[flag]),
               tramos_obs = obs, tramos_esp = round(mean(nulo), 1), p_perm = (1 + sum(nulo >= obs)) / 1001, cepas_lista = claves$clave[i])
  }))[, fdr := p.adjust(p_perm, "BH")]
  fwrite(conf_bip[[k]], file.path(OUT, paste0("conflicto_biparticiones_", k, ".tsv")), sep = "\t")
  cifra(paste0(k, "_conf_bip_clado_menos_1o2"), sum(conf_bip[[k]]$cepas_de_mas_en_ref <= 2L))
  cifra(paste0(k, "_conf_bip_en_tramos"), sum(conf_bip[[k]]$fdr < 0.05))
  cifra(paste0(k, "_conf_bip_crom_min"), min(conf_bip[[k]]$cromosomas)); cifra(paste0(k, "_conf_bip_crom_max"), max(conf_bip[[k]]$cromosomas))
  cifra(paste0(k, "_conf_bip_clado_ref_max"), max(conf_bip[[k]]$clado_ref_menor))
}
# earlier forest
Fr <- pubt("cer", "F_bosque_anterior_resumen.tsv"); Fo <- pubt("cer", "F_bosque_anterior_por_orf.tsv")[is.na(motivo) | motivo == ""]
cifra("F_orfs", Fr$orfs_comparados); cifra("F_rf_mediana", round(Fr$rf_anterior_vs_nuevo_mediana, 2)); cifra("F_rho_snps", round(Fr$rho_rf_vs_snps, 2)); cifra("F_rho_ref", round(Fr$rho_rf_referencia_anterior_vs_nuevo, 2))
cifra("F_rf_q1", round(Fr$rf_anterior_vs_nuevo_q1, 2)); cifra("F_rf_q3", round(Fr$rf_anterior_vs_nuevo_q3, 2))
cifra("F_rf_mediana_snps500", round(median(Fo[n_snps >= 500, rf_anterior_vs_nuevo]), 2)); cifra("F_rf_mediana_snps50", round(median(Fo[n_snps < 50, rf_anterior_vs_nuevo]), 2))

# -----------------------------------------------------------------------------
# 4. FIGURES
# -----------------------------------------------------------------------------
COL <- list(cer = "#ea7600", eub = "#2e6fb0", teal = "#00a499", rojo = "#c8102e", gris = "#9aa5af", oro = "#eaaa00", verde = "#2e8b3d", purp = "#7e5ea8")
pdfpng <- function(nombre, w, h, fn) { for (dev in c("pdf", "png")) { f <- file.path(OUT, paste0(nombre, ".", dev)); if (dev == "pdf") cairo_pdf(f, width = w, height = h) else png(f, width = w, height = h, units = "in", res = 300); par(family = "sans"); fn(); dev.off() } }
panel <- function(l, x = 0.02, y = 0.98) mtext(l, side = 3, adj = -0.12, line = 0.6, font = 2, cex = 1.1)

# ---- Fig 1: scheme of the method
pdfpng("Fig1_esquema", 7.2, 3.6, function() {
  par(mar = c(0, 0, 0, 0)); plot(0, 0, type = "n", xlim = c(0, 100), ylim = c(0, 50), axes = FALSE, xlab = "", ylab = "")
  caja <- function(x, y, w, h, t, col = "#f6f7f9", bord = "#8a929b", cex = 0.72) { rect(x, y, x + w, y + h, col = col, border = bord, lwd = 1.2); text(x + w / 2, y + h / 2, t, cex = cex) }
  flecha <- function(x0, y0, x1, y1) arrows(x0, y0, x1, y1, length = 0.07, lwd = 1.2, col = "#555d66")
  caja(1, 30, 17, 16, "VCF of the panel\n(biallelic SNPs,\nsame strains)\n+ ORF annotation", "#fff1e3", COL$cer)
  flecha(18, 38, 23, 38)
  caja(23, 30, 18, 16, "Genetic distance\nper ORF and\ngenome-wide\n(allele-dose IBS)")
  flecha(41, 38, 46, 38)
  caja(46, 30, 18, 16, "Neighbour-joining\ntrees: one per ORF\n+ one reference\n(all SNPs)", "#e0f5f3", COL$teal)
  flecha(64, 38, 69, 38)
  caja(69, 30, 30, 16, "Bipartitions of every tree\nforest support per branch,\nRF and directional concordance\nfor all pairs (incl. reference)", "#e5eef8", COL$eub)
  flecha(84, 30, 84, 24)
  caja(1, 4, 31, 16, "Position along the genome:\nSNPs, resolution, support, agreement\nwith the reference, conflict per ORF", cex = 0.68)
  caja(35, 4, 29, 16, "Topological groups (MST-kNN)\nwith resolution controls;\nGO/KEGG enrichment; linkage test", cex = 0.68)
  caja(68, 4, 31, 16, "YeastForest: web application\nforest projection, trees with support,\npairwise comparison, groups, strains", "#fff5d6", COL$oro, cex = 0.68)
  segments(16, 24, 84, 24, lwd = 1.2, col = "#555d66"); flecha(84, 24, 84, 20.3); flecha(49, 24, 49, 20.3); flecha(16, 24, 16, 20.3)
})

# ---- Fig 2: genomic map of the groups in both species + adjacency statistic
mapa_genoma <- function(pos, genes, ligg, titulo, etiquetar = 10L) {
  d <- merge(pos, genes[, .(orf, cluster)], by = "orf")[order(chr, pos)]; d[, idx := seq_len(.N), by = chr]
  pal <- c("#c8102e", "#2e6fb0", "#2e8b3d", "#7e5ea8", "#ea7600", "#00a499", "#eaaa00", "#8a2043", "#59a8d2", "#5e7a46", "#b35a00", "#a06ab4", "#159c88", "#c56a6e", "#4a5fa6", "#8a9a34", "#e39a00", "#35673b", "#d98ba0", "#6e82be")
  ids <- sort(unique(na.omit(d$cluster))); set.seed(7); colc <- setNames(pal[(sample(seq_along(ids)) - 1L) %% length(pal) + 1L], ids)
  maxn <- max(d$idx); nchr <- max(d$chr)
  plot(0, 0, type = "n", xlim = c(0, maxn * 1.02), ylim = c(0.5, nchr + 0.5), axes = FALSE, xlab = "", ylab = "")
  axis(2, at = nchr:1, labels = as.roman(1:nchr), las = 1, tick = FALSE, cex.axis = 0.62, line = -0.4)
  axis(1, at = pretty(c(0, maxn)), cex.axis = 0.62); mtext("ORFs in chromosomal order", 1, line = 1.2, cex = 0.68)
  for (ch in 1:nchr) {
    t <- d[chr == ch]; y <- nchr + 1 - ch
    rect(t$idx - 1, y - 0.38, t$idx, y + 0.38, col = ifelse(is.na(t$cluster), "#e4e7ea", colc[as.character(t$cluster)]), border = NA)
    # centromere (first ORF of the right arm); the right arm of XVI has no trees
    if ("brazo" %in% names(t) && any(t$brazo == "R")) { cen <- t[brazo == "R", min(idx)]; points(cen - 0.5, y, pch = 21, bg = "white", col = "#1b2127", cex = 0.55, lwd = 0.7) }
  }
  # label of the largest linked blocks, at the centre of their dominant run
  lg <- ligg[ligado == TRUE][order(-orfs)][seq_len(min(etiquetar, sum(ligg$ligado)))]
  for (i in seq_len(nrow(lg))) {
    k <- lg$cluster[i]; t <- d[cluster == k]; ch <- as.integer(names(which.max(table(t$chr)))); tt <- t[chr == ch]
    text(median(tt$idx), nchr + 1 - ch + 0.66, paste0("G", k), cex = 0.48, col = "#1b2127", font = 2)
  }
  title(main = titulo, cex.main = 0.75, font.main = 3, adj = 0.04)
  invisible(colc)
}
pdfpng("Fig2_mapa_genoma", 7.2, 7.6, function() {
  layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE), heights = c(1.45, 1))
  par(mar = c(2.3, 2.6, 1.6, 0.6), mgp = c(1.4, 0.35, 0))
  mapa_genoma(pos_cer, sp$cer$genes, ligg$cer, "S. cerevisiae: 1,011 strains, 5,903 ORF trees, 210 MST-kNN groups", 14L); mtext("A", side = 3, line = 0.3, adj = -0.03, font = 2, cex = 1.1)
  par(mar = c(2.3, 2.6, 1.6, 0.6))
  mapa_genoma(pos_eub, sp$eub$genes, ligg$eub, "S. eubayanus: 471 strains, 3,589 ORF trees, 114 groups", 2L); mtext("B", side = 3, line = 0.3, adj = -0.06, font = 2, cex = 1.1)
  par(mar = c(3.2, 3.4, 1.6, 0.6), cex.axis = 0.68, cex.lab = 0.76)
  bp <- barplot(rbind(c(lig$cer$esperado, lig$cer$obs), c(lig$eub$esperado, lig$eub$obs)) * 100, beside = TRUE, col = c(adjustcolor(COL$cer, .45), COL$cer, adjustcolor(COL$eub, .45), COL$eub)[c(1, 3, 2, 4)], border = NA,
    names.arg = c("random assignment", "observed"), ylab = "Adjacent ORFs in the same group (%)", ylim = c(0, 70))
  legend("topleft", bty = "n", cex = 0.68, fill = c(COL$cer, COL$eub), border = NA, legend = c("S. cerevisiae", "S. eubayanus"))
  text(bp, rbind(c(lig$cer$esperado, lig$cer$obs), c(lig$eub$esperado, lig$eub$obs)) * 100, sprintf("%.1f", rbind(c(lig$cer$esperado, lig$cer$obs), c(lig$eub$esperado, lig$eub$obs)) * 100), pos = 3, cex = 0.6)
  panel("C")
})
# ---- Fig 3: resolution and groups
pdfpng("Fig3_resolucion", 7.2, 5.6, function() {
  layout(matrix(1:4, 2, byrow = TRUE)); par(mar = c(3.2, 3.4, 1.6, 0.6), mgp = c(1.7, 0.4, 0), cex.axis = 0.7, cex.lab = 0.78)
  g <- sp$cer$genes
  # A: SNPs vs RF to the reference, G1 highlighted
  plot(g$n_snps, g$rf_ref, log = "x", pch = 16, cex = 0.25, col = adjustcolor("#9aa5af", 0.5), xlab = "SNPs within the ORF", ylab = "RF distance to the reference tree")
  points(g[cluster == 1, n_snps], g[cluster == 1, rf_ref], pch = 16, cex = 0.3, col = adjustcolor(COL$rojo, 0.6))
  legend("bottomleft", bty = "n", cex = 0.65, pch = 16, col = c(COL$rojo, "#9aa5af"), legend = c("G1 (498 ORFs, ribosome-enriched)", "other ORFs"))
  legend("topright", bty = "n", cex = 0.65, legend = sprintf("Spearman rho = %.2f", cifras$cer_rho_snps_rfref)); panel("A")
  # B: resolution per group (12 largest), cerevisiae
  top <- sp$cer$G$clusters$id[order(-sp$cer$G$clusters$tamano)][1:12]
  bx <- g[cluster %in% top]; bx[, cluster := factor(cluster, levels = top)]
  boxplot(resolucion ~ cluster, bx, outline = FALSE, col = ifelse(top == 1, adjustcolor(COL$rojo, 0.5), "#eceff2"), border = "#555d66", xlab = "MST-kNN group (12 largest, S. cerevisiae)", ylab = "Tree resolution (internal branches / max)", names = paste0("G", top), las = 2, cex.axis = 0.6)
  text(par("usr")[2], par("usr")[4], sprintf("Kruskal-Wallis eta2 = %.2f", cifras$cer_eta2_resol), adj = c(1.05, 1.6), cex = 0.65); panel("B")
  # C: ARI vs resolution threshold, both species (SNP threshold 0)
  plot(0, 0, type = "n", xlim = c(0, 0.25), ylim = c(0, 1), xlab = "Minimum resolution required to enter the clustering", ylab = "Adjusted Rand index vs. full clustering")
  for (k in c("cer", "eub")) { b <- B[[k]][umbral_snps == 0][order(umbral_resolucion)]; lines(b$umbral_resolucion, b$ari_vs_completo, type = "b", pch = 16, col = COL[[k]], lwd = 1.6) }
  legend("bottomleft", bty = "n", cex = 0.7, lwd = 1.6, pch = 16, col = c(COL$cer, COL$eub), legend = c("S. cerevisiae", "S. eubayanus")); panel("C")
  # D: ARI vs SNP threshold
  plot(0, 0, type = "n", xlim = c(0, 100), ylim = c(0, 1), xlab = "Minimum SNPs per ORF required to enter the clustering", ylab = "Adjusted Rand index vs. full clustering")
  for (k in c("cer", "eub")) { b <- B[[k]][umbral_resolucion == 0][order(umbral_snps)]; lines(b$umbral_snps, b$ari_vs_completo, type = "b", pch = 16, col = COL[[k]], lwd = 1.6) }
  legend("topright", bty = "n", cex = 0.7, lwd = 1.6, pch = 16, col = c(COL$cer, COL$eub), legend = c("S. cerevisiae", "S. eubayanus")); panel("D")
})

# ---- Fig 4: conflict with the reference
pdfpng("Fig4_conflicto", 7.2, 5.4, function() {
  layout(matrix(c(1, 2, 3, 3), 2, byrow = TRUE), heights = c(1.15, 1)); par(mgp = c(1.7, 0.4, 0), cex.axis = 0.68, cex.lab = 0.76)
  for (k in c("cer", "eub")) {
    par(mar = c(3.4, 8.8, 2.2, 1.6))
    t <- head(top_conf[[k]], 8L)
    lab <- ifelse(is.na(t$grupo_dominante), sprintf("mixed clade of %d strains", t$cepas_lado_menor),
                  sprintf("%s %d/%d", t$grupo_dominante, round(t$pct_dominante / 100 * t$cepas_lado_menor), t$cepas_lado_menor))
    b <- barplot(rev(t$orfs), horiz = TRUE, col = COL[[k]], border = NA, names.arg = rev(lab), las = 1, xlab = "ORF trees that contain the branch", cex.names = 0.62, xlim = c(0, max(t$orfs) * 1.25), ylim = c(0, 9.8), width = 0.85, space = 0.18)
    text(rev(t$orfs), b, sprintf("%.1f%%", rev(t$respaldo)), pos = 4, cex = 0.58, xpd = TRUE)
    mtext(if (k == "cer") "S. cerevisiae" else "S. eubayanus", side = 3, line = 0.9, cex = 0.72, font = 3, adj = 0)
    mtext("supported branches absent from the reference tree", side = 3, line = 0.15, cex = 0.55, adj = 0)
    mtext(if (k == "cer") "A" else "B", side = 3, line = 0.9, adj = -0.42, font = 2, cex = 1.1)
  }
  par(mar = c(3.4, 3.6, 2.2, 0.8))
  sup <- lapply(ref_tree, function(t) { s <- suppressWarnings(as.numeric(t$node.label)); s[!is.na(s)] })
  br <- c(-0.001, 0.0001, 1, 5, 25, 50, 100); h1 <- hist(sup$cer, breaks = br, plot = FALSE)$counts / length(sup$cer); h2 <- hist(sup$eub, breaks = br, plot = FALSE)$counts / length(sup$eub)
  barplot(rbind(h1, h2) * 100, beside = TRUE, col = c(COL$cer, COL$eub), border = NA, names.arg = c("0", "> 0 to 1", "1 to 5", "5 to 25", "25 to 50", "50 or more"), ylab = "Branches of the reference tree (%)", xlab = "Forest support of the branch (% of ORF trees that contain it)")
  legend("topright", bty = "n", cex = 0.7, fill = c(COL$cer, COL$eub), border = NA, legend = c(sprintf("S. cerevisiae (%d branches)", length(sup$cer)), sprintf("S. eubayanus (%d branches)", length(sup$eub))))
  mtext("C", side = 3, line = 0.9, adj = -0.06, font = 2, cex = 1.1)
})
# ---- Fig 5: comparison with the earlier forest and between species
pdfpng("Fig5_validacion", 7.2, 3.2, function() {
  layout(matrix(1:3, 1)); par(mar = c(3.4, 3.4, 2.4, 0.6), mgp = c(1.7, 0.4, 0), cex.axis = 0.7, cex.lab = 0.78)
  plot(Fo$n_snps, Fo$rf_anterior_vs_nuevo, log = "x", pch = 16, cex = 0.25, col = adjustcolor("#555d66", 0.35), xlab = "SNPs within the ORF", ylab = "RF: alignment-based vs. VCF-based tree")
  legend("topright", bty = "n", cex = 0.65, legend = sprintf("%d ORFs, rho = %.2f", nrow(Fo), cifras$F_rho_snps)); panel("A")
  plot(Fo$rf_anterior_vs_referencia, Fo$rf_nuevo_vs_referencia, pch = 16, cex = 0.25, col = adjustcolor("#555d66", 0.35), xlab = "RF to reference, alignment-based tree", ylab = "RF to reference, VCF-based tree"); abline(0, 1, lty = 2, col = "#9aa5af")
  legend("topleft", bty = "n", cex = 0.65, legend = sprintf("rho = %.2f", cifras$F_rho_ref)); panel("B")
  d1 <- density(sp$cer$genes$rf_ref, from = 0.7, to = 1); d2 <- density(sp$eub$genes$rf_ref, from = 0.7, to = 1)
  plot(d1, col = COL$cer, lwd = 1.8, main = "", xlab = "RF distance of each ORF tree to its reference", ylab = "Density", ylim = c(0, max(d1$y, d2$y)))
  lines(d2, col = COL$eub, lwd = 1.8); legend("topleft", bty = "n", cex = 0.7, lwd = 1.8, col = c(COL$cer, COL$eub), legend = c("S. cerevisiae", "S. eubayanus")); panel("C")
})

# -----------------------------------------------------------------------------
# 5. Save the numbers
# -----------------------------------------------------------------------------
cif <- data.table(clave = names(cifras), valor = vapply(cifras, function(v) as.character(v), ""))
fwrite(cif, file.path(OUT, "cifras.tsv"), sep = "\t")
print(cif, nrows = 300)
