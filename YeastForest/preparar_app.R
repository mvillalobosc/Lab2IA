# =============================================================================
# PREPARAR LOS DATOS DE LA APP "BOSQUE FILOGENETICO" (S. cerevisiae y S. eubayanus)
# Manuel: deja este archivo junto a las carpetas de resultados del bosque
# (Bosque_cerevisiae y Bosque_eubayanus) y ejecutalo con source("preparar_app.R").
# Escribe la carpeta data/ que lee index.html (junto a este script). Se puede volver a correr cada vez
# que cambien los resultados (por ejemplo cuando este el enriquecimiento de
# S. eubayanus): rehace solo la especie cuyos archivos cambiaron, salvo rehacer = TRUE.
# Fecha: 2026-10-05.
# =============================================================================
# ENTRADAS POR ESPECIE (carpeta de resultados del bosque, prefijo de la especie)
#   <prefijo>_resumen.tsv                  obligatorio
#   <prefijo>_arboles.nwk                  obligatorio (linea 1 = NJ global)
#   <prefijo>_RF.csv.gz                    obligatorio
#   <prefijo>_concordancia.csv.gz          obligatorio
#   <prefijo>_distancias_geneticas.csv.gz  obligatorio
#   <prefijo>_clusters.tsv                 opcional (del script de clusters)
#   <prefijo>_clusters_resumen.tsv         opcional
#   <prefijo>_enriquecimiento.tsv          opcional (si falta, la app marca "pendiente")
#   <prefijo>_genes_sin_ubicar.tsv         opcional (solo S. eubayanus)
# ARCHIVOS OPCIONALES QUE SE INDICAN EN CONFIG
#   cepas:  TSV: primera columna cepa y despues una columna por capa categorica
#           (linaje, pais, localidad, hospedero...). La primera capa pinta el anillo
#           por defecto; las demas se eligen en la app. Las cepas que no esten quedan
#           "sin grupo". Los nombres se normalizan igual que en el bosque (caracteres
#           fuera de A-Z a-z 0-9 _ . - pasan a "_").
#   genes:  anotacion de los genes para la ficha. Acepta SGD_features.tab,
#           gene_result.txt de NCBI, gene_info.json (app anterior) o un TSV con
#           columnas orf, nombre, descripcion, enlace.
# SALIDA: data/especies.js y, por especie, data/<clave>/ con
#   arboles.js     un registro por arbol (metricas del resumen, cluster, proyecciones)
#   vecinos.js     k vecinos mas cercanos por RF, con concordancia en ambos sentidos
#   grupos.js      clusters MST-kNN, medoide de cada uno y enriquecimiento
#   cepas.js       cepas, grupo de cada una y cepas geneticamente mas cercanas
#   genes.js       nombre, descripcion y enlace de cada gen con anotacion
#   omitidos.js    ORFs sin arbol (con motivo) y genes sin ubicar
#   arboles/<tree_id>.js    un Newick por arbol, con el respaldo en los nodos
# Cada archivo es JSON envuelto en una llamada BF.load("<clave>", <json>): asi el
# index.html los carga como <script> y funciona con doble clic (file://), donde el
# navegador no permite fetch(). El Newick de cada arbol va como string JSON.
# =============================================================================

CONFIG <- list(
  salida = "data",                    # carpeta data de la app (junto a index.html)
  k_vecinos = 15L,                    # vecinos por arbol
  k_cepas = 10L,                      # cepas mas cercanas por cepa (distancia genetica)
  perplexity = 50,                    # t-SNE
  umap_vecinos = 15L,                 # UMAP
  semilla = 2026L,
  fdr_guardar = 0.25,                 # pruebas de enriquecimiento que se guardan (y top 3 por cluster)
  hilos = 2L,
  rehacer = FALSE,                    # TRUE: rehace todo aunque no haya cambios
  especies = list(
    list(clave = "cerevisiae", nombre = "Saccharomyces cerevisiae", corto = "S. cerevisiae",
         prefijo = "SCerevisiae", carpeta = "Bosque_cerevisiae",
         cepas = "cepas_cerevisiae.tsv",      # cepa, Población (Peter et al. 2018)
         genes = c("~/EvolutiveSCerevisiae/DATA/SGD_features.tab", "genes_cerevisiae.tsv"),  # usa el primero que exista
         enlace_gen = "https://www.yeastgenome.org/locus/{orf}",
         fuente = "Panel de 1.011 aislados (Peter et al. 2018); VCF 1011Matrix; ORFs de SGD_features.tab"),
    list(clave = "eubayanus", nombre = "Saccharomyces eubayanus", corto = "S. eubayanus",
         prefijo = "Eubayanus", carpeta = "Bosque_eubayanus",
         cepas = "cepas_eubayanus.tsv",       # cepa, Linaje, Pais, Localidad, Hospedero, Sustrato, Continente (MetaData_SEu.csv)
         genes = c("gene_result_eubayanus.txt", "~/EvolutiveEubayanus/DATA/gene_result.txt"),  # usa el primero que exista
         enlace_gen = "https://www.ncbi.nlm.nih.gov/gene/?term={orf}+Saccharomyces+eubayanus",
         fuente = "VCF filtered_eub sobre CBS12357 (GCA_003327605.1); genes de NCBI (FM1318) ubicados por secuencia")
  )
)

