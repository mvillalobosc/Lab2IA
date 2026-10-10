# =============================================================================
# ANALISIS PARA PUBLICAR EL BOSQUE FILOGENETICO (S. cerevisiae o S. eubayanus)
# Manuel: deja este archivo en la carpeta de resultados del bosque (donde estan
# <prefijo>_resumen.tsv, _arboles.nwk, _RF.csv.gz, _clusters.tsv, _enriquecimiento.tsv)
# junto a bosque_<especie>.R y clusters_<especie>.R, y ejecutalo con
# source("publicar_bosque.R"). El mismo archivo sirve en las dos carpetas: la
# especie sale del <prefijo>_resumen.tsv que encuentra (SCerevisiae o Eubayanus) y
# con ella los scripts, las etapas y los archivos de ESPECIES (mas abajo). Corre las
# etapas de CONFIG$etapas; cada una escribe sus tablas <prefijo>_pub_*.tsv y se
# puede repetir sola. El TSV de cepas y la anotacion los busca en esta carpeta y en
# la de arriba (donde los usa preparar_app.R). Fecha: 2026-10-10.
# =============================================================================
# ETAPAS (lo que un revisor va a pedir)
#  A resolucion  Confundente de resolucion en los grupos MST-kNN: SNPs, resolucion,
#                RF a la referencia y respaldo por grupo; Kruskal-Wallis entre grupos.
#  B umbrales    MST-kNN repetido solo con ORFs que superen umbrales de SNPs y de
#                resolucion; cuantos grupos sobreviven y ARI contra el clustering
#                completo (sobre los ORFs que entran).
#  C nulo        Enriquecimiento con nulo emparejado por SNPs: para cada termino que
#                paso FDR < nulo_fdr_max con la hipergeometrica, p empirico contra
#                conjuntos aleatorios de genes con la misma distribucion de SNPs.
#  D conflicto   Mapa gen-genoma: ramas con respaldo >= conflicto_min_respaldo y al
#                menos conflicto_min_cepas cepas en su lado menor que NO estan en la
#                referencia (conflicto apoyado por otros genes),
#                ordenadas por cromosoma; tramos contiguos de ORFs en conflicto con
#                p empirico por permutacion dentro de cada cromosoma; y que grupos de
#                cepas separan esas ramas (si hay archivo de cepas).
#  E bootstrap   Bootstrap clasico de SNPs (B replicas) en una submuestra de ORFs
#                estratificada por SNPs, leyendo el VCF con las funciones del script
#                del bosque; correlacion rama a rama entre bootstrap y respaldo.
#  F anterior    Comparacion con el bosque anterior por alineamientos (carpeta con
#                <ORF>.nwk): RF entre el arbol viejo y el nuevo del mismo ORF.
#  G submuestra  Lista estratificada de cepas para rehacer el bosque de cerevisiae
#                con tantas cepas como eubayanus, y comparar_bosques() para poner
#                dos corridas lado a lado.
# DEFINICIONES: las mismas del bosque. RF(A,B) = (sA+sB-2c)/(sA+sB). Respaldo de una
# rama = % de los OTROS ORFs con esa biparticion. Resolucion = ramas internas/(n-3).
# Nada de esto recalcula el bosque: E es la unica etapa que vuelve a leer el VCF.
# =============================================================================

CONFIG <- list(
  species = NULL,                          # prefijo de los archivos del bosque; NULL = el de esta carpeta
  # Lo que queda en NULL se toma de ESPECIES segun la especie:
  etapas = NULL,                           # E necesita el VCF (lo lee con bosque_<especie>.R)
  script_bosque = NULL,                    # funciones del bosque (splits, VCF, NJ)
  script_clusters = NULL,                  # funciones de anotacion GO/KEGG (etapa C)
  cepas = NULL,                            # cepa + capas; D usa la primera capa
  anotacion = NULL,                        # coordenadas para D: SGD_features.tab o gene_result.txt
  umbrales_snps = NULL,                    # B: minimo de SNPs del ORF
  umbrales_resolucion = c(0, 0.10, 0.25),  # B: minimo de resolucion
  nulo_B = 1000L, nulo_bines = 10L, nulo_fdr_max = 0.25, nulo_semilla = 2026L,
  conflicto_min_respaldo = 5,              # D: % de otros ORFs para llamar "respaldada" a una rama
  conflicto_min_cepas = 5L,                # D: cepas minimas en el lado menor (descarta pares y trios de cepas casi identicas)
  conflicto_min_tramo = 3L,                # D: ORFs contiguos en conflicto para llamarlo tramo
  conflicto_permutaciones = 1000L,
  bootstrap_n_orfs = 200L, bootstrap_B = 100L, bootstrap_semilla = 2026L,
  bosque_anterior = "~/SCForest/data/Arboles", # F: carpeta con <ORF>.nwk del bosque por alineamientos
  submuestra_n = 471L, submuestra_semilla = 2026L,
  hilos = 2L
)
# Valores de cada especie, los mismos con que se hicieron las tablas del paper. En
# cerevisiae D ordena los ORFs por su nombre sistematico (anotacion = NULL); en
# eubayanus usa las coordenadas de gene_result.txt (la primera que encuentre).
# C y F solo tienen sentido en cerevisiae (enriquecimiento y bosque anterior) y G
# tambien, porque eubayanus ya tiene 471 cepas.
ESPECIES <- list(
  SCerevisiae = list(etapas = c("A", "B", "C", "D", "E", "F", "G"),
                     script_bosque = "bosque_SCerevisiae.R", script_clusters = "clusters_SCerevisiae.R",
                     cepas = "cepas_cerevisiae.tsv", anotacion = NULL, umbrales_snps = c(0L, 30L, 100L)),
  Eubayanus = list(etapas = c("A", "B", "D", "E"),
                   script_bosque = "bosque_Eubayanus.R", script_clusters = "clusters_Eubayanus.R",
                   cepas = "cepas_eubayanus.tsv", umbrales_snps = c(0L, 10L, 30L),
                   anotacion = c("gene_result.txt", "gene_result_eubayanus.txt", "~/EvolutiveEubayanus/DATA/gene_result.txt"))
)

