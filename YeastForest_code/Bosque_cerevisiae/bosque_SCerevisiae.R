# =============================================================================
# PHYLOGENETIC FOREST FROM A VCF: S. cerevisiae
# Place this file in the folder where the results should be written and run it
# with source("bosque_SCerevisiae.R"), with Rscript or as an RStudio Job.
# It is independent of the S. eubayanus script: both can run at the same time if
# the machine has enough RAM and cores (each one uses workers + 1 processes).
# Date: 2026-10-03. No bootstrap is used and the data are never resampled.
# The log reports stages, ORF batches, percentage, elapsed time and ETA.
# The ETA refers to the current stage and is approximate; the VCF pass and the genome-wide NJ have none.
# =============================================================================
# OUTPUT: in the SAME folder as this script, without subfolders
# (in getwd() when it is run line by line). Five files:
#   SCerevisiae_arboles.nwk             line 1 = genome-wide NJ; then one NJ per
#                                       ORF. Each node carries its forest support:
#                                       % of the other ORFs (excluding its own)
#                                       that contain that branch.
#   SCerevisiae_distancias_geneticas.csv.gz  sample x sample, used by the genome-wide NJ
#   SCerevisiae_RF.csv.gz               normalised RF, all against all
#   SCerevisiae_concordancia.csv.gz     concordance per pair: % of the branches of
#                                       the row tree that are present in the column
#                                       tree (0 to 100)
#   SCerevisiae_resumen.tsv             one row per tree (genome-wide and each ORF):
#                                       line in the .nwk, SNPs, resolution,
#                                       mean support and comparison with the
#                                       genome-wide tree. ORFs without a tree carry the reason.
# Only if a VCF sample ID contains characters that Newick does not accept, the file
# SCerevisiae_muestras_renombradas.tsv is added with the equivalence.
# While running, progress is saved in the hidden folder .tmp_bosque_SCerevisiae.
# If the run stops, running it again resumes from the last batch; when it
# finishes, that folder is deleted. To start from scratch, delete it.
# If a COMPLETE run of the previous version of this script (previous_results) with
# the same data and parameters exists, its results are rearranged into this format
# without recomputing. That earlier folder can be deleted afterwards.
# =============================================================================
# GOALS
# 1. Total-evidence NJ: all biallelic SNPs that pass the filters,
#    intergenic ones included. Each SNP is counted once.
# 2. One NJ per ORF, with exactly the same samples as the total NJ.
# 3. Normalised RF, all against all, REF_TOTAL included.
# 4. Empirical support within the forest: directional recovery of bipartitions
#    per pair, and frequency of each bipartition among the remaining ORFs.
# 5. A single Newick file with all the trees and the support on their nodes.
#
# DEFINITIONS (unrooted trees; branch lengths are ignored when comparing them)
# RF(A,B) = (sA + sB - 2*cAB)/(sA + sB), with s = number of internal splits.
# Concordance(A <- B) = 100*cAB/sA: % of the splits of A present in B.
# Forest support of a branch of A (gene concordance factor) = % of the OTHER ORFs
# that contain that split. The total NJ is in the matrices but does NOT vote in it.
# An absence may reflect conflict or lack of resolution. It is not a statistical
# test, a probability that the tree is true, or bootstrap support.
# With binary trees, the pairwise concordance equals 100*(1-RF).
# For two trees without informative splits NA is reported, not perfect agreement.
#
# GENETIC DISTANCE
# Mean of |fALT_i - fALT_j| over the SNPs called in both individuals.
# fALT = ALT copies / ploidy declared in GT. In diploids it equals the normalised
# IBS distance. Phase is ignored; haplotypes are not reconstructed.
# The distances come from the SNP panel: they are not substitutions per site
# of a full sequence. A partial or missing GT is treated as missing.
#
# OPTIMISATION
# The VCF is read once, in blocks; temporary SNP cache; raw genotypes;
# genetic distances with bitsets and popcount in C++; ORFs in parallel on Linux;
# forest comparison through a sparse split incidence matrix and blocks of rows.
# The full VCF is never loaded and several M x M matrices are never kept in RAM.
# Splits are identified by the SHA-256 of their canonical sets of tips.
#
# ANNOTATION
# It must refer to the SAME assembly as the VCF; renaming chromosomes does not
# convert coordinates between assemblies. Before computing, the script checks that
# the chromosomes match the VCF and that no ORF runs past the end of its chromosome.
# SGD_features.tab: ORFs minus the introns with an identified Parent.
# GFF3: union of the CDS of each gene (no introns).
# Table: intervals from chr/start/end; if they are gene limits, introns are included.
# NCBI gene_result.txt: uses start/end_position_on_the_genomic_accession and,
# as chromosome, the column (chromosome or accession) that matches the VCF.
# It has no gene type, so every gene with coordinates is included.
# All table coordinates are read as 1-based and inclusive, unless
# annotation_zero_based=TRUE. Site coordinates and geographic metadata are not used.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. CONFIGURATION
# -----------------------------------------------------------------------------
CONFIG <- list(
  species = "SCerevisiae",          # prefix of the output files
  folder = "DATA",                  # VCF and annotation folder (absolute, or relative to the working directory)
  vcf = "1011Matrix.gvcf.gz",
  annotation = "SGD_features.tab",
  annotation_format = "sgd",        # auto, sgd, gff3 or table
  annotation_zero_based = FALSE,
  chromosome_map = NULL,            # optional TSV: annotation_chr, vcf_chr
  samples_file = NULL,              # optional: one VCF sample ID per line
  output_dir = NULL,                # NULL = the folder of this script
  previous_results = NULL,          # optional: folder of a complete run of the previous script
  install_packages = TRUE,
  chunk_snps = 2000L,
  workers = 2L,                     # adjust to CPU/RAM; Windows uses 1
  comparison_block = 100L,
  orf_batch_size = 10L,             # reports progress and saves it after every batch
  max_ploidy = 8L,                  # if GT declares more, the run stops with a message
  min_site_call_rate = 0.90,
  accept_filter_dot = TRUE,         # '.' means no filter applied, not PASS
  min_snps_orf = 1L,                # tries ALL ORFs with SNPs; raise it if desired
  min_shared_snps_orf = 1L,         # requires a defined distance for every pair
  min_shared_snps_total = 50L,
  collapse_tolerance = 1e-10,       # collapses internal branches <= this value
  overwrite = FALSE                 # FALSE: if the results already exist, nothing is recomputed
)
PIPELINE_VERSION <- "2026-10-03"