# -----------------------------------------------------------------------------
# 1. DEPENDENCIAS Y UTILIDADES
# -----------------------------------------------------------------------------
ensure_packages <- function() {
  pk <- c("data.table", "jsonlite", "ape", "Rtsne", "uwot", "R.utils")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) stop("Faltan paquetes: ", paste(falta, collapse = ", "))
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
# De varios candidatos, el primero que exista (si ninguno existe, el primero, para avisar).
first_existing <- function(files) { if (is.null(files)) return(NULL); ok <- files[file.exists(files)]; if (length(ok)) ok[1L] else files[1L] }
write_json <- function(x, file) jsonlite::write_json(x, file, auto_unbox = TRUE, na = "null",
                                                     digits = NA, null = "null", pretty = FALSE)
# Archivo de datos de la app: JSON envuelto en BF.load("<clave>", ...), cargable como <script>.
write_js <- function(x, key, file) {
  js <- jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", digits = NA, null = "null", pretty = FALSE)
  writeLines(paste0('BF.load("', key, '",', js, ');'), file, useBytes = TRUE)
}
read_tsv <- function(f, ...) data.table::fread(f, sep = "\t", na.strings = c("NA", ""), ...)

# Matriz cuadrada desde CSV.gz (primera columna = ids de fila; cabecera = ids de columna).
leer_matriz <- function(path) {
  x <- data.table::fread(path, header = TRUE, check.names = FALSE)
  m <- as.matrix(x[, -1L, with = FALSE])
  dimnames(m) <- list(as.character(x[[1L]]), names(x)[-1L])
  rm(x); invisible(gc())
  if (!identical(rownames(m), colnames(m))) stop("La matriz ", basename(path), " no tiene los mismos ids en filas y columnas.")
  m
}

# Huella de las entradas de una especie: si no cambia, no se rehace.
huella <- function(files) {
  files <- files[file.exists(files)]
  i <- file.info(files)
  paste(basename(files), i$size, as.numeric(i$mtime), collapse = "|")
}

# -----------------------------------------------------------------------------
# 2. RESUMEN, ARBOLES Y CEPAS
# -----------------------------------------------------------------------------
leer_resumen <- function(dir, prefijo) {
  f <- file.path(dir, paste0(prefijo, "_resumen.tsv"))
  if (!file.exists(f)) stop("No encuentro ", f)
  r <- read_tsv(f, colClasses = list(character = c("tree_id", "orf", "status", "reason")))
  r[is.na(reason), reason := ""]
  r
}

