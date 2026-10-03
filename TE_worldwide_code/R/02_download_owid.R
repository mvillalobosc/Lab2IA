# =====================================================================
# 02_download_owid.R  (optional: needs internet access to raw.githubusercontent.com, about 100 MB)
# Pandemic variables of the 2020 model (Supplementary Table S17) from the Our World in Data COVID-19 dataset, for the
# 59 countries of the 2020 annual frontier:
#   cases_pm   cumulative confirmed cases per million people on the last reported day of 2020
#   deaths_pm  cumulative confirmed deaths per million people on that day
#   r_mean     mean over the days of 2020 of the daily effective reproduction number (Arroyo-Marioli et al. 2021,
#              as distributed by OWID); r_days = number of days with an estimate (Laos has none)
# Output: data/raw/covid_2020_owid.csv (the shipped file is the extraction used in the paper; this script rebuilds it).
# The 100 MB source file is downloaded to a temporary folder and is not kept in the repository.
# =====================================================================
source(file.path("R", "00_setup.R"))

URL <- "https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/owid-covid-data.csv"
src <- file.path(tempdir(), "owid-covid-data.csv")
if (!file.exists(src)) {
  options(timeout = max(600, getOption("timeout")))
  download.file(URL, src, mode = "wb")
}

cols <- c("iso_code", "date", "total_cases_per_million", "total_deaths_per_million", "reproduction_rate")
owid <- read.csv(src, colClasses = "character")[, cols]
owid <- owid[owid$date >= "2020-01-01" & owid$date <= "2020-12-31" & !startsWith(owid$iso_code, "OWID"), ]
for (v in cols[3:5]) owid[[v]] <- suppressWarnings(as.numeric(owid[[v]]))

scores <- read.csv(SCORES_FILE)
codes <- sort(scores$code[scores$year == 2020])
stopifnot(length(codes) == 59)

# last reported (non-missing) value of a cumulative series within 2020
last_value <- function(x, date) if (any(!is.na(x))) x[!is.na(x)][which.max(as.Date(date[!is.na(x)]))] else NA
out <- do.call(rbind, lapply(codes, function(cc) {
  d <- owid[owid$iso_code == cc, ]
  if (!nrow(d)) return(data.frame(code = cc, cases_pm = NA, deaths_pm = NA, r_mean = NA, r_days = 0L))
  data.frame(code = cc, cases_pm = last_value(d$total_cases_per_million, d$date),
             deaths_pm = last_value(d$total_deaths_per_million, d$date),
             r_mean = if (any(!is.na(d$reproduction_rate))) mean(d$reproduction_rate, na.rm = TRUE) else NA,
             r_days = sum(!is.na(d$reproduction_rate)))
}))
message("countries without OWID rows: ", paste(setdiff(codes, owid$iso_code), collapse = ", "))
message("countries without a reproduction-number estimate: ", paste(out$code[out$r_days == 0], collapse = ", "))
write.csv(out, COVID_FILE, row.names = FALSE, na = "")
message("saved ", COVID_FILE)