# -----------------------------------------------------------------------------
# 1. DEPENDENCIES AND UTILITIES
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
  if (length(absent)) stop("Missing packages: ", paste(absent, collapse = ", "))
}

logmsg <- function(...) {
  cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")
  flush.console()
}
format_duration <- function(seconds) {
  if (!is.finite(seconds)) return("not available")
  seconds <- max(0, round(seconds))
  sprintf("%02d:%02d:%02d", as.integer(seconds %/% 3600),
          as.integer((seconds %% 3600) %/% 60), as.integer(seconds %% 60))
}
# rate_done: ORFs computed in this session (resumed ones do not count for the ETA).
report_progress <- function(stage, done, total, started, detail = "", rate_done = done) {
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  remaining <- if (rate_done > 0) elapsed * (total - done)/rate_done else Inf
  logmsg(stage, " | ", done, "/", total, " (", sprintf("%.1f", 100*done/total),
    "%) | elapsed ", format_duration(elapsed),
    " | estimated time left for THIS stage ", format_duration(remaining), detail)
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
# Writes and then renames, so an interrupted write never leaves a broken file.
save_atomic <- function(x, file) {
  part <- paste0(file, ".part")
  saveRDS(x, part, compress = FALSE)
  if (!file.rename(part, file)) stop("Could not save ", file)
}

# Folder of this script: source(), Rscript or, in RStudio Jobs, getwd(),
# which by default is the folder of the script.
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

# One run per species and folder: a second simultaneous run would double
# RAM and CPU use and overwrite the progress of the first one.
take_lock <- function(tmp) {
  lock <- file.path(tmp, "en_curso.txt")
  if (file.exists(lock)) {
    other <- suppressWarnings(as.integer(readLines(lock, n = 1L, warn = FALSE)))
    if (length(other) == 1L && !is.na(other) && other != Sys.getpid() &&
        .Platform$OS.type != "windows" && isTRUE(tools::pskill(other, 0L))) {
      msg <- paste0("Another run is already using this folder (process ", other,
        "). Wait for it to finish or stop it. If there is none, delete ", lock)
      logmsg("ERROR: ", msg)
      stop(msg, call. = FALSE)
    }
  }
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(Sys.getpid()), lock)
  lock
}

# Shows each warning in the log as it happens (in Jobs they are not kept until the end).
with_logged_warnings <- function(expr) {
  seen <- character()
  withCallingHandlers(expr, warning = function(w) {
    msg <- conditionMessage(w)
    if (!msg %in% seen) { seen <<- c(seen, msg); logmsg("WARNING: ", msg) }
    invokeRestart("muffleWarning")
  })
}

# Rows of a matrix as CSV: id, values; NA and NaN are written as NA.
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

