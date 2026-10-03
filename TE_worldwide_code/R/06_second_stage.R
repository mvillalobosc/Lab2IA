# =====================================================================
# 06_second_stage.R
# Contextual variables and the IO-CRS score of the main analysis (Table 3, Supplementary Tables S9, S14 and S15).
#   Sample: the 445 country-years of the main analysis with every covariate observed (the other 21 lack public
#   education expenditure); 56 of them are on the frontier (published score 1.00).
#   Dependent variable: published IO-CRS score (2024 extraction). Covariates: September 2026 extraction, rescaled in
#   R/00_setup.R (GDP and GNI per capita in thousand USD, labour force in ten million persons, density in hundred
#   persons per km2).
#   Models: eight predictors (with GNI per capita) and the main model with seven (GNI per capita dropped because of its
#   collinearity with GDP per capita).
#   Estimators: Tobit censored at 0 and 1 with case-resampling bootstrap (5,000 replications; percentile 95% intervals,
#   p values from the normal approximation to the bootstrap standard error); OLS with HC1 errors; Simar-Wilson
#   Algorithms 1 (L = 2000) and 2 (L1 = 100, L2 = 1000) on the Shephard input distance 1 / score (negative
#   coefficients = higher efficiency); main Tobit without Singapore; year-specific Tobit models.
# Outputs: results/second_stage.rds, results/second_stage_coefficients.csv, results/sw2_bias_corrected_scores.csv
# Run time: about 3 minutes on one core.
# =====================================================================
source(file.path("R", "00_setup.R"))

fresh <- add_rescaled(read.csv(file.path(RESULTS, "fresh_annual_scores.csv")))
cc <- fresh[complete.cases(fresh[, c(PRED_FULL, "te_io_crs")]), ]
cc <- cc[order(cc$code, cc$year), ]
stopifnot(nrow(cc) == 445, sum(cc$te_io_crs >= 1) == 56)

S <- list(n = nrow(cc), n_at_1 = sum(cc$te_io_crs >= 1))

# Multicollinearity (Table S9)
S$vif_full <- vif(cc, PRED_FULL)
S$vif_main <- vif(cc, PRED_MAIN)
S$corr <- cor(cc[, c(PRED_FULL, "pop_m")])
message("VIF, eight predictors: ", paste(PRED_FULL, fmt(S$vif_full, 2), sep = " = ", collapse = ", "))

t0 <- Sys.time()
elapsed <- function() sprintf("%.0f s", as.numeric(difftime(Sys.time(), t0, units = "secs")))

# Tobit models (Table 3, Table S14 panel a)
S$tobit_full <- tobit_boot(cc, PRED_FULL, B_TOBIT, SEED)
S$tobit_main <- tobit_boot(cc, PRED_MAIN, B_TOBIT, SEED)
S$tobit_main_noSGP <- tobit_boot(cc[cc$code != "SGP", ], PRED_MAIN, B_TOBIT, SEED)
message("Tobit models done (", elapsed(), "); redraws: ",
        attr(S$tobit_full, "redraws"), ", ", attr(S$tobit_main, "redraws"), ", ", attr(S$tobit_main_noSGP, "redraws"))
print(S$tobit_main, digits = 4)

# OLS with HC1 errors (Table S14 panel b)
S$ols_main <- ols_hc1(cc, PRED_MAIN)

# Simar-Wilson Algorithm 1 (Table S14 panel b)
S$sw1_main <- sw_algorithm1(cc, PRED_MAIN, L_SW1, SEED)
message("Simar-Wilson Algorithm 1 done (", elapsed(), "), n = ", attr(S$sw1_main, "n"))

# Simar-Wilson Algorithm 2 (Table 3, Table S14 panel b)
S$sw2_main <- sw_algorithm2(cc, PRED_MAIN, L1_SW2, L2_SW2, SEED)
bc <- attr(S$sw2_main, "scores")
S$sw2_by_year <- data.frame(year = YEARS, mean_score = tapply(bc$theta, bc$year, mean),
                            mean_bias_corrected_score = tapply(bc$theta_bc, bc$year, mean))
message("Simar-Wilson Algorithm 2 done (", elapsed(), "), observations in the truncated regression: ",
        attr(S$sw2_main, "n"), " of ", nrow(bc))
print(S$sw2_main, digits = 4)

# Year-specific Tobit models (Table S15)
S$tobit_by_year <- lapply(setNames(YEARS, YEARS), function(y) {
  d <- cc[cc$year == y, ]
  tobit_boot(d, PRED_MAIN, B_TOBIT, SEED)
})
message("year-specific Tobit models done (", elapsed(), ")")
for (y in names(S$tobit_by_year)) {
  r <- S$tobit_by_year[[y]]
  r <- r[r$term %in% PRED_MAIN & r$p < 0.05, ]
  message("  ", y, " (n = ", attr(S$tobit_by_year[[y]], "n"), "): significant at 0.05: ",
          paste0(r$term, ifelse(r$coef > 0, " (+)", " (-)"), collapse = ", "))
}

saveRDS(S, file.path(RESULTS, "second_stage.rds"))
tab <- function(x, model) if (!is.null(x)) cbind(model = model, x[, intersect(names(x), c("term", "coef", "se", "p", "ci_lo", "ci_hi"))])
coef_all <- do.call(rbind, list(
  tab(S$tobit_full, "Tobit, eight predictors"), tab(S$tobit_main, "Tobit, main model"),
  tab(S$tobit_main_noSGP, "Tobit, main model without Singapore"),
  tab(S$ols_main, "OLS HC1, main model"),
  cbind(tab(S$sw1_main, "Simar-Wilson Algorithm 1, main model"), se = NA, p = NA)[, c("model", "term", "coef", "se", "p", "ci_lo", "ci_hi")],
  cbind(tab(S$sw2_main, "Simar-Wilson Algorithm 2, main model"), se = NA, p = NA)[, c("model", "term", "coef", "se", "p", "ci_lo", "ci_hi")]))
write.csv(coef_all, file.path(RESULTS, "second_stage_coefficients.csv"), row.names = FALSE)
write.csv(bc, file.path(RESULTS, "sw2_bias_corrected_scores.csv"), row.names = FALSE)
message("saved results/second_stage.rds, results/second_stage_coefficients.csv, results/sw2_bias_corrected_scores.csv")