# Un archivo Newick por arbol. Devuelve las cepas (tips) del NJ global.
escribir_arboles <- function(dir, prefijo, resumen, out) {
  f <- file.path(dir, paste0(prefijo, "_arboles.nwk"))
  if (!file.exists(f)) stop("No encuentro ", f)
  lineas <- readLines(f, warn = FALSE)
  ok <- resumen[status == "ok" & !is.na(newick_line)]
  if (max(ok$newick_line) > length(lineas)) stop("El resumen apunta a lineas que no estan en ", basename(f))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  clave <- basename(dirname(out))
  for (i in seq_len(nrow(ok))) writeLines(paste0('BF.load("', clave, '/arboles/', ok$tree_id[i], '",',
    jsonlite::toJSON(trimws(lineas[ok$newick_line[i]]), auto_unbox = TRUE), ');'),
    file.path(out, paste0(ok$tree_id[i], ".js")), useBytes = TRUE)
  ref <- ape::read.tree(text = lineas[ok$newick_line[ok$tree_id == "REF_TOTAL"]])
  # Todos los arboles tienen las mismas cepas que el global; se comprueba en una muestra.
  muestra <- ok$newick_line[sample.int(nrow(ok), min(25L, nrow(ok)))]
  for (ln in muestra) {
    tr <- ape::read.tree(text = lineas[ln])
    if (!setequal(tr$tip.label, ref$tip.label)) stop("El arbol de la linea ", ln, " no tiene las mismas cepas que el global.")
  }
  logmsg("  ", fmt_n(nrow(ok)), " arboles escritos en ", out, " | cepas: ", length(ref$tip.label))
  sort(ref$tip.label)
}

leer_cepas <- function(tips, file) {
  # Primera columna = cepa; cada columna siguiente es una capa categorica (linaje,
  # pais, localidad...). La primera capa es la que pinta el anillo por defecto.
  capas <- list()
  metadata <- NULL
  if (!is.null(file) && file.exists(file)) {
    t <- read_tsv(file, colClasses = "character", encoding = "UTF-8")
    if (ncol(t) < 2L) stop("El archivo de cepas necesita la columna cepa y al menos una capa: ", file)
    nombres <- safe_names(trimws(t[[1L]]))
    j <- match(tips, nombres)
    extra <- sum(!nombres %in% tips)
    metadata <- lapply(seq_along(tips), function(i) as.list(t[j[i], -1L, drop = FALSE]))
    for (k in which(!names(t) %in% c(names(t)[1L], "Aislado", "Población de origen", "Latitud", "Longitud", "Precision"))) {
      g <- trimws(t[[k]])[j]; g[is.na(g) | !nzchar(g)] <- NA_character_
      grupos <- sort(unique(stats::na.omit(g)))
      capas[[length(capas) + 1L]] <- list(nombre = names(t)[k], grupos = grupos,
                                          grupo = ifelse(is.na(g), -1L, match(g, grupos) - 1L))
    }
    logmsg("  Cepas con ", capas[[1L]]$nombre, ": ", sum(capas[[1L]]$grupo >= 0L), " de ", length(tips),
           " | capas: ", paste(vapply(capas, `[[`, "", "nombre"), collapse = ", "),
           if (extra) paste0(" | en el archivo pero no en el arbol: ", extra))
  } else logmsg("  Sin archivo de cepas", if (!is.null(file)) paste0(" (no existe ", file, ")"), ": todas quedan sin grupo")
  if (!length(capas)) capas <- list(list(nombre = "Grupo", grupos = character(), grupo = rep(-1L, length(tips))))
  list(nombres = tips, capas = capas, metadata = metadata)
}

# Cepas mas cercanas por distancia genetica (NJ global).
vecinos_cepas <- function(dir, prefijo, tips, k) {
  f <- file.path(dir, paste0(prefijo, "_distancias_geneticas.csv.gz"))
  if (!file.exists(f)) stop("No encuentro ", f)
  d <- leer_matriz(f)
  if (!setequal(rownames(d), tips)) stop("Las cepas de la matriz de distancias no calzan con el arbol global.")
  d <- d[tips, tips]
  out <- vector("list", length(tips))
  for (i in seq_along(tips)) {
    o <- unname(order(d[i, ], tips)); o <- o[o != i][seq_len(min(k, length(tips) - 1L))]
    out[[i]] <- lapply(o, function(j) list(j - 1L, round(unname(d[i, j]), 5)))
  }
  list(vecinos = out, media = unname(round(rowMeans(d), 5)))
}

# -----------------------------------------------------------------------------
# 3. VECINOS, PROYECCIONES Y MEDOIDES DESDE LAS MATRICES DEL BOSQUE
# -----------------------------------------------------------------------------
calcular_vecinos <- function(rf, cc, ids, k) {
  n <- length(ids); es_ref <- ids == "REF_TOTAL"
  out <- vector("list", n)
  for (i in seq_len(n)) {
    r <- rf[i, ]; cab <- cc[i, ]
    cand <- which(!is.na(r) & seq_len(n) != i)
    if (!es_ref[i]) cand <- cand[!es_ref[cand]]      # la RF al global ya esta en el resumen
    o <- unname(cand[order(r[cand], -cab[cand], ids[cand])][seq_len(min(k, length(cand)))])
    out[[i]] <- lapply(o, function(j) list(j - 1L, round(unname(r[j]), 4), round(unname(cab[j]), 2), round(unname(cc[j, i]), 2)))
  }
  out
}

