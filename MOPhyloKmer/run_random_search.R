# =====================================================================
# run_random_search.R  ·  Runs the Random Search baseline on ALL data sets
# ---------------------------------------------------------------------
# Runs RS (11 runs) on every data set in config.R and stores everything in
# results/ (conv_RS_*.csv, resumen_RS_*.csv, front_RS_*.csv, medoid_RS_*.nwk).
# Parameters POP_RS / GEN_RS and the DATASETS list are in config.R.
#
# Uso:  Rscript run_random_search.R
# =====================================================================
.app_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
APP <- .app_dir()
assign("TUNE_ONLY", FALSE, envir = globalenv())   # clears leftover irace state in the same session
source(file.path(APP, "config.R"))

DATA_DIR    <- file.path(APP, "data")
RESULTS_DIR <- file.path(APP, "results")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
VERBOSE <- TRUE

for (dsf in DATASETS) {
  DATASET <- dsf
  message("\n########## RS: ", tools::file_path_sans_ext(dsf), " ##########")
  source(file.path(APP, "algorithms", "rs", "run_rs.R"))
}

message("\nDone. Random Search executed on ", length(DATASETS),
         " data sets. Summaries in results/ (resumen_RS_*.csv).")
