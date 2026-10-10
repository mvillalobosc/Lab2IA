# =============================================================================
# BOSQUE FILOGENETICO DESDE VCF: S. cerevisiae
# Manuel: deja este archivo en la carpeta donde quieres los resultados y
# ejecutalo con source("~/bosque_SCerevisiae_2026-10-03.R") o como Job.
# Es independiente del script de S. eubayanus: puedes correr los dos a la vez si
# el servidor tiene RAM y nucleos para ambos (cada uno usa workers + 1 procesos).
# Fecha: 2026-10-03. No utiliza bootstrap ni genera replicas de los datos.
# Progreso visible en Jobs: etapas, lotes de ORFs, porcentaje, elapsed y ETA.
# ETA corresponde a la etapa actual y es aproximada; VCF/NJ global sin ETA.
# =============================================================================
# RESULTADOS: en la MISMA carpeta de este script, sin subcarpetas
# (si lo corres linea a linea, en getwd()). Son cinco archivos:
#   SCerevisiae_arboles.nwk             linea 1 = NJ global; despues un NJ por
#                                       ORF. Cada nodo lleva su confidence: % de
#                                       los ORFs (sin contar el propio) que
#                                       tienen esa rama.
#   SCerevisiae_distancias_geneticas.csv.gz  muestra x muestra, la del NJ global
#   SCerevisiae_RF.csv.gz               RF normalizada, todos vs todos
#   SCerevisiae_concordancia.csv.gz     confidence por par: % de las ramas del
#                                       arbol de la fila que estan en el de la
#                                       columna (0 a 100)
#   SCerevisiae_resumen.tsv             una fila por arbol (global y cada ORF):
#                                       linea en el .nwk, SNPs, resolucion,
#                                       confidence media y comparacion con el
#                                       global. Los ORFs sin arbol van con motivo.
# Solo si algun ID del VCF trae caracteres que Newick no admite se agrega
# SCerevisiae_muestras_renombradas.tsv con la equivalencia.
# Mientras corre, el avance se guarda en la carpeta oculta .tmp_bosque_SCerevisiae.
# Si la corrida se corta, al ejecutar de nuevo retoma desde el ultimo lote; al
# terminar bien la carpeta se borra. Si quieres partir de cero, borrala.
# Si existe una corrida COMPLETA del script anterior (previous_results) con los
# mismos datos y parametros, ordena esos resultados en este formato sin
# recalcular. Despues puedes borrar esa carpeta anterior.
# =============================================================================
# OBJETIVOS
# 1. NJ de evidencia total: todos los SNPs bialelicos que pasan los filtros,
#    incluidos los intergenicos. Cada SNP se cuenta una sola vez.
# 2. Un NJ por ORF, con exactamente las mismas muestras que el NJ total.
# 3. RF normalizada, todos vs todos, incluido REF_TOTAL.
# 4. Respaldo empirico en el bosque: recuperacion direccional de biparticiones
#    por par, y frecuencia de cada biparticion entre los ORFs restantes.
# 5. Un solo Newick con todos los arboles y la concordancia en los nodos.
#
# DEFINICIONES (arboles sin raiz; se ignoran longitudes para compararlos)
# RF(A,B) = (sA + sB - 2*cAB)/(sA + sB), con s = numero de splits internos.
# Concordancia(A <- B) = 100*cAB/sA: % de splits de A presentes en B.
# Respaldo de una rama de A = % de los OTROS ORFs que contienen ese split.
# El NJ total se incluye en las matrices, pero NO vota en el respaldo del bosque.
# Una ausencia puede reflejar conflicto o falta de resolucion. No es una prueba
# estadistica, probabilidad de que el arbol sea verdadero ni soporte bootstrap.
# Con arboles binarios, la concordancia por par coincide con 100*(1-RF).
# Para dos arboles sin splits informativos se informa NA, no evidencia perfecta.
#
# DISTANCIA GENETICA
# Media de |fALT_i - fALT_j| sobre SNPs llamados en ambos individuos.
# fALT = copias ALT / ploidia declarada en GT. En diploides equivale a distancia
# IBS normalizada. Usa fase indistintamente; no reconstruye haplotipos.
# Las distancias proceden del panel de SNPs: no son sustituciones por sitio
# de una secuencia completa. GT parcial o ausente se considera perdido.
#
# OPTIMIZACION
# VCF leido una sola vez por bloques; cache temporal de SNPs; genotipos raw;
# distancias geneticas con bitsets y popcount en C++; ORFs en paralelo en Linux;
# comparacion del bosque mediante incidencia sparse de splits y bloques de filas.
# No se carga el VCF completo ni se retienen varias matrices M x M en RAM.
# Los splits se identifican mediante SHA-256 de sus conjuntos canonicos de tips.
#
# ANOTACION
# Debe corresponder al MISMO ensamblaje del VCF; cambiar nombres de cromosomas
# no convierte coordenadas entre ensamblajes. Antes de calcular se revisa que los
# cromosomas calcen con el VCF y que ningun ORF pase el largo del cromosoma.
# SGD_features.tab: ORFs menos los intrones con Parent identificado.
# GFF3: union de CDS de cada gen (no intrones).
# Tabla: intervalos segun chr/start/end; si son limites de gen, incluye intrones.
# gene_result.txt de NCBI: usa start/end_position_on_the_genomic_accession y,
# como cromosoma, la columna (chromosome o accession) que calza con el VCF.
# No trae tipo de gen, asi que entran todos los genes con coordenadas.
# Todas las coordenadas de tablas se interpretan como 1-based inclusivas, salvo
# annotation_zero_based=TRUE. No se utilizan sitios_coords ni metadatos geograficos.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. CONFIGURACION: rutas tomadas de la imagen
# -----------------------------------------------------------------------------
CONFIG <- list(
  species = "SCerevisiae",          # prefijo de los archivos de resultados
  folder = "~/EvolutiveSCerevisiae/DATA",
  vcf = "1011Matrix.gvcf.gz",
  annotation = "SGD_features.tab",
  annotation_format = "sgd",        # auto, sgd, gff3 o table
  annotation_zero_based = FALSE,
  chromosome_map = NULL,            # TSV opcional: annotation_chr, vcf_chr
  samples_file = NULL,              # opcional: un ID de muestra del VCF por linea
  output_dir = NULL,                # NULL = misma carpeta de este script
  previous_results = "~/EvolutiveSCerevisiae/BOSQUE_NJ_SIN_BOOTSTRAP_PROGRESO",
  install_packages = TRUE,
  chunk_snps = 2000L,
  workers = 2L,                     # ajustar segun CPU/RAM; Windows usa 1
  comparison_block = 100L,
  orf_batch_size = 10L,             # informa progreso y guarda avance cada lote
  max_ploidy = 8L,                  # si GT declara mas, se detiene y avisa
  min_site_call_rate = 0.90,
  accept_filter_dot = TRUE,         # '.' significa sin filtro aplicado, no PASS
  min_snps_orf = 1L,                # intenta TODOS los ORFs con SNPs; subir si se desea
  min_shared_snps_orf = 1L,         # requiere distancia definida para todas las parejas
  min_shared_snps_total = 50L,
  collapse_tolerance = 1e-10,       # contrae ramas internas <= este valor
  overwrite = FALSE                 # FALSE: si ya estan los resultados, no recalcula
)
PIPELINE_VERSION <- "2026-10-03"

