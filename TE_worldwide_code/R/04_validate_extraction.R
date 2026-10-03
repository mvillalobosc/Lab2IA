# =====================================================================
# 04_validate_extraction.R
# Re-estimates the annual IO-CRS and IO-VRS frontiers with the September 2026 extraction, restricted to the 466
# country-years of the main analysis, and compares them with the published scores (2024 extraction).
# The statistics printed here are quoted in Section 2.7 of the paper and in the data appendix (two data extractions).
# Output: results/fresh_annual_scores.csv (466 rows: inputs, outputs, published scores and re-estimated scores)
# =====================================================================
source(file.path("R", "00_setup.R"))

df <- read.csv(DATABASE)
sub <- df[df$in_main_sample, ]
res <- list()
for (y in YEARS) {
  d <- sub[sub$year == y, ]
  d$fresh_crs <- dea_input(d[, INPUTS], d[, OUTPUTS], "crs")
  d$fresh_vrs <- dea_input(d[, INPUTS], d[, OUTPUTS], "vrs")
  res[[as.character(y)]] <- d
  pub_front <- d$code[d$te_io_crs >= 1]
  new_front <- d$code[d$fresh_crs >= 1 - TOL_FRONTIER]
  message(sprintf("%d: n = %d | Spearman = %.3f | Pearson = %.3f | mean absolute difference = %.3f | frontier published = %d, re-estimated = %d, common = %d | VRS Spearman = %.3f",
                  y, nrow(d), spearman(d$te_io_crs, d$fresh_crs), cor(d$te_io_crs, d$fresh_crs),
                  mean(abs(d$te_io_crs - d$fresh_crs)), length(pub_front), length(new_front),
                  length(intersect(pub_front, new_front)), spearman(d$te_io_vrs, d$fresh_vrs)))
}
fresh <- do.call(rbind, res)
rownames(fresh) <- NULL
message(sprintf("pooled: Spearman = %.3f | mean absolute difference = %.3f",
                spearman(fresh$te_io_crs, fresh$fresh_crs), mean(abs(fresh$te_io_crs - fresh$fresh_crs))))
fresh$diff <- fresh$fresh_crs - fresh$te_io_crs
message("largest differences (re-estimated minus published):")
print(head(fresh[order(-abs(fresh$diff)), c("code", "year", "te_io_crs", "fresh_crs", "phys", "beds")], 10), row.names = FALSE)

write.csv(fresh, file.path(RESULTS, "fresh_annual_scores.csv"), row.names = FALSE)
message("saved results/fresh_annual_scores.csv")
