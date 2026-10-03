# =====================================================================
# 08_tables.R
# LaTeX fragments (table rows and the numbers quoted in the table notes) for the tables of the paper, written to
# results/tables/. The table environments, captions and notes of the manuscript were assembled from these fragments.
#   table1_rows.tex   Table 1: annual, pooled and fixed-sample frontiers; 2019-2020 transition
#   table2_rows.tex   Table 2: scale efficiency by income group; income-group frontiers and technology gap ratios
#   table3_rows.tex   Table 3: pooled Tobit (main model) and Simar-Wilson Algorithm 2
#   S6_rows.tex ... S17_rows.tex   Supplementary Tables S6 to S17 (S16 recomputed from the two-decimal scores)
# Annual means and medians of the main estimation in Table 1 and Table S16 of the paper are the unrounded values of the
# source thesis; recomputed here from the two-decimal scores they can differ by up to 0.005.
# =====================================================================
source(file.path("R", "00_setup.R"))

R <- readRDS(file.path(RESULTS, "robustness.rds"))
S <- readRDS(file.path(RESULTS, "second_stage.rds"))
C <- readRDS(file.path(RESULTS, "covid_model.rds"))
db <- read.csv(DATABASE)
scores <- db[db$in_main_sample, c("code", "country", "income", "financing", "year", "te_io_crs", "te_oo_crs", "te_io_vrs", "te_oo_vrs")]

write_tex <- function(name, lines) {
  writeLines(lines, file.path(TABLES, name), useBytes = TRUE)
  message("--- ", name, " ---")
  cat(lines, sep = "\n")
  cat("\n")
}
f2 <- function(x) fmt(x, 2)
f3 <- function(x) fmt(x, 3)
num <- function(x, d = 4) fmt_tex(x, d)
ci_to <- function(lo, hi, d = 4) paste0(num(lo, d), " to ", num(hi, d))
ci_par <- function(lo, hi, d = 4) paste0("(", num(lo, d), ", ", num(hi, d), ")")
row <- function(...) paste0(paste(..., sep = " & "), " \\\\")
lab <- function(term) unname(LABELS[term])
pct <- function(x) paste0(round(100 * x), "\\%")
yrs <- as.character(YEARS)

# ---------------------------------------------------------------------
# Table 1
# ---------------------------------------------------------------------
a <- R$annual; p <- R$pooled_by_year; fx <- R$fixed_by_year
rc_a <- c("--", f2(R$rank_corr_published_39)); rc_f <- c("--", f2(R$rank_corr_fixed))
t1 <- c("% (a) Year & n & annual mean & annual median & frontier (L/LM/UM/H) & pooled mean & pooled median & fixed mean & fixed median & fixed frontier & rank corr annual & rank corr fixed",
        "% annual mean and median recomputed from two-decimal scores (the paper reports the unrounded thesis values)",
        sapply(seq_along(YEARS), function(i) row(YEARS[i], a$n[i], f3(a$mean[i]), f3(a$median[i]),
                                                 sprintf("%d (%d/%d/%d/%d)", a$frontier[i], a$L[i], a$LM[i], a$UM[i], a$H[i]),
                                                 f3(p$mean[i]), f3(p$median[i]), f3(fx$mean[i]), f3(fx$median[i]), fx$frontier[i],
                                                 rc_a[i], rc_f[i])))