proyecciones <- function(rf, cfg) {
  n <- nrow(rf)
  D <- rf; D[is.na(D)] <- 1; diag(D) <- 0
  set.seed(cfg$semilla)
  logmsg("  t-SNE (perplexity ", cfg$perplexity, ") sobre ", fmt_n(n), " arboles")
  ts <- Rtsne::Rtsne(D, is_distance = TRUE, dims = 2L, perplexity = min(cfg$perplexity, floor((n - 1)/3)),
                     theta = 0.5, max_iter = 1000L, check_duplicates = FALSE, verbose = FALSE,
                     num_threads = cfg$hilos)$Y
  logmsg("  UMAP (", cfg$umap_vecinos, " vecinos)")
  set.seed(cfg$semilla)
  um <- uwot::umap(stats::as.dist(D), n_neighbors = min(cfg$umap_vecinos, n - 1L), min_dist = 0.1,
                   n_threads = cfg$hilos, verbose = FALSE)
  logmsg("  MDS clasico (PCoA)")
  md <- suppressWarnings(stats::cmdscale(D, k = 2L))
  esc <- function(m) { m <- sweep(m, 2L, colMeans(m)); m <- m / max(abs(m)) * 100; round(m, 2) }
  list(tsne = unname(esc(ts)), umap = unname(esc(um)), mds = unname(esc(md)))
}

leer_clusters <- function(dir, prefijo, ids) {
  f_cl <- file.path(dir, paste0(prefijo, "_clusters.tsv"))
  f_rs <- file.path(dir, paste0(prefijo, "_clusters_resumen.tsv"))
  f_en <- file.path(dir, paste0(prefijo, "_enriquecimiento.tsv"))
  if (!file.exists(f_cl)) { logmsg("  Sin clusters (", basename(f_cl), " no existe)"); return(NULL) }
  cl <- read_tsv(f_cl, colClasses = list(character = c("tree_id", "orf", "origen")))
  faltan <- setdiff(ids[ids != "REF_TOTAL"], cl$tree_id)
  if (length(faltan)) stop(length(faltan), " arboles del resumen no estan en ", basename(f_cl), " (ej. ", faltan[1L], ")")
  sobran <- setdiff(cl$tree_id, ids)
  if (length(sobran)) stop(length(sobran), " arboles de ", basename(f_cl), " no estan en el bosque (ej. ", sobran[1L], ")")
  rs <- if (file.exists(f_rs)) read_tsv(f_rs, colClasses = list(character = c("origen", "principales", "enriquecido"))) else NULL
  en <- if (file.exists(f_en)) read_tsv(f_en, colClasses = list(character = c("base", "termino", "descripcion", "genes"))) else NULL
  estado <- if (!is.null(en)) "ok" else "pendiente"
  logmsg("  Clusters: ", data.table::uniqueN(cl$cluster), " | enriquecimiento: ", estado,
         if (!is.null(en)) paste0(" (", fmt_n(nrow(en)), " pruebas)"))
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
# 4. ANOTACION DE GENES (ficha): SGD_features.tab, gene_result.txt, gene_info.json o TSV
# -----------------------------------------------------------------------------
gene_result_ids <- function(symbol, gene_id) {   # misma regla que el bosque de S. eubayanus
  id <- ifelse(is.na(symbol) | !nzchar(symbol), gene_id, symbol)
  dup <- id %in% id[duplicated(id)]
  id[dup] <- paste0(id[dup], "_", gene_id[dup])
  id
}

leer_genes <- function(file, orfs) {
  vacio <- data.table::data.table(orf = character(), nombre = character(), descripcion = character(), enlace = character())
  if (is.null(file)) return(vacio)
  if (!file.exists(file)) { logmsg("  AVISO: no existe la anotacion de genes ", file, "; la ficha ira sin descripcion"); return(vacio) }
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
    if (!all(c("GeneID", "Symbol") %in% names(x))) stop(bn, " no trae GeneID y Symbol")
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
    if (!all(c("orf", "descripcion") %in% names(g))) stop("El TSV de genes necesita columnas orf y descripcion: ", file)
    if (!"nombre" %in% names(g)) g[, nombre := ""]
    if (!"enlace" %in% names(g)) g[, enlace := ""]
    g <- g[, .(orf, nombre, descripcion, enlace)]
  }
  g[is.na(nombre), nombre := ""]; g[is.na(descripcion), descripcion := ""]; g[is.na(enlace), enlace := ""]
  g <- unique(g[orf %in% orfs], by = "orf")
  logmsg("  Genes con ficha: ", fmt_n(nrow(g)), " de ", fmt_n(length(orfs)))
  g
}

