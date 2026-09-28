"""LaTeX fragments for the tables of the manuscript and the supplementary material, written to results/tables/.

  table1_rows.tex   Table 1: mean, median, minimum, CV and frontier size of IO-CRS, IO-VRS and OO-VRS by year (thesis appendices)
  table2_rows.tex   Table 2: pooled Tobit (main model) and Simar-Wilson Algorithm 2
  table3_rows.tex   Table 3: 2020 pandemic model
  S6_rows.tex       Table S6: published IO-CRS scores by country
  S7_rows.tex       Table S7: mean score by income group and year
  S8_rows.tex       Table S8: frontier composition, 2019-2020 transition, fixed set of 39 countries
  S9.tex            Table S9: correlations and VIF
  S10_S13.tex       Tables S10-S13: scale efficiency, reference-set robustness, expenditure measure, metafrontier
  S14_S15.tex       Tables S14-S15: estimator comparison and year-specific models
The table environments, captions and notes of the submitted files were assembled from these fragments.
"""
import json
import numpy as np, pandas as pd
from config import DATA, RESULTS, TABLES, YEARS, PRED_FULL, PRED_MAIN, LABELS, REPORT_SCALE

Y = [str(y) for y in YEARS]


def f(x, k=1.0, d=4):
    v = x * k
    return ("$-$" if v < 0 else "") + f"{abs(v):.{d}f}"


def write(name, text):
    (TABLES / name).write_text(text, encoding="utf-8")
    print(f"--- {name} ---\n{text}\n")


# ---------------- Table 1 (thesis appendices, unrounded statistics computed on the two-decimal appendix scores) ----------------
rows = ["Countries in the frontier & " + " & ".join(str(int(pd.read_csv(DATA / 'thesis_IO_CRS.csv', index_col=0)[y].notna().sum())) for y in Y) + " \\\\"]
for name, lab in [("IO_CRS", "IO--CRS and OO--CRS"), ("IO_VRS", "IO--VRS"), ("OO_VRS", "OO--VRS")]:
    t = pd.read_csv(DATA / f"thesis_{name}.csv", index_col=0)
    rows.append(f"\\multicolumn{{7}}{{@{{}}l}}{{\\textit{{{lab}}}}} \\\\")
    rows.append("\\quad Mean & " + " & ".join(f"{t[y].mean():.3f}" for y in Y) + " \\\\")
    rows.append("\\quad Median & " + " & ".join(f"{t[y].median():.3f}" for y in Y) + " \\\\")
    rows.append("\\quad Minimum & " + " & ".join(f"{t[y].min():.3f}" for y in Y) + " \\\\")
    rows.append("\\quad CV & " + " & ".join(f"{t[y].std() / t[y].mean():.3f}" for y in Y) + " \\\\")
    rows.append("\\quad Countries on the frontier & " + " & ".join(str(int((t[y] >= 0.995).sum())) for y in Y) + " \\\\")
write("table1_rows.tex", "% Table 1 statistics recomputed from the appendix scores (two decimals); the submitted table uses the\n% unrounded means, medians, minima and CVs of the source thesis (tables 5.1 to 5.4, whose mean and median columns are interchanged).\n" + "\n".join(rows))

# ---------------- Tables S6, S7, S8 (published scores) ----------------
s6 = pd.read_csv(DATA / "s6_scores.csv")
fmt = lambda v: "--" if pd.isna(v) else f"{v:.2f}"
write("S6_rows.tex", "\n".join(f"{r['code']} & {r['country'].replace('&', chr(92) + '&')} & {r['income']} & {r['financing']} & " + " & ".join(fmt(r[y]) for y in Y) + " \\\\" for _, r in s6.iterrows()))
order = [("Low", "Low income"), ("Lower-mid", "Lower-middle income"), ("Upper-mid", "Upper-middle income"), ("High", "High income")]
rows = [f"{lab} & " + " & ".join(f"{s6[s6.income == k][y].mean():.2f} ({int(s6[s6.income == k][y].notna().sum())})" for y in Y) + " \\\\" for k, lab in order]
rows += ["\\midrule", "All countries, mean & " + " & ".join(f"{s6[y].mean():.3f} ({int(s6[y].notna().sum())})" for y in Y) + " \\\\",
         "All countries, median & " + " & ".join(f"{s6[y].median():.2f}" for y in Y) + " \\\\",
         "All countries, SD & " + " & ".join(f"{s6[y].std(ddof=1):.2f}" for y in Y) + " \\\\"]
