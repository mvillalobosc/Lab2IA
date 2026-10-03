# =====================================================================
# 01_download_worldbank.R  (optional: needs internet access to api.worldbank.org)
# Downloads the 15 World Bank indicators used by the pipeline for the 120 countries of the main analysis, 2015-2020,
# and writes them in the format of the shipped snapshot: one row per country-year, one column per indicator.
#
# The paper uses the snapshot data/raw/worldbank_2026-09-27.csv. The World Bank revises its series (WHO physician and bed
# data in particular), so a new download can differ from the snapshot. The script therefore writes a new dated file and
# never overwrites the snapshot; to run the pipeline on the new file, point WB_FILE in R/00_setup.R to it and run
# run_all.R again (03_build_dataset.R rebuilds the database from it).
#
# Variables and indicator codes (Supplementary Table S3 of the paper):
#   che_gdp     SH.XPD.CHEX.GD.ZS  current health expenditure, % of GDP                        DEA input
#   phys        SH.MED.PHYS.ZS     physicians per 1,000 people                                 DEA input
#   beds        SH.MED.BEDS.ZS     hospital beds per 1,000 people                              DEA input
#   le          SP.DYN.LE00.IN     life expectancy at birth, years                             DEA output
#   imr         SP.DYN.IMRT.IN     infant mortality per 1,000 live births (output = 1 / imr)   DEA output
#   che_pc_ppp  SH.XPD.CHEX.PP.CD  current health expenditure per capita, PPP dollars          sensitivity analysis
#   cbr         SP.DYN.CBRT.IN     crude birth rate per 1,000 people                           second stage
#   cdr         SP.DYN.CDRT.IN     crude death rate per 1,000 people                           second stage
#   gni_pc      NY.GNP.PCAP.CD     GNI per capita, Atlas method, current USD                   second stage
#   lf          SL.TLF.TOTL.IN     labour force, total                                         second stage
#   edu         SE.XPD.TOTL.GD.ZS  government expenditure on education, % of GDP               second stage
#   gdp_pc      NY.GDP.PCAP.CD     GDP per capita, current USD                                 second stage
#   dens        EN.POP.DNST        people per km2 of land area                                 second stage
#   rur         SP.RUR.TOTL.ZS     rural population, % of total                                second stage
#   pop         SP.POP.TOTL        total population                                            Table S9 (memorandum)
# =====================================================================
source(file.path("R", "00_setup.R"))
if (!requireNamespace("WDI", quietly = TRUE)) stop("Install the package first: install.packages(\"WDI\")")

INDICATORS <- c(che_gdp = "SH.XPD.CHEX.GD.ZS", che_pc_ppp = "SH.XPD.CHEX.PP.CD", phys = "SH.MED.PHYS.ZS",
                beds = "SH.MED.BEDS.ZS", le = "SP.DYN.LE00.IN", imr = "SP.DYN.IMRT.IN", cbr = "SP.DYN.CBRT.IN",
                cdr = "SP.DYN.CDRT.IN", gni_pc = "NY.GNP.PCAP.CD", lf = "SL.TLF.TOTL.IN", edu = "SE.XPD.TOTL.GD.ZS",
                gdp_pc = "NY.GDP.PCAP.CD", dens = "EN.POP.DNST", rur = "SP.RUR.TOTL.ZS", pop = "SP.POP.TOTL")

codes <- sort(unique(read.csv(SCORES_FILE)$code))
stopifnot(length(codes) == 120)

# Every economy, then keep the 120 countries (one call per indicator is made by WDI)
wdi <- WDI::WDI(country = "all", indicator = INDICATORS, start = min(YEARS), end = max(YEARS), extra = FALSE)
wdi <- wdi[wdi$iso3c %in% codes & wdi$year %in% YEARS, c("iso3c", "year", names(INDICATORS))]
names(wdi)[1] <- "code"

# Complete 120 x 6 grid in the order of the snapshot (missing values stay NA)
grid <- expand.grid(year = YEARS, code = codes, stringsAsFactors = FALSE)[, c("code", "year")]
out <- merge(grid, wdi, by = c("code", "year"), all.x = TRUE, sort = FALSE)
out <- out[order(out$code, out$year), c("code", "year", names(INDICATORS))]
stopifnot(nrow(out) == 720, !anyDuplicated(out[, c("code", "year")]))
missing_countries <- setdiff(codes, wdi$code)
if (length(missing_countries)) warning("No data returned for: ", paste(missing_countries, collapse = ", "))

target <- file.path(RAW, paste0("worldbank_", format(Sys.Date(), "%Y-%m-%d"), ".csv"))
if (normalizePath(target, mustWork = FALSE) == normalizePath(WB_FILE, mustWork = FALSE)) {
  stop("The target file is the snapshot used by the paper; rename it before downloading again.")
}
write.csv(out, target, row.names = FALSE, na = "")
message("saved ", target, " (", sum(!is.na(out[, names(INDICATORS)])), " non-missing values)")

# Differences with the snapshot of the paper, by indicator
snap <- read.csv(WB_FILE)
snap <- snap[order(snap$code, snap$year), ]
for (v in names(INDICATORS)) {
  a <- snap[[v]]; b <- out[[v]]
  both <- !is.na(a) & !is.na(b)
  rel <- abs(a[both] - b[both]) / pmax(abs(a[both]), 1e-12)
  message(sprintf("  %-10s cells in both: %3d | only in snapshot: %2d | only in new file: %2d | max relative difference: %.4f",
                  v, sum(both), sum(!is.na(a) & is.na(b)), sum(is.na(a) & !is.na(b)), if (any(both)) max(rel) else NA))
}