# -----------------------------------------------------------------------------
# 5. UNA ESPECIE COMPLETA
# -----------------------------------------------------------------------------
motivo_corto <- function(reason) {
  ifelse(grepl("SNPs compartidos", reason), "Alguna pareja de cepas sin SNPs compartidos en el ORF (distancia indefinida)",
  ifelse(grepl("Menos de", reason), "Sin SNPs retenidos dentro del ORF", reason))
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
    logmsg(sp$nombre, ": sin cambios en las entradas, se conserva ", out)
    return(jsonlite::fromJSON(file.path(out, "meta.json")))
  }
  logmsg("== ", sp$nombre, " | resultados en ", dir)
  unlink(out, recursive = TRUE); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  res <- leer_resumen(dir, pref)
  ok <- res[status == "ok"]
  data.table::setorder(ok, newick_line)
  ids <- ok$tree_id
  if (ids[1L] != "REF_TOTAL") stop("El primer arbol del resumen debe ser REF_TOTAL")
  tips <- escribir_arboles(dir, pref, res, file.path(out, "arboles"))
  cepas <- leer_cepas(tips, f_cepas)
  vc <- vecinos_cepas(dir, pref, tips, cfg$k_cepas)

  logmsg("  Leyendo RF y concordancia (todos vs todos)")
  rf <- leer_matriz(file.path(dir, paste0(pref, "_RF.csv.gz")))
  if (!all(ids %in% rownames(rf))) stop("Arboles del resumen que no estan en la matriz RF")
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
      logmsg("  Pruebas de enriquecimiento guardadas: ", fmt_n(nrow(e)), " (FDR < ", cfg$fdr_guardar, " o top 3 por cluster)")
    }
    grupos_json <- list(estado = cl$estado, n_clusters = length(clusters), clusters = clusters, enriquecimiento = enr)
  }
  write_js(grupos_json, paste0(sp$clave, "/grupos"), file.path(out, "grupos.js"))

  # Registro por arbol: todo lo del resumen que usa la app, mas cluster y proyecciones.
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
  write_js(list(nombres = cepas$nombres, capas = cepas$capas, metadata = cepas$metadata,
                vecinos = vc$vecinos, distancia_media = vc$media), paste0(sp$clave, "/cepas"), file.path(out, "cepas.js"))

  genes <- leer_genes(f_genes, unique(res$orf))
  gl <- stats::setNames(lapply(seq_len(nrow(genes)), function(i) list(genes$nombre[i], genes$descripcion[i], genes$enlace[i])), genes$orf)
  write_js(gl, paste0(sp$clave, "/genes"), file.path(out, "genes.js"))

  om <- res[status != "ok", .(orf, motivo = motivo_corto(reason), n_snps)]
  su <- NULL; f_su <- file.path(dir, paste0(pref, "_genes_sin_ubicar.tsv"))
  if (file.exists(f_su)) { s <- read_tsv(f_su, colClasses = "character"); su <- s[, .(orf, motivo)] }
  write_js(list(sin_arbol = om, sin_ubicar = su), paste0(sp$clave, "/omitidos"), file.path(out, "omitidos.js"))
  logmsg("  ORFs sin arbol: ", fmt_n(nrow(om)), if (!is.null(su)) paste0(" | genes sin ubicar: ", fmt_n(nrow(su))))

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
# 6. EJECUCION
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
  logmsg("TERMINADO | ", length(metas), " especies en ", salida, " | ",
         format(round(difftime(Sys.time(), inicio, units = "mins"), 1)))
  invisible(metas)
}

if (Sys.getenv("PREPARAR_APP_LIBRARY_ONLY") != "1") preparar_app(CONFIG)