tr <- R$transition
t1 <- c(t1, "% (b) transition between the 2019 and 2020 annual models",
        row("Countries in the 2019 model", tr$n2019, paste("2019 mean", f2(tr$mean2019))),
        row("\\quad without a 2020 score", tr$lost_n, sprintf("2019 mean %s (income groups L %d, LM %d, UM %d, H %d)", f2(tr$lost_mean2019),
                                                              tr$lost_income[["Low"]], tr$lost_income[["Lower-mid"]], tr$lost_income[["Upper-mid"]], tr$lost_income[["High"]])),
        row("\\quad retained in 2020", tr$kept_n, sprintf("annual frontier: %s in 2019, %s in 2020; pooled frontier: %s in 2019, %s in 2020",
                                                         f2(tr$kept_mean2019), f2(tr$kept_mean2020), f2(R$pooled_kept48[["mean2019"]]), f2(R$pooled_kept48[["mean2020"]]))),
        row("Countries entering only in 2020", tr$new_n, paste("2020 mean", f2(tr$new_mean2020))),
        row("Frontier members in at least one year, 2015--2019", tr$front1519_n,
            sprintf("%d without a 2020 score (%s)", length(tr$front1519_absent2020), paste(tr$front1519_absent2020, collapse = ", "))),
        row("Members of the 2019 frontier", tr$front19_n,
            sprintf("%d without a 2020 score (%s)", length(tr$front19_absent2020), paste(tr$front19_absent2020, collapse = ", "))))
write_tex("table1_rows.tex", t1)

# ---------------------------------------------------------------------
# Table 2
# ---------------------------------------------------------------------
inc_lab <- c("Low" = "Low income", "Lower-mid" = "Lower-middle income", "Upper-mid" = "Upper-middle income", "High" = "High income")
grp_lab <- c("L+LM" = "Low and lower-middle income", "UM" = "Upper-middle income", "H" = "High income")
sb <- R$scale_by_income; mp <- R$meta_pooled
t2 <- c("% (a) Income group & n & CRS mean & VRS mean & scale efficiency mean & share below 0.8",
        sapply(seq_len(nrow(sb)), function(i) row(inc_lab[[sb$income[i]]], sb$n[i], f3(sb$mean_crs[i]), f3(sb$mean_vrs[i]),
                                                  f3(sb$mean_se[i]), pct(sb$share_below_0.8[i]))),
        "% (b) Income group & n & global mean & group mean & TGR mean & TGR median & rank corr",
        sapply(seq_len(nrow(mp)), function(i) row(grp_lab[[mp$group[i]]], mp$n[i], f2(mp$meta[i]), f2(mp$group_score[i]),
                                                  f2(mp$tgr[i]), f2(mp$tgr_median[i]), f2(mp$spearman_meta_group[i]))))
write_tex("table2_rows.tex", t2)

# ---------------------------------------------------------------------
# Table 3 (bold: p < 0.05 in the Tobit model)
# ---------------------------------------------------------------------
tm <- S$tobit_main; sw <- S$sw2_main
bold <- function(x, on) ifelse(on, paste0("\\textbf{\\boldmath ", x, "}"), x)
t3 <- c("% Variable & Tobit coefficient (95% CI) & p & Simar-Wilson Algorithm 2 coefficient (95% CI), Shephard distance scale")
for (term in c(PRED_MAIN, "(Intercept)")) {
  i <- match(term, tm$term); j <- match(term, sw$term)
  on <- term != "(Intercept)" && tm$p[i] < 0.05
  t3 <- c(t3, row(bold(lab(term), on), bold(paste0(num(tm$coef[i]), " (", ci_to(tm$ci_lo[i], tm$ci_hi[i]), ")"), on),
                  bold(fmt_p(tm$p[i]), on), paste0(num(sw$coef[j]), " (", ci_to(sw$ci_lo[j], sw$ci_hi[j]), ")")))
}
nsgp <- S$tobit_main_noSGP[S$tobit_main_noSGP$term == "dens_h", ]
t3 <- c(t3, sprintf("%% n = %d (on the frontier %d); Tobit residual SD = %.2f; Simar-Wilson Algorithm 2: %d observations",
                    S$n, S$n_at_1, exp(tm$coef[tm$term == "log_sigma"]), attr(sw, "n")),
        sprintf("%% density without Singapore: %s (95%% CI %s), p = %s", num(nsgp$coef), ci_to(nsgp$ci_lo, nsgp$ci_hi), fmt_p(nsgp$p)))
write_tex("table3_rows.tex", t3)

# ---------------------------------------------------------------------
# Tables S6, S7, S8 (published scores)
# ---------------------------------------------------------------------
w <- reshape(scores[, c("code", "country", "income", "financing", "year", "te_io_crs")],
             idvar = c("code", "country", "income", "financing"), timevar = "year", direction = "wide")