# -----------------------------------------------------------------------------
# 1. DEPENDENCIAS Y UTILIDADES
# -----------------------------------------------------------------------------
ensure_packages <- function(install = TRUE) {
  cran <- c("ape", "data.table", "Matrix", "Rcpp", "digest")
  bioc <- c("VariantAnnotation", "Rsamtools", "GenomicRanges", "GenomeInfoDb", "IRanges",
            "SummarizedExperiment", "S4Vectors")
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
format_duration <- function(seconds) {
  if (!is.finite(seconds)) return("no disponible")
  seconds <- max(0, round(seconds))
  sprintf("%02d:%02d:%02d", as.integer(seconds %/% 3600),
          as.integer((seconds %% 3600) %/% 60), as.integer(seconds %% 60))
}
# rate_done: ORFs calculados en esta sesion (los retomados no cuentan para la ETA).
report_progress <- function(stage, done, total, started, detail = "", rate_done = done) {
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  remaining <- if (rate_done > 0) elapsed * (total - done)/rate_done else Inf
  logmsg(stage, " | ", done, "/", total, " (", sprintf("%.1f", 100*done/total),
    "%) | transcurrido ", format_duration(elapsed),
    " | restante estimado de ESTA etapa ", format_duration(remaining), detail)
}
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
safe_names <- function(x) make.unique(gsub("[^A-Za-z0-9_.-]", "_", x), sep = "__")
resolve_file <- function(folder, file) {
  if (is.null(file)) return(NULL)
  path.expand(if (grepl("^(~|/|[A-Za-z]:)", file)) file else file.path(folder, file))
}
open_text <- function(file) {
  if (grepl("\\.(gz|bgz)$", file, ignore.case = TRUE)) gzfile(file, "rt")
  else file(file, "rt")
}
read_lines <- function(path, n = -1L) {
  con <- open_text(path); on.exit(close(con)); readLines(con, n = n, warn = FALSE)
}
write_tsv <- function(x, file) data.table::fwrite(x, file, sep = "\t", na = "NA")
# Escribe y despues renombra: un corte a mitad de escritura no deja un archivo roto.
save_atomic <- function(x, file) {
  part <- paste0(file, ".part")
  saveRDS(x, part, compress = FALSE)
  if (!file.rename(part, file)) stop("No se pudo guardar ", file)
}

# Carpeta de este script: source(), Rscript o, en Jobs de RStudio, getwd(),
# que por defecto es la carpeta del script.
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
output_files <- function(out_dir, name) {
  stats::setNames(file.path(out_dir, paste0(name, c("_arboles.nwk", "_distancias_geneticas.csv.gz",
    "_RF.csv.gz", "_concordancia.csv.gz", "_resumen.tsv"))),
    c("arboles", "distancias", "RF", "concordancia", "resumen"))
}

# Una sola corrida por especie y carpeta: una segunda corrida simultanea
# duplicaria RAM y CPU y pisaria el avance de la primera.
take_lock <- function(tmp) {
  lock <- file.path(tmp, "en_curso.txt")
  if (file.exists(lock)) {
    other <- suppressWarnings(as.integer(readLines(lock, n = 1L, warn = FALSE)))
    if (length(other) == 1L && !is.na(other) && other != Sys.getpid() &&
        .Platform$OS.type != "windows" && isTRUE(tools::pskill(other, 0L))) {
      msg <- paste0("Ya hay otra corrida en marcha con esta carpeta (proceso ", other,
        "). Espera a que termine o detenla. Si no hay ninguna, borra ", lock)
      logmsg("ERROR: ", msg)
      stop(msg, call. = FALSE)
    }
  }
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(Sys.getpid()), lock)
  lock
}

# Muestra cada aviso en el registro en el momento: en Jobs no quedan para el final.
with_logged_warnings <- function(expr) {
  seen <- character()
  withCallingHandlers(expr, warning = function(w) {
    msg <- conditionMessage(w)
    if (!msg %in% seen) { seen <<- c(seen, msg); logmsg("AVISO: ", msg) }
    invokeRestart("muffleWarning")
  })
}

# Filas de una matriz como CSV: id, valores; NA y NaN se escriben como NA.
matrix_lines <- function(mat, ids, digits = 8L) {
  txt <- matrix(sprintf(paste0("%.", digits, "g"), mat), nrow(mat))
  txt[is.na(mat)] <- "NA"
  paste(ids, apply(txt, 1L, paste, collapse = ","), sep = ",")
}
write_matrix_gz <- function(mat, ids, file, first, digits = 8L) {
  con <- gzfile(file, "wt"); on.exit(close(con))
  writeLines(paste(c(first, ids), collapse = ","), con)
  for (start in seq.int(1L, nrow(mat), by = 200L)) {
    rows <- start:min(nrow(mat), start + 199L)
    writeLines(matrix_lines(mat[rows, , drop = FALSE], ids[rows], digits), con)
  }
}

# Solo normaliza nomenclatura simple (chrI <-> 1), nunca accesiones NC_/scaffolds.
chr_key <- function(x) {
  y <- toupper(trimws(as.character(x)))
  y <- sub("^CHROMOSOME[ _]*", "", y)
  y <- sub("^CHR[ _]*", "", y)
  roman <- c("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
             "XI", "XII", "XIII", "XIV", "XV", "XVI")
  hit <- match(y, roman); y[!is.na(hit)] <- as.character(hit[!is.na(hit)])
  y[grepl("^[0-9]+$", y)] <- as.character(as.integer(y[grepl("^[0-9]+$", y)]))
  y[y %in% c("MT", "MITO", "MITOCHONDRION", "MITOCHONDRIAL", "M")] <- "MT"
  y
}