# Only normalises simple names (chrI <-> 1), never NC_ accessions or scaffolds.
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
# 2. READING ANNOTATIONS: SGD, GFF3 OR A TABLE WITH COORDINATES
# -----------------------------------------------------------------------------
read_annotation <- function(path, format = "auto", zero_based = FALSE, vcf_contigs = NULL) {
  if (!file.exists(path)) stop("Annotation not found: ", path)
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
    if (ncol(x) < 12L) stop("SGD_features.tab needs at least 12 columns.")
    orf <- x[toupper(V2) == "ORF" & !is.na(V4) & nzchar(V4)]
    ans <- orf[, .(orf = as.character(V4), chr = as.character(V9),
                   start = pmin(as.numeric(V10), as.numeric(V11)),
                   end = pmax(as.numeric(V10), as.numeric(V11)),
                   basis = "SGD_ORF_minus_annotated_introns")]
    # Subtract ONLY the introns whose Parent is this ORF.
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
    if (ncol(x) != 9L) stop("GFF3 needs 9 columns before ##FASTA.")
    attr_get <- function(v, key) vapply(strsplit(v, ";", fixed = TRUE), function(z) {
      hit <- z[startsWith(z, paste0(key, "="))]
      if (!length(hit)) NA_character_ else utils::URLdecode(sub("^[^=]*=", "", hit[1L]))
    }, character(1))
    ids <- attr_get(x$V9, "ID"); parents <- attr_get(x$V9, "Parent")
    loci <- attr_get(x$V9, "locus_tag"); names_ <- attr_get(x$V9, "Name")
    # Climb CDS -> transcript -> gene. Genes and assemblies are never mixed.
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
    if (!length(k)) stop("GFF3 without CDS: an annotation of coding regions is required.")
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
    # Accepts CSV/TSV with a header, including NCBI gene_result.txt (Gene,
    # Send to > File > Tabular). Coordinates are never parsed from descriptive text.
    x <- tryCatch(data.table::fread(path, header = TRUE, quote = "\"", check.names = FALSE),
      error = function(e) stop("Cannot read the table ", path, ": ", conditionMessage(e)))
    norm <- function(z) gsub("[^a-z0-9]", "", tolower(z))
    cn <- norm(names(x))
    find_cols <- function(aliases) { z <- match(aliases, cn); unique(names(x)[z[!is.na(z)]]) }
    find_col <- function(aliases) { z <- find_cols(aliases); if (length(z)) z[1L] else NA_character_ }
    chr_cols <- find_cols(c("chr", "chrom", "chromosome", "seqid", "contig", "sequenceid",
      "genomicnucleotideaccessionversion", "genomicaccession", "chraccver",
      "annotationgenomicaccession"))
    # gene_result.txt gives the chromosome twice (chromosome and accession) for the
    # same coordinates: the column whose names match the VCF is used.
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
      "The annotation ", basename(path), " does not provide ORF/chromosome/start/end.\n",
      "Columns found: ", paste(names(x), collapse = ", "), "\n",
      "It requires the GFF3 of the SAME assembly used in the VCF, a table\n",
      "chr/start/end/orf or the tabular NCBI gene_result.txt with\n",
      "start_position_on_the_genomic_accession and end_position_on_the_genomic_accession.")
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
    logmsg("  Annotation read as a table: ORF = ", cols[["orf"]], ", chromosome = ", cols[["chr"]],
           ", start = ", cols[["start"]], ", end = ", cols[["end"]])
    warning("The table gives fixed intervals; for ORFs without introns, prefer the CDS of a GFF3.",
            call. = FALSE)
  } else stop("annotation_format must be auto, sgd, gff3 or table.")
  ok <- !is.na(ans$orf) & nzchar(ans$orf) & !is.na(ans$chr) & nzchar(ans$chr) &
        is.finite(ans$start) & is.finite(ans$end) & ans$start >= 1 & ans$end >= ans$start
  if (any(!ok)) warning(sum(!ok), " invalid annotation intervals skipped.", call. = FALSE)
  ans <- unique(ans[ok])
  if (!nrow(ans)) stop("No valid ORF intervals in ", path)
  if (any(ans[, data.table::uniqueN(chr), by = orf]$V1 > 1L))
    stop("An ORF ID appears on several chromosomes: check the assembly and the IDs.")
  ans[, chr_key := chr_key(chr)]
  ans
}

# -----------------------------------------------------------------------------
# 3. GENOTYPES AND FAST DISTANCES IN C++ (called from R)
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
  if (length(levels) > 254L) stop("Too many dosage states for the raw encoding.")
  codebook <- matrix(0L, max_ploidy + 1L, max_ploidy + 1L)
  for (p in seq_len(max_ploidy)) codebook[p + 1L, seq_len(p + 1L)] <- match(round((0:p)/p, 12), levels)
  list(levels = levels, codebook = codebook)
}

