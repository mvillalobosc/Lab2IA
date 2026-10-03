# =====================================================================
# 05_reference_sets_and_robustness.R
# Reference-set comparisons and robustness analyses of the frontier (Tables 1 and 2, Supplementary Tables S6-S8 and
# S10-S13 of the paper).
#   (0) annual frontiers of the main analysis (published scores): composition, 2019-2020 transition, fixed set of 39
#   (a) scale efficiency = IO-CRS / IO-VRS, published scores of the main analysis
#   (b) pooled intertemporal frontier: all 466 country-years in one reference set (September 2026 extraction)
#   (c) fixed-sample annual frontiers: the 39 countries with a score in every year (September 2026 extraction)
#   (d) health expenditure per capita (PPP dollars) instead of its share of GDP (September 2026 extraction)
#   (e) income-group frontiers and technology gap ratios, TGR = global score / group score (September 2026 extraction)
# Outputs: results/robustness.rds (list with every statistic), results/robustness_scores.csv (country-year scores)
# =====================================================================
source(file.path("R", "00_setup.R"))

df <- read.csv(file.path(RESULTS, "fresh_annual_scores.csv"))
df <- df[order(df$code, df$year), ]
R <- list()

# ---------------------------------------------------------------------
# (0) Annual frontiers of the main analysis (published scores, 2024 extraction)
# ---------------------------------------------------------------------
short <- c("Low" = "L", "Lower-mid" = "LM", "Upper-mid" = "UM", "High" = "H")
R$annual <- do.call(rbind, lapply(YEARS, function(y) {
  d <- df[df$year == y, ]
  fr <- d[d$te_io_crs >= 1, ]
  data.frame(year = y, n = nrow(d), mean = mean(d$te_io_crs), median = median(d$te_io_crs), sd = sd(d$te_io_crs),
             frontier = nrow(fr), L = sum(fr$income == "Low"), LM = sum(fr$income == "Lower-mid"),
             UM = sum(fr$income == "Upper-mid"), H = sum(fr$income == "High"),
             frontier_codes = paste(sort(fr$code), collapse = ", "))
}))
R$annual_by_income <- aggregate(te_io_crs ~ year + income, data = df, FUN = function(x) c(mean = mean(x), n = length(x)))

wide <- reshape(df[, c("code", "year", "te_io_crs")], idvar = "code", timevar = "year", direction = "wide")
names(wide) <- sub("te_io_crs.", "", names(wide), fixed = TRUE)
yr <- as.character(YEARS)
fixed39 <- sort(wide$code[complete.cases(wide[, yr])])
R$fixed_set <- fixed39
w39 <- wide[wide$code %in% fixed39, ]
R$fixed_set_published <- data.frame(year = YEARS, mean = colMeans(w39[, yr]), median = apply(w39[, yr], 2, median))
R$rank_corr_published_39 <- setNames(sapply(1:5, function(i) spearman(w39[[yr[i]]], w39[[yr[i + 1]]])),
                                     paste(yr[1:5], yr[2:6], sep = "-"))

p19 <- wide[!is.na(wide[["2019"]]), ]
lost <- p19[is.na(p19[["2020"]]), ]
kept <- p19[!is.na(p19[["2020"]]), ]
new20 <- wide[!is.na(wide[["2020"]]) & is.na(wide[["2019"]]), ]
front1519 <- sort(unique(df$code[df$year <= 2019 & df$te_io_crs >= 1]))
front19 <- sort(df$code[df$year == 2019 & df$te_io_crs >= 1])
inc <- setNames(df$income, df$code)
R$transition <- list(
  n2019 = nrow(p19), mean2019 = mean(p19[["2019"]]),
  lost_n = nrow(lost), lost_mean2019 = mean(lost[["2019"]]), lost_income = table(factor(inc[lost$code], names(short))),
  kept_n = nrow(kept), kept_mean2019 = mean(kept[["2019"]]), kept_mean2020 = mean(kept[["2020"]]),
  new_n = nrow(new20), new_mean2020 = mean(new20[["2020"]]), new_codes = sort(new20$code),
  front1519_n = length(front1519), front1519_absent2020 = setdiff(front1519, wide$code[!is.na(wide[["2020"]])]),
  front19_n = length(front19), front19_absent2020 = setdiff(front19, wide$code[!is.na(wide[["2020"]])]))
kept48 <- sort(kept$code)

