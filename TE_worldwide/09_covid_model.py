"""Tobit model of the 2020 IO-CRS score on pandemic-related variables (Table 3).

Predictors: cumulative confirmed cases per thousand people, cumulative confirmed deaths per 100,000 people (31 December 2020)
and the mean daily effective reproduction number over 2020, from data/covid_2020_sample.csv (08_fetch_owid.py).
Tobit censored at 0 and 1, case-resampling bootstrap with 500 replications (seed config.SEED_COVID), percentile intervals.
Models: full (three predictors, 58 countries: Laos has no reproduction-number estimate), without R (59), cases only, deaths only.
Output: results/covid_tobit_results.json, results/covid_2020_model_data.csv
"""
import json
import numpy as np, pandas as pd
from scipy.stats import norm, spearmanr
from dea_lib import fit_tobit
from config import DATA, RESULTS, SEED_COVID

rng = np.random.default_rng(SEED_COVID)
s = pd.read_csv(DATA / "fresh_annual_scores.csv")
s20 = s[s.year == 2020][["code", "country", "income", "te_io_crs"]].set_index("code")   # sorted by ISO3 code
c = pd.read_csv(DATA / "covid_2020_sample.csv", index_col=0)
d = s20.join(c)
d["cases_k"] = d.cases_pm / 1000.0    # cases per thousand people
d["deaths_h"] = d.deaths_pm / 10.0    # deaths per 100,000 people
R = {"corr_cases_deaths": float(d.cases_k.corr(d.deaths_h)), "corr_cases_R": float(d.cases_k.corr(d.r_mean)), "corr_deaths_R": float(d.deaths_h.corr(d.r_mean)),
     "spearman_score_cases": float(spearmanr(d.te_io_crs, d.cases_k).correlation), "spearman_score_deaths": float(spearmanr(d.te_io_crs, d.deaths_h).correlation)}


def tob(dd, pr, B=500):
    y = dd.te_io_crs.values; Z = np.column_stack([np.ones(len(dd)), dd[pr].values])
    th = fit_tobit(y, Z); boot = np.zeros((B, len(th)))
    for b in range(B):
        idx = rng.integers(0, len(y), len(y)); boot[b] = fit_tobit(y[idx], Z[idx], x0=th)
    se = boot.std(axis=0, ddof=1); p = 2 * norm.sf(np.abs(th / se)); ci = np.percentile(boot, [2.5, 97.5], axis=0)
    return {n: dict(coef=float(th[i]), se=float(se[i]), p=float(p[i]), ci_lo=float(ci[0, i]), ci_hi=float(ci[1, i])) for i, n in enumerate(["Intercept"] + pr + ["log sigma"])}


dd = d.dropna(subset=["cases_k", "deaths_h", "r_mean"])
R["n_full"] = int(len(dd)); R["n_at_1_full"] = int((dd.te_io_crs >= 1).sum()); R["full"] = tob(dd, ["cases_k", "deaths_h", "r_mean"])
R["n_noR"] = int(len(d)); R["noR"] = tob(d, ["cases_k", "deaths_h"])
R["cases_only"] = tob(d, ["cases_k"]); R["deaths_only"] = tob(d, ["deaths_h"])
R["desc"] = {k: dict(mean=float(d[k].mean()), sd=float(d[k].std()), min=float(d[k].min()), max=float(d[k].max()), n=int(d[k].notna().sum())) for k in ["cases_k", "deaths_h", "r_mean"]}
for k in ["full", "noR", "cases_only", "deaths_only"]:
    print("==", k)
    for n, v in R[k].items():
        print(f"  {n:10s} coef={v['coef']: .4f} se={v['se']:.4f} p={v['p']:.3f} ci=({v['ci_lo']: .4f},{v['ci_hi']: .4f})")
json.dump(R, open(RESULTS / "covid_tobit_results.json", "w"), indent=1)
d.to_csv(RESULTS / "covid_2020_model_data.csv")
print("saved results/covid_tobit_results.json")
