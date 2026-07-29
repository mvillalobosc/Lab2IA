# =====================================================================
# run_tuning.R  ·  Runs the irace tuning for BOTH algorithms, one after the other
# ---------------------------------------------------------------------
# Single command:   Rscript tuning/run_tuning.R
# Produces: tuning/best_nsga.csv and tuning/best_mosa.csv
# Total time ~ HOURS_NSGA + HOURS_MOSA = 3 + 3 = 6 h (editable in config.R).
# To change the budget, cores or testbed, edit
# config.R (this script only runs both tunings in order).
# =====================================================================
.this <- function() {
  # works with Rscript, with source() in RStudio and from any folder
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
TUNE_DIR <- .this()

message("\n################ NSGA-II TUNING ################")
source(file.path(TUNE_DIR, "irace_nsga.R"))

message("\n################ MOSA TUNING ################")
source(file.path(TUNE_DIR, "irace_mosa.R"))

message("\nDone. Best configurations in:\n  ",
        file.path(TUNE_DIR, "best_nsga.csv"), "\n  ",
        file.path(TUNE_DIR, "best_sa.csv"))
