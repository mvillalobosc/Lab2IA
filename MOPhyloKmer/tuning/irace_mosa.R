# =====================================================================
# irace_mosa.R  ·  MOSA parameter tuning with irace (FIXED budget)
# ---------------------------------------------------------------------
# Optimises N_inner, T0 and alpha at a fixed number of evaluations
# (outer cycles = BUDGET / N_inner), maximising the hypervolume.
# (MOSA has no mutation probability: its perturbation is fixed.)
#
# Uso:  Rscript tuning/irace_mosa.R
# Output: tuning/best_mosa.csv and tuning/irace_mosa.Rdata
# =====================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("irace", quietly = TRUE)) install.packages("irace")
  library(irace)
})

.this <- function() {
  # works with Rscript, with source() in RStudio and from any folder
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
TUNE_DIR <- .this(); ROOT <- dirname(TUNE_DIR)   # tuning/ lives in the repository root
source(file.path(ROOT, "config.R"))
HOURS   <- HOURS_MOSA                 # time budget for THIS tuning (from config.R)
HV_BASE <- (2 - 0.1) * (2 - 0.1)   # 3.61: base tree normalised at (0.1,0.1), identical for every data set
HV_MAX  <- 4

TUNE_ONLY <- TRUE; VERBOSE <- FALSE; PARALLEL <- FALSE
SEQ_TYPE <- "DNA"; K <- 5; N_RUNS <- 1
DATA_DIR    <- file.path(ROOT, "data")
RESULTS_DIR <- tempdir()
source(file.path(ROOT, "algorithms", "mosa", "run_mosa.R"))          # defines run_once_mosa

parameters <- readParameters(text = '
N_INNER "" i (50, 500)
T0         "" r (10, 5000)
ALPHA      "" r (0.50, 0.99)
')

target_runner <- function(experiment, scenario) {
  conf <- experiment$configuration
  N_INNER <<- as.integer(conf[["N_INNER"]])
  N_OUTER     <<- max(1L, as.integer(round(BUDGET / N_INNER)))
  T0         <<- as.numeric(conf[["T0"]])
  ALPHA      <<- as.numeric(conf[["ALPHA"]])
  DATASET    <<- experiment$instance
  SEED    <<- as.integer(experiment$seed)
  out <- tryCatch(run_once_mosa(1L),
                  error = function(e) data.frame(hv_best = NA_real_, seconds = NA_real_))
  if (is.na(out$hv_best)) return(list(cost = 1e6))
  list(cost = -(out$hv_best - HV_BASE) / (HV_MAX - HV_BASE), time = out$seconds)
}

scenario <- list(
  targetRunner   = target_runner,
  parameters     = parameters,
  instances      = INSTANCES,
  maxTime        = as.integer(HOURS * 3600),   # budget in seconds
  parallel       = N_PAR,
  logFile        = file.path(TUNE_DIR, "irace_mosa.Rdata"),
  seed           = 1
)

cat("== irace MOSA | budget", BUDGET, "evals | ", HOURS, "hours ==\n")
res <- irace(scenario = scenario)

best <- removeConfigurationsMetaData(res[1, ])
best$N_OUTER <- max(1L, as.integer(round(BUDGET / as.integer(best$N_INNER))))
write.csv(best, file.path(TUNE_DIR, "best_mosa.csv"), row.names = FALSE)
cat("\n>>> Best MOSA configuration (saved in tuning/best_mosa.csv):\n")
print(best)
