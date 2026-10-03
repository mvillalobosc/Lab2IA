# =====================================================================
# run_all.R
# Runs the full pipeline of "How much does the reference set matter? Benchmarking national health-system efficiency on
# a global frontier, 2015-2020" from the data shipped in data/. Total run time: about 4 minutes on one core.
#
#   Rscript run_all.R          (from any folder; the script moves to its own folder)
#   or, in R/RStudio:          setwd("<folder of this file>"); source("run_all.R")
#
# Steps (results go to results/, LaTeX table fragments to results/tables/):
#   01_download_worldbank.R            optional: re-downloads the World Bank indicators (needs internet; package WDI)
#   02_download_owid.R                 optional: rebuilds the OWID pandemic variables (needs internet, about 100 MB)
#   03_build_dataset.R                 the database data/dataset_country_year.csv (720 rows, 466 in the main analysis)
#   04_validate_extraction.R           annual frontiers re-estimated with the 2026 extraction vs the published scores
#   05_reference_sets_and_robustness.R pooled and fixed-sample frontiers, scale efficiency, expenditure per capita,
#                                      income-group frontiers (Tables 1-2, S6-S8, S10-S13)
#   06_second_stage.R                  Tobit, OLS and Simar-Wilson models (Table 3, S9, S14, S15)
#   07_covid_model.R                   2020 pandemic model (Table S17)
#   08_tables.R                        LaTeX fragments of every table
#   09_figure_S1_workflow.R            Supplementary Figure S1
# Required packages: lpSolve, AER, sandwich (install.packages(c("lpSolve", "AER", "sandwich"))); WDI only for step 01.
# =====================================================================
local({
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(f) == 1) setwd(dirname(normalizePath(f)))
})

DOWNLOAD <- FALSE   # TRUE re-downloads the inputs (steps 01 and 02) before running the analysis

steps <- c(if (DOWNLOAD) c("01_download_worldbank.R", "02_download_owid.R"),
           "03_build_dataset.R", "04_validate_extraction.R", "05_reference_sets_and_robustness.R",
           "06_second_stage.R", "07_covid_model.R", "08_tables.R", "09_figure_S1_workflow.R")
for (s in steps) {
  message("\n==================== ", s, " ====================")
  t0 <- Sys.time()
  source(file.path("R", s), local = new.env(), echo = FALSE)
  message(sprintf("%s finished in %.0f s", s, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
message("\npipeline finished; see results/ and results/tables/")
