# =============================================================================
# run_all.R
#
# Runs the whole pipeline in order. Every step is a standalone script that can
# also be run on its own; this file only sequences them and stops at the first
# failure so that a broken step is never silently skipped.
#
# Usage
#   Rscript run_all.R                 every step
#   Rscript run_all.R --from 5        from step 5 to the end
#   Rscript run_all.R --only 7        just step 7
#   Rscript run_all.R --from 5 --to 8
#   Rscript run_all.R --list          show the steps and exit
#
# Everything runs in R. There is no second runtime to install and no file handed
# between languages: the hypervolume indicator and the SHAP values are computed in
# R/lib_hypervolume.R and R/lib_shap.R, called by steps 9 and 8 respectively.
#
# Expect the full run to take hours, dominated by step 1 (reading roughly 4 GB of
# text) and step 7 (500 resamples times three models times nine scenarios). Step 7
# accepts a scenario name, so it can be split across several sessions or machines:
#   Rscript R/07_select_features.R D1_ACV_GENERAL
# =============================================================================

source("R/utils.R")

STEPS <- data.frame(
  number = 1:9,
  script = c(
    "R/01_ingest_grd.R",
    "R/02_clean_and_derive.R",
    "R/03_define_outcomes.R",
    "R/04_municipal_indicators.R",
    "R/05_split_and_screen.R",
    "R/06_build_model_matrix.R",
    "R/07_select_features.R",
    "R/08_consensus.R",
    "R/09_tables_and_figures.R"
  ),
  description = c(
    "read the yearly DRG files into parquet",
    "clean, deduplicate and derive variables",
    "case definition and long code table",
    "territorial linkage of municipal indicators",
    "70/30 partition and chi-square screening",
    "build the model matrix",
    "balanced resampling and multimodel selection",
    "consensus index, final Lasso and SHAP values",
    "hypervolume, manuscript tables and all figures"
  ),
  optional = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  stringsAsFactors = FALSE
)


# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NA_integer_) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  as.integer(args[i + 1L])
}

if ("--list" %in% args) {
  cat("Pipeline steps\n\n")
  for (i in seq_len(nrow(STEPS))) {
    cat(sprintf("  %d  %-28s %s%s\n", STEPS$number[i], basename(STEPS$script[i]),
                STEPS$description[i], if (STEPS$optional[i]) "  (optional)" else ""))
  }
  quit(save = "no", status = 0)
}

only <- get_arg("--only")
from <- if (!is.na(only)) only else get_arg("--from", 1L)
to <- if (!is.na(only)) only else get_arg("--to", 9L)

selected <- STEPS[STEPS$number >= from & STEPS$number <= to, ]
if (nrow(selected) == 0L) {
  stop("No step selected. Steps run from 1 to ", nrow(STEPS), ".", call. = FALSE)
}


# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

cfg <- load_config()

cat(strrep("=", 78), "\n")
cat("Project : ", cfg$project$label, "\n", sep = "")
cat("Steps   : ", paste(selected$number, collapse = ", "), "\n", sep = "")
cat("Started : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
cat(strrep("=", 78), "\n\n")

t_start <- Sys.time()
timings <- data.frame()

for (i in seq_len(nrow(selected))) {
  step <- selected[i, ]
  cat("\n", strrep("-", 78), "\n", sep = "")
  cat(sprintf("STEP %d  %s\n", step$number, step$description))
  cat(strrep("-", 78), "\n", sep = "")

  if (!file.exists(step$script)) {
    stop("Missing script: ", step$script, call. = FALSE)
  }

  t0 <- Sys.time()

  # Each step runs in its own environment so that objects from one step cannot
  # leak into the next and hide a missing input.
  ok <- tryCatch({
    sys.source(step$script, envir = new.env(parent = globalenv()))
    TRUE
  }, error = function(e) {
    message("\nStep ", step$number, " failed: ", conditionMessage(e))
    FALSE
  })

  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  timings <- rbind(timings, data.frame(
    step = step$number, script = step$script,
    minutes = round(mins, 2), status = if (ok) "ok" else "failed",
    stringsAsFactors = FALSE
  ))

  if (!ok) {
    if (step$optional) {
      message("Step ", step$number, " is optional; continuing without it.\n")
    } else {
      write_csv_utf8(timings, cfg_path(cfg, "results", "run_all_timings.csv"))
      stop("Pipeline stopped at step ", step$number, ".", call. = FALSE)
    }
  }

  cat(sprintf("\nStep %d finished in %.2f minutes\n", step$number, mins))
}

write_csv_utf8(timings, cfg_path(cfg, "results", "run_all_timings.csv"))

cat("\n", strrep("=", 78), "\n", sep = "")
cat(sprintf("Finished in %.1f minutes\n",
            as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
print(timings)
cat(strrep("=", 78), "\n")