# -----------------------------------------------------------------------------
# 2. LECTURA DE ANOTACIONES: SGD, GFF3 O TABLA CON COORDENADAS
# -----------------------------------------------------------------------------
read_annotation <- function(path, format = "auto", zero_based = FALSE, vcf_contigs = NULL) {
  if (!file.exists(path)) stop("No existe la anotacion: ", path)
  txt <- read_lines(path)
  if (format == "auto") {
    if (grepl("\\.gff3?(\\.(gz|bgz))?$", path, ignore.case = TRUE) ||
        any(grepl("^##gff-version", head(txt, 20)))) format <- "gff3"
    else if (grepl("SGD_features", basename(path), ignore.case = TRUE)) format <- "sgd"
    else format <- "table"
  }
  if (format == "sgd") {
    x <- data.table::fread(text = paste(txt[!grepl("^#|^$", txt)], collapse = "\n"),
                          header = FALSE, sep = "\t", quote = "", fill = TRUE)
    if (ncol(x) < 12L) stop("SGD_features.tab requiere al menos 12 columnas.")
    orf <- x[toupper(V2) == "ORF" & !is.na(V4) & nzchar(V4)]
    ans <- orf[, .(orf = as.character(V4), chr = as.character(V9),
                   start = pmin(as.numeric(V10), as.numeric(V11)),
                   end = pmax(as.numeric(V10), as.numeric(V11)),
                   basis = "SGD_ORF_minus_annotated_introns")]
    # Restar SOLO intrones cuyo Parent coincide con el ORF.
    intr <- x[tolower(V2) == "intron"]
    if (nrow(intr)) {
      split_rows <- lapply(seq_len(nrow(ans)), function(i) {
        a <- ans[i]; z <- intr[V7 == a$orf & as.character(V9) == a$chr]
        if (!nrow(z)) return(a)
        g <- GenomicRanges::GRanges(a$chr, IRanges::IRanges(a$start, a$end))
        h <- GenomicRanges::GRanges(as.character(z$V9), IRanges::IRanges(
          pmin(as.numeric(z$V10), as.numeric(z$V11)),
          pmax(as.numeric(z$V10), as.numeric(z$V11))))
        g <- GenomicRanges::setdiff(g, h, ignore.strand = TRUE)
        data.table::data.table(orf = a$orf, chr = as.character(GenomicRanges::seqnames(g)),
          start = IRanges::start(g), end = IRanges::end(g), basis = a$basis)
      })
      ans <- data.table::rbindlist(split_rows)
    }
  } else if (format == "gff3") {
    fasta <- which(grepl("^##FASTA", txt))
    if (length(fasta)) txt <- head(txt, fasta[1L] - 1L)
    x <- data.table::fread(text = paste(txt[!grepl("^#|^$", txt)], collapse = "\n"),
                          header = FALSE, sep = "\t", quote = "", fill = TRUE)
    if (ncol(x) != 9L) stop("GFF3 requiere 9 columnas, antes de ##FASTA.")
    attr_get <- function(v, key) vapply(strsplit(v, ";", fixed = TRUE), function(z) {
      hit <- z[startsWith(z, paste0(key, "="))]
      if (!length(hit)) NA_character_ else utils::URLdecode(sub("^[^=]*=", "", hit[1L]))
    }, character(1))
    ids <- attr_get(x$V9, "ID"); parents <- attr_get(x$V9, "Parent")
    loci <- attr_get(x$V9, "locus_tag"); names_ <- attr_get(x$V9, "Name")
    # Ascender CDS -> transcript -> gene. No se mezclan genes ni ensamblajes.
    gene_for <- function(id) {
      seen <- character()
      while (!is.na(id) && nzchar(id) && !(id %in% seen)) {
        seen <- c(seen, id); j <- match(id, ids)
        if (is.na(j)) return(id)
        if (tolower(x$V3[j]) %in% c("gene", "pseudogene")) return(id)
        id <- strsplit(ifelse(is.na(parents[j]), "", parents[j]), ",", fixed = TRUE)[[1]][1]
      }
      if (length(seen)) tail(seen, 1L) else NA_character_
    }
    k <- which(toupper(x$V3) == "CDS")
    if (!length(k)) stop("GFF3 sin CDS: se requiere anotacion de regiones codificantes.")
    out <- lapply(k, function(i) {
      p <- if (is.na(parents[i])) ids[i] else strsplit(parents[i], ",", fixed = TRUE)[[1]]
      if (!length(p)) return(NULL)
      gids <- unique(vapply(p, gene_for, character(1)))
      labels <- vapply(gids, function(gid) {
        j <- match(gid, ids)
        if (!is.na(j) && !is.na(loci[j]) && nzchar(loci[j])) loci[j]
        else if (!is.na(j) && !is.na(names_[j]) && nzchar(names_[j])) names_[j]
        else gid
      }, character(1))
      data.table::data.table(orf = labels, chr = as.character(x$V1[i]),
        start = as.numeric(x$V4[i]), end = as.numeric(x$V5[i]), basis = "GFF3_CDS_union")
    })
    ans <- data.table::rbindlist(out)
  } else if (format == "table") {
    # Acepta CSV/TSV con encabezado, incluido gene_result.txt de NCBI (Gene,
    # Send to > File > Tabular). No extrae coordenadas de texto descriptivo.
    x <- tryCatch(data.table::fread(path, header = TRUE, quote = "\"", check.names = FALSE),
      error = function(e) stop("No puedo leer la tabla ", path, ": ", conditionMessage(e)))
    norm <- function(z) gsub("[^a-z0-9]", "", tolower(z))
    cn <- norm(names(x))
    find_cols <- function(aliases) { z <- match(aliases, cn); unique(names(x)[z[!is.na(z)]]) }
    find_col <- function(aliases) { z <- find_cols(aliases); if (length(z)) z[1L] else NA_character_ }
    chr_cols <- find_cols(c("chr", "chrom", "chromosome", "seqid", "contig", "sequenceid",
      "genomicnucleotideaccessionversion", "genomicaccession", "chraccver",
      "annotationgenomicaccession"))
    # gene_result.txt trae el cromosoma dos veces (chromosome y accession) para las
    # mismas coordenadas: se usa la columna cuyos nombres calzan con el VCF.
    if (length(chr_cols) > 1L && length(vcf_contigs)) {
      hits <- vapply(chr_cols, function(k) sum(chr_key(x[[k]]) %in% chr_key(vcf_contigs)), integer(1))
      chr_cols <- chr_cols[order(-hits)]
    }
    cols <- c(orf = find_col(c("orf", "locustag", "geneid", "gene", "symbol", "id")),
      chr = if (length(chr_cols)) chr_cols[1L] else NA_character_,
      start = find_col(c("start", "begin", "genomicstart", "chrstart",
                        "annotationgenomicrangestart", "startpositiononthegenomicaccession")),
      end = find_col(c("end", "stop", "genomicend", "chrstop",
                      "annotationgenomicrangestop", "endpositiononthegenomicaccession")))
    if (anyNA(cols)) stop(
      "La anotacion ", basename(path), " no aporta ORF/cromosoma/inicio/fin.\n",
      "Columnas encontradas: ", paste(names(x), collapse = ", "), "\n",
      "Se necesita el GFF3 del MISMO ensamblaje usado en el VCF, una tabla\n",
      "chr/start/end/orf o el gene_result.txt tabular de NCBI con\n",
      "start_position_on_the_genomic_accession y end_position_on_the_genomic_accession.")
    number <- function(z) suppressWarnings(as.numeric(gsub(",", "", as.character(z), fixed = TRUE)))
    s <- number(x[[cols["start"]]]); e <- number(x[[cols["end"]]])
    ans <- data.table::data.table(orf = as.character(x[[cols["orf"]]]),
      chr = as.character(x[[cols["chr"]]]), start = pmin(s, e), end = pmax(s, e),
      basis = "table_interval")
    if (zero_based) ans[, `:=`(start = start + 1L, end = end + 1L)]
    type_col <- find_col(c("type", "genetype", "typeofgene", "featuretype"))
    if (!is.na(type_col)) {
      t <- norm(as.character(x[[type_col]]))
      ans <- ans[t %in% c("proteincoding", "orf", "cds", "coding")]
    }
    logmsg("  Anotacion como tabla: ORF = ", cols[["orf"]], ", cromosoma = ", cols[["chr"]],
           ", inicio = ", cols[["start"]], ", fin = ", cols[["end"]])
    warning("La tabla usa intervalos dados; para ORFs sin intrones, preferir CDS de GFF3.",
            call. = FALSE)
  } else stop("annotation_format debe ser auto, sgd, gff3 o table.")
  ok <- !is.na(ans$orf) & nzchar(ans$orf) & !is.na(ans$chr) & nzchar(ans$chr) &
        is.finite(ans$start) & is.finite(ans$end) & ans$start >= 1 & ans$end >= ans$start
  if (any(!ok)) warning(sum(!ok), " intervalos de anotacion invalidos omitidos.", call. = FALSE)
  ans <- unique(ans[ok])
  if (!nrow(ans)) stop("No hay intervalos ORF validos en ", path)
  if (any(ans[, data.table::uniqueN(chr), by = orf]$V1 > 1L))
    stop("Un ID de ORF aparece en varios cromosomas: revisar ensamblaje/IDs.")
  ans[, chr_key := chr_key(chr)]
  ans
}