# -----------------------------------------------------------------------------
# 1. UTILIDADES
# -----------------------------------------------------------------------------
ensure_packages <- function() {
  pk <- c("data.table", "ape", "digest", "Matrix", "mstknnclust", "R.utils")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) stop("Faltan paquetes: ", paste(falta, collapse = ", "))
}
logmsg <- function(...) { cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = ""); flush.console() }
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
safe_names <- function(x) make.unique(gsub("[^A-Za-z0-9_.-]", "_", x), sep = "__")
read_tsv <- function(f, ...) data.table::fread(f, sep = "\t", na.strings = c("NA", ""), ...)
write_tsv <- function(x, file) { data.table::fwrite(x, file, sep = "\t", na = "NA"); logmsg("  Guardado ", basename(file)) }
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) { f <- sys.frame(i)$ofile; if (is.character(f) && length(f) == 1L && nzchar(f)) return(dirname(normalizePath(path.expand(f)))) }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}
resolve_file <- function(base, file) { if (is.null(file)) return(NULL); path.expand(if (grepl("^(~|/|[A-Za-z]:)", file)) file else file.path(base, file)) }
out_file <- function(ctx, sufijo) file.path(ctx$dir, paste0(ctx$pref, "_pub_", sufijo))
# Primer archivo que exista entre los candidatos, en esta carpeta o en la de arriba.
buscar_archivo <- function(dir, archivos) {
  for (a in archivos) for (p in unique(c(resolve_file(dir, a), resolve_file(dirname(dir), a)))) if (file.exists(p)) return(p)
  NULL
}
# Especie de la carpeta (el prefijo que tiene _resumen.tsv y _RF.csv.gz) y valores de
# ESPECIES para todo lo que CONFIG deja en NULL.
completar_config <- function(cfg, dir) {
  if (is.null(cfg$species)) {
    pref <- sub("_resumen\\.tsv$", "", list.files(dir, pattern = "_resumen\\.tsv$"))
    pref <- pref[file.exists(file.path(dir, paste0(pref, "_RF.csv.gz")))]
    if (length(pref) != 1L) stop("No pude saber la especie en ", dir, ": pon CONFIG$species (prefijos con _resumen.tsv y _RF.csv.gz: ",
                                 if (length(pref)) paste(pref, collapse = ", ") else "ninguno", ")")
    cfg$species <- pref
  }
  base <- ESPECIES[[cfg$species]]
  if (is.null(base)) base <- list(etapas = c("A", "B", "D"), umbrales_snps = c(0L, 30L, 100L))   # otra especie: completa CONFIG a mano
  for (k in names(base)) if (is.null(cfg[[k]])) cfg[k] <- list(base[[k]])
  cfg
}