write("S7_rows.tex", "\n".join(rows))
d = s6.set_index("code"); short = {"Low": "L", "Lower-mid": "LM", "Upper-mid": "UM", "High": "H"}
rows = ["% (a) frontier-defining countries by year"]
for y in Y:
    fr = d[d[y] == 1.0]; cnt = fr.income.value_counts()
    rows.append(f"{y} & {int(d[y].notna().sum())} & {len(fr)} & {cnt.get('Low', 0)}/{cnt.get('Lower-mid', 0)}/{cnt.get('Upper-mid', 0)}/{cnt.get('High', 0)} & " + ", ".join(f"{c} ({short[fr.loc[c, 'income']]})" for c in sorted(fr.index)) + " \\\\")
p19 = d[d["2019"].notna()]; lost = p19[p19["2020"].isna()]; kept = p19[p19["2020"].notna()]; new20 = d[d["2020"].notna() & d["2019"].isna()]
front1519 = set().union(*[set(d.index[d[y] == 1.0]) for y in Y[:-1]]); absent = sorted(c for c in front1519 if pd.isna(d.loc[c, "2020"]))
front19 = sorted(d.index[d["2019"] == 1.0]); front19_absent = sorted(c for c in front19 if pd.isna(d.loc[c, "2020"]))
rows += ["% (b) 2019-2020 transition",
         f"Countries in the 2019 model & {len(p19)} & 2019 mean {p19['2019'].mean():.2f} \\\\",
         f"\\quad without a 2020 score & {len(lost)} & 2019 mean {lost['2019'].mean():.2f}; income groups L {int((lost.income == 'Low').sum())}, LM {int((lost.income == 'Lower-mid').sum())}, UM {int((lost.income == 'Upper-mid').sum())}, H {int((lost.income == 'High').sum())} \\\\",
         f"\\quad retained in 2020 & {len(kept)} & 2019 mean {kept['2019'].mean():.2f}; 2020 mean {kept['2020'].mean():.2f} \\\\",
         f"Countries entering only in 2020 & {len(new20)} & 2020 mean {new20['2020'].mean():.2f}; {', '.join(sorted(new20.index))} \\\\",
         f"Frontier-defining countries in at least one year, 2015--2019 & {len(front1519)} & of which without a 2020 score: {len(absent)} ({', '.join(absent)}) \\\\",
         f"Countries on the 2019 frontier & {len(front19)} & of which without a 2020 score: {len(front19_absent)} ({', '.join(front19_absent)}) \\\\"]
full = d[d[Y].notna().all(axis=1)]
rows += ["% (c) countries with a score in every year",
         f"Countries with a score in every year & {len(full)}; income groups L {int((full.income == 'Low').sum())}, LM {int((full.income == 'Lower-mid').sum())}, UM {int((full.income == 'Upper-mid').sum())}, H {int((full.income == 'High').sum())}; financing public {int((full.financing == 'Public').sum())}, mixed {int((full.financing == 'Mixed').sum())}, private {int((full.financing == 'Private').sum())} \\\\",
         "Annual mean & " + " & ".join(f"{full[y].mean():.3f}" for y in Y) + " \\\\", "Annual median & " + " & ".join(f"{full[y].median():.2f}" for y in Y) + " \\\\",
         "Frontier members within the set & " + " & ".join(", ".join(sorted(full.index[full[y] == 1.0])) for y in Y) + " \\\\",
         "Spearman rank correlation between consecutive years & " + "; ".join(f"{a}--{b}: {full[a].corr(full[b], method='spearman'):.2f}" for a, b in zip(Y[:-1], Y[1:])) + " \\\\",
         "% members: " + ", ".join(sorted(full.index))]
write("S8_rows.tex", "\n".join(rows))