names(w) <- sub("te_io_crs.", "", names(w), fixed = TRUE)
w <- w[order(w$code), c("code", "country", "income", "financing", yrs)]
s6 <- apply(w, 1, function(r) row(r[["code"]], gsub("&", "\\\\&", r[["country"]]), r[["income"]], r[["financing"]],
                                  paste(ifelse(is.na(as.numeric(r[yrs])), "--", f2(as.numeric(r[yrs]))), collapse = " & ")))
write_tex("S6_rows.tex", s6)

s7 <- c(sapply(names(inc_lab), function(g) row(inc_lab[[g]], paste(sapply(yrs, function(y) {
  x <- w[w$income == g, y]; sprintf("%s (%d)", f2(mean(x, na.rm = TRUE)), sum(!is.na(x)))
}), collapse = " & "))),
"\\midrule",
row("All countries, mean", paste(sapply(yrs, function(y) sprintf("%s (%d)", f3(mean(w[[y]], na.rm = TRUE)), sum(!is.na(w[[y]])))), collapse = " & ")),
row("All countries, median", paste(sapply(yrs, function(y) f2(median(w[[y]], na.rm = TRUE))), collapse = " & ")),
row("All countries, SD", paste(sapply(yrs, function(y) f2(sd(w[[y]], na.rm = TRUE))), collapse = " & ")))
write_tex("S7_rows.tex", s7)

short <- c("Low" = "L", "Lower-mid" = "LM", "Upper-mid" = "UM", "High" = "H")
inc <- setNames(w$income, w$code)
s8 <- c("% (a) frontier-defining countries by year",
        sapply(seq_along(YEARS), function(i) row(YEARS[i], a$n[i], a$frontier[i], sprintf("%d/%d/%d/%d", a$L[i], a$LM[i], a$UM[i], a$H[i]),
                                                 paste0(strsplit(a$frontier_codes[i], ", ")[[1]], " (", short[inc[strsplit(a$frontier_codes[i], ", ")[[1]]]], ")", collapse = ", "))),
        "% (b) transition: see table1_rows.tex",
        "% (c) countries with a score in every year",
        row("Countries with a score in every year", sprintf("\\multicolumn{6}{l}{%d; income groups L %d, LM %d, UM %d, H %d; financing public %d, mixed %d, private %d}",
                                                            length(R$fixed_set), sum(inc[R$fixed_set] == "Low"), sum(inc[R$fixed_set] == "Lower-mid"),
                                                            sum(inc[R$fixed_set] == "Upper-mid"), sum(inc[R$fixed_set] == "High"),
                                                            sum(w$financing[w$code %in% R$fixed_set] == "Public"), sum(w$financing[w$code %in% R$fixed_set] == "Mixed"),
                                                            sum(w$financing[w$code %in% R$fixed_set] == "Private"))),
        row("Annual mean", paste(f3(R$fixed_set_published$mean), collapse = " & ")),
        row("Annual median", paste(f2(R$fixed_set_published$median), collapse = " & ")),
        row("Frontier members within the set", paste(sapply(yrs, function(y) paste(sort(w$code[w$code %in% R$fixed_set & w[[y]] %in% 1]), collapse = ", ")), collapse = " & ")),
        row("Spearman rank correlation between consecutive years", sprintf("\\multicolumn{6}{l}{%s}",
                                                                           paste(sub("-", "--", names(R$rank_corr_published_39)), f2(R$rank_corr_published_39), sep = ": ", collapse = "; "))),
        paste0("% members: ", paste(R$fixed_set, collapse = ", ")))
write_tex("S8_rows.tex", s8)

