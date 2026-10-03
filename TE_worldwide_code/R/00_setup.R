# =====================================================================
# 00_setup.R
# Shared settings for the TE_worldwide pipeline: packages, paths, constants and the variable dictionary.
# Every script sources this file first. Run the scripts from the repository root (the folder that holds run_all.R).
#
# Paper: "How much does the reference set matter? Benchmarking national health-system efficiency on a global frontier,
# 2015-2020" (Valenzuela-Silva et al.). The pipeline reproduces the re-estimations, robustness analyses and second-stage
# models of the paper.
#
# Data
#   data/dataset_country_year.csv     THE DATABASE: 720 country-years (120 countries x 2015-2020) with every variable of
#                                     the analysis (World Bank indicators, pandemic variables, published scores, income
#                                     group and financing model). Built by 03_build_dataset.R from the source files below;
#                                     the variable dictionary is at the top of that script.
#   data/raw/worldbank_2026-09-27.csv World Bank extraction of 27 September 2026 (15 indicators; codes in
#                                     01_download_worldbank.R)
#   data/raw/published_scores_2024.csv IO-CRS, OO-CRS, IO-VRS and OO-VRS scores of the 466 country-years of the main
#                                     analysis (source thesis, Valenzuela-Silva 2024, appendices H-K; IO-CRS = Table S6),
#                                     with the World Bank income group and the financing model of each country
#   data/raw/covid_2020_owid.csv      pandemic variables of the 59 countries of the 2020 frontier (Our World in Data)
# Outputs go to results/ (CSV and RDS files) and results/tables/ (LaTeX fragments of the paper tables).
#
# R packages: lpSolve (DEA linear programmes), AER (Tobit, a wrapper of survival::survreg), sandwich (HC1 errors).
# Optional, only to re-download the inputs: WDI (World Bank API).
# =====================================================================

for (pkg in c("lpSolve", "AER", "sandwich")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Install the package first: install.packages(\"", pkg, "\")")
}
suppressPackageStartupMessages({
  library(lpSolve)
  library(AER)
  library(sandwich)
})

# ---------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------
DATA <- "data"
RAW <- file.path(DATA, "raw")
RESULTS <- "results"
TABLES <- file.path(RESULTS, "tables")
if (!dir.exists(RAW)) stop("Run the scripts from the repository root (the folder that contains run_all.R and data/).")
dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)

DATABASE <- file.path(DATA, "dataset_country_year.csv")
WB_FILE <- file.path(RAW, "worldbank_2026-09-27.csv")
SCORES_FILE <- file.path(RAW, "published_scores_2024.csv")
COVID_FILE <- file.path(RAW, "covid_2020_owid.csv")

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------
YEARS <- 2015:2020
INPUTS <- c("che_gdp", "phys", "beds")   # health expenditure (% of GDP), physicians per 1,000, hospital beds per 1,000
OUTPUTS <- c("le", "inf_surv")           # life expectancy at birth, infant survival = 1 / infant mortality rate
SEED <- 20260927                         # seed of every bootstrap of the second stage (06_second_stage.R)
SEED_COVID <- 2020                       # seed of the bootstrap of the 2020 pandemic model (07_covid_model.R)
TOL_FRONTIER <- 1e-6                     # a re-estimated score >= 1 - TOL_FRONTIER counts as a frontier score
# The published scores have two decimals, so a published 1.00 marks a frontier country-year.

# Bootstrap sizes
B_TOBIT <- 5000       # every Tobit model (pooled, year-specific, 2020 pandemic model); with 5,000 replicates the
                      # percentile limits and p values no longer depend on the seed at the reported precision
L_SW1 <- 2000         # Simar-Wilson Algorithm 1
L1_SW2 <- 100         # Simar-Wilson Algorithm 2, bias correction
L2_SW2 <- 1000        # Simar-Wilson Algorithm 2, confidence intervals

# Income groups of the metafrontier (low- and lower-middle-income countries form one group: the low-income group has
# only three to seven countries per year)
META_GROUP <- c("Low" = "L+LM", "Lower-mid" = "L+LM", "Upper-mid" = "UM", "High" = "H")

# Second-stage predictors after rescaling (see add_rescaled below)
PRED_FULL <- c("cbr", "cdr", "gni_k", "lf_10m", "edu", "gdp_k", "dens_h", "rur")
PRED_MAIN <- c("cbr", "cdr", "lf_10m", "edu", "gdp_k", "dens_h", "rur")   # main model: GNI per capita dropped (VIF about 50)
LABELS <- c(
  cbr = "Crude birth rate (per 1,000 population)",
  cdr = "Crude death rate (per 1,000 population)",
  gni_k = "GNI per capita (thousand USD)",
  lf_10m = "Labour force (ten million persons)",
  edu = "Public education expenditure (\\% of GDP)",
  gdp_k = "GDP per capita (thousand USD)",
  dens_h = "Population density (hundred persons per km\\textsuperscript{2})",
  rur = "Rural population (\\% of total)",
  `(Intercept)` = "Intercept"
)

# Rescaled predictors used in every second-stage model: units chosen so that coefficients have readable magnitudes
add_rescaled <- function(d) {
  d$gni_k <- d$gni_pc / 1000     # thousand USD
  d$gdp_k <- d$gdp_pc / 1000     # thousand USD
  d$lf_10m <- d$lf / 1e7         # ten million persons
  d$dens_h <- d$dens / 100       # hundred persons per km2
  d$pop_m <- d$pop / 1e6         # million persons (memorandum variable of Table S9)
  d
}

source(file.path("R", "functions.R"))