# ---------------- Table S9 (correlations and VIF) and Tables S14-S15 (second stage) ----------------
S = json.load(open(RESULTS / "second_stage_results.json"))
names = {"cbr": "CBR", "cdr": "CDR", "gni_k": "GNIpc", "lf_m": "LF", "edu": "EDU", "gdp_k": "GDPpc", "dens_h": "DENS", "rur": "RUR", "pop_m": "POP"}
rows = []
for i, p in enumerate(PRED_FULL + ["pop_m"]):
    cells = [f(S["corr"][q][p], d=2) if j < i else ("1" if j == i else "") for j, q in enumerate(PRED_FULL)]
    vif = ["--", "--"] if p == "pop_m" else [f"{S['vif_full'][p]:.2f}", f"{S['vif_reduced'][p]:.2f}" if p in S["vif_reduced"] else "--"]
    rows.append(f"{LABELS.get(p, 'Total population (memorandum)')} ({names[p]}) & " + " & ".join(cells) + " & " + " & ".join(vif) + " \\\\")
write("S9.tex", "\n".join(rows))

est = {"Tobit, eight predictors": S["tobit_full"], "Tobit, main model": S["tobit_reduced"], "Tobit, main model without Singapore": S["tobit_reduced_noSGP"],
       "OLS, HC1 errors": S["ols_reduced"], "Simar--Wilson Algorithm 1": S["sw1_reduced"], "Simar--Wilson Algorithm 2": S["sw2_reduced"]}
nobs = {"Tobit, eight predictors": S["n"], "Tobit, main model": S["n"], "Tobit, main model without Singapore": S["n_noSGP"], "OLS, HC1 errors": S["n"], "Simar--Wilson Algorithm 1": S["sw1_n"], "Simar--Wilson Algorithm 2": S["sw2_n"]}


def cell(e, key):
    if key not in e:
        return "--"
    k = REPORT_SCALE.get(key, 1.0)
    return f"{f(e[key]['coef'], k)} ({f(e[key]['ci_lo'], k)}, {f(e[key]['ci_hi'], k)})"


rows = ["% Table S14: coefficient (95% CI) by estimator; columns: " + " | ".join(est)]
for key in PRED_FULL + ["Intercept"]:
    rows.append(f"{LABELS[key]} & " + " & ".join(cell(e, key) for e in est.values()) + " \\\\")
rows.append("Observations & " + " & ".join(str(v) for v in nobs.values()) + " \\\\")
rows.append("% bias correction by year (mean fresh -> bias-corrected): " + "; ".join(f"{y}: {v['mean_fresh']:.3f} -> {v['mean_bc']:.3f} (bias {v['mean_bias']:.3f})" for y, v in S["sw2_by_year"].items()))
star = lambda p: "***" if p < 0.001 else "**" if p < 0.01 else "*" if p < 0.05 else ""
rows.append("% Table S15: year-specific Tobit, main model")
by = S["tobit_by_year_reduced"]
for key in PRED_MAIN:
    rows.append(f"{LABELS[key]} & " + " & ".join(f"{f(by[y][key]['coef'], REPORT_SCALE.get(key, 1.0))}" + (f"$^{{{star(by[y][key]['p'])}}}$" if star(by[y][key]['p']) else "") for y in Y) + " \\\\")
rows.append("Observations & " + " & ".join(str(by[y]["n"]) for y in Y) + " \\\\")
rows.append("Observations on the frontier & " + " & ".join(str(by[y]["n_at_1"]) for y in Y) + " \\\\")
write("S14_S15.tex", "\n".join(rows))

# ---------------- Table 2 (main text) ----------------
rows = ["% (a) Tobit, main model: coefficient & SE & 95% CI & p"]
for key in PRED_MAIN + ["Intercept"]:
    e = S["tobit_reduced"][key]; k = REPORT_SCALE.get(key, 1.0)
    p = "$<$0.001" if e["p"] < 0.001 else f"{e['p']:.3f}" if e["p"] < 0.1 else f"{e['p']:.2f}"
    rows.append(f"{LABELS[key]} & {f(e['coef'], k)} & {f(e['se'], k)} & {f(e['ci_lo'], k)} to {f(e['ci_hi'], k)} & {p} \\\\")
