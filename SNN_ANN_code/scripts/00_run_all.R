# =====================================================================
# 00_run_all.R
# Runs the whole pipeline in order from the repository root. Steps that
# need the raw database exports (and the abstracts they contain) are
# skipped automatically when data/raw/Scopus.csv is absent; everything
# downstream of the screening and charting decisions runs from the
# public files in data/.
#
# Usage: Rscript scripts/00_run_all.R
# =====================================================================
run <- function(script, ...) {
  args <- c(...)
  cat("\n==>", script, paste(args, collapse = " "), "\n")
  status <- system2("Rscript", c(file.path("scripts", script), args))
  if (status != 0) stop("step failed: ", script)
}
have_raw <- file.exists("data/raw/Scopus.csv")
if (have_raw) {
  run("01_deduplicate.R")
  run("02_screening_batches.R", "100", "200", "20261014")
  run("05_full_abstract_batches.R", "data/screening/kappa_sample/kappa_ids.csv", "data/processed/kappa", "86")
  run("05_full_abstract_batches.R", "data/screening/rescreen/rescreen_a_ids.csv", "data/processed/rescreen_a", "80")
  run("06_rescreen_set.R")
} else {
  cat("data/raw/Scopus.csv not found: batch generation skipped, using the distributed decision files\n")
}
run("04_check_screening_batches.R")
run("03_screening_agreement.R",
    "data/screening/pilot/pilot_1_reviewer1.tsv", "data/screening/pilot/pilot_2_reviewer1.tsv", "--",
    "data/screening/pilot/pilot_1_reviewer2.tsv", "data/screening/pilot/pilot_2_reviewer2.tsv")
run("07_consolidate_screening.R")
if (have_raw) run("08_charting_batches.R", "20261015")
run("09_check_charting.R")
run("10_build_map.R")
run("11_fulltext_candidates.R", "5")
run("12_figures.R", "figures")
cat("\nPipeline finished\n")