# Carga las funciones de otro script sin ejecutarlo (PHYLO_LIBRARY_ONLY=1) en su propio entorno.
cargar_script <- function(path) {
  if (!file.exists(path)) stop("No encuentro ", path)
  old <- Sys.getenv("PHYLO_LIBRARY_ONLY"); Sys.setenv(PHYLO_LIBRARY_ONLY = "1"); on.exit(Sys.setenv(PHYLO_LIBRARY_ONLY = old))
  env <- new.env(parent = globalenv()); sys.source(path, envir = env); env
}
leer_matriz <- function(path) {
  x <- data.table::fread(path, header = TRUE, check.names = FALSE)
  m <- as.matrix(x[, -1L, with = FALSE]); dimnames(m) <- list(as.character(x[[1L]]), names(x)[-1L]); rm(x)
  if (!identical(rownames(m), colnames(m))) stop("La matriz ", basename(path), " no tiene los mismos ids en filas y columnas.")
  m
}
# Indice de Rand ajustado entre dos particiones (vectores de etiquetas, mismo largo).
rand_ajustado <- function(a, b) {
  tab <- table(a, b); n <- sum(tab)
  comb2 <- function(x) x * (x - 1) / 2
  sij <- sum(comb2(tab)); si <- sum(comb2(rowSums(tab))); sj <- sum(comb2(colSums(tab)))
  esperado <- si * sj / comb2(n); maximo <- (si + sj) / 2
  if (maximo == esperado) return(1)
  (sij - esperado) / (maximo - esperado)
}
# Biparticiones de un arbol con su respaldo (node.label) usando tree_splits del bosque,
# y el tamano del lado menor de cada una.
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
# 2. CONTEXTO: resumen, clusters, arboles, cepas
# -----------------------------------------------------------------------------
abrir_contexto <- function(cfg) {
  dir <- script_dir(); pref <- cfg$species
  f <- function(s) file.path(dir, paste0(pref, s))
  for (s in c("_resumen.tsv", "_arboles.nwk", "_RF.csv.gz")) if (!file.exists(f(s))) stop("No encuentro ", f(s))
  res <- read_tsv(f("_resumen.tsv"), colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  ok <- res[status == "ok"][order(newick_line)]
  cl <- if (file.exists(f("_clusters.tsv"))) read_tsv(f("_clusters.tsv"), colClasses = list(character = c("tree_id", "orf", "origen"))) else NULL
  enr <- if (file.exists(f("_enriquecimiento.tsv"))) read_tsv(f("_enriquecimiento.tsv"), colClasses = list(character = c("base", "termino", "descripcion", "genes"))) else NULL
  cepas <- NULL; fc <- buscar_archivo(dir, cfg$cepas)
  if (!is.null(fc) && file.exists(fc)) {
    t <- read_tsv(fc, colClasses = "character", encoding = "UTF-8")
    cepas <- data.table::data.table(cepa = safe_names(trimws(t[[1L]])), grupo = trimws(t[[2L]]))
    cepas[is.na(grupo) | !nzchar(grupo), grupo := NA_character_]
    logmsg("  Cepas con ", names(t)[2L], ": ", sum(!is.na(cepas$grupo)), " de ", nrow(cepas))
  }
  env_bosque <- if (!is.null(cfg$script_bosque) && file.exists(resolve_file(dir, cfg$script_bosque))) cargar_script(resolve_file(dir, cfg$script_bosque)) else NULL
  logmsg("Bosque ", pref, ": ", fmt_n(nrow(ok) - 1L), " ORFs con arbol | grupos: ", if (is.null(cl)) "no" else data.table::uniqueN(cl$cluster),
         " | enriquecimiento: ", if (is.null(enr)) "no" else fmt_n(nrow(enr)), " pruebas")
  list(dir = dir, pref = pref, cfg = cfg, res = res, ok = ok, cl = cl, enr = enr, cepas = cepas, env = env_bosque,
       f_rf = f("_RF.csv.gz"), f_nwk = f("_arboles.nwk"))
}
# RF y arboles se leen solo cuando una etapa los necesita (son grandes).
ctx_rf <- function(ctx) { if (is.null(ctx$rf)) { logmsg("  Leyendo RF todos vs todos"); ctx$rf <- leer_matriz(ctx$f_rf)[ctx$ok$tree_id, ctx$ok$tree_id] }; ctx }
ctx_arboles <- function(ctx) {
  if (is.null(ctx$arboles)) {
    logmsg("  Leyendo ", basename(ctx$f_nwk), " (", fmt_n(nrow(ctx$ok)), " arboles)")
    tr <- ape::read.tree(ctx$f_nwk)
    if (length(tr) != nrow(ctx$ok)) stop("El .nwk trae ", length(tr), " arboles y el resumen ", nrow(ctx$ok))
    names(tr) <- ctx$ok$tree_id; ctx$arboles <- tr; ctx$labels <- sort(tr[[1L]]$tip.label)
  }
  ctx
}

# -----------------------------------------------------------------------------
# A. CONFUNDENTE DE RESOLUCION EN LOS GRUPOS
# -----------------------------------------------------------------------------
etapa_A <- function(ctx) {
  if (is.null(ctx$cl)) { logmsg("A: sin clusters, se omite"); return(ctx) }
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
  # eta cuadrado de Kruskal (cuanto de la varianza explica el grupo), para reportar efecto y no solo p
  eta <- function(v) { h <- stats::kruskal.test(multi[[v]], factor(multi$cluster))$statistic; k <- data.table::uniqueN(multi$cluster); n <- nrow(multi); max(0, (h - k + 1) / (n - k)) }
  pruebas[, eta2_kruskal := c(eta("n_snps"), eta("resolution"), eta("RF_to_total"), eta("forest_branch_mean_pct"))]
  write_tsv(por, out_file(ctx, "A_resolucion_por_grupo.tsv"))
  write_tsv(pruebas, out_file(ctx, "A_resolucion_pruebas.tsv"))
  logmsg("A: eta2 de resolucion entre grupos = ", sprintf("%.3f", pruebas$eta2_kruskal[2]),
         " | grupo mas grande: SNPs mediana ", por$snps_mediana[1L], ", ", sprintf("%.0f", por$pct_resolucion_bajo_10[1L]), "% con resolucion < 10%")
  ctx
}

# -----------------------------------------------------------------------------
# B. MST-kNN CON UMBRALES DE SNPs Y RESOLUCION
# -----------------------------------------------------------------------------
mstknn_subconjunto <- function(rf, ids) {
  D <- rf[ids, ids, drop = FALSE]; diag(D) <- 0
  if (anyNA(D)) stop("RF indefinidas en el subconjunto")
  msgs <- utils::capture.output(r <- mstknnclust::mst.knn(D))
  cl <- if (any(grepl("Only singletons", msgs))) integer() else r$cluster
  member <- data.table::data.table(tree_id = names(cl), cluster = as.integer(cl))
  solos <- setdiff(ids, member$tree_id)   # igual que el script de clusters: cada solitario, un grupo
  if (length(solos)) member <- rbind(member, data.table::data.table(tree_id = solos, cluster = max(c(0L, member$cluster)) + seq_along(solos)))
  member[, tamano := .N, by = cluster]
  ord <- member[, .(tamano = tamano[1L]), by = cluster][order(-tamano, cluster)]
  member[, cluster := match(cluster, ord$cluster)][]
}
etapa_B <- function(ctx) {
  if (is.null(ctx$cl)) { logmsg("B: sin clusters, se omite"); return(ctx) }
  ctx <- ctx_rf(ctx); cfg <- ctx$cfg
  genes <- ctx$ok[tree_id != "REF_TOTAL"]
  completo <- ctx$cl$cluster; names(completo) <- ctx$cl$tree_id
  filas <- list(); miembros <- list()
  for (s in cfg$umbrales_snps) for (r in cfg$umbrales_resolucion) {
    ids <- genes[n_snps >= s & resolution >= r, tree_id]
    if (length(ids) < 10L) { logmsg("  SNPs>=", s, " res>=", r, ": solo ", length(ids), " ORFs, se omite"); next }
    logmsg("  MST-kNN con SNPs >= ", s, " y resolucion >= ", r, ": ", fmt_n(length(ids)), " ORFs")
    m <- if (s == 0 && r == 0) data.table::data.table(tree_id = ctx$cl$tree_id, cluster = ctx$cl$cluster)[, tamano := .N, by = cluster][tree_id %in% ids]
         else mstknn_subconjunto(ctx$rf, ids)
    ari <- rand_ajustado(m$cluster, completo[m$tree_id])
    tam <- m[, .(tamano = .N), by = cluster][order(-tamano)]
    # con que grupo del clustering completo se solapa mas cada grupo nuevo (los 5 mayores)
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
  logmsg("B: ARI contra el clustering completo por umbral: ", paste(sprintf("SNPs>=%d/res>=%.2f: %.2f", tabla$umbral_snps, tabla$umbral_resolucion, tabla$ari_vs_completo), collapse = " | "))
  ctx
}

# -----------------------------------------------------------------------------
# C. ENRIQUECIMIENTO CON NULO EMPAREJADO POR SNPs
# -----------------------------------------------------------------------------
# ann: data.table(gene, term, database, description) con el gen del bosque como "gene"
# (la construye anotaciones_desde_clusters con las funciones de clusters_<especie>.R).
anotaciones_desde_clusters <- function(ctx) {
  f <- resolve_file(ctx$dir, ctx$cfg$script_clusters)
  if (is.null(f) || !file.exists(f)) stop("C necesita clusters_<especie>.R para las anotaciones (CONFIG$script_clusters)")
  env <- cargar_script(f); cfgc <- env$CONFIG
  member <- data.table::copy(ctx$cl)
  if (!"orf_sgd" %in% names(member) || all(is.na(member$orf_sgd))) {
    if (identical(cfgc$gene_ids, "sgd")) member[, orf_sgd := orf] else {
      map <- env$map_orthologs(member$orf, cfgc, ctx$dir); member[, orf_sgd := map$orf_sgd[match(orf, map$gene)]]
    }
  }
  ann_sgd <- env$sgd_annotations(unique(stats::na.omit(member$orf_sgd)), cfgc)
  if (!nrow(ann_sgd)) stop("Sin anotaciones GO/KEGG")
  merge(member[!is.na(orf_sgd), .(gene = orf, orf_sgd)], ann_sgd, by.x = "orf_sgd", by.y = "gene", allow.cartesian = TRUE)[, orf_sgd := NULL]
}
nulo_emparejado <- function(ctx, ann) {
  cfg <- ctx$cfg; set.seed(cfg$nulo_semilla)
  if (is.null(ctx$enr)) stop("C necesita <prefijo>_enriquecimiento.tsv")
  snps <- ctx$ok$n_snps; names(snps) <- ctx$ok$orf
  cl <- ctx$cl[, .(gene = orf, cluster)]
  probar <- ctx$enr[fdr < cfg$nulo_fdr_max]
  if (!nrow(probar)) { logmsg("C: ningun termino con FDR < ", cfg$nulo_fdr_max); return(NULL) }
  out <- list()
  for (db in unique(probar$base)) {
    a <- unique(ann[database == db, .(gene, term)])
    univ <- unique(a$gene); univ <- univ[univ %in% names(snps)]
    a <- a[gene %in% univ]
    terms <- unique(probar[base == db, termino])
    a <- a[term %in% terms]
    if (!nrow(a)) next
    M <- Matrix::sparseMatrix(i = match(a$gene, univ), j = match(a$term, terms), x = 1, dims = c(length(univ), length(terms)))
    # bines de SNPs por cuantiles del universo de esta base
    cortes <- unique(stats::quantile(snps[univ], probs = seq(0, 1, length.out = cfg$nulo_bines + 1L)))
    bin <- cut(snps[univ], breaks = cortes, include.lowest = TRUE, labels = FALSE)
    por_bin <- split(seq_along(univ), bin)
    for (k in unique(probar[base == db, cluster])) {
      genes_k <- intersect(cl[cluster == k, gene], univ); n_k <- length(genes_k)
      if (n_k < 2L) next
      cuenta <- table(factor(bin[match(genes_k, univ)], levels = names(por_bin)))
      idx_k <- match(genes_k, univ)
      k_obs <- as.numeric(Matrix::colSums(M[idx_k, , drop = FALSE]))
      K <- matrix(0, cfg$nulo_B, length(terms))
      for (b in seq_len(cfg$nulo_B)) {
        idx <- unlist(lapply(names(por_bin), function(bn) { pool <- por_bin[[bn]]; m <- cuenta[[bn]]; if (m == 0L) integer() else if (length(pool) == 1L) rep(pool, m) else sample(pool, m, replace = m > length(pool)) }), use.names = FALSE)
        K[b, ] <- as.numeric(Matrix::colSums(M[idx, , drop = FALSE]))
      }
      for (t in probar[base == db & cluster == k, termino]) {
        j <- match(t, terms); if (is.na(j)) next
        fila <- probar[base == db & cluster == k & termino == t][1L]
        out[[length(out) + 1L]] <- data.table::data.table(cluster = k, base = db, termino = t, descripcion = fila$descripcion,
          k_observado = k_obs[j], n_cluster_anotados = n_k, K_en_universo = fila$K_en_universo, p_hipergeometrica = fila$p, fdr_hipergeometrica = fila$fdr,
          k_nulo_media = mean(K[, j]), k_nulo_q95 = unname(stats::quantile(K[, j], .95)),
          p_empirico = (1 + sum(K[, j] >= k_obs[j])) / (cfg$nulo_B + 1), replicas = cfg$nulo_B)
      }
    }
  }
  res <- data.table::rbindlist(out)
  if (!nrow(res)) return(NULL)
  res[, fdr_empirico := stats::p.adjust(p_empirico, "BH")]
  res[, sobrevive_FDR05 := fdr_hipergeometrica < 0.05 & fdr_empirico < 0.05]
  data.table::setorder(res, fdr_empirico, p_empirico)
  res
}
etapa_C <- function(ctx, ann = NULL) {
  if (is.null(ctx$cl) || is.null(ctx$enr)) { logmsg("C: faltan clusters o enriquecimiento, se omite"); return(ctx) }
  if (is.null(ann)) ann <- anotaciones_desde_clusters(ctx)
  res <- nulo_emparejado(ctx, ann)
  if (is.null(res)) return(ctx)
  write_tsv(res, out_file(ctx, "C_enriquecimiento_nulo_snps.tsv"))
  logmsg("C: terminos probados ", nrow(res), " | con FDR hipergeometrico < 0.05: ", sum(res$fdr_hipergeometrica < 0.05),
         " | de esos, sobreviven al nulo por SNPs (FDR empirico < 0.05): ", sum(res$sobrevive_FDR05))
  ctx
}

# -----------------------------------------------------------------------------
# D. MAPA GEN-GENOMA: RAMAS RESPALDADAS QUE CONTRADICEN LA REFERENCIA
# -----------------------------------------------------------------------------
# Posicion de cada ORF: anotacion (SGD_features.tab o gene_result.txt) o, sin ella,
# el nombre sistematico de S. cerevisiae (Y + cromosoma A..P + brazo L/R + numero).
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
    logmsg("  Posiciones desde ", basename(f), ": ", nrow(pos), " de ", length(orfs), " ORFs")
    return(pos)
  }
  m <- regmatches(orfs, regexec("^Y([A-P])([LR])([0-9]{3})[WC]", orfs))
  ok <- lengths(m) == 4L
  if (!any(ok)) stop("D: sin anotacion y los nombres no son sistematicos de S. cerevisiae; indica CONFIG$anotacion")
  chr <- vapply(m[ok], `[`, "", 2L); brazo <- vapply(m[ok], `[`, "", 3L); num <- as.integer(vapply(m[ok], `[`, "", 4L))
  pos <- data.table::data.table(orf = orfs[ok], chr = paste0("chr", as.roman(match(chr, LETTERS[1:16]))), inicio = ifelse(brazo == "L", -num, num))
  logmsg("  Posiciones desde el nombre sistematico: ", nrow(pos), " de ", length(orfs), " ORFs (orden relativo dentro del cromosoma)")
  pos
}
etapa_D <- function(ctx) {
  if (is.null(ctx$env)) stop("D necesita CONFIG$script_bosque para calcular biparticiones")
  ctx <- ctx_arboles(ctx); cfg <- ctx$cfg; env <- ctx$env; labels <- ctx$labels; n <- length(labels)
  logmsg("  Biparticiones de la referencia y de cada ORF (tarda unos minutos)")
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
      # lado menor de cada rama en conflicto y que grupo de cepas domina ese lado
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
  # tramos contiguos de ORFs en conflicto dentro de cada cromosoma
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
  # p empirico: permutar la bandera de conflicto dentro de cada cromosoma
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
  logmsg("D: ORFs en conflicto (alguna rama con respaldo >= ", cfg$conflicto_min_respaldo, "%, lado menor >= ", cfg$conflicto_min_cepas, " cepas, que no esta en la referencia): ", sum(tabla$conflicto),
         " de ", nrow(tabla), " | tramos de >= ", cfg$conflicto_min_tramo, " ORFs: ", n_tramos_obs, " (esperados ", sprintf("%.1f", mean(nulo)), ", p = ", sprintf("%.3f", p_tramos), ")")
  ctx
}