rows.append("% (b) Simar-Wilson Algorithm 2: coefficient & 95% CI")
for key in PRED_MAIN + ["Intercept"]:
    e = S["sw2_reduced"][key]; k = REPORT_SCALE.get(key, 1.0)
    rows.append(f"{LABELS[key]} & {f(e['coef'], k)} & & {f(e['ci_lo'], k)} to {f(e['ci_hi'], k)} & \\\\")
rows.append(f"% Tobit residual SD = {np.exp(S['tobit_reduced']['log sigma']['coef']):.3f}; n = {S['n']}, on the frontier {S['n_at_1']}; SW2 observations below one after correction: {S['sw2_n']}")
e = S["tobit_reduced_noSGP"]["dens_h"]
rows.append(f"% density without Singapore: {f(e['coef'])} ({f(e['ci_lo'])} to {f(e['ci_hi'])}), p = {e['p']:.2f}")
write("table2_rows.tex", "\n".join(rows))

# ---------------- Table 3 (2020 pandemic model) ----------------
C = json.load(open(RESULTS / "covid_tobit_results.json"))
lab3 = {"cases_k": "Cumulative confirmed cases (per 1,000 people)", "deaths_h": "Cumulative confirmed deaths (per 100,000 people)", "r_mean": "Mean daily effective reproduction number", "Intercept": "Intercept"}
rows = []
for key in ["cases_k", "deaths_h", "r_mean", "Intercept"]:
    e = C["full"][key]; dd = 4 if key in ("cases_k", "deaths_h") else 3
    p = "$<$0.001" if e["p"] < 0.001 else f"{e['p']:.3f}" if e["p"] < 0.1 else f"{e['p']:.2f}"
    rows.append(f"{lab3[key]} & {f(e['coef'], d=dd)} & {f(e['se'], d=dd)} & {f(e['ci_lo'], d=dd)} to {f(e['ci_hi'], d=dd)} & {p} \\\\")
rows.append(f"% n = {C['n_full']} (with R), {C['n_noR']} without R; residual SD = {np.exp(C['full']['log sigma']['coef']):.3f}; r(cases, deaths) = {C['corr_cases_deaths']:.2f}")
rows.append(f"% cases only: {f(C['cases_only']['cases_k']['coef'])} (p = {C['cases_only']['cases_k']['p']:.3f}); deaths only: {f(C['deaths_only']['deaths_h']['coef'])} (p = {C['deaths_only']['deaths_h']['p']:.3f}); "
            f"without R: cases {f(C['noR']['cases_k']['coef'])} (p = {C['noR']['cases_k']['p']:.3f}), deaths {f(C['noR']['deaths_h']['coef'])} (p = {C['noR']['deaths_h']['p']:.2f})")
write("table3_rows.tex", "\n".join(rows))

# ---------------- Tables S10-S13 (robustness) ----------------
R = json.load(open(RESULTS / "robustness_results.json"))
rows = ["% Table S10 (a): year & n & CRS mean & CRS median & VRS mean & VRS median & SE mean & SE median & CRS frontier & VRS frontier & Spearman"]
for y in Y:
    a = R["a_scale"][y]
    rows.append(f"{y} & {a['n']} & {a['mean_crs']:.3f} & {a['median_crs']:.3f} & {a['mean_vrs']:.3f} & {a['median_vrs']:.3f} & {a['mean_se']:.3f} & {a['median_se']:.3f} & {a['frontier_crs']} & {a['frontier_vrs']} & {a['spearman_crs_vrs']:.2f} \\\\")
rows.append("% Table S10 (b): income group & n & CRS mean & VRS mean & SE mean & share SE < 0.8")
for g, lab in [("Low", "Low income"), ("Lower-mid", "Lower-middle income"), ("Upper-mid", "Upper-middle income"), ("High", "High income")]:
    p = R["a_scale_pooled_income"][g]
    rows.append(f"{lab} & {p['n']} & {p['mean_crs']:.3f} & {p['mean_vrs']:.3f} & {p['mean_se']:.3f} & {100 * p['share_se_below_0_8']:.0f}\\% \\\\")
