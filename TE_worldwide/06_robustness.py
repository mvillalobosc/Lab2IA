"""Robustness analyses of the frontier (Supplementary Tables S10-S13, Section 4.4 of the main text).

(a) scale efficiency from the published IO-CRS and IO-VRS scores (main estimation, thesis appendices)
(b) pooled intertemporal frontier: all 466 country-years form one reference set (fresh extraction)
(c) fixed-sample annual frontiers: the 39 countries observed in every year (fresh extraction)
(d) expenditure per capita in PPP dollars instead of the share of GDP (fresh extraction)
(e) income-group frontiers and technology gap ratios (fresh extraction)
Outputs: results/robustness_results.json, results/robustness_scores.csv, results/fixed_sample_scores.csv, results/percap_scores.csv
"""
import json
import numpy as np, pandas as pd
from scipy.stats import spearmanr
from dea_lib import dea_input
from config import DATA, RESULTS, YEARS, INPUTS, OUTPUTS

df = pd.read_csv(DATA / "fresh_annual_scores.csv")
R = {}

# (a) scale efficiency = IO-CRS / IO-VRS on the published scores
df["scale_eff"] = df.te_io_crs / df.te_io_vrs
a = {}
for y in YEARS:
    d = df[df.year == y]
    a[y] = dict(n=len(d), mean_crs=d.te_io_crs.mean(), median_crs=d.te_io_crs.median(), mean_vrs=d.te_io_vrs.mean(), median_vrs=d.te_io_vrs.median(),
                mean_se=d.scale_eff.mean(), median_se=d.scale_eff.median(), frontier_crs=int((d.te_io_crs >= 0.995).sum()), frontier_vrs=int((d.te_io_vrs >= 0.995).sum()),
                frontier_vrs_codes=sorted(d.code[d.te_io_vrs >= 0.995]), spearman_crs_vrs=spearmanr(d.te_io_crs, d.te_io_vrs).correlation,
                se_by_income={g: round(v, 3) for g, v in d.groupby("income").scale_eff.mean().items()})
R["a_scale"] = a
R["a_scale_pooled_income"] = {g: dict(n=len(x), mean_crs=round(x.te_io_crs.mean(), 3), mean_vrs=round(x.te_io_vrs.mean(), 3), mean_se=round(x.scale_eff.mean(), 3),
                                      share_se_below_0_8=round((x.scale_eff < 0.8).mean(), 3)) for g, x in df.groupby("income")}
R["a_lowest_se_countries"] = {c: round(v, 2) for c, v in df.groupby("code").scale_eff.mean().sort_values().head(12).items()}

# (b) pooled intertemporal frontier
df["pooled_crs"] = dea_input(df[INPUTS].values, df[OUTPUTS].values, "crs")
R["b_pooled"] = {y: dict(n=len(d), mean=d.pooled_crs.mean(), median=d.pooled_crs.median(), frontier=int((d.pooled_crs >= 0.9999).sum()),
                         frontier_codes=sorted(d.code[d.pooled_crs >= 0.9999]), spearman_vs_annual_fresh=spearmanr(d.pooled_crs, d.fresh_crs).correlation,
                         spearman_vs_published=spearmanr(d.pooled_crs, d.te_io_crs).correlation) for y, d in df.groupby("year")}
fixed = sorted(set.intersection(*[set(df.code[df.year == y]) for y in YEARS]))
R["fixed_set_n"] = len(fixed)
fx = df[df.code.isin(fixed)]
R["b_pooled_fixed_set"] = {y: dict(mean=round(fx[fx.year == y].pooled_crs.mean(), 3), median=round(fx[fx.year == y].pooled_crs.median(), 3)) for y in YEARS}
kept = sorted(set(df.code[df.year == 2019]) & set(df.code[df.year == 2020]))
R["b_pooled_kept48"] = dict(n=len(kept), mean2019=round(df[(df.year == 2019) & df.code.isin(kept)].pooled_crs.mean(), 3), mean2020=round(df[(df.year == 2020) & df.code.isin(kept)].pooled_crs.mean(), 3))

# (c) fixed-sample annual frontiers
c = {}; fixed_scores = []
for y in YEARS:
    d = fx[fx.year == y].copy()
    d["fixed_crs"] = dea_input(d[INPUTS].values, d[OUTPUTS].values, "crs")
    fixed_scores.append(d)
    c[y] = dict(n=len(d), mean=d.fixed_crs.mean(), median=float(d.fixed_crs.median()), frontier=int((d.fixed_crs >= 0.9999).sum()), frontier_codes=sorted(d.code[d.fixed_crs >= 0.9999]),
                spearman_vs_fresh_full=spearmanr(d.fixed_crs, d.fresh_crs).correlation)
fixed_scores = pd.concat(fixed_scores)
R["c_fixed"] = c
piv = fixed_scores.pivot(index="code", columns="year", values="fixed_crs")
R["c_fixed_rank_corr_consecutive"] = {f"{a_}-{b_}": round(spearmanr(piv[a_], piv[b_]).correlation, 3) for a_, b_ in zip(YEARS[:-1], YEARS[1:])}