# ---------------------------------------------------------------------
# Table S9 (correlations and VIF)
# ---------------------------------------------------------------------
abbr <- c(cbr = "CBR", cdr = "CDR", gni_k = "GNIpc", lf_10m = "LF", edu = "EDU", gdp_k = "GDPpc", dens_h = "DENS", rur = "RUR", pop_m = "POP")
s9 <- sapply(c(PRED_FULL, "pop_m"), function(v) {
  i <- match(v, c(PRED_FULL, "pop_m"))
  cells <- sapply(seq_along(PRED_FULL), function(j) if (j < i) num(S$corr[v, PRED_FULL[j]], 2) else if (j == i) "1" else "")
  vifs <- if (v == "pop_m") c("--", "--") else c(f2(S$vif_full[[v]]), if (v %in% PRED_MAIN) f2(S$vif_main[[v]]) else "--")
  row(paste0(if (v == "pop_m") "Total population (memorandum)" else sub(" \\(.*", "", lab(v)), " (", abbr[[v]], ")"),
      paste(cells, collapse = " & "), paste(vifs, collapse = " & "))
})
write_tex("S9_rows.tex", s9)

# ---------------------------------------------------------------------
# Tables S10 to S13 (frontier robustness)
# ---------------------------------------------------------------------
sc <- R$scale_by_year
s10 <- c("% (a) year & n & CRS mean & CRS median & VRS mean & VRS median & SE mean & SE median & CRS frontier & VRS frontier & Spearman",
         "% CRS and VRS means and medians recomputed from two-decimal scores (the paper reports the unrounded thesis values)",
         sapply(seq_len(nrow(sc)), function(i) row(sc$year[i], sc$n[i], f3(sc$mean_crs[i]), f3(sc$median_crs[i]), f3(sc$mean_vrs[i]),
                                                   f3(sc$median_vrs[i]), f3(sc$mean_se[i]), f3(sc$median_se[i]), sc$frontier_crs[i],
                                                   sc$frontier_vrs[i], f2(sc$spearman_crs_vrs[i]))),
         "% (b): see table2_rows.tex",
         paste0("% VRS frontier: ", paste(sc$year, sc$frontier_vrs_codes, sep = ": ", collapse = ". ")),
         paste0("% lowest pooled scale efficiency: ", paste0(names(R$scale_lowest_countries), " (", f2(R$scale_lowest_countries), ")", collapse = ", ")))
write_tex("S10_rows.tex", s10)

s11 <- c("% year & n & pooled mean & pooled median & pooled frontier & Spearman vs annual & fixed mean & fixed median & fixed frontier & pooled mean of the 39",
         sapply(seq_along(YEARS), function(i) row(YEARS[i], p$n[i], f3(p$mean[i]), f3(p$median[i]), p$frontier[i], f2(p$spearman_vs_annual[i]),
                                                  f3(fx$mean[i]), f3(fx$median[i]), fx$frontier[i], f3(p$mean_fixed39[i]))),
         paste0("% pooled frontier: ", paste(p$year, p$frontier_codes, sep = ": ", collapse = "; ")),
         paste0("% fixed-sample frontier: ", paste(fx$year, fx$frontier_codes, sep = ": ", collapse = "; ")),
         sprintf("%% 48 retained countries under the pooled frontier: %s in 2019, %s in 2020", f2(R$pooled_kept48[["mean2019"]]), f2(R$pooled_kept48[["mean2020"]])),
         paste0("% fixed-sample rank correlations: ", paste(sub("-", "--", names(R$rank_corr_fixed)), f2(R$rank_corr_fixed), sep = ": ", collapse = "; ")))
write_tex("S11_rows.tex", s11)

pc <- R$percap_by_year
s12 <- c("% year & n & mean & median & frontier & Spearman vs main & Low & Lower-mid & Upper-mid & High (share of GDP / per capita)",
         sapply(seq_len(nrow(pc)), function(i) row(pc$year[i], pc$n[i], f3(pc$mean[i]), f3(pc$median[i]), pc$frontier[i], f2(pc$spearman_vs_annual[i]),
                                                   paste(sapply(short, function(s) paste0(f2(pc[[paste0("gdp_", s)]][i]), "/", f2(pc[[paste0("pc_", s)]][i]))), collapse = " & "))),
         paste0("% per-capita frontier: ", paste(pc$year, pc$frontier_codes, sep = ": ", collapse = "; ")),
         sprintf("%% pooled Spearman %s (high income %s)", f2(R$percap_spearman_pooled), f2(R$percap_spearman_high)),
         paste0("% largest decreases: ", paste0(names(R$percap_largest_drop), " (", num(R$percap_largest_drop, 2), ")", collapse = ", ")),
         paste0("% largest increases: ", paste0(rev(names(R$percap_largest_gain)), " (+", f2(rev(R$percap_largest_gain)), ")", collapse = ", ")))