filter_chunk <- function(vcf, cb, cfg) {
  gt <- VariantAnnotation::geno(vcf)$GT
  if (is.null(gt)) stop("The VCF has no FORMAT/GT field.")
  ref <- as.character(VariantAnnotation::ref(vcf))
  alt <- as.list(VariantAnnotation::alt(vcf))
  is_snp <- vapply(seq_along(alt), function(i) {
    a <- as.character(alt[[i]])
    concrete <- a[!a %in% c("<NON_REF>", "<*>")]
    # A gVCF may contain C,<NON_REF>; the concrete allele must have index 1.
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
    stop("GT with ploidy > max_ploidy. Increase CONFIG$max_ploidy; genotypes are never converted to diploid.")
  x <- encoded$gt
  called <- x != as.raw(0L)
  enough <- rowMeans(called) >= cfg$min_site_call_rate
  # Two different dosages among the samples: removes SNPs that do not vary in this set.
  lo <- matrix(as.integer(x), nrow(x)); lo[!called] <- 999L
  hi <- matrix(as.integer(x), nrow(x)); hi[!called] <- -1L
  variable <- do.call(pmin, as.data.frame(lo)) != do.call(pmax, as.data.frame(hi))
  keep <- which(enough & variable)
  list(gt = x[keep, , drop = FALSE], rows = idx[keep], candidates = idx,
       biallelic_pass = length(idx), low_call = sum(!enough), constant = sum(enough & !variable))
}

parts_to_distance <- function(parts, labels, min_shared) {
  too_few <- parts$den < min_shared; diag(too_few) <- FALSE
  if (any(too_few)) stop("At least one pair has < ", min_shared,
    " shared SNPs (minimum = ", min(parts$den[lower.tri(parts$den)]),
    "). Distances are not imputed and no sample is dropped for a single ORF.")
  d <- parts$num / parts$den; diag(d) <- 0
  if (any(!is.finite(d))) stop("Non-finite distances.")
  dimnames(d) <- list(labels, labels)
  stats::as.dist(d)
}

# -----------------------------------------------------------------------------
# 4. PRELIMINARY CHECKS: EVERYTHING THAT CAN FAIL IS CHECKED BEFORE COMPUTING
# -----------------------------------------------------------------------------
prepare_inputs <- function(cfg) {
  folder <- path.expand(cfg$folder)
  vcf <- resolve_file(folder, cfg$vcf)
  annotation_path <- resolve_file(folder, cfg$annotation)
  map_path <- resolve_file(folder, cfg$chromosome_map)
  if (!file.exists(vcf)) stop("VCF not found: ", vcf)
  if (!file.exists(paste0(vcf, ".tbi"))) {
    logmsg("  Creating the tabix index of the VCF (requires a sorted BGZF file).")
    tryCatch(Rsamtools::indexTabix(vcf, format = "vcf"), error = function(e)
      stop("Could not index ", basename(vcf), ". It must be sorted BGZF: ", conditionMessage(e)))
  }
  vcf_contigs <- Rsamtools::seqnamesTabix(vcf)
  ann <- read_annotation(annotation_path, cfg$annotation_format, cfg$annotation_zero_based,
                         vcf_contigs)
  if (!is.null(map_path)) {
    map <- data.table::fread(map_path)
    if (!all(c("annotation_chr", "vcf_chr") %in% names(map)))
      stop("The map needs annotation_chr and vcf_chr.")
    j <- match(ann$chr, map$annotation_chr)
    if (anyNA(j)) stop("The chromosome map does not cover the whole annotation.")
    ann$chr_key <- chr_key(map$vcf_chr[j])
  }
  vcf_keys <- chr_key(vcf_contigs)
  if (anyDuplicated(vcf_keys))
    stop("Two VCF contigs get the same name after normalisation: ",
      paste(vcf_contigs[vcf_keys %in% vcf_keys[duplicated(vcf_keys)]], collapse = ", "),
      ". A chromosome_map is needed.")
  inside <- ann$chr_key %in% vcf_keys
  if (!any(inside)) stop("No annotation chromosome matches the VCF contigs.\n",
    "  Annotation: ", paste(head(unique(ann$chr), 6), collapse = ", "), "\n",
    "  VCF: ", paste(head(vcf_contigs, 6), collapse = ", "), "\n",
    "  If it is the same assembly with other names, use chromosome_map (annotation_chr, vcf_chr).")
  if (any(!inside)) logmsg("WARNING: ", data.table::uniqueN(ann$orf[!inside]),
    " ORFs are on chromosomes absent from the VCF (",
    paste(unique(ann$chr[!inside]), collapse = ", "),
    "): they get no tree and are listed in the summary.")
  hdr <- VariantAnnotation::scanVcfHeader(vcf)
  len <- suppressWarnings(GenomeInfoDb::seqlengths(hdr))
  len <- len[!is.na(len)]
  if (length(len)) {
    limit <- len[match(ann$chr_key, chr_key(names(len)))]
    beyond <- !is.na(limit) & ann$end > limit
    if (any(beyond)) stop(data.table::uniqueN(ann$orf[beyond]),
      " ORFs end after the chromosome length declared in the VCF (e.g. ",
      ann$orf[beyond][1L], " on ", ann$chr[beyond][1L], ":", ann$end[beyond][1L], " > ",
      limit[beyond][1L], "). The annotation seems to come from another assembly.")
  }
  selected <- VariantAnnotation::samples(hdr)
  if (anyDuplicated(selected)) stop("Duplicated sample IDs in the VCF header.")
  if (!is.null(cfg$samples_file)) {
    requested <- trimws(read_lines(resolve_file(folder, cfg$samples_file)))
    requested <- requested[nzchar(requested) & !startsWith(requested, "#")]
    if (anyDuplicated(requested) || !all(requested %in% selected))
      stop("samples_file contains duplicated IDs or IDs absent from the VCF.")
    selected <- selected[selected %in% requested]
  }
  if (length(selected) < 4L) stop("At least four samples are needed to compare splits.")
  list(vcf = vcf, ann = ann, selected = selected, labels = safe_names(selected),
       vcf_contigs = vcf_contigs)
}

# Progress is saved in the hidden folder. The fingerprint records the data and
# parameters used: if those of the VCF change, the run starts from scratch; if only
# those of the ORFs change, the VCF pass is kept and the ORFs are recomputed.
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
    if (identical(old$orfs, fp$orfs)) logmsg("RESUMING: using the progress saved in ", tmp)
    else {
      logmsg("RESUMING the saved VCF pass; the ORF parameters changed and the ORFs are recomputed.")
      unlink(file.path(tmp, "orfs"), recursive = TRUE)
    }
  } else {
    if (file.exists(f)) logmsg("Discarding earlier progress made with other data or parameters.")
    old_files <- list.files(tmp, all.files = TRUE, no.. = TRUE, full.names = TRUE)
    unlink(old_files[basename(old_files) != "en_curso.txt"], recursive = TRUE)
  }
  dir.create(file.path(tmp, "cache_snps"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp, "orfs"), showWarnings = FALSE)
  save_atomic(fp, f)
}