# -----------------------------------------------------------------------------
# E. BOOTSTRAP CLASICO DE SNPs EN UNA SUBMUESTRA DE ORFs
# -----------------------------------------------------------------------------
# Nucleo del bootstrap: x = genotipos codificados (SNPs x muestras, raw), levels del
# codebook, labels = cepas. Devuelve % de replicas que contienen cada rama del arbol original.
bootstrap_orf <- function(x, levels, labels, env, B, tol, min_shared) {
  d0 <- env$parts_to_distance(distance_parts(x, levels), labels, min_shared)
  t0 <- env$make_nj(d0, tol)$tree
  s0 <- env$tree_splits(t0, labels)
  cuenta <- integer(nrow(s0)); validas <- 0L
  for (b in seq_len(B)) {
    idx <- sample.int(nrow(x), nrow(x), replace = TRUE)
    db <- tryCatch(env$parts_to_distance(distance_parts(x[idx, , drop = FALSE], levels), labels, min_shared), error = function(e) NULL)
    if (is.null(db)) next
    sb <- env$tree_splits(env$make_nj(db, tol)$tree, labels)
    cuenta <- cuenta + (s0$key %in% sb$key); validas <- validas + 1L
  }
  list(tree = t0, splits = s0[, bootstrap := if (validas) 100 * cuenta / validas else NA_real_], replicas_validas = validas)
}
etapa_E <- function(ctx) {
  if (is.null(ctx$env)) stop("E necesita CONFIG$script_bosque (lee el VCF con sus funciones)")
  env <- ctx$env; cfgb <- env$CONFIG; cfg <- ctx$cfg
  for (p in c("VariantAnnotation", "GenomicRanges", "IRanges", "S4Vectors", "Rcpp")) if (!requireNamespace(p, quietly = TRUE)) stop("E necesita ", p)
  set.seed(cfg$bootstrap_semilla)
  genes <- ctx$ok[tree_id != "REF_TOTAL"]
  # submuestra estratificada por quintiles de SNPs
  genes[, estrato := cut(n_snps, breaks = unique(stats::quantile(n_snps, seq(0, 1, .2))), include.lowest = TRUE, labels = FALSE)]
  por <- ceiling(cfg$bootstrap_n_orfs / data.table::uniqueN(genes$estrato))
  elegidos <- genes[, .SD[sample.int(.N, min(.N, por))], by = estrato][, .(tree_id, orf, n_snps, estrato)]
  logmsg("  E: ", nrow(elegidos), " ORFs elegidos (", data.table::uniqueN(elegidos$estrato), " estratos de SNPs); leyendo el VCF")
  p <- env$prepare_inputs(cfgb); env$compile_helpers(); cb <- env$make_codebook(cfgb$max_ploidy)
  ann <- p$ann[orf %in% elegidos$orf]
  contigs <- p$vcf_contigs; vcf_chr <- contigs[match(ann$chr_key, env$chr_key(contigs))]
  if (anyNA(vcf_chr)) stop("E: cromosomas de la anotacion sin equivalente en el VCF")
  gr <- GenomicRanges::GRanges(vcf_chr, IRanges::IRanges(ann$start, ann$end))
  param <- VariantAnnotation::ScanVcfParam(info = NA_character_, geno = "GT", samples = p$selected, which = gr)
  v <- VariantAnnotation::readVcf(p$vcf, genome = "unspecified", param = param)
  if (!identical(colnames(VariantAnnotation::geno(v)$GT), p$selected)) stop("E: orden de muestras distinto al de la cabecera")
  z <- env$filter_chunk(v, cb, cfgb)
  rr <- SummarizedExperiment::rowRanges(v)
  pos_gr <- GenomicRanges::GRanges(env$chr_key(as.character(GenomicRanges::seqnames(rr)))[z$rows], IRanges::IRanges(IRanges::start(rr)[z$rows], width = 1L))
  ann_gr <- GenomicRanges::GRanges(ann$chr_key, IRanges::IRanges(ann$start, ann$end))
  hits <- GenomicRanges::findOverlaps(pos_gr, ann_gr, ignore.strand = TRUE)
  memb <- data.table::data.table(orf = ann$orf[S4Vectors::subjectHits(hits)], row = S4Vectors::queryHits(hits))
  memb <- unique(memb)
  ctx <- ctx_arboles(ctx); labels <- ctx$labels
  ramas <- list(); porf <- list(); started <- Sys.time()
  for (i in seq_len(nrow(elegidos))) {
    o <- elegidos$orf[i]; rows <- sort(unique(memb[orf == o, row])); if (!length(rows)) next
    x <- z$gt[rows, , drop = FALSE]
    r <- tryCatch(bootstrap_orf(x, cb$levels, p$labels, env, cfg$bootstrap_B, cfgb$collapse_tolerance, cfgb$min_shared_snps_orf), error = function(e) NULL)
    if (is.null(r)) { logmsg("    ", o, ": no se pudo (", nrow(x), " SNPs)"); next }
    # respaldo del bosque de las mismas ramas (del arbol guardado; deberia ser el mismo arbol)
    guardado <- splits_con_respaldo(ctx$arboles[[elegidos$tree_id[i]]], labels, env)
    r$splits[, respaldo_bosque := guardado$respaldo[match(key, guardado$key)]]
    rf_guardado <- { sA <- nrow(r$splits); sB <- nrow(guardado); c <- sum(r$splits$key %in% guardado$key); if (sA + sB) (sA + sB - 2 * c) / (sA + sB) else NA_real_ }
    ramas[[length(ramas) + 1L]] <- data.table::data.table(orf = o, n_snps = nrow(x), key = r$splits$key, bootstrap = r$splits$bootstrap, respaldo_bosque = r$splits$respaldo_bosque)
    porf[[length(porf) + 1L]] <- data.table::data.table(orf = o, n_snps = nrow(x), n_snps_bosque = elegidos$n_snps[i], ramas = nrow(r$splits), replicas_validas = r$replicas_validas,
      rf_vs_arbol_guardado = rf_guardado, bootstrap_media = mean(r$splits$bootstrap, na.rm = TRUE), respaldo_media = mean(r$splits$respaldo_bosque, na.rm = TRUE),
      rho_spearman = if (nrow(r$splits) >= 5L) suppressWarnings(stats::cor(r$splits$bootstrap, r$splits$respaldo_bosque, method = "spearman", use = "complete.obs")) else NA_real_,
      pct_ramas_boot70 = 100 * mean(r$splits$bootstrap >= 70, na.rm = TRUE), pct_ramas_resp5 = 100 * mean(r$splits$respaldo_bosque >= cfg$conflicto_min_respaldo, na.rm = TRUE))
    if (i %% 20L == 0L) logmsg("    ", i, "/", nrow(elegidos), " ORFs | ", format(round(difftime(Sys.time(), started, units = "mins"), 1)))
  }
  ramas_dt <- data.table::rbindlist(ramas); porf_dt <- data.table::rbindlist(porf)
  global <- data.table::data.table(orfs = nrow(porf_dt), ramas = nrow(ramas_dt), B = cfg$bootstrap_B,
    rho_spearman_global = suppressWarnings(stats::cor(ramas_dt$bootstrap, ramas_dt$respaldo_bosque, method = "spearman", use = "complete.obs")),
    pct_ramas_boot70 = 100 * mean(ramas_dt$bootstrap >= 70, na.rm = TRUE),
    pct_boot70_con_respaldo = 100 * mean(ramas_dt[bootstrap >= 70, respaldo_bosque] >= cfg$conflicto_min_respaldo, na.rm = TRUE),
    pct_boot_bajo30_con_respaldo = 100 * mean(ramas_dt[bootstrap < 30, respaldo_bosque] >= cfg$conflicto_min_respaldo, na.rm = TRUE),
    orfs_con_rf_guardado_0 = sum(porf_dt$rf_vs_arbol_guardado == 0, na.rm = TRUE))
  write_tsv(ramas_dt, out_file(ctx, "E_bootstrap_ramas.tsv")); write_tsv(porf_dt, out_file(ctx, "E_bootstrap_por_orf.tsv")); write_tsv(global, out_file(ctx, "E_bootstrap_resumen.tsv"))
  logmsg("E: rho Spearman bootstrap vs respaldo (todas las ramas) = ", sprintf("%.3f", global$rho_spearman_global),
         " | ramas con bootstrap >= 70 que tienen respaldo >= ", cfg$conflicto_min_respaldo, "%: ", sprintf("%.1f", global$pct_boot70_con_respaldo), "%",
         " | arboles reconstruidos identicos al guardado: ", global$orfs_con_rf_guardado_0, " de ", nrow(porf_dt))
  ctx
}