# (d) expenditure per capita (PPP) instead of % GDP
d_res = {}; pc_scores = []
for y in YEARS:
    d = df[df.year == y].copy()
    d["pc_crs"] = dea_input(d[["che_pc_ppp", "phys", "beds"]].values, d[OUTPUTS].values, "crs")
    pc_scores.append(d)
    d_res[y] = dict(n=len(d), mean=d.pc_crs.mean(), median=float(d.pc_crs.median()), frontier=int((d.pc_crs >= 0.9999).sum()), frontier_codes=sorted(d.code[d.pc_crs >= 0.9999]),
                    spearman_vs_fresh=spearmanr(d.pc_crs, d.fresh_crs).correlation,
                    mean_by_income={g: round(v, 3) for g, v in d.groupby("income").pc_crs.mean().items()},
                    mean_by_income_gdp={g: round(v, 3) for g, v in d.groupby("income").fresh_crs.mean().items()})
pc_scores = pd.concat(pc_scores)
R["d_percap"] = d_res
diff = (pc_scores.groupby("code").pc_crs.mean() - pc_scores.groupby("code").fresh_crs.mean()).sort_values()
R["d_percap_biggest_drop"] = {k: round(v, 2) for k, v in diff.head(10).items()}
R["d_percap_biggest_gain"] = {k: round(v, 2) for k, v in diff.tail(10).items()}
R["d_percap_pooled_spearman"] = round(spearmanr(pc_scores.pc_crs, pc_scores.fresh_crs).correlation, 3)
hi = pc_scores[pc_scores.income == "High"]
R["d_percap_high_income_spearman"] = round(spearmanr(hi.pc_crs, hi.fresh_crs).correlation, 3)

# (e) metafrontier: group frontiers by income stratum, TGR = global score / group score
grp = {"Low": "L+LM", "Lower-mid": "L+LM", "Upper-mid": "UM", "High": "H"}
df["group"] = df.income.map(grp)
e = {}; meta_rows = []
for y in YEARS:
    d = df[df.year == y].copy()
    d["group_crs"] = np.nan
    for g, dg in d.groupby("group"):
        d.loc[dg.index, "group_crs"] = dea_input(dg[INPUTS].values, dg[OUTPUTS].values, "crs")
    d["tgr"] = d.fresh_crs / d.group_crs
    meta_rows.append(d)
    e[y] = {g: dict(n=len(x), meta=round(x.fresh_crs.mean(), 3), group=round(x.group_crs.mean(), 3), tgr=round(x.tgr.mean(), 3),
                    frontier_group=int((x.group_crs >= 0.9999).sum()), spearman_meta_group=round(spearmanr(x.fresh_crs, x.group_crs).correlation, 3) if len(x) > 3 else None)
            for g, x in d.groupby("group")}
meta = pd.concat(meta_rows)
R["e_meta"] = e
R["e_meta_pooled"] = {g: dict(n=len(x), meta=round(x.fresh_crs.mean(), 3), group=round(x.group_crs.mean(), 3), tgr=round(x.tgr.mean(), 3), tgr_median=round(x.tgr.median(), 3),
                              spearman_meta_group=round(spearmanr(x.fresh_crs, x.group_crs).correlation, 3)) for g, x in meta.groupby("group")}
ex = lambda sub, codes: {c: dict(meta=round(sub[sub.code == c].fresh_crs.mean(), 2), group=round(sub[sub.code == c].group_crs.mean(), 2)) for c in codes if c in set(sub.code)}
R["e_meta_high_examples"] = ex(meta[meta.group == "H"], ["SWE", "FIN", "EST", "JPN", "SGP", "DEU", "CHE", "AUT", "USA"])
R["e_meta_um_examples"] = ex(meta[meta.group == "UM"], ["ARG", "BRA", "CRI", "THA", "MYS", "KAZ", "CHN", "COL", "MEX", "TUR"])
R["e_meta_llm_examples"] = ex(meta[meta.group == "L+LM"], ["NER", "LAO", "BGD", "NPL", "MLI", "BTN", "IDN", "PAK", "MOZ", "RWA", "AFG", "HTI"])
R["e_meta_lowest_group_scores"] = {g: {c: round(v, 2) for c, v in x.groupby("code").group_crs.mean().sort_values().head(6).items()} for g, x in meta.groupby("group")}

meta.to_csv(RESULTS / "robustness_scores.csv", index=False)
fixed_scores[["code", "year", "fixed_crs"]].to_csv(RESULTS / "fixed_sample_scores.csv", index=False)
pc_scores[["code", "year", "pc_crs"]].to_csv(RESULTS / "percap_scores.csv", index=False)


def conv(o):
    if isinstance(o, np.floating): return float(o)
    if isinstance(o, np.integer): return int(o)
    if isinstance(o, dict): return {str(k): conv(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)): return [conv(v) for v in o]
    return o


json.dump(conv(R), open(RESULTS / "robustness_results.json", "w"), indent=1)
print("pooled frontier annual means:", {y: round(v["mean"], 3) for y, v in R["b_pooled"].items()})
print("fixed-sample annual means:", {y: round(v["mean"], 3) for y, v in R["c_fixed"].items()})
print("metafrontier pooled:", R["e_meta_pooled"])
print("saved results/robustness_results.json")