# ---------------------------------------------------------------------
# (a) Scale efficiency, published IO-CRS / IO-VRS scores
# ---------------------------------------------------------------------
df$scale_eff <- df$te_io_crs / df$te_io_vrs
R$scale_by_year <- do.call(rbind, lapply(YEARS, function(y) {
  d <- df[df$year == y, ]
  data.frame(year = y, n = nrow(d), mean_crs = mean(d$te_io_crs), median_crs = median(d$te_io_crs),
             mean_vrs = mean(d$te_io_vrs), median_vrs = median(d$te_io_vrs), mean_se = mean(d$scale_eff),
             median_se = median(d$scale_eff), frontier_crs = sum(d$te_io_crs >= 1), frontier_vrs = sum(d$te_io_vrs >= 1),
             spearman_crs_vrs = spearman(d$te_io_crs, d$te_io_vrs),
             frontier_vrs_codes = paste(sort(d$code[d$te_io_vrs >= 1]), collapse = ", "))
}))
R$scale_by_income <- do.call(rbind, lapply(names(short), function(g) {
  d <- df[df$income == g, ]
  data.frame(income = g, n = nrow(d), mean_crs = mean(d$te_io_crs), mean_vrs = mean(d$te_io_vrs),
             mean_se = mean(d$scale_eff), share_below_0.8 = mean(d$scale_eff < 0.8))
}))
se_country <- sort(tapply(df$scale_eff, df$code, mean))
R$scale_lowest_countries <- head(se_country, 12)

# ---------------------------------------------------------------------
# (b) Pooled intertemporal frontier
# ---------------------------------------------------------------------
df$pooled_crs <- dea_input(df[, INPUTS], df[, OUTPUTS], "crs")
R$pooled_by_year <- do.call(rbind, lapply(YEARS, function(y) {
  d <- df[df$year == y, ]
  data.frame(year = y, n = nrow(d), mean = mean(d$pooled_crs), median = median(d$pooled_crs),
             frontier = sum(d$pooled_crs >= 1 - TOL_FRONTIER),
             frontier_codes = paste(sort(d$code[d$pooled_crs >= 1 - TOL_FRONTIER]), collapse = ", "),
             spearman_vs_annual = spearman(d$pooled_crs, d$fresh_crs),
             mean_fixed39 = mean(d$pooled_crs[d$code %in% fixed39]),
             median_fixed39 = median(d$pooled_crs[d$code %in% fixed39]))
}))
R$pooled_kept48 <- c(n = length(kept48),
                     mean2019 = mean(df$pooled_crs[df$year == 2019 & df$code %in% kept48]),
                     mean2020 = mean(df$pooled_crs[df$year == 2020 & df$code %in% kept48]))

# ---------------------------------------------------------------------
# (c) Fixed-sample annual frontiers (39 countries)
# ---------------------------------------------------------------------
df$fixed_crs <- NA_real_
for (y in YEARS) {
  i <- which(df$year == y & df$code %in% fixed39)
  df$fixed_crs[i] <- dea_input(df[i, INPUTS], df[i, OUTPUTS], "crs")
}
fx <- df[df$code %in% fixed39, ]
R$fixed_by_year <- do.call(rbind, lapply(YEARS, function(y) {
  d <- fx[fx$year == y, ]
  data.frame(year = y, n = nrow(d), mean = mean(d$fixed_crs), median = median(d$fixed_crs),
             frontier = sum(d$fixed_crs >= 1 - TOL_FRONTIER),
             frontier_codes = paste(sort(d$code[d$fixed_crs >= 1 - TOL_FRONTIER]), collapse = ", "),
             spearman_vs_annual = spearman(d$fixed_crs, d$fresh_crs))
}))
fw <- reshape(fx[, c("code", "year", "fixed_crs")], idvar = "code", timevar = "year", direction = "wide")
R$rank_corr_fixed <- setNames(sapply(1:5, function(i) spearman(fw[[paste0("fixed_crs.", YEARS[i])]],
                                                               fw[[paste0("fixed_crs.", YEARS[i + 1])]])),
                              paste(yr[1:5], yr[2:6], sep = "-"))