write_tex("S12_rows.tex", s12)

mb <- R$meta_by_year
s13 <- c("% year & [n & meta & group & TGR] x (L+LM, UM, H)",
         sapply(YEARS, function(y) row(y, paste(sapply(c("L+LM", "UM", "H"), function(g) {
           x <- mb[mb$year == y & mb$group == g, ]; paste(x$n, f2(x$meta), f2(x$group_score), f2(x$tgr), sep = " & ")
         }), collapse = " & "))),
         row("Pooled", paste(sapply(seq_len(nrow(mp)), function(i) paste(mp$n[i], f2(mp$meta[i]), f2(mp$group_score[i]), f2(mp$tgr[i]), sep = " & ")), collapse = " & ")),
         "% (b) country examples, pooled mean of the years with data (global -> group)")
ex <- R$meta_examples
ex_lab <- c(H = "High", UM = "Upper-middle", `L+LM` = "Low and lower-middle")
s13 <- c(s13,
         sapply(names(ex_lab), function(g) row(ex_lab[[g]], paste0(ex[[g]]$code, " ", f2(ex[[g]]$meta), "$\\rightarrow$",
                                                                    f2(ex[[g]]$group_score), collapse = "; "))),
         paste0("% Spearman global vs group scores, pooled: ", paste(mp$group, f2(mp$spearman_meta_group), collapse = "; "),
                " | median TGR: ", paste(mp$group, f2(mp$tgr_median), collapse = "; ")))
write_tex("S13_rows.tex", s13)

# ---------------------------------------------------------------------
# Table S14 (estimators) and Table S15 (year-specific Tobit)
# ---------------------------------------------------------------------
cell <- function(tab, term) { i <- match(term, tab$term); if (is.na(i)) "--" else paste(num(tab$coef[i]), ci_par(tab$ci_lo[i], tab$ci_hi[i])) }
s14 <- c("% (a) Tobit: eight predictors | main model | main model without Singapore",
         sapply(c(PRED_FULL, "(Intercept)"), function(term) row(lab(term), cell(S$tobit_full, term), cell(S$tobit_main, term), cell(S$tobit_main_noSGP, term))),
         row("Observations", attr(S$tobit_full, "n"), attr(S$tobit_main, "n"), attr(S$tobit_main_noSGP, "n")),
         "% (b) OLS HC1 | Simar-Wilson Algorithm 1 | Simar-Wilson Algorithm 2 (Shephard distance scale for both Simar-Wilson columns)",
         sapply(c(PRED_MAIN, "(Intercept)"), function(term) row(lab(term), cell(S$ols_main, term), cell(S$sw1_main, term), cell(S$sw2_main, term))),
         row("Observations", S$n, attr(S$sw1_main, "n"), attr(S$sw2_main, "n")),
         paste0("% Simar-Wilson Algorithm 2, mean score by year before and after bias correction: ",
                paste(S$sw2_by_year$year, ": ", f3(S$sw2_by_year$mean_score), " -> ", f3(S$sw2_by_year$mean_bias_corrected_score), sep = "", collapse = "; ")),
         paste0("% main Tobit p values: ", paste(S$tobit_main$term, fmt(S$tobit_main$p, 4), sep = " = ", collapse = ", ")),
         paste0("% without Singapore p values: ", paste(S$tobit_main_noSGP$term, fmt(S$tobit_main_noSGP$p, 4), sep = " = ", collapse = ", ")))
