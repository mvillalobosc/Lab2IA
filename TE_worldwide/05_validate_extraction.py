"""Re-estimate the annual IO-CRS (and IO-VRS) frontiers on the September 2026 extraction, restricted to the published
country sets, and compare them with the published scores (Table S6 / thesis appendices).  Output: data/fresh_annual_scores.csv
with, for each of the 466 country-years, the fresh inputs and outputs, the published scores and the fresh scores.

The comparison statistics printed here are the ones quoted in Supplementary Table S3 (item 7) and Section 3.10.
One cell is imputed: physicians of Albania 2018 are no longer published by the World Bank and are interpolated linearly
between the 2016 and 2019 values.
"""
import numpy as np, pandas as pd
from scipy.stats import spearmanr, pearsonr
from dea_lib import dea_input
from config import DATA, YEARS, INPUTS, OUTPUTS

df = pd.read_csv(DATA / "dataset_country_year.csv")
m = (df.code == "ALB") & (df.year == 2018)
p16 = float(df.loc[(df.code == "ALB") & (df.year == 2016), "phys"].iloc[0]); p19 = float(df.loc[(df.code == "ALB") & (df.year == 2019), "phys"].iloc[0])
df.loc[m, "phys"] = p16 + (p19 - p16) * 2 / 3
print(f"ALB 2018 physicians interpolated: {p16} -> {df.loc[m, 'phys'].iloc[0]:.3f} -> {p19}")
df["inf_surv"] = 1 / df["imr"]
sub = df[df.in_frontier_sample].copy()
assert sub[INPUTS + OUTPUTS].notna().all().all(), "missing DEA variables inside the published sample"
res = []
for y in YEARS:
    d = sub[sub.year == y].copy()
    d["fresh_crs"] = dea_input(d[INPUTS].values, d[OUTPUTS].values, "crs")
    d["fresh_vrs"] = dea_input(d[INPUTS].values, d[OUTPUTS].values, "vrs")
    res.append(d)
    pub, th = d.te_io_crs.values, d.fresh_crs.values
    print(f"{y}: n={len(d)} spearman={spearmanr(pub, th).correlation:.3f} pearson={pearsonr(pub, th)[0]:.3f} MAD={np.mean(np.abs(pub - th)):.3f} "
          f"frontier published={int((pub >= 0.995).sum())} fresh={int((th >= 0.9999).sum())} overlap={len(set(d.code[pub >= 0.995]) & set(d.code[th >= 0.9999]))} "
          f"| VRS spearman={spearmanr(d.te_io_vrs, d.fresh_vrs).correlation:.3f}")
allr = pd.concat(res)
print("pooled spearman:", round(spearmanr(allr.te_io_crs, allr.fresh_crs).correlation, 3), "| pooled MAD:", round(np.mean(np.abs(allr.te_io_crs - allr.fresh_crs)), 3))
allr["diff"] = allr.fresh_crs - allr.te_io_crs
print("largest discrepancies (fresh - published):")
print(allr.reindex(allr["diff"].abs().sort_values(ascending=False).index)[["code", "year", "te_io_crs", "fresh_crs", "phys", "beds"]].head(10).to_string(index=False))
allr.to_csv(DATA / "fresh_annual_scores.csv", index=False)
print("saved data/fresh_annual_scores.csv")
