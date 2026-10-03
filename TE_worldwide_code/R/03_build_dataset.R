# =====================================================================
# 03_build_dataset.R
# Builds THE DATABASE of the analysis, data/dataset_country_year.csv: 720 rows (120 countries x 2015-2020), one column
# per variable, from the source files in data/raw/. Every later script reads this file.
#
# Variable dictionary
#   code               ISO 3166-1 alpha-3 country code
#   country            country name
#   year               calendar year, 2015-2020
#   income             World Bank income group recorded in the source dataset: Low, Lower-mid, Upper-mid, High
#   financing          dominant financing model of the health system: Public, Mixed, Private (Commonwealth Fund profiles)
#   in_main_sample     TRUE for the 466 country-years of the annual DEA frontiers of the main analysis
#   -- DEA inputs and outputs (World Bank extraction of 27 September 2026)
#   che_gdp            current health expenditure, % of GDP                           SH.XPD.CHEX.GD.ZS   input
#   phys               physicians per 1,000 people                                    SH.MED.PHYS.ZS      input
#   phys_interpolated  TRUE for Albania 2018: the value is no longer published and is interpolated linearly between 2016
#                      and 2019 (the only imputed cell of the database)
#   beds               hospital beds per 1,000 people                                 SH.MED.BEDS.ZS      input
#   le                 life expectancy at birth, years                                SP.DYN.LE00.IN      output
#   imr                infant mortality rate per 1,000 live births                    SP.DYN.IMRT.IN
#   inf_surv           infant survival = 1 / imr                                                          output
#   che_pc_ppp         current health expenditure per capita, PPP international $     SH.XPD.CHEX.PP.CD   sensitivity
#   -- second-stage covariates (World Bank extraction of 27 September 2026)
#   cbr                crude birth rate per 1,000 people                              SP.DYN.CBRT.IN
#   cdr                crude death rate per 1,000 people                              SP.DYN.CDRT.IN
#   gni_pc             GNI per capita, Atlas method, current USD                      NY.GNP.PCAP.CD
#   lf                 labour force, total persons                                    SL.TLF.TOTL.IN
#   edu                government expenditure on education, % of GDP                  SE.XPD.TOTL.GD.ZS
#   gdp_pc             GDP per capita, current USD                                    NY.GDP.PCAP.CD
#   dens               people per km2 of land area                                    EN.POP.DNST
#   rur                rural population, % of total                                   SP.RUR.TOTL.ZS
#   pop                total population                                               SP.POP.TOTL
#   -- pandemic variables (Our World in Data; filled only for the 59 countries of the 2020 frontier, year 2020)
#   cases_pm           cumulative confirmed COVID-19 cases per million people at 31 December 2020
#   deaths_pm          cumulative confirmed COVID-19 deaths per million people at 31 December 2020
#   r_mean             mean daily effective reproduction number over 2020 (none for Laos)
#   r_days             days of 2020 with a reproduction-number estimate
#   -- published efficiency scores of the main analysis (source thesis, 2024 extraction, two decimals)
#   te_io_crs          input-oriented, constant returns to scale (primary model; Supplementary Table S6)
#   te_oo_crs          output-oriented, constant returns to scale
#   te_io_vrs          input-oriented, variable returns to scale
#   te_oo_vrs          output-oriented, variable returns to scale
# Missing values are empty cells. No value other than Albania 2018 physicians is imputed or carried across years.
# =====================================================================
source(file.path("R", "00_setup.R"))

wb <- read.csv(WB_FILE)
scores <- read.csv(SCORES_FILE)
covid <- read.csv(COVID_FILE)
stopifnot(nrow(wb) == 720, length(unique(wb$code)) == 120, nrow(scores) == 466, length(unique(scores$code)) == 120,
          nrow(covid) == 59)

# Country attributes (constant within country), published scores and pandemic variables (2020 only)
meta <- unique(scores[, c("code", "country", "income", "financing")])
stopifnot(nrow(meta) == 120)
df <- merge(wb, meta, by = "code", all.x = TRUE)
df <- merge(df, scores[, c("code", "year", "te_io_crs", "te_oo_crs", "te_io_vrs", "te_oo_vrs")],
            by = c("code", "year"), all.x = TRUE)
covid$year <- 2020
df <- merge(df, covid, by = c("code", "year"), all.x = TRUE)
df <- df[order(df$code, df$year), ]
df$in_main_sample <- !is.na(df$te_io_crs)

# Albania 2018, physicians: linear interpolation between 2016 and 2019
df$phys_interpolated <- FALSE
alb <- function(y) which(df$code == "ALB" & df$year == y)
if (is.na(df$phys[alb(2018)])) {
  p16 <- df$phys[alb(2016)]; p19 <- df$phys[alb(2019)]
  df$phys[alb(2018)] <- p16 + (p19 - p16) * 2 / 3
  df$phys_interpolated[alb(2018)] <- TRUE
  message(sprintf("ALB 2018 physicians interpolated: %.3f (2016) -> %.3f -> %.3f (2019)", p16, df$phys[alb(2018)], p19))
}
df$inf_surv <- 1 / df$imr

cols <- c("code", "country", "year", "income", "financing", "in_main_sample",
          "che_gdp", "phys", "phys_interpolated", "beds", "le", "imr", "inf_surv", "che_pc_ppp",
          "cbr", "cdr", "gni_pc", "lf", "edu", "gdp_pc", "dens", "rur", "pop",
          "cases_pm", "deaths_pm", "r_mean", "r_days",
          "te_io_crs", "te_oo_crs", "te_io_vrs", "te_oo_vrs")
stopifnot(setequal(cols, names(df)))
df <- df[, cols]
rownames(df) <- NULL

# Checks quoted in the paper (data appendix)
sub <- df[df$in_main_sample, ]
dea_vars <- c(INPUTS, "le", "imr")
cov <- c("cbr", "cdr", "gni_pc", "lf", "edu", "gdp_pc", "dens", "rur")
message("country-years with a published score: ", nrow(sub), " (", length(unique(sub$code)), " countries); per year: ",
        paste(names(table(sub$year)), table(sub$year), sep = " = ", collapse = ", "))
message("missing DEA variables inside the main sample: ", sum(is.na(sub[, dea_vars])))
message("country-years with every second-stage covariate: ", sum(complete.cases(sub[, cov])), " of ", nrow(sub),
        " | missing by variable: ", paste(cov, colSums(is.na(sub[, cov])), sep = " = ", collapse = ", "))
message("2020 countries with pandemic variables: ", sum(!is.na(df$cases_pm)), " (", sum(!is.na(df$r_mean)), " with R)")
stopifnot(!anyNA(sub[, dea_vars]), sum(complete.cases(sub[, cov])) == 445, sum(!is.na(df$cases_pm)) == 59)

write.csv(df, DATABASE, row.names = FALSE, na = "")
message("saved ", DATABASE, ": ", nrow(df), " rows x ", ncol(df), " columns")