# -----------------------------------------------------------------------------
# 5. SNP CACHE: ONE PASS OVER THE VCF AND THE TOTAL-EVIDENCE NJ
# -----------------------------------------------------------------------------
cache_vcf <- function(vcf_path, ann, labels, selected, tmp, cb, cfg) {
  cache <- file.path(tmp, "cache_snps"); done_file <- file.path(tmp, "etapa1.rds")
  st <- if (file.exists(done_file)) tryCatch(readRDS(done_file), error = function(e) NULL)
  if (!is.null(st) && all(file.exists(file.path(cache, st$files)))) {
    logmsg("STAGE 1/4: RESUMING, the VCF was already read; it is not read again")
  } else {
    unlink(file.path(tmp, "orfs", "*"))  # the ORFs depend on this pass
    unlink(cache, recursive = TRUE); dir.create(cache)
    n <- length(labels); total <- list(num = matrix(0, n, n), den = matrix(0, n, n))
    ranges <- GenomicRanges::GRanges(ann$chr_key, IRanges::IRanges(ann$start, ann$end))
    vf <- VariantAnnotation::VcfFile(vcf_path, yieldSize = cfg$chunk_snps)
    open(vf); on.exit(close(vf))
    param <- VariantAnnotation::ScanVcfParam(info = NA_character_, geno = "GT", samples = selected)
    memberships <- list(); files <- character(); b <- 0L; n_raw <- 0; n_kept <- 0
    started <- Sys.time()
    logmsg("STAGE 1/4: reading the VCF and accumulating distances; total number of records unknown, no ETA yet")
    qc <- c(biallelic_pass = 0, low_call = 0, constant = 0)
    last_candidate <- NULL
    repeat {
      v <- VariantAnnotation::readVcf(vf, genome = "unspecified", param = param)
      if (!nrow(v)) break
      if (!identical(colnames(VariantAnnotation::geno(v)$GT), selected))
        stop("The sample order of the VCF reader changed; check the header.")
      rr <- SummarizedExperiment::rowRanges(v)
      chr <- as.character(GenomicRanges::seqnames(rr)); pos <- IRanges::start(rr)
      n_raw <- n_raw + nrow(v)
      z <- filter_chunk(v, cb, cfg)
      # Two SNP records at the same position (a multiallelic site split over lines or
      # a repeated record) are not counted twice. An indel at the same position
      # does not change the SNP, so it does not stop the run.
      cand <- paste(chr[z$candidates], pos[z$candidates], sep = ":")
      if (length(cand)) {
        dup <- if (!is.null(last_candidate) && cand[1L] == last_candidate) cand[1L]
               else cand[duplicated(cand)][1L]
        if (!is.na(dup)) stop("There are two SNP records at position ", dup,
          " (a multiallelic site split over lines or a repeated record). Merge them first with",
          " bcftools norm -m +any; they are never counted twice.")
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
      logmsg("VCF | block ", b, " | records read ", fmt_n(n_raw),
        " | SNPs kept ", fmt_n(n_kept),
        " | position ", tail(chr, 1L), ":", tail(pos, 1L),
        " | elapsed ", format_duration(as.numeric(difftime(Sys.time(), started, units = "secs"))))
    }
    if (!n_kept) stop("No SNP passed the filters.")
    mapping <- data.table::rbindlist(memberships)
    if (!nrow(mapping)) stop("Zero SNPs inside ORFs: check coordinates, assembly and chromosomes.")
    st <- list(files = files, mapping = mapping, total = total, n_snps = n_kept,
               n_raw = n_raw, qc = qc)
    save_atomic(st, done_file)
  }
  logmsg("VCF | records ", fmt_n(st$n_raw), " | biallelic SNPs with an accepted FILTER ",
    fmt_n(st$qc[["biallelic_pass"]]), " | below ", cfg$min_site_call_rate, " call rate ",
    fmt_n(st$qc[["low_call"]]), " | invariant in these samples ",
    fmt_n(st$qc[["constant"]]), " | kept ", fmt_n(st$n_snps))
  list(files = file.path(cache, st$files), mapping = st$mapping, n_snps = st$n_snps,
       distance = parts_to_distance(st$total, labels, cfg$min_shared_snps_total))
}

# -----------------------------------------------------------------------------
# 6. UNROOTED NJ; BRANCH COLLAPSING; CANONICAL INTERNAL SPLITS
# -----------------------------------------------------------------------------
make_nj <- function(distance, tol) {
  tree <- ape::nj(distance)
  n <- length(tree$tip.label)
  internal <- tree$edge[, 2] > n
  contracted <- sum(internal & tree$edge.length <= tol)
  negative <- sum(tree$edge.length < 0)
  # Negative NJ values are not interpretable evolutionary lengths.
  tree$edge.length <- pmax(tree$edge.length, 0)
  tree <- ape::di2multi(tree, tol = max(tol, .Machine$double.eps))
  tree <- ape::unroot(tree)
  list(tree = tree, n_contracted = contracted, n_negative = negative)
}

tree_splits <- function(tree, common_labels) {
  n <- length(common_labels)
  if (!setequal(tree$tip.label, common_labels)) stop("The trees do not have the same taxa.")
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
  # Small cache per process: each ORF usually spans only one or two blocks.
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
      info$reason <- paste0("Fewer than ", cfg$min_snps_orf, " retained SNPs")
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
  logmsg("STAGE 3/4: building ", length(all_orfs), " ORFs; processes=", workers)
  started <- Sys.time()
  n_ok <- 0L; n_omitted <- 0L; n_resumed <- 0L; n_computed <- 0L
  # During this stage the trees stay only on disk (progress batches) and only the
  # control table stays in memory, so each child process starts light and its
  # cost does not grow with the ORFs already computed. gc() consolidates memory
  # before the processes are created.
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
        logmsg("ORFs | RESUMING: ", n_resumed, " ORFs were already computed")
      logmsg("ORFs | starting batch ", first, "-", tail(positions, 1L),
        " | first ", all_orfs[first], " | last ", all_orfs[tail(positions, 1L)])
      batch <- if (workers > 1L) parallel::mclapply(all_orfs[positions], build_one,
        mc.cores = workers, mc.preschedule = TRUE, mc.set.seed = FALSE)
      else lapply(all_orfs[positions], build_one)
      # A dead process (for example, out of RAM) returns NULL or a try-error: the run stops
      # instead of silently losing ORFs. Everything computed so far stays saved.
      failed <- vapply(batch, function(x) is.null(x) || inherits(x, "try-error") ||
                         is.null(x$info), logical(1))
      if (any(failed)) stop("A process failed while computing the ORFs ",
        paste(all_orfs[positions][failed], collapse = ", "),
        "; this is usually a lack of RAM: lower workers and run again.")
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
        paste0(" | with tree ", n_ok, " | without tree ", n_omitted), rate_done = n_computed)
  }
  info <- data.table::rbindlist(batch_info)
  keep <- which(info$status == "ok")
  reasons <- sort(table(info$reason[info$status != "ok"]), decreasing = TRUE)
  reasons <- paste(sprintf("%s (%d)", names(reasons), as.integer(reasons))[seq_len(min(3L,
    length(reasons)))], collapse = "; ")
  if (!length(keep)) stop("No ORF could produce a tree. Reasons: ", reasons)
  logmsg("  ORFs with a tree: ", length(keep), "; without a tree: ", nrow(info) - length(keep),
         if (nzchar(reasons)) paste0(". Reasons: ", reasons), " (details in the summary)")
  # Trees and splits of the ORFs with a tree, read from the batches in the same order.
  results <- unlist(lapply(batch_files, function(f) {
    b <- readRDS(f); b[vapply(b, function(x) identical(x$info$status, "ok"), logical(1))]
  }), recursive = FALSE)
  if (length(results) != length(keep) ||
      !identical(vapply(results, function(x) x$info$tree_id, character(1)), info$tree_id[keep]))
    stop("The saved batches do not match the ORF table; delete ", tmp, " and run again.")
  list(results = results, info = info[keep], all_info = info)
}

