"""Parse the published IO-CRS scores (Table S6 of supplementary.tex) into data/s6_scores.csv.

Usage: python 01_parse_table_s6.py [path/to/supplementary.tex]
Default path: data/supplementary_TE_worldwide.tex (copy of the submitted supplementary file, which contains Table S6).

No DEA is estimated here; the script re-tabulates the scores already published (frontier composition by year,
2019-2020 transition, fixed set of countries with a score in every year) and prints the checks used in the text.
"""
import re, sys
import numpy as np, pandas as pd
from config import DATA, YEARS

src = sys.argv[1] if len(sys.argv) > 1 else DATA / "supplementary_TE_worldwide.tex"
txt = open(src, encoding="utf-8").read()

# rows of Table S6:  AFG & Afghanistan & Low & Public & 0.62 & 0.59 & 0.45 & -- & -- & -- \\
row_re = re.compile(r"^([A-Z]{3}) & (.+?) & (Low|Lower-mid|Upper-mid|High) & (Public|Mixed|Private) & (.+?) \\\\$", re.M)
rows = []
for m in row_re.finditer(txt):
    code, name, inc, fin, vals = m.groups()
    vals = [v.strip() for v in vals.split("&")]
    assert len(vals) == 6, (code, vals)
    rows.append([code, name.replace("\\&", "&"), inc, fin] + [np.nan if v == "--" else float(v) for v in vals])
df = pd.DataFrame(rows, columns=["code", "country", "income", "financing"] + YEARS)
assert len(df) == 120, len(df)
assert int(df[YEARS].notna().sum().sum()) == 466
print("countries:", len(df), "| country-years:", int(df[YEARS].notna().sum().sum()))
print("countries per year:", df[YEARS].notna().sum().to_dict())
print("annual mean:", df[YEARS].mean().round(3).to_dict())
print("annual median:", df[YEARS].median().round(3).to_dict())

d = df.set_index("code")
frontier = {y: sorted(d.index[d[y] == 1.0]) for y in YEARS}
print("frontier (score = 1.00) by year:", {y: len(v) for y, v in frontier.items()})
p19 = d[d[2019].notna()]; lost = p19[p19[2020].isna()]; kept = p19[p19[2020].notna()]
print(f"2019 model: {len(p19)}; without 2020 score: {len(lost)} (mean 2019 {lost[2019].mean():.3f}); retained: {len(kept)} (2019 {kept[2019].mean():.3f}, 2020 {kept[2020].mean():.3f})")
full = d[d[YEARS].notna().all(axis=1)]
print("countries with a score in every year:", len(full), "| annual mean:", full[YEARS].mean().round(3).to_dict())
df.to_csv(DATA / "s6_scores.csv", index=False)
full.to_csv(DATA / "s6_fixed_set.csv")
print("saved data/s6_scores.csv and data/s6_fixed_set.csv")
