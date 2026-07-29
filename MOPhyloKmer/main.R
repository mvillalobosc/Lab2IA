# =====================================================================
# main.R  ·  Runs both algorithms on ONE data set and makes the figures
# ---------------------------------------------------------------------
# Set the parameters in config.R (repository root).  Run:  Rscript main.R
# =====================================================================

# --- repository root (works with Rscript and with source() in RStudio) --------
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

# --- central configuration -------------------------------------------
source(file.path(APP, "config.R"))

DATA_DIR    <- file.path(APP, "data")
RESULTS_DIR <- file.path(APP, "results")
FIG_DIR     <- file.path(APP, "figures")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR,     recursive = TRUE, showWarnings = FALSE)
ds <- tools::file_path_sans_ext(DATASET)

# --- run both algorithms -----------------------------------------
message("\n===== NSGA-II =====")
source(file.path(APP, "algorithms", "nsga2", "run_nsga.R"))
message("\n===== MOSA =====")
source(file.path(APP, "algorithms", "mosa", "run_mosa.R"))

# --- figures (same process; robust on Windows) --------
if (isTRUE(MAKE_PLOTS)) {
  message("\nMaking figures...")
  run_plot <- function(archivo, etiqueta) {
    ok <- try(source(file.path(APP, "plots", archivo)), silent = TRUE)
    if (inherits(ok, "try-error"))
      message("  (", etiqueta, ") error: ", conditionMessage(attr(ok, "condition")))
  }
  run_plot("plot_convergence.R", "convergence")
  run_plot("plot_fronts.R",      "fronts")
  run_plot("plot_trees.R",       "medoid trees")
}