# -----------------------------------------------------------------------------
# 7. ALL AGAINST ALL AND BRANCH SUPPORT WITHIN THE FOREST (NO BOOTSTRAP)
# -----------------------------------------------------------------------------
compare_forest <- function(results, info, labels, tmp_files, cfg) {
  logmsg("STAGE 4/4: forest support of each branch and all-against-all matrices")
  M <- length(results)
  splits <- lapply(results, `[[`, "splits")
  lens <- vapply(splits, nrow, integer(1))
  all_keys <- unlist(lapply(splits, `[[`, "key"), use.names = FALSE)
  keys <- unique(all_keys)
  key_idx <- match(all_keys, keys)
  S <- Matrix::sparseMatrix(i = rep(seq_len(M), lens), j = key_idx, x = 1,
    dims = c(M, length(keys)))
  # Indices of each tree computed once (not one match per tree).
  key_idx <- split(key_idx, factor(rep(seq_len(M), lens), levels = seq_len(M)))
  is_gene <- info$tree_id != "REF_TOTAL"; N <- sum(is_gene)
  frequency <- as.numeric(Matrix::colSums(S[is_gene, , drop = FALSE]))
  # Support of each branch among the other ORFs; the ORF itself and REF_TOTAL do not vote.
  # It is written on the nodes of each tree: one Newick line per tree.
  tree_con <- file(tmp_files[["arboles"]], "wt"); on.exit(close(tree_con), add = TRUE)
  branch_mean <- branch_median <- rep(NA_real_, M)
  branch_started <- Sys.time()
  for (i in seq_len(M)) {
    if (i == 1L || i %% 10L == 0L) report_progress("Forest support of branches", i - 1L, M, branch_started)
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
  # CSV.gz matrices written in blocks. Rows = evaluated tree A, columns = B.
  rf_con <- gzfile(tmp_files[["RF"]], "wt"); on.exit(close(rf_con), add = TRUE)
  cc_con <- gzfile(tmp_files[["concordancia"]], "wt"); on.exit(close(cc_con), add = TRUE)
  header <- paste(c("tree_id", info$tree_id), collapse = ",")
  writeLines(header, rf_con); writeLines(header, cc_con)
  mean_rf <- mean_cc <- rf_total <- own_in_total <- total_in_own <- rep(NA_real_, M)
  mean_ok <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  ref <- match("REF_TOTAL", info$tree_id)
  comparison_started <- Sys.time()
  logmsg("All against all | ", M, " trees | ", fmt_n(as.double(M)*M), " ordered pairs including the diagonal")
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
    report_progress("All against all", tail(rows, 1L), M, comparison_started)
  }
  info[, `:=`(forest_branch_mean_pct = branch_mean, forest_branch_median_pct = branch_median,
    mean_RF_other_trees = mean_rf, mean_pair_concordance_pct = mean_cc, RF_to_total = rf_total,
    own_splits_in_total_pct = own_in_total, total_splits_in_own_pct = total_in_own,
    newick_line = seq_len(M))]
  info
}

