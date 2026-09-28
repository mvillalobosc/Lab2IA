"""Assemble the country-year dataset (data/dataset_country_year.csv) from the World Bank extracts (data/wb/*.txt),
Table S6 (income group, financing model, published IO-CRS score) and the thesis appendices (IO-VRS and OO-VRS scores).

720 rows = 120 countries x 6 years. in_frontier_sample marks the 466 country-years with a published score.
"""
import re, glob, os
import numpy as np, pandas as pd
from config import DATA, WB, YEARS, WB_INDICATORS

rows = []
for f in sorted(glob.glob(str(WB / "*.txt"))):
    ind = os.path.basename(f)[:-4]
    seen = set()
    for line in open(f, encoding="utf-8"):
        parts = line.split()
        if not parts:
            continue
        code = parts[0]
        assert re.fullmatch(r"[A-Z]{3}", code) and code not in seen, (f, line)
        seen.add(code)
        vals = dict(p.split("=") for p in parts[1:])
        assert set(vals) == {str(y) for y in YEARS}, (f, line)
        for y in YEARS:
            rows.append((code, y, ind, np.nan if vals[str(y)] == "NA" else float(vals[str(y)])))
    assert len(seen) == 120, (f, len(seen))
long = pd.DataFrame(rows, columns=["code", "year", "indicator", "value"])
wide = long.pivot_table(index=["code", "year"], columns="indicator", values="value", aggfunc="first").reset_index()
wide.columns.name = None
wide = wide.rename(columns=WB_INDICATORS)
wide["inf_surv"] = 1.0 / wide["imr"]

s6 = pd.read_csv(DATA / "s6_scores.csv")
meta = s6[["code", "country", "income", "financing"]]


def melt(name, col):
    d = pd.read_csv(DATA / f"thesis_{name}.csv", index_col=0)
    d.index.name = "code"
    m = d.reset_index().melt(id_vars="code", var_name="year", value_name=col)
    m["year"] = m["year"].astype(int)
    return m


df = (wide.merge(meta, on="code", how="left")
          .merge(melt("IO_CRS", "te_io_crs"), on=["code", "year"], how="left")
          .merge(melt("IO_VRS", "te_io_vrs"), on=["code", "year"], how="left")
          .merge(melt("OO_VRS", "te_oo_vrs"), on=["code", "year"], how="left"))
df["in_frontier_sample"] = df["te_io_crs"].notna()
sub = df[df.in_frontier_sample]
print("rows:", len(df), "| country-years with a published score:", int(df.in_frontier_sample.sum()))
dea_vars = ["che_gdp", "phys", "beds", "le", "imr"]
print("missing fresh DEA values inside the published sample:", sub[dea_vars].isna().sum().to_dict())
print(sub[sub[dea_vars].isna().any(axis=1)][["code", "year"] + dea_vars].to_string(index=False))
cov = ["cbr", "cdr", "gni_pc", "lf", "edu", "gdp_pc", "dens", "rur"]
print("complete covariate rows inside the sample:", int(sub[cov].notna().all(axis=1).sum()), "of", len(sub), "| missing by variable:", sub[cov].isna().sum().to_dict())
df.to_csv(DATA / "dataset_country_year.csv", index=False)
print("saved data/dataset_country_year.csv")
