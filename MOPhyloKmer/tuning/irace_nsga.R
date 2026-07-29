# =====================================================================
# irace_nsga.R  ·  NSGA-II parameter tuning with irace (FIXED budget)
# ---------------------------------------------------------------------
# Optimises population size, P_cross and P_mut at a fixed number of evaluations
# (generations = BUDGET / population size), maximising the hypervolume.
# This way irace improves QUALITY and cannot win by spending more evaluations;
# the resulting configuration already matches the comparison budget.
#
# Uso:  Rscript tuning/irace_nsga.R
# Resultado: tuning/best_nsga.csv  +  tune/irace_nsga.Rdata
# =====================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("irace", quietly = TRUE)) install.packages("irace")
  library(irace)
})

# repository root (this script lives in tuning/)
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
HOURS   <- HOURS_NSGA                 # time budget for THIS tuning (from config.R)
HV_BASE <- (2 - 0.1) * (2 - 0.1)   # 3.61: base tree normalised at (0.1,0.1), identical for every data set
HV_MAX  <- 4

# --- globals needed by run_once (without executing the batch) -----------
TUNE_ONLY <- TRUE; VERBOSE <- FALSE; PARALLEL <- FALSE
SEQ_TYPE <- "DNA"; K <- 5; N_RUNS <- 1
DATA_DIR    <- file.path(ROOT, "data")
RESULTS_DIR <- tempdir()               # writes go to a temporary folder
source(file.path(ROOT, "algorithms", "nsga2", "run_nsga.R"))   # defines run_once_nsga

# --- parameters to tune ---------------------------------------------
parameters <- readParameters(text = '
POP_SIZE "" i (20, 120)
P_CROSS   "" r (0.00, 1.00)
P_MUT    "" r (0.00, 1.00)
')

# --- objective function: one run, returns -HV (irace minimises) ---
target_runner <- function(experiment, scenario) {
  conf <- experiment$configuration
  POP_SIZE    <<- as.integer(conf[["POP_SIZE"]])
  N_GEN <<- max(1L, as.integer(round(BUDGET / POP_SIZE)))
  P_CROSS      <<- as.numeric(conf[["P_CROSS"]])
  P_MUT       <<- as.numeric(conf[["P_MUT"]])
  DATASET      <<- experiment$instance
  SEED      <<- as.integer(experiment$seed)
  out <- tryCatch(run_once_nsga(1L),
                  error = function(e) data.frame(hv_max = NA_real_, seconds = NA_real_))
  if (is.na(out$hv_max)) return(list(cost = 1e6))
  list(cost = -(out$hv_max - HV_BASE) / (HV_MAX - HV_BASE), time = out$seconds)
}

scenario <- list(
  targetRunner   = target_runner,
  parameters     = parameters,
  instances      = INSTANCES,
  maxTime        = as.integer(HOURS * 3600),   # budget in seconds
  parallel       = N_PAR,
  logFile        = file.path(TUNE_DIR, "irace_nsga.Rdata"),
  seed           = 1
)

cat("== irace NSGA-II | budget", BUDGET, "evals | ", HOURS, "hours ==\n")
res <- irace(scenario = scenario)

best <- removeConfigurationsMetaData(res[1, ])
best$N_GEN <- max(1L, as.integer(round(BUDGET / as.integer(best$POP_SIZE))))
write.csv(best, file.path(TUNE_DIR, "best_nsga.csv"), row.names = FALSE)
cat("\n>>> Best NSGA-II configuration (saved in tuning/best_nsga.csv):\n")
print(best)