# Summary: genome-wide NJ and ALL the ORFs of the annotation, in that order; those
# without a tree keep their reason and have no line in the .nwk.
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
# 8. COMPLETE RUN OF THE PREVIOUS SCRIPT: REARRANGED WITHOUT RECOMPUTING
# -----------------------------------------------------------------------------
# Only if it finished (ESTADO.txt = COMPLETE) and used the same unchanged VCF, the
# same samples, the same ORF intervals and the same parameters.
reuse_previous <- function(prev, p, cfg, tmp, tmp_files) {
  if (is.null(prev) || !nzchar(prev)) return(FALSE)
  prev <- path.expand(prev)
  if (!file.exists(file.path(prev, "ESTADO.txt"))) {
    logmsg("No previous run in ", prev, ": computing from scratch.")
    return(FALSE)
  }
  if (!identical(readLines(file.path(prev, "ESTADO.txt"), n = 1L, warn = FALSE), "COMPLETE")) {
    logmsg("The previous run in ", prev, " is incomplete: computing again.")
    return(FALSE)
  }
  need <- c("configuracion.rds", "muestras.tsv", "intervalos_orfs.tsv", "bosque_concordancia.nwk",
            "orden_bosque.tsv", "RF_normalizada.csv.gz", "concordancia_direccional_pct.csv.gz",
            "distancias_geneticas_total.rds", "resumen_arboles.tsv", "control_orfs.tsv")
  if (!all(file.exists(file.path(prev, need)))) {
    logmsg("The previous run in ", prev, " is missing files: computing again.")
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
    differ <- c(differ, "VCF modified afterwards")
  }
  chars <- c("tree_id", "orf", "status", "reason")
  sm <- data.table::fread(file.path(prev, "muestras.tsv"), colClasses = "character")
  if (!identical(sm$vcf_sample, p$selected) || !identical(sm$tip_id, p$labels))
    differ <- c(differ, "samples")
  iv <- data.table::fread(file.path(prev, "intervalos_orfs.tsv"),
                          colClasses = list(character = c("orf", "chr", "chr_key")))
  norm_iv <- function(x) {
    y <- data.table::data.table(orf = as.character(x$orf), chr_key = as.character(x$chr_key),
                                start = as.numeric(x$start), end = as.numeric(x$end))
    data.table::setorder(y, orf, chr_key, start, end); as.list(y)
  }
  if (!identical(norm_iv(iv), norm_iv(p$ann))) differ <- c(differ, "ORF intervals")
  if (length(differ)) {
    logmsg("There is a complete previous run in ", prev, ", but this changed: ",
           paste(differ, collapse = ", "), ". Computing again.")
    return(FALSE)
  }
  logmsg("COMPLETE previous run in ", prev, " with the same data and parameters: ",
         "its results are rearranged into this format, without recomputing.")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  copies <- c(arboles = "bosque_concordancia.nwk", RF = "RF_normalizada.csv.gz",
              concordancia = "concordancia_direccional_pct.csv.gz")
  for (k in names(copies))
    if (!file.copy(file.path(prev, copies[[k]]), tmp_files[[k]], overwrite = TRUE))
      stop("Could not copy ", copies[[k]])
  d <- readRDS(file.path(prev, "distancias_geneticas_total.rds"))
  if (!identical(labels(d), p$labels)) stop("The previous distances do not match the samples.")
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
# 9. RUN
# -----------------------------------------------------------------------------
run_forest <- function(p, cfg, cb, tmp, tmp_files) {
  index <- cache_vcf(p$vcf, p$ann, p$labels, p$selected, tmp, cb, cfg)
  logmsg("STAGE 2/4: computing the GENOME-WIDE NJ with ", fmt_n(index$n_snps), " SNPs and ",
         length(p$labels), " samples; no ETA for this step")
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
    stop("Invalid configuration parameters.")
  started <- Sys.time()
  name <- cfg$species
  out_dir <- if (is.null(cfg$output_dir)) script_dir() else path.expand(cfg$output_dir)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)
  final <- output_files(out_dir, name)
  renamed <- file.path(out_dir, paste0(name, "_muestras_renombradas.tsv"))
  tmp <- file.path(out_dir, paste0(".tmp_bosque_", name))
  tmp_files <- stats::setNames(file.path(tmp, basename(final)), names(final))
  logmsg(name, " | results in ", out_dir)
  lock <- take_lock(tmp)
  completed <- FALSE
  # If the run stops after reading the VCF, progress is kept for resuming; if there is
  # nothing useful to resume, the hidden folder is removed.
  on.exit(if (!completed) {
    if (file.exists(file.path(tmp, "etapa1.rds"))) {
      unlink(lock)
      logmsg("Progress was saved in ", tmp,
             "; running again with the same data resumes from there.")
    } else unlink(tmp, recursive = TRUE)
  }, add = TRUE)
  tryCatch(with_logged_warnings({
    if (!cfg$overwrite && any(file.exists(final)))
      stop("Results of ", name, " already exist in ", out_dir, ": ",
        paste(basename(final[file.exists(final)]), collapse = ", "),
        ". To recompute, delete them or set overwrite = TRUE.")
    logmsg("SETUP: checking/installing the required packages")
    ensure_packages(cfg$install_packages)
    logmsg("SETUP: checking the VCF, the annotation and the chromosomes before computing")
    p <- prepare_inputs(cfg)
    logmsg("  Samples: ", length(p$labels),
      if (is.null(cfg$samples_file)) " (all those in the VCF)" else " (those in samples_file)",
      " | ORFs: ", data.table::uniqueN(p$ann$orf), " | VCF contigs: ", length(p$vcf_contigs))
    if (!reuse_previous(cfg$previous_results, p, cfg, tmp, tmp_files)) {
      logmsg("SETUP: compiling the C++ distance functions")
      data.table::setDTthreads(1L) # avoids multiplying threads inside each process
      compile_helpers()
      cb <- make_codebook(cfg$max_ploidy)
      open_workdir(tmp, p, cfg)
      run_forest(p, cfg, cb, tmp, tmp_files)
    }
    for (k in names(final)) {
      if (file.exists(final[[k]])) unlink(final[[k]])
      if (!file.rename(tmp_files[[k]], final[[k]]))
        stop("Could not move ", basename(final[[k]]), " a ", out_dir)
    }
    changed <- p$labels != p$selected
    if (file.exists(renamed)) unlink(renamed)
    if (any(changed)) {
      write_tsv(data.table::data.table(tip_id = p$labels[changed], vcf_sample = p$selected[changed]),
                renamed)
      logmsg("  ", sum(changed), " sample IDs changed for Newick: ", basename(renamed))
    }
  }), error = function(e) {
    logmsg("ERROR: ", conditionMessage(e))
    stop(conditionMessage(e), call. = FALSE)
  })
  completed <- TRUE
  unlink(tmp, recursive = TRUE)
  logmsg("FINISHED ", name, " | total time ",
         format_duration(as.numeric(difftime(Sys.time(), started, units = "secs"))))
  for (f in c(final, if (file.exists(renamed)) renamed))
    logmsg("  ", basename(f), " (", format(structure(file.size(f), class = "object_size"),
                                          units = "auto"), ")")
  invisible(final)
}

# -----------------------------------------------------------------------------
# 10. RUN. To load the functions without running: PHYLO_LIBRARY_ONLY=1.
# -----------------------------------------------------------------------------
if (Sys.getenv("PHYLO_LIBRARY_ONLY") != "1") RESULTADOS <- run_pipeline(CONFIG)

# =============================================================================
# READING THE RESULTS IN R (example)
# resumen <- data.table::fread("SCerevisiae_resumen.tsv")
# arboles <- ape::read.tree("SCerevisiae_arboles.nwk")   # [[1]] = genome-wide NJ
# names(arboles) <- resumen[!is.na(newick_line)][order(newick_line)]$tree_id
# arboles[[1]]$node.label                                  # forest support per branch
# # The matrices can be large: read them only if M x M fits in RAM.
# rf <- as.matrix(read.csv(gzfile("SCerevisiae_RF.csv.gz"), row.names = 1, check.names = FALSE))
# # Genes that differ most from the total NJ:
# resumen[tree_id != "REF_TOTAL"][order(-RF_to_total)]
# # Most concordant genes within the forest: high support and good resolution.
# resumen[tree_id != "REF_TOTAL"][order(-forest_branch_mean_pct)]
# =============================================================================