# -----------------------------------------------------------------------------
# 3. GENOTIPOS Y DISTANCIAS RAPIDAS EN C++ (invocadas desde R)
# -----------------------------------------------------------------------------
compile_helpers <- function() {
  Rcpp::sourceCpp(code = '
  #include <Rcpp.h>
  #include <vector>
  #include <cstdint>
  #include <cmath>
  using namespace Rcpp;
  // [[Rcpp::plugins(cpp11)]]
  // [[Rcpp::export]]
  List encode_gt(CharacterMatrix gt, IntegerMatrix codebook) {
    int m=gt.nrow(), n=gt.ncol(), maxp=codebook.nrow()-1;
    RawMatrix out(m,n); long unsupported=0, missing=0;
    for(int j=0;j<n;++j) for(int i=0;i<m;++i) {
      if(CharacterVector::is_na(gt(i,j))) { ++missing; continue; }
      std::string z=as<std::string>(gt(i,j)); int a=0,p=0; bool bad=false, expect=true;
      for(char c:z) {
        if(expect && (c==\'0\' || c==\'1\')) { ++p; a+=(c==\'1\'); expect=false; }
        else if(!expect && (c==\'/\' || c==\'|\')) expect=true;
        else { bad=true; break; }
      }
      if(bad || expect || p==0) { ++missing; continue; }
      if(p>maxp) { ++unsupported; continue; }
      out(i,j)=static_cast<Rbyte>(codebook(p,a));
    }
    return List::create(_["gt"]=out, _["unsupported_ploidy"]=unsupported,
                        _["missing_gt"]=missing);
  }
  // [[Rcpp::export]]
  List distance_parts(RawMatrix x, NumericVector levels) {
    int m=x.nrow(), n=x.ncol(), W=(m+63)/64;
    std::vector<int> used(levels.size()+1,0), map(levels.size()+1,-1), codes;
    for(int j=0;j<n;++j) for(int i=0;i<m;++i) if(x(i,j)>0) used[x(i,j)]=1;
    for(int k=1;k<(int)used.size();++k) if(used[k]) { map[k]=codes.size(); codes.push_back(k); }
    int K=codes.size();
    std::vector<uint64_t> masks((size_t)n*K*W,0), present((size_t)n*W,0);
    for(int j=0;j<n;++j) for(int i=0;i<m;++i) if(x(i,j)>0) {
      int w=i/64; uint64_t b=UINT64_C(1)<<(i%64);
      present[(size_t)j*W+w] |= b;
      masks[((size_t)j*K+map[x(i,j)])*W+w] |= b;
    }
    NumericMatrix num(n,n), den(n,n);
    for(int i=0;i<n;++i) {
      if(i%32==0) checkUserInterrupt();
      for(int j=0;j<=i;++j) {
        double d=0, v=0;
        for(int w=0;w<W;++w)
          v+=__builtin_popcountll(present[(size_t)i*W+w] & present[(size_t)j*W+w]);
        if(i!=j) for(int a=0;a<K;++a) for(int b=a+1;b<K;++b) {
          double weight=std::fabs(levels[codes[a]-1]-levels[codes[b]-1]);
          const uint64_t *ia=&masks[((size_t)i*K+a)*W], *ib=&masks[((size_t)i*K+b)*W];
          const uint64_t *ja=&masks[((size_t)j*K+a)*W], *jb=&masks[((size_t)j*K+b)*W];
          for(int w=0;w<W;++w) d+=weight*(
            __builtin_popcountll(ia[w]&jb[w])+__builtin_popcountll(ib[w]&ja[w]));
        }
        num(i,j)=num(j,i)=d; den(i,j)=den(j,i)=v;
      }
    }
    return List::create(_["num"]=num, _["den"]=den);
  }
  ', env = .GlobalEnv, rebuild = FALSE, showOutput = FALSE)
}

make_codebook <- function(max_ploidy) {
  levels <- sort(unique(round(unlist(lapply(seq_len(max_ploidy), function(p) (0:p)/p)), 12)))
  if (length(levels) > 254L) stop("Demasiados estados de dosis para codificacion raw.")
  codebook <- matrix(0L, max_ploidy + 1L, max_ploidy + 1L)
  for (p in seq_len(max_ploidy)) codebook[p + 1L, seq_len(p + 1L)] <- match(round((0:p)/p, 12), levels)
  list(levels = levels, codebook = codebook)
}

filter_chunk <- function(vcf, cb, cfg) {
  gt <- VariantAnnotation::geno(vcf)$GT
  if (is.null(gt)) stop("El VCF no tiene el campo FORMAT/GT.")
  ref <- as.character(VariantAnnotation::ref(vcf))
  alt <- as.list(VariantAnnotation::alt(vcf))
  is_snp <- vapply(seq_along(alt), function(i) {
    a <- as.character(alt[[i]])
    concrete <- a[!a %in% c("<NON_REF>", "<*>")]
    # gVCF puede contener C,<NON_REF>; el alelo concreto debe tener indice 1.
    length(concrete) == 1L && length(a) >= 1L && a[1L] == concrete[1L] &&
      ref[i] %in% c("A", "C", "G", "T") &&
      concrete %in% c("A", "C", "G", "T") && ref[i] != concrete
  }, logical(1))
  fil <- as.character(VariantAnnotation::fixed(vcf)$FILTER)
  allowed <- c("PASS", if (cfg$accept_filter_dot) ".")
  idx <- which(is_snp & fil %in% allowed)
  if (!length(idx)) return(list(gt = matrix(raw(), 0L, ncol(gt)), rows = integer(),
                               candidates = integer(), biallelic_pass = 0L, low_call = 0L,
                               constant = 0L))
  encoded <- encode_gt(gt[idx, , drop = FALSE], cb$codebook)
  if (encoded$unsupported_ploidy > 0)
    stop("GT con ploidia > max_ploidy. Aumentar CONFIG$max_ploidy; no se convierte a diploide.")
  x <- encoded$gt
  called <- x != as.raw(0L)
  enough <- rowMeans(called) >= cfg$min_site_call_rate
  # Dos dosis distintas entre las muestras: elimina SNPs no variables en este conjunto.
  lo <- matrix(as.integer(x), nrow(x)); lo[!called] <- 999L
  hi <- matrix(as.integer(x), nrow(x)); hi[!called] <- -1L
  variable <- do.call(pmin, as.data.frame(lo)) != do.call(pmax, as.data.frame(hi))
  keep <- which(enough & variable)
  list(gt = x[keep, , drop = FALSE], rows = idx[keep], candidates = idx,
       biallelic_pass = length(idx), low_call = sum(!enough), constant = sum(enough & !variable))
}

parts_to_distance <- function(parts, labels, min_shared) {
  too_few <- parts$den < min_shared; diag(too_few) <- FALSE
  if (any(too_few)) stop("Alguna pareja tiene < ", min_shared,
    " SNPs compartidos (minimo=", min(parts$den[lower.tri(parts$den)]),
    "). No se imputan distancias ni se eliminan muestras solo en este ORF.")
  d <- parts$num / parts$den; diag(d) <- 0
  if (any(!is.finite(d))) stop("Distancias no finitas.")
  dimnames(d) <- list(labels, labels)
  stats::as.dist(d)
}

# -----------------------------------------------------------------------------
# 4. REVISION PREVIA: TODO LO QUE PUEDE FALLAR SE REVISA ANTES DE CALCULAR
# -----------------------------------------------------------------------------
prepare_inputs <- function(cfg) {
  folder <- path.expand(cfg$folder)
  vcf <- resolve_file(folder, cfg$vcf)
  annotation_path <- resolve_file(folder, cfg$annotation)
  map_path <- resolve_file(folder, cfg$chromosome_map)
  if (!file.exists(vcf)) stop("No existe el VCF: ", vcf)
  if (!file.exists(paste0(vcf, ".tbi"))) {
    logmsg("  Creando indice tabix del VCF (requiere BGZF ordenado).")
    tryCatch(Rsamtools::indexTabix(vcf, format = "vcf"), error = function(e)
      stop("No se pudo indexar ", basename(vcf), ". Debe ser BGZF/ordenado: ", conditionMessage(e)))
  }
  vcf_contigs <- Rsamtools::seqnamesTabix(vcf)
  ann <- read_annotation(annotation_path, cfg$annotation_format, cfg$annotation_zero_based,
                         vcf_contigs)
  if (!is.null(map_path)) {
    map <- data.table::fread(map_path)
    if (!all(c("annotation_chr", "vcf_chr") %in% names(map)))
      stop("El mapa necesita annotation_chr y vcf_chr.")
    j <- match(ann$chr, map$annotation_chr)
    if (anyNA(j)) stop("El mapa de cromosomas no cubre toda la anotacion.")
    ann$chr_key <- chr_key(map$vcf_chr[j])
  }
  vcf_keys <- chr_key(vcf_contigs)
  if (anyDuplicated(vcf_keys))
    stop("Dos contigs del VCF quedan con el mismo nombre al normalizar: ",
      paste(vcf_contigs[vcf_keys %in% vcf_keys[duplicated(vcf_keys)]], collapse = ", "),
      ". Se necesita chromosome_map.")
  inside <- ann$chr_key %in% vcf_keys
  if (!any(inside)) stop("Ningun cromosoma de la anotacion calza con los contigs del VCF.\n",
    "  Anotacion: ", paste(head(unique(ann$chr), 6), collapse = ", "), "\n",
    "  VCF: ", paste(head(vcf_contigs, 6), collapse = ", "), "\n",
    "  Si es el mismo ensamblaje con otros nombres, usa chromosome_map (annotation_chr, vcf_chr).")
  if (any(!inside)) logmsg("AVISO: ", data.table::uniqueN(ann$orf[!inside]),
    " ORFs estan en cromosomas que no aparecen en el VCF (",
    paste(unique(ann$chr[!inside]), collapse = ", "),
    "): quedan sin arbol y figuran en el resumen.")
  hdr <- VariantAnnotation::scanVcfHeader(vcf)
  len <- suppressWarnings(GenomeInfoDb::seqlengths(hdr))
  len <- len[!is.na(len)]
  if (length(len)) {
    limit <- len[match(ann$chr_key, chr_key(names(len)))]
    beyond <- !is.na(limit) & ann$end > limit
    if (any(beyond)) stop(data.table::uniqueN(ann$orf[beyond]),
      " ORFs terminan despues del largo del cromosoma declarado en el VCF (ej. ",
      ann$orf[beyond][1L], " en ", ann$chr[beyond][1L], ":", ann$end[beyond][1L], " > ",
      limit[beyond][1L], "). La anotacion parece de otro ensamblaje.")
  }
  selected <- VariantAnnotation::samples(hdr)
  if (anyDuplicated(selected)) stop("IDs de muestras duplicados en la cabecera VCF.")
  if (!is.null(cfg$samples_file)) {
    requested <- trimws(read_lines(resolve_file(folder, cfg$samples_file)))
    requested <- requested[nzchar(requested) & !startsWith(requested, "#")]
    if (anyDuplicated(requested) || !all(requested %in% selected))
      stop("samples_file contiene IDs duplicados o ausentes del VCF.")
    selected <- selected[selected %in% requested]
  }
  if (length(selected) < 4L) stop("Se necesitan al menos cuatro muestras para comparar splits.")
  list(vcf = vcf, ann = ann, selected = selected, labels = safe_names(selected),
       vcf_contigs = vcf_contigs)
}

# Avance guardado en la carpeta oculta. La huella dice con que datos y parametros
# se hizo: si cambian los del VCF se parte de cero; si cambian solo los de los
# ORFs, se conserva la lectura del VCF y se rehacen los ORFs.
open_workdir <- function(tmp, p, cfg) {
  finfo <- function(f) { i <- file.info(f); list(path = normalizePath(f), size = i$size,
                                                 mtime = as.numeric(i$mtime)) }
  fp <- list(version = PIPELINE_VERSION,
    vcf = c(finfo(p$vcf), list(samples = p$selected,
      intervals = digest::digest(list(as.character(p$ann$orf), p$ann$chr_key,
                                      as.numeric(p$ann$start), as.numeric(p$ann$end)))),
      cfg[c("chunk_snps", "max_ploidy", "min_site_call_rate", "accept_filter_dot")]),
    orfs = cfg[c("orf_batch_size", "min_snps_orf", "min_shared_snps_orf", "collapse_tolerance")])
  f <- file.path(tmp, "huella.rds")
  old <- if (file.exists(f)) tryCatch(readRDS(f), error = function(e) NULL) else NULL
  if (!is.null(old) && identical(old$vcf, fp$vcf)) {
    if (identical(old$orfs, fp$orfs)) logmsg("RETOMANDO: se usa el avance guardado en ", tmp)
    else {
      logmsg("RETOMANDO la lectura del VCF guardada; cambiaron parametros de los ORFs y se rehacen.")
      unlink(file.path(tmp, "orfs"), recursive = TRUE)
    }
  } else {
    if (file.exists(f)) logmsg("Se descarta un avance anterior hecho con otros datos o parametros.")
    old_files <- list.files(tmp, all.files = TRUE, no.. = TRUE, full.names = TRUE)
    unlink(old_files[basename(old_files) != "en_curso.txt"], recursive = TRUE)
  }
  dir.create(file.path(tmp, "cache_snps"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp, "orfs"), showWarnings = FALSE)
  save_atomic(fp, f)
}

# -----------------------------------------------------------------------------
# 5. CACHE DE SNPs: UNA PASADA DEL VCF Y NJ DE EVIDENCIA TOTAL
# -----------------------------------------------------------------------------
cache_vcf <- function(vcf_path, ann, labels, selected, tmp, cb, cfg) {
  cache <- file.path(tmp, "cache_snps"); done_file <- file.path(tmp, "etapa1.rds")
  st <- if (file.exists(done_file)) tryCatch(readRDS(done_file), error = function(e) NULL)
  if (!is.null(st) && all(file.exists(file.path(cache, st$files)))) {
    logmsg("ETAPA 1/4: RETOMANDO, el VCF ya estaba leido; no se vuelve a leer")
  } else {
    unlink(file.path(tmp, "orfs", "*"))  # los ORFs dependen de esta lectura
    unlink(cache, recursive = TRUE); dir.create(cache)
    n <- length(labels); total <- list(num = matrix(0, n, n), den = matrix(0, n, n))
    ranges <- GenomicRanges::GRanges(ann$chr_key, IRanges::IRanges(ann$start, ann$end))
    vf <- VariantAnnotation::VcfFile(vcf_path, yieldSize = cfg$chunk_snps)
    open(vf); on.exit(close(vf))
    param <- VariantAnnotation::ScanVcfParam(info = NA_character_, geno = "GT", samples = selected)
    memberships <- list(); files <- character(); b <- 0L; n_raw <- 0; n_kept <- 0
    started <- Sys.time()
    logmsg("ETAPA 1/4: leyendo VCF y acumulando distancias; total de registros desconocido, ETA aun no disponible")
    qc <- c(biallelic_pass = 0, low_call = 0, constant = 0)
    last_candidate <- NULL
    repeat {
      v <- VariantAnnotation::readVcf(vf, genome = "unspecified", param = param)
      if (!nrow(v)) break
      if (!identical(colnames(VariantAnnotation::geno(v)$GT), selected))
        stop("El orden de muestras del lector VCF cambio; revisar cabecera.")
      rr <- SummarizedExperiment::rowRanges(v)
      chr <- as.character(GenomicRanges::seqnames(rr)); pos <- IRanges::start(rr)
      n_raw <- n_raw + nrow(v)
      z <- filter_chunk(v, cb, cfg)
      # Dos registros SNP en la misma posicion (multialelico partido en lineas o
      # registro repetido) no se cuentan dos veces. Un indel en la misma posicion
      # no cambia al SNP, asi que no detiene nada.
      cand <- paste(chr[z$candidates], pos[z$candidates], sep = ":")
      if (length(cand)) {
        dup <- if (!is.null(last_candidate) && cand[1L] == last_candidate) cand[1L]
               else cand[duplicated(cand)][1L]
        if (!is.na(dup)) stop("Hay dos registros SNP en la posicion ", dup,
          " (multialelico partido en lineas o registro repetido). Unelos antes con",
          " bcftools norm -m +any; no se cuentan dos veces.")
        last_candidate <- tail(cand, 1L)
      }
      for (q in names(qc)) qc[q] <- qc[q] + z[[q]]
      if (!nrow(z$gt)) next
      b <- b + 1L; n_kept <- n_kept + nrow(z$gt)
      dat <- list(gt = z$gt, chr = chr[z$rows], pos = pos[z$rows])
      files[b] <- sprintf("snps_%06d.rds", b)
      saveRDS(dat, file.path(cache, files[b]), compress = FALSE)
      p <- distance_parts(dat$gt, cb$levels)
      total$num <- total$num + p$num; total$den <- total$den + p$den
      snp_gr <- GenomicRanges::GRanges(chr_key(dat$chr), IRanges::IRanges(dat$pos, width = 1L))
      hits <- suppressWarnings(GenomicRanges::findOverlaps(snp_gr, ranges, ignore.strand = TRUE))
      memberships[[b]] <- unique(data.table::data.table(
        orf = ann$orf[S4Vectors::subjectHits(hits)], block = rep.int(b, length(hits)),
        row = S4Vectors::queryHits(hits)))
      logmsg("VCF | bloque ", b, " | registros leidos ", fmt_n(n_raw),
        " | SNPs retenidos ", fmt_n(n_kept),
        " | posicion ", tail(chr, 1L), ":", tail(pos, 1L),
        " | transcurrido ", format_duration(as.numeric(difftime(Sys.time(), started, units = "secs"))))
    }
    if (!n_kept) stop("Ningun SNP paso los filtros.")
    mapping <- data.table::rbindlist(memberships)
    if (!nrow(mapping)) stop("Cero SNPs dentro de ORFs: revisar coordenadas/ensamblaje/cromosomas.")
    st <- list(files = files, mapping = mapping, total = total, n_snps = n_kept,
               n_raw = n_raw, qc = qc)
    save_atomic(st, done_file)
  }
  logmsg("VCF | registros ", fmt_n(st$n_raw), " | SNP bialelicos con FILTER aceptado ",
    fmt_n(st$qc[["biallelic_pass"]]), " | bajo ", cfg$min_site_call_rate, " de llamado ",
    fmt_n(st$qc[["low_call"]]), " | sin variacion en estas muestras ",
    fmt_n(st$qc[["constant"]]), " | retenidos ", fmt_n(st$n_snps))
  list(files = file.path(cache, st$files), mapping = st$mapping, n_snps = st$n_snps,
       distance = parts_to_distance(st$total, labels, cfg$min_shared_snps_total))
}

# -----------------------------------------------------------------------------
# 6. NJ SIN RAIZ; CONTRACCION DE RAMAS; SPLITS INTERNOS CANONICOS
# -----------------------------------------------------------------------------
make_nj <- function(distance, tol) {
  tree <- ape::nj(distance)
  n <- length(tree$tip.label)
  internal <- tree$edge[, 2] > n
  contracted <- sum(internal & tree$edge.length <= tol)
  negative <- sum(tree$edge.length < 0)
  # Los valores negativos de NJ no son longitudes evolutivas interpretables.
  tree$edge.length <- pmax(tree$edge.length, 0)
  tree <- ape::di2multi(tree, tol = max(tol, .Machine$double.eps))
  tree <- ape::unroot(tree)
  list(tree = tree, n_contracted = contracted, n_negative = negative)
}

tree_splits <- function(tree, common_labels) {
  n <- length(common_labels)
  if (!setequal(tree$tip.label, common_labels)) stop("Los arboles no tienen los mismos taxones.")
  t <- ape::reorder.phylo(tree, "postorder")
  descendants <- vector("list", n + t$Nnode)
  for (i in seq_len(n)) descendants[[i]] <- match(t$tip.label[i], common_labels)
  for (e in seq_len(nrow(t$edge))) {
    parent <- t$edge[e, 1]; child <- t$edge[e, 2]
    descendants[[parent]] <- c(descendants[[parent]], descendants[[child]])
  }
  nodes <- n + seq_len(t$Nnode)
  size <- lengths(descendants[nodes])
  nodes <- nodes[size >= 2L & size <= n - 2L]
  keys <- vapply(nodes, function(node) {
    side <- sort(descendants[[node]])
    if (length(side) > n/2 || (length(side) == n/2 && 1L %in% side))
      side <- setdiff(seq_len(n), side)
    digest::digest(side, algo = "sha256", serialize = TRUE)
  }, character(1))
  data.table::as.data.table(list(key = keys, node = nodes))[!duplicated(key)]
}

build_orf_trees <- function(index, ann, labels, tmp, cb, cfg) {
  all_orfs <- unique(ann$orf)
  mapping <- split(index$mapping, factor(index$mapping$orf, levels = all_orfs))
  tree_ids <- setNames(paste0("ORF_", safe_names(all_orfs)), all_orfs)
  # Cache pequena por proceso: cada ORF suele atravesar solo uno o dos bloques.
  memo <- new.env(parent = emptyenv()); memo$order <- character()
  read_block <- function(i) {
    key <- as.character(i)
    if (!exists(key, envir = memo, inherits = FALSE)) {
      assign(key, readRDS(index$files[i]), envir = memo)
      memo$order <- c(memo$order, key)
      if (length(memo$order) > 3L) { rm(list = memo$order[1L], envir = memo); memo$order <- memo$order[-1L] }
    }
    get(key, envir = memo, inherits = FALSE)
  }
  build_one <- function(orf) {
    id <- unname(tree_ids[orf]); z <- mapping[[orf]]
    info <- data.table::data.table(tree_id = id, orf = orf, status = "omitted",
      reason = "", n_snps = if (is.null(z)) 0L else nrow(z), n_splits = NA_integer_,
      resolution = NA_real_, n_contracted = NA_integer_, n_negative = NA_integer_)
    if (is.null(z) || nrow(z) < cfg$min_snps_orf) {
      info$reason <- paste0("Menos de ", cfg$min_snps_orf, " SNPs retenidos")
      return(list(info = info))
    }
    tryCatch({
      rows <- split(z$row, z$block)
      x <- do.call(rbind, lapply(names(rows), function(k)
        read_block(as.integer(k))$gt[sort(unique(rows[[k]])), , drop = FALSE]))
      d <- parts_to_distance(distance_parts(x, cb$levels), labels, cfg$min_shared_snps_orf)
      r <- make_nj(d, cfg$collapse_tolerance)
      splits <- tree_splits(r$tree, labels)
      info[, `:=`(status = "ok", n_snps = nrow(x), n_splits = nrow(splits),
        resolution = nrow(splits)/(length(labels) - 3L),
        n_contracted = r$n_contracted, n_negative = r$n_negative)]
      list(info = info, tree = r$tree, splits = splits)
    }, error = function(e) {
      info$reason <- conditionMessage(e); list(info = info)
    })
  }
  workers <- if (.Platform$OS.type == "windows") 1L else cfg$workers
  logmsg("ETAPA 3/4: construyendo ", length(all_orfs), " ORFs; procesos=", workers)
  started <- Sys.time()
  n_ok <- 0L; n_omitted <- 0L; n_resumed <- 0L; n_computed <- 0L
  # Durante esta etapa los arboles quedan solo en disco (lotes del avance) y en
  # memoria solo la tabla de control. Asi cada proceso hijo nace liviano y su
  # costo no crece con los ORFs ya calculados. gc() consolida la memoria antes
  # de empezar a crear procesos.
  batch_files <- character(); batch_info <- list()
  invisible(gc())
  for (first in seq.int(1L, length(all_orfs), by = cfg$orf_batch_size)) {
    positions <- first:min(length(all_orfs), first + cfg$orf_batch_size - 1L)
    done_file <- file.path(tmp, "orfs", sprintf("lote_%07d.rds", first))
    computed_now <- !file.exists(done_file)
    if (!computed_now) {
      batch <- readRDS(done_file); n_resumed <- n_resumed + length(positions)
    } else {
      if (n_resumed > 0L && n_computed == 0L)
        logmsg("ORFs | RETOMANDO: ", n_resumed, " ORFs ya estaban calculados")
      logmsg("ORFs | iniciando lote ", first, "-", tail(positions, 1L),
        " | primero ", all_orfs[first], " | ultimo ", all_orfs[tail(positions, 1L)])
      batch <- if (workers > 1L) parallel::mclapply(all_orfs[positions], build_one,
        mc.cores = workers, mc.preschedule = TRUE, mc.set.seed = FALSE)
      else lapply(all_orfs[positions], build_one)
      # Un proceso muerto (por ejemplo por RAM) devuelve NULL o try-error: se detiene
      # en vez de perder ORFs en silencio. Lo calculado hasta aqui queda guardado.
      failed <- vapply(batch, function(x) is.null(x) || inherits(x, "try-error") ||
                         is.null(x$info), logical(1))
      if (any(failed)) stop("Fallo un proceso al calcular los ORFs ",
        paste(all_orfs[positions][failed], collapse = ", "),
        "; suele ser falta de RAM: baja workers y vuelve a ejecutar.")
      save_atomic(batch, done_file)
      n_computed <- n_computed + length(positions)
    }
    batch_files <- c(batch_files, done_file)
    batch_info[[length(batch_info) + 1L]] <- data.table::rbindlist(lapply(batch, `[[`, "info"))
    success <- vapply(batch, function(x) identical(x$info$status, "ok"), logical(1))
    n_ok <- n_ok + sum(success); n_omitted <- n_omitted + sum(!success)
    rm(batch)
    if (computed_now || tail(positions, 1L) == length(all_orfs))
      report_progress("ORFs", tail(positions, 1L), length(all_orfs), started,
        paste0(" | con arbol ", n_ok, " | sin arbol ", n_omitted), rate_done = n_computed)
  }
  info <- data.table::rbindlist(batch_info)
  keep <- which(info$status == "ok")
  reasons <- sort(table(info$reason[info$status != "ok"]), decreasing = TRUE)
  reasons <- paste(sprintf("%s (%d)", names(reasons), as.integer(reasons))[seq_len(min(3L,
    length(reasons)))], collapse = "; ")
  if (!length(keep)) stop("Ningun ORF pudo producir un arbol. Motivos: ", reasons)
  logmsg("  ORFs con arbol: ", length(keep), "; sin arbol: ", nrow(info) - length(keep),
         if (nzchar(reasons)) paste0(". Motivos: ", reasons), " (detalle en el resumen)")
  # Arboles y splits de los ORFs con arbol, leidos desde los lotes en el mismo orden.
  results <- unlist(lapply(batch_files, function(f) {
    b <- readRDS(f); b[vapply(b, function(x) identical(x$info$status, "ok"), logical(1))]
  }), recursive = FALSE)
  if (length(results) != length(keep) ||
      !identical(vapply(results, function(x) x$info$tree_id, character(1)), info$tree_id[keep]))
    stop("Los lotes guardados no calzan con la tabla de ORFs; borra ", tmp, " y ejecuta de nuevo.")
  list(results = results, info = info[keep], all_info = info)
}

# -----------------------------------------------------------------------------
# 7. TODOS VS TODOS Y RESPALDO DE RAMAS DENTRO DEL BOSQUE (SIN BOOTSTRAP)
# -----------------------------------------------------------------------------
compare_forest <- function(results, info, labels, tmp_files, cfg) {
  logmsg("ETAPA 4/4: confidence de cada rama y matrices todos vs todos")
  M <- length(results)
  splits <- lapply(results, `[[`, "splits")
  lens <- vapply(splits, nrow, integer(1))
  all_keys <- unlist(lapply(splits, `[[`, "key"), use.names = FALSE)
  keys <- unique(all_keys)
  key_idx <- match(all_keys, keys)
  S <- Matrix::sparseMatrix(i = rep(seq_len(M), lens), j = key_idx, x = 1,
    dims = c(M, length(keys)))
  # Indices de cada arbol calculados una sola vez (no un match por arbol).
  key_idx <- split(key_idx, factor(rep(seq_len(M), lens), levels = seq_len(M)))
  is_gene <- info$tree_id != "REF_TOTAL"; N <- sum(is_gene)
  frequency <- as.numeric(Matrix::colSums(S[is_gene, , drop = FALSE]))
  # Soporte de cada rama entre otros ORFs; el propio ORF y REF_TOTAL no votan.
  # Se escribe en los nodos de cada arbol: una linea Newick por arbol.
  tree_con <- file(tmp_files[["arboles"]], "wt"); on.exit(close(tree_con), add = TRUE)
  branch_mean <- branch_median <- rep(NA_real_, M)
  branch_started <- Sys.time()
  for (i in seq_len(M)) {
    if (i == 1L || i %% 10L == 0L) report_progress("Confidence de ramas", i - 1L, M, branch_started)
    numerator <- frequency[key_idx[[i]]] - as.integer(is_gene[i])
    denominator <- N - as.integer(is_gene[i])
    pct <- if (denominator > 0L) 100*numerator/denominator else rep(NA_real_, length(numerator))
    if (length(pct) && !all(is.na(pct))) {
      branch_mean[i] <- mean(pct, na.rm = TRUE); branch_median[i] <- median(pct, na.rm = TRUE)
    }
    tr <- results[[i]]$tree; tr$node.label <- rep("", tr$Nnode)
    if (length(pct)) tr$node.label[splits[[i]]$node - length(labels)] <-
      ifelse(is.na(pct), "", sprintf("%.2f", pct))
    writeLines(ape::write.tree(tr), tree_con)
  }
  # Matrices CSV.gz escritas por bloques. Filas = arbol evaluado A, columnas = B.
  rf_con <- gzfile(tmp_files[["RF"]], "wt"); on.exit(close(rf_con), add = TRUE)
  cc_con <- gzfile(tmp_files[["concordancia"]], "wt"); on.exit(close(cc_con), add = TRUE)
  header <- paste(c("tree_id", info$tree_id), collapse = ",")
  writeLines(header, rf_con); writeLines(header, cc_con)
  mean_rf <- mean_cc <- rf_total <- own_in_total <- total_in_own <- rep(NA_real_, M)
  mean_ok <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  ref <- match("REF_TOTAL", info$tree_id)
  comparison_started <- Sys.time()
  logmsg("Todos vs todos | ", M, " arboles | ", fmt_n(as.double(M)*M), " pares ordenados incluyendo diagonal")
  for (start in seq.int(1L, M, by = cfg$comparison_block)) {
    rows <- start:min(M, start + cfg$comparison_block - 1L)
    shared <- as.matrix(Matrix::tcrossprod(S[rows, , drop = FALSE], S))
    divisor <- outer(lens[rows], lens, "+")
    rf <- (divisor - 2*shared)/divisor
    rf[divisor == 0] <- NA_real_
    recovery <- sweep(100*shared, 1L, lens[rows], "/")
    recovery[lens[rows] == 0L, ] <- NA_real_
    writeLines(matrix_lines(rf, info$tree_id[rows]), rf_con)
    writeLines(matrix_lines(recovery, info$tree_id[rows]), cc_con)
    for (r in seq_along(rows)) {
      i <- rows[r]
      mean_rf[i] <- mean_ok(rf[r, -i]); mean_cc[i] <- mean_ok(recovery[r, -i])
      rf_total[i] <- rf[r, ref]; own_in_total[i] <- recovery[r, ref]
      total_in_own[i] <- if (lens[ref]) 100*shared[r, ref]/lens[ref] else NA_real_
    }
    report_progress("Todos vs todos", tail(rows, 1L), M, comparison_started)
  }
  info[, `:=`(forest_branch_mean_pct = branch_mean, forest_branch_median_pct = branch_median,
    mean_RF_other_trees = mean_rf, mean_pair_concordance_pct = mean_cc, RF_to_total = rf_total,
    own_splits_in_total_pct = own_in_total, total_splits_in_own_pct = total_in_own,
    newick_line = seq_len(M))]
  info
}

# Resumen: NJ global y TODOS los ORFs de la anotacion, en ese orden; los que no
# tienen arbol quedan con su motivo y sin linea en el .nwk.
build_summary <- function(metrics, all_info) {
  base <- names(all_info)
  res <- data.table::rbindlist(list(metrics[tree_id == "REF_TOTAL", base, with = FALSE], all_info),
                               use.names = TRUE)
  pos <- match(res$tree_id, metrics$tree_id)
  for (k in setdiff(names(metrics), base)) data.table::set(res, j = k, value = metrics[[k]][pos])
  data.table::setcolorder(res, c("newick_line", setdiff(names(res), "newick_line")))
  res
}

# -----------------------------------------------------------------------------
# 8. CORRIDA COMPLETA DEL SCRIPT ANTERIOR: SE ORDENA SIN RECALCULAR
# -----------------------------------------------------------------------------
# Solo si termino (ESTADO.txt = COMPLETE) y uso el mismo VCF sin cambios, las
# mismas muestras, los mismos intervalos de ORFs y los mismos parametros.
reuse_previous <- function(prev, p, cfg, tmp, tmp_files) {
  if (is.null(prev) || !nzchar(prev)) return(FALSE)
  prev <- path.expand(prev)
  if (!file.exists(file.path(prev, "ESTADO.txt"))) {
    logmsg("No hay corrida anterior en ", prev, ": se calcula desde cero.")
    return(FALSE)
  }
  if (!identical(readLines(file.path(prev, "ESTADO.txt"), n = 1L, warn = FALSE), "COMPLETE")) {
    logmsg("La corrida anterior en ", prev, " quedo incompleta: se calcula de nuevo.")
    return(FALSE)
  }
  need <- c("configuracion.rds", "muestras.tsv", "intervalos_orfs.tsv", "bosque_concordancia.nwk",
            "orden_bosque.tsv", "RF_normalizada.csv.gz", "concordancia_direccional_pct.csv.gz",
            "distancias_geneticas_total.rds", "resumen_arboles.tsv", "control_orfs.tsv")
  if (!all(file.exists(file.path(prev, need)))) {
    logmsg("A la corrida anterior en ", prev, " le faltan archivos: se calcula de nuevo.")
    return(FALSE)
  }
  old <- tryCatch(readRDS(file.path(prev, "configuracion.rds")), error = function(e) NULL)
  if (is.null(old$settings) || is.null(old$dataset)) return(FALSE)
  differ <- character()
  for (k in c("max_ploidy", "min_site_call_rate", "accept_filter_dot", "min_snps_orf",
              "min_shared_snps_orf", "min_shared_snps_total", "collapse_tolerance"))
    if (!identical(old$settings[[k]], cfg[[k]])) differ <- c(differ, k)
  old_vcf <- resolve_file(path.expand(old$dataset$folder), old$dataset$vcf)
  if (!identical(normalizePath(old_vcf, mustWork = FALSE), normalizePath(p$vcf))) {
    differ <- c(differ, "VCF")
  } else if (file.mtime(p$vcf) > file.mtime(file.path(prev, "configuracion.rds"))) {
    differ <- c(differ, "VCF modificado despues")
  }
  chars <- c("tree_id", "orf", "status", "reason")
  sm <- data.table::fread(file.path(prev, "muestras.tsv"), colClasses = "character")
  if (!identical(sm$vcf_sample, p$selected) || !identical(sm$tip_id, p$labels))
    differ <- c(differ, "muestras")
  iv <- data.table::fread(file.path(prev, "intervalos_orfs.tsv"),
                          colClasses = list(character = c("orf", "chr", "chr_key")))
  norm_iv <- function(x) {
    y <- data.table::data.table(orf = as.character(x$orf), chr_key = as.character(x$chr_key),
                                start = as.numeric(x$start), end = as.numeric(x$end))
    data.table::setorder(y, orf, chr_key, start, end); as.list(y)
  }
  if (!identical(norm_iv(iv), norm_iv(p$ann))) differ <- c(differ, "intervalos de ORFs")
  if (length(differ)) {
    logmsg("Hay una corrida anterior completa en ", prev, ", pero cambio: ",
           paste(differ, collapse = ", "), ". Se calcula de nuevo.")
    return(FALSE)
  }
  logmsg("Corrida anterior COMPLETA en ", prev, " con los mismos datos y parametros: ",
         "se ordenan sus resultados en este formato, sin recalcular.")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  copies <- c(arboles = "bosque_concordancia.nwk", RF = "RF_normalizada.csv.gz",
              concordancia = "concordancia_direccional_pct.csv.gz")
  for (k in names(copies))
    if (!file.copy(file.path(prev, copies[[k]]), tmp_files[[k]], overwrite = TRUE))
      stop("No se pudo copiar ", copies[[k]])
  d <- readRDS(file.path(prev, "distancias_geneticas_total.rds"))
  if (!identical(labels(d), p$labels)) stop("Las distancias anteriores no calzan con las muestras.")
  write_matrix_gz(as.matrix(d), p$labels, tmp_files[["distancias"]], "muestra", 15L)
  metrics <- data.table::fread(file.path(prev, "resumen_arboles.tsv"),
                               colClasses = list(character = chars))
  forest_order <- data.table::fread(file.path(prev, "orden_bosque.tsv"),
                                    colClasses = list(character = c("tree_id", "orf")))
  metrics[, newick_line := forest_order$line[match(tree_id, forest_order$tree_id)]]
  all_info <- data.table::fread(file.path(prev, "control_orfs.tsv"),
                                colClasses = list(character = chars))
  write_tsv(build_summary(metrics, all_info), tmp_files[["resumen"]])
  TRUE
}

# -----------------------------------------------------------------------------
# 9. EJECUCION
# -----------------------------------------------------------------------------
run_forest <- function(p, cfg, cb, tmp, tmp_files) {
  index <- cache_vcf(p$vcf, p$ann, p$labels, p$selected, tmp, cb, cfg)
  logmsg("ETAPA 2/4: calculando NJ GLOBAL con ", fmt_n(index$n_snps), " SNPs y ",
         length(p$labels), " muestras; ETA no disponible para esta operacion")
  ref <- make_nj(index$distance, cfg$collapse_tolerance)
  write_matrix_gz(as.matrix(index$distance), p$labels, tmp_files[["distancias"]], "muestra", 15L)
  rs <- tree_splits(ref$tree, p$labels)
  ref_info <- data.table::data.table(tree_id = "REF_TOTAL", orf = "ALL_FILTERED_SNPS",
    status = "ok", reason = "", n_snps = index$n_snps, n_splits = nrow(rs),
    resolution = nrow(rs)/(length(p$labels) - 3L),
    n_contracted = ref$n_contracted, n_negative = ref$n_negative)
  forest <- build_orf_trees(index, p$ann, p$labels, tmp, cb, cfg)
  results <- c(list(list(tree = ref$tree, splits = rs)), forest$results)
  info <- data.table::rbindlist(list(ref_info, forest$info))
  metrics <- compare_forest(results, info, p$labels, tmp_files, cfg)
  write_tsv(build_summary(metrics, forest$all_info), tmp_files[["resumen"]])
}

run_pipeline <- function(cfg = CONFIG) {
  if (cfg$workers < 1L || cfg$chunk_snps < 1L || cfg$comparison_block < 1L ||
      cfg$orf_batch_size < 1L || cfg$max_ploidy < 1L || cfg$min_site_call_rate <= 0 ||
      cfg$min_site_call_rate > 1 || cfg$collapse_tolerance < 0)
    stop("Parametros de configuracion invalidos.")
  started <- Sys.time()
  name <- cfg$species
  out_dir <- if (is.null(cfg$output_dir)) script_dir() else path.expand(cfg$output_dir)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)
  final <- output_files(out_dir, name)
  renamed <- file.path(out_dir, paste0(name, "_muestras_renombradas.tsv"))
  tmp <- file.path(out_dir, paste0(".tmp_bosque_", name))
  tmp_files <- stats::setNames(file.path(tmp, basename(final)), names(final))
  logmsg(name, " | resultados en ", out_dir)
  lock <- take_lock(tmp)
  completed <- FALSE
  # Si se corta despues de leer el VCF, el avance queda para retomar; si no hay
  # nada util que retomar, no deja la carpeta oculta.
  on.exit(if (!completed) {
    if (file.exists(file.path(tmp, "etapa1.rds"))) {
      unlink(lock)
      logmsg("El avance quedo guardado en ", tmp,
             "; al ejecutar de nuevo con los mismos datos, retoma desde ahi.")
    } else unlink(tmp, recursive = TRUE)
  }, add = TRUE)
  tryCatch(with_logged_warnings({
    if (!cfg$overwrite && any(file.exists(final)))
      stop("Ya existen resultados de ", name, " en ", out_dir, ": ",
        paste(basename(final[file.exists(final)]), collapse = ", "),
        ". Para recalcular, borralos o usa overwrite = TRUE.")
    logmsg("PREPARACION: comprobando/instalando paquetes requeridos")
    ensure_packages(cfg$install_packages)
    logmsg("PREPARACION: revisando VCF, anotacion y cromosomas antes de calcular")
    p <- prepare_inputs(cfg)
    logmsg("  Muestras: ", length(p$labels),
      if (is.null(cfg$samples_file)) " (todas las del VCF)" else " (las de samples_file)",
      " | ORFs: ", data.table::uniqueN(p$ann$orf), " | contigs del VCF: ", length(p$vcf_contigs))
    if (!reuse_previous(cfg$previous_results, p, cfg, tmp, tmp_files)) {
      logmsg("PREPARACION: compilando funciones C++ de distancias")
      data.table::setDTthreads(1L) # evita multiplicar hilos dentro de cada proceso
      compile_helpers()
      cb <- make_codebook(cfg$max_ploidy)
      open_workdir(tmp, p, cfg)
      run_forest(p, cfg, cb, tmp, tmp_files)
    }
    for (k in names(final)) {
      if (file.exists(final[[k]])) unlink(final[[k]])
      if (!file.rename(tmp_files[[k]], final[[k]]))
        stop("No se pudo mover ", basename(final[[k]]), " a ", out_dir)
    }
    changed <- p$labels != p$selected
    if (file.exists(renamed)) unlink(renamed)
    if (any(changed)) {
      write_tsv(data.table::data.table(tip_id = p$labels[changed], vcf_sample = p$selected[changed]),
                renamed)
      logmsg("  ", sum(changed), " IDs de muestra cambiaron para Newick: ", basename(renamed))
    }
  }), error = function(e) {
    logmsg("ERROR: ", conditionMessage(e))
    stop(conditionMessage(e), call. = FALSE)
  })
  completed <- TRUE
  unlink(tmp, recursive = TRUE)
  logmsg("TERMINADO ", name, " | tiempo total ",
         format_duration(as.numeric(difftime(Sys.time(), started, units = "secs"))))
  for (f in c(final, if (file.exists(renamed)) renamed))
    logmsg("  ", basename(f), " (", format(structure(file.size(f), class = "object_size"),
                                          units = "auto"), ")")
  invisible(final)
}

# -----------------------------------------------------------------------------
# 10. EJECUTAR. Para importar funciones sin ejecutar: PHYLO_LIBRARY_ONLY=1.
# -----------------------------------------------------------------------------
if (Sys.getenv("PHYLO_LIBRARY_ONLY") != "1") RESULTADOS <- run_pipeline(CONFIG)

# =============================================================================
# LECTURA DE RESULTADOS EN R (ejemplo)
# resumen <- data.table::fread("SCerevisiae_resumen.tsv")
# arboles <- ape::read.tree("SCerevisiae_arboles.nwk")   # [[1]] = NJ global
# names(arboles) <- resumen[!is.na(newick_line)][order(newick_line)]$tree_id
# arboles[[1]]$node.label                                  # confidence por rama
# # Las matrices pueden ser grandes: leerlas solo si se necesita RAM M x M.
# rf <- as.matrix(read.csv(gzfile("SCerevisiae_RF.csv.gz"), row.names = 1, check.names = FALSE))
# # Genes mas diferentes respecto al NJ completo:
# resumen[tree_id != "REF_TOTAL"][order(-RF_to_total)]
# # Bosque internamente concordante: respaldo alto y buena resolucion.
# resumen[tree_id != "REF_TOTAL"][order(-forest_branch_mean_pct)]
# =============================================================================