write_tex("S14_rows.tex", s14)

star <- function(p) ifelse(p < 0.001, "$^{***}$", ifelse(p < 0.01, "$^{**}$", ifelse(p < 0.05, "$^{*}$", "")))
by <- S$tobit_by_year
s15 <- c(sapply(PRED_MAIN, function(term) row(lab(term), paste(sapply(yrs, function(y) {
  r <- by[[y]][by[[y]]$term == term, ]; paste0(num(r$coef), star(r$p))
}), collapse = " & "))),
"\\midrule",
row("Observations", paste(sapply(yrs, function(y) attr(by[[y]], "n")), collapse = " & ")),
row("Observations on the frontier", paste(sapply(yrs, function(y) attr(by[[y]], "n_censored_at_1")), collapse = " & ")))
write_tex("S15_rows.tex", s15)

# ---------------------------------------------------------------------
# Table S16 (DEA specifications; recomputed from the two-decimal scores)
# ---------------------------------------------------------------------
s16 <- c("% statistics recomputed from the two-decimal scores; the paper reports the unrounded thesis values (frontier counts are identical)",
         row("Countries in the frontier", paste(sapply(YEARS, function(y) sum(scores$year == y)), collapse = " & ")))
for (m in list(c("te_io_crs", "IO--CRS and OO--CRS"), c("te_io_vrs", "IO--VRS"), c("te_oo_vrs", "OO--VRS"))) {
  st <- sapply(YEARS, function(y) { x <- scores[scores$year == y, m[1]]; c(mean(x), median(x), min(x), sd(x) / mean(x), sum(x >= 1)) })
  s16 <- c(s16, sprintf("\\multicolumn{7}{@{}l}{\\textit{%s}} \\\\", m[2]),
           row("\\quad Mean", paste(f3(st[1, ]), collapse = " & ")), row("\\quad Median", paste(f3(st[2, ]), collapse = " & ")),
           row("\\quad Minimum", paste(f3(st[3, ]), collapse = " & ")), row("\\quad CV", paste(f3(st[4, ]), collapse = " & ")),
           row("\\quad Countries on the frontier", paste(st[5, ], collapse = " & ")))
}
write_tex("S16_rows.tex", s16)

# ---------------------------------------------------------------------
# Table S17 (2020 pandemic model)
# ---------------------------------------------------------------------
lab17 <- c(cases_k = "Cumulative confirmed cases (per 1,000 people)", deaths_h = "Cumulative confirmed deaths (per 100,000 people)",
           r_mean = "Mean daily effective reproduction number", `(Intercept)` = "Intercept")
cf <- C$full
s17 <- sapply(names(lab17), function(term) {
  i <- match(term, cf$term); d <- if (term %in% c("cases_k", "deaths_h")) 4 else 3
  row(lab17[[term]], num(cf$coef[i], d), num(cf$se[i], d), ci_to(cf$ci_lo[i], cf$ci_hi[i], d), fmt_p(cf$p[i]))
})
g <- function(m, term, what) C[[m]][C[[m]]$term == term, what]
s17 <- c(s17, sprintf("%% n = %d (with R), %d without R; residual SD = %.2f; r(cases, deaths) = %.2f", attr(C$full, "n"), attr(C$no_r, "n"),
                      exp(g("full", "log_sigma", "coef")), C$corr_cases_deaths),
         sprintf("%% cases only: %s (p = %s); deaths only: %s (p = %s); without R: cases %s (p = %s), deaths %s (p = %s)",
                 num(g("cases_only", "cases_k", "coef")), fmt_p(g("cases_only", "cases_k", "p")), num(g("deaths_only", "deaths_h", "coef")),
                 fmt_p(g("deaths_only", "deaths_h", "p")), num(g("no_r", "cases_k", "coef")), fmt_p(g("no_r", "cases_k", "p")),
                 num(g("no_r", "deaths_h", "coef")), fmt_p(g("no_r", "deaths_h", "p"))))
write_tex("S17_rows.tex", s17)
message("all fragments written to results/tables/")