rows.append("% VRS frontier by year: " + " ".join(f"{y}: {', '.join(R['a_scale'][y]['frontier_vrs_codes'])}." for y in Y))
rows.append("% lowest pooled scale efficiency: " + ", ".join(f"{c} ({v:.2f})" for c, v in R["a_lowest_se_countries"].items()))
rows.append("% Table S11: year & n & pooled mean & pooled median & pooled frontier & Spearman vs annual & fixed mean & fixed median & fixed frontier & pooled mean of the 39")
for y in Y:
    b = R["b_pooled"][y]; c = R["c_fixed"][y]; bf = R["b_pooled_fixed_set"][y]
    rows.append(f"{y} & {b['n']} & {b['mean']:.3f} & {b['median']:.3f} & {b['frontier']} & {b['spearman_vs_annual_fresh']:.2f} & {c['mean']:.3f} & {c['median']:.3f} & {c['frontier']} & {bf['mean']:.3f} \\\\")
rows.append("% pooled frontier members: " + "; ".join(f"{y}: {', '.join(R['b_pooled'][y]['frontier_codes'])}" for y in Y))
rows.append("% fixed-sample frontier members: " + "; ".join(f"{y}: {', '.join(R['c_fixed'][y]['frontier_codes'])}" for y in Y))
rows.append(f"% kept-48 under the pooled frontier: 2019 {R['b_pooled_kept48']['mean2019']:.2f}, 2020 {R['b_pooled_kept48']['mean2020']:.2f}; fixed-sample rank correlations: {R['c_fixed_rank_corr_consecutive']}")
rows.append("% Table S12: year & n & mean & median & frontier & Spearman vs main & Low & Lower-mid & Upper-mid & High (share of GDP / per capita)")
for y in Y:
    dd = R["d_percap"][y]; mi = dd["mean_by_income"]; mg = dd["mean_by_income_gdp"]
    rows.append(f"{y} & {dd['n']} & {dd['mean']:.3f} & {dd['median']:.3f} & {dd['frontier']} & {dd['spearman_vs_fresh']:.2f} & " + " & ".join(f"{mg[g]:.2f}/{mi[g]:.2f}" for g in ["Low", "Lower-mid", "Upper-mid", "High"]) + " \\\\")
rows.append("% per-capita frontier members: " + "; ".join(f"{y}: {', '.join(R['d_percap'][y]['frontier_codes'])}" for y in Y))
rows.append(f"% pooled Spearman {R['d_percap_pooled_spearman']} (high income {R['d_percap_high_income_spearman']}); largest decreases: " + ", ".join(f"{c} ({v:+.2f})" for c, v in R["d_percap_biggest_drop"].items()) + "; largest increases: " + ", ".join(f"{c} ({v:+.2f})" for c, v in R["d_percap_biggest_gain"].items()))
rows.append("% Table S13 (a): year & [n & meta & group & TGR] x (L+LM, UM, H)")
for y in Y:
    e = R["e_meta"][y]
    rows.append(f"{y} & " + " & ".join(f"{e[g]['n']} & {e[g]['meta']:.2f} & {e[g]['group']:.2f} & {e[g]['tgr']:.2f}" for g in ["L+LM", "UM", "H"]) + " \\\\")
p = R["e_meta_pooled"]
rows.append("Pooled & " + " & ".join(f"{p[g]['n']} & {p[g]['meta']:.2f} & {p[g]['group']:.2f} & {p[g]['tgr']:.2f}" for g in ["L+LM", "UM", "H"]) + " \\\\")
for g, key in [("High", "e_meta_high_examples"), ("Upper-middle", "e_meta_um_examples"), ("Low and lower-middle", "e_meta_llm_examples")]:
    rows.append(f"{g} & " + "; ".join(f"{c} {v['meta']:.2f}$\\rightarrow${v['group']:.2f}" for c, v in R[key].items()) + " \\\\")
rows.append("% Spearman meta vs group, pooled: " + ", ".join(f"{g} {p[g]['spearman_meta_group']}" for g in p) + "; median TGR: " + ", ".join(f"{g} {p[g]['tgr_median']}" for g in p))
write("S10_S13.tex", "\n".join(rows))
print("all fragments written to results/tables/")