# ---------------------------------------------------------------------
# (d) Expenditure per capita in PPP dollars
# ---------------------------------------------------------------------
INPUTS_PC <- c("che_pc_ppp", "phys", "beds")
df$pc_crs <- NA_real_
for (y in YEARS) {
  i <- which(df$year == y)
  df$pc_crs[i] <- dea_input(df[i, INPUTS_PC], df[i, OUTPUTS], "crs")
}
R$percap_by_year <- do.call(rbind, lapply(YEARS, function(y) {
  d <- df[df$year == y, ]
  m_pc <- tapply(d$pc_crs, factor(d$income, names(short)), mean)
  m_gdp <- tapply(d$fresh_crs, factor(d$income, names(short)), mean)
  cbind(data.frame(year = y, n = nrow(d), mean = mean(d$pc_crs), median = median(d$pc_crs),
                   frontier = sum(d$pc_crs >= 1 - TOL_FRONTIER),
                   frontier_codes = paste(sort(d$code[d$pc_crs >= 1 - TOL_FRONTIER]), collapse = ", "),
                   spearman_vs_annual = spearman(d$pc_crs, d$fresh_crs)),
        as.list(setNames(m_gdp, paste0("gdp_", short))), as.list(setNames(m_pc, paste0("pc_", short))))
}))
chg <- sort(tapply(df$pc_crs, df$code, mean) - tapply(df$fresh_crs, df$code, mean))
R$percap_largest_drop <- head(chg, 10)
R$percap_largest_gain <- tail(chg, 10)
R$percap_spearman_pooled <- spearman(df$pc_crs, df$fresh_crs)
R$percap_spearman_high <- with(df[df$income == "High", ], spearman(pc_crs, fresh_crs))

# ---------------------------------------------------------------------
# (e) Income-group frontiers (metafrontier) and technology gap ratios
# ---------------------------------------------------------------------
df$group <- unname(META_GROUP[df$income])
df$group_crs <- NA_real_
for (y in YEARS) for (g in unique(META_GROUP)) {
  i <- which(df$year == y & df$group == g)
  df$group_crs[i] <- dea_input(df[i, INPUTS], df[i, OUTPUTS], "crs")
}
df$tgr <- df$fresh_crs / df$group_crs
groups <- c("L+LM", "UM", "H")
R$meta_by_year <- do.call(rbind, lapply(YEARS, function(y) do.call(rbind, lapply(groups, function(g) {
  d <- df[df$year == y & df$group == g, ]
  data.frame(year = y, group = g, n = nrow(d), meta = mean(d$fresh_crs), group_score = mean(d$group_crs),
             tgr = mean(d$tgr), frontier_group = sum(d$group_crs >= 1 - TOL_FRONTIER))
}))))
R$meta_pooled <- do.call(rbind, lapply(groups, function(g) {
  d <- df[df$group == g, ]
  data.frame(group = g, n = nrow(d), meta = mean(d$fresh_crs), group_score = mean(d$group_crs), tgr = mean(d$tgr),
             tgr_median = median(d$tgr), spearman_meta_group = spearman(d$fresh_crs, d$group_crs))
}))
country_means <- function(g, codes) {
  d <- df[df$group == g & df$code %in% codes, ]
  out <- data.frame(code = sort(unique(d$code)))
  out$meta <- tapply(d$fresh_crs, d$code, mean)[out$code]
  out$group_score <- tapply(d$group_crs, d$code, mean)[out$code]
  out[match(intersect(codes, out$code), out$code), ]
}
R$meta_examples <- list(
  H = country_means("H", c("SWE", "FIN", "EST", "JPN", "SGP", "DEU", "CHE", "AUT", "USA")),
  UM = country_means("UM", c("ARG", "BRA", "CRI", "THA", "MYS", "KAZ", "CHN", "COL", "MEX", "TUR")),
  `L+LM` = country_means("L+LM", c("NER", "LAO", "BGD", "NPL", "MLI", "BTN", "IDN", "PAK", "MOZ", "RWA", "AFG", "HTI")))
R$meta_lowest_group <- lapply(setNames(groups, groups), function(g) {
  d <- df[df$group == g, ]
  head(sort(tapply(d$group_crs, d$code, mean)), 6)
})

saveRDS(R, file.path(RESULTS, "robustness.rds"))
write.csv(df[, c("code", "year", "income", "group", "te_io_crs", "te_io_vrs", "scale_eff", "fresh_crs", "pooled_crs",
                 "fixed_crs", "pc_crs", "group_crs", "tgr")],
          file.path(RESULTS, "robustness_scores.csv"), row.names = FALSE)

message("annual frontiers (published): means ", paste(fmt(R$annual$mean), collapse = " "))
message("pooled frontier: means ", paste(fmt(R$pooled_by_year$mean), collapse = " "),
        " | 48 retained countries 2019 -> 2020: ", fmt(R$pooled_kept48["mean2019"]), " -> ", fmt(R$pooled_kept48["mean2020"]))
message("fixed sample (", length(fixed39), "): means ", paste(fmt(R$fixed_by_year$mean), collapse = " "),
        " | rank correlations ", paste(fmt(R$rank_corr_fixed, 2), collapse = " "))
message("metafrontier, pooled TGR: ", paste(R$meta_pooled$group, fmt(R$meta_pooled$tgr, 2), collapse = "; "))
message("saved results/robustness.rds and results/robustness_scores.csv")