# -----------------------------------------------------------------------------
# F. COMPARACION CON EL BOSQUE ANTERIOR (ALINEAMIENTOS)
# -----------------------------------------------------------------------------
etapa_F <- function(ctx) {
  if (is.null(ctx$env)) stop("F necesita CONFIG$script_bosque para calcular biparticiones")
  dir_old <- resolve_file(ctx$dir, ctx$cfg$bosque_anterior)
  if (is.null(dir_old) || !dir.exists(dir_old)) { logmsg("F: no existe la carpeta del bosque anterior (", dir_old, "), se omite"); return(ctx) }
  ctx <- ctx_arboles(ctx); env <- ctx$env; labels <- ctx$labels
  viejos <- sub("\\.nwk$", "", list.files(dir_old, pattern = "\\.nwk$"))
  genes <- ctx$ok[tree_id != "REF_TOTAL" & orf %in% viejos]
  logmsg("  F: ", fmt_n(length(viejos)), " arboles anteriores, ", fmt_n(nrow(genes)), " ORFs en comun con el bosque nuevo")
  ref <- env$tree_splits(ctx$arboles[["REF_TOTAL"]], labels)$key
  filas <- list(); started <- Sys.time()
  for (i in seq_len(nrow(genes))) {
    o <- genes$orf[i]
    told <- tryCatch(ape::read.tree(file.path(dir_old, paste0(o, ".nwk"))), error = function(e) NULL)
    if (is.null(told) || !setequal(told$tip.label, labels)) { filas[[i]] <- data.table::data.table(orf = o, motivo = "cepas distintas o no se pudo leer"); next }
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
  logmsg("F: RF anterior vs nuevo (mediana) = ", sprintf("%.3f", resumen$rf_anterior_vs_nuevo_mediana),
         " | rho(RF, SNPs) = ", sprintf("%.3f", resumen$rho_rf_vs_snps), " | rho de la RF a la referencia entre bosques = ", sprintf("%.3f", resumen$rho_rf_referencia_anterior_vs_nuevo))
  ctx
}

# -----------------------------------------------------------------------------
# G. SUBMUESTRA DE CEPAS Y COMPARACION ENTRE DOS CORRIDAS
# -----------------------------------------------------------------------------
etapa_G <- function(ctx) {
  cfg <- ctx$cfg; set.seed(cfg$submuestra_semilla)
  ctx <- ctx_arboles(ctx); labels <- ctx$labels
  if (cfg$submuestra_n >= length(labels)) { logmsg("G: el bosque tiene ", length(labels), " cepas, no hay que submuestrear"); return(ctx) }
  grupo <- if (!is.null(ctx$cepas)) ctx$cepas$grupo[match(labels, ctx$cepas$cepa)] else rep("todas", length(labels))
  grupo[is.na(grupo)] <- "sin grupo"
  d <- data.table::data.table(cepa = labels, grupo = grupo)
  # proporcional por grupo (al menos 1 por grupo), ajustado al total pedido
  cuota <- d[, .(n = .N), by = grupo][, q := pmax(1L, round(n * cfg$submuestra_n / length(labels)))]
  while (sum(cuota$q) > cfg$submuestra_n) { j <- which.max(cuota$q - 1L); cuota$q[j] <- cuota$q[j] - 1L }
  while (sum(cuota$q) < cfg$submuestra_n) { j <- which.max(cuota$n - cuota$q); cuota$q[j] <- cuota$q[j] + 1L }
  sel <- d[, .SD[sample.int(.N, cuota$q[match(.BY$grupo, cuota$grupo)])], by = grupo]$cepa
  f <- out_file(ctx, paste0("G_submuestra_", cfg$submuestra_n, "_cepas.txt"))
  writeLines(sel, f)
  logmsg("G: ", length(sel), " cepas en ", basename(f), " (", data.table::uniqueN(grupo[labels %in% sel]), " grupos). ",
         "Para rehacer el bosque con ellas: en bosque_", cfg$species, ".R pon species = \"", cfg$species, "_sub", cfg$submuestra_n,
         "\", samples_file = \"", basename(f), "\" y previous_results = NULL, y corre el script en otra carpeta.")
  ctx
}
# Pone dos corridas lado a lado (por ejemplo cerevisiae completo, cerevisiae submuestreado y eubayanus).
comparar_bosques <- function(dirs, prefijos, salida = "comparacion_bosques.tsv") {
  filas <- lapply(seq_along(dirs), function(i) {
    r <- read_tsv(file.path(dirs[i], paste0(prefijos[i], "_resumen.tsv")), colClasses = list(character = c("tree_id", "orf", "status", "reason")))
    g <- r[status == "ok" & tree_id != "REF_TOTAL"]; ref <- r[tree_id == "REF_TOTAL"]
    data.table::data.table(bosque = prefijos[i], cepas = ref$n_splits + 3L, snps_referencia = ref$n_snps, orfs_con_arbol = nrow(g), orfs_sin_arbol = sum(r$status != "ok"),
      snps_por_orf_mediana = median(g$n_snps), resolucion_mediana = median(g$resolution), rf_referencia_mediana = median(g$RF_to_total),
      pct_orfs_rf_1 = 100 * mean(g$RF_to_total >= 0.9999), respaldo_medio_mediana = median(g$forest_branch_mean_pct),
      respaldo_referencia = ref$forest_branch_mean_pct)
  })
  tabla <- data.table::rbindlist(filas)
  # KS entre pares de bosques para las distribuciones que importan
  if (length(dirs) >= 2L) {
    g <- lapply(seq_along(dirs), function(i) { r <- read_tsv(file.path(dirs[i], paste0(prefijos[i], "_resumen.tsv")), colClasses = list(character = c("tree_id", "orf", "status", "reason"))); r[status == "ok" & tree_id != "REF_TOTAL"] })
    ks <- list()
    for (i in seq_along(dirs)) for (j in seq_along(dirs)) if (i < j) for (v in c("RF_to_total", "forest_branch_mean_pct", "resolution"))
      ks[[length(ks) + 1L]] <- data.table::data.table(a = prefijos[i], b = prefijos[j], variable = v, D_ks = suppressWarnings(stats::ks.test(g[[i]][[v]], g[[j]][[v]])$statistic),
        p_ks = suppressWarnings(stats::ks.test(g[[i]][[v]], g[[j]][[v]])$p.value))
    write_tsv(data.table::rbindlist(ks), sub("\\.tsv$", "_ks.tsv", salida))
  }
  write_tsv(tabla, salida); tabla
}

# -----------------------------------------------------------------------------
# EJECUCION
# -----------------------------------------------------------------------------
publicar <- function(cfg = CONFIG) {
  inicio <- Sys.time(); ensure_packages(); data.table::setDTthreads(cfg$hilos)
  cfg <- completar_config(cfg, script_dir())
  logmsg("Especie ", cfg$species, " | etapas: ", paste(cfg$etapas, collapse = ", "))
  ctx <- abrir_contexto(cfg)
  fallas <- character()
  for (e in cfg$etapas) {
    logmsg("== Etapa ", e)
    # Si una etapa falla (por ejemplo E sin el VCF a mano), se anota y siguen las demas.
    ctx <- tryCatch(switch(e, A = etapa_A(ctx), B = etapa_B(ctx), C = etapa_C(ctx), D = etapa_D(ctx), E = etapa_E(ctx), F = etapa_F(ctx), G = etapa_G(ctx), stop("Etapa desconocida: ", e)),
                    error = function(err) { logmsg("ERROR en la etapa ", e, ": ", conditionMessage(err)); fallas <<- c(fallas, e); ctx })
  }
  if (length(fallas)) logmsg("Etapas con error: ", paste(fallas, collapse = ", "))
  logmsg("TERMINADO ", cfg$species, " | ", format(round(difftime(Sys.time(), inicio, units = "mins"), 1)))
  invisible(ctx)
}
if (Sys.getenv("PUBLICAR_LIBRARY_ONLY") != "1") RESULTADO_PUB <- publicar(CONFIG)
