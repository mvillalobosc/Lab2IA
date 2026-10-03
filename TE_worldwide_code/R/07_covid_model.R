# =====================================================================
# 07_covid_model.R
# Tobit model of the 2020 IO-CRS score (published, 59 countries) on pandemic-related variables (Supplementary Table S17).
# Predictors (database columns cases_pm, deaths_pm, r_mean; source file data/raw/covid_2020_owid.csv):
#   cases_k   cumulative confirmed cases per thousand people at 31 December 2020
#   deaths_h  cumulative confirmed deaths per 100,000 people at 31 December 2020
#   r_mean    mean over 2020 of the daily effective reproduction number (no estimate for Laos)
# Tobit censored at 0 and 1, case-resampling bootstrap (B_TOBIT replicates, seed SEED_COVID), percentile intervals.
# Models: three predictors (58 countries), without the reproduction number (59), cases only, deaths only.
# Output: results/covid_model.rds, results/covid_2020_model_data.csv
# =====================================================================
source(file.path("R", "00_setup.R"))

db <- read.csv(DATABASE)
d <- db[db$in_main_sample & db$year == 2020,
        c("code", "country", "income", "te_io_crs", "cases_pm", "deaths_pm", "r_mean", "r_days")]
d <- d[order(d$code), ]
stopifnot(nrow(d) == 59)
d$cases_k <- d$cases_pm / 1000    # cases per thousand people
d$deaths_h <- d$deaths_pm / 10    # deaths per 100,000 people

C <- list(
  corr_cases_deaths = cor(d$cases_k, d$deaths_h),
  corr_cases_r = cor(d$cases_k, d$r_mean, use = "complete.obs"),
  corr_deaths_r = cor(d$deaths_h, d$r_mean, use = "complete.obs"),
  desc = sapply(d[, c("cases_k", "deaths_h", "r_mean")], function(x)
    c(mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE), min = min(x, na.rm = TRUE), max = max(x, na.rm = TRUE),
      n = sum(!is.na(x)))))
full <- d[complete.cases(d[, c("cases_k", "deaths_h", "r_mean")]), ]
C$full <- tobit_boot(full, c("cases_k", "deaths_h", "r_mean"), B_TOBIT, SEED_COVID)
C$no_r <- tobit_boot(d, c("cases_k", "deaths_h"), B_TOBIT, SEED_COVID)
C$cases_only <- tobit_boot(d, "cases_k", B_TOBIT, SEED_COVID)
C$deaths_only <- tobit_boot(d, "deaths_h", B_TOBIT, SEED_COVID)

for (m in c("full", "no_r", "cases_only", "deaths_only")) {
  message("== ", m, " (n = ", attr(C[[m]], "n"), ", on the frontier ", attr(C[[m]], "n_censored_at_1"), ")")
  print(C[[m]], digits = 4, row.names = FALSE)
}
saveRDS(C, file.path(RESULTS, "covid_model.rds"))
write.csv(d, file.path(RESULTS, "covid_2020_model_data.csv"), row.names = FALSE)
message("saved results/covid_model.rds and results/covid_2020_model_data.csv")
