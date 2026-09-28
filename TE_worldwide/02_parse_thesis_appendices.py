"""Parse appendices H-K of the source thesis (per-country efficiency scores of the four DEA specifications) into
data/thesis_IO_CRS.csv, thesis_OO_CRS.csv, thesis_IO_VRS.csv, thesis_OO_VRS.csv (rows = ISO3 code, columns = years).

Usage: python 02_parse_thesis_appendices.py path/to/thesis.txt
The text file is the plain-text export of the thesis PDF (Valenzuela Silva, 2024). Each appendix row lists the scores of the
years in which the country was in the model, in the order 2020, 2019, ..., 2015, without placeholders for missing years;
the years present for each country are taken from Table S6 (data/s6_scores.csv, produced by 01_parse_table_s6.py), whose
country sets are identical across the four specifications. The four CSVs are shipped in data/, so this script only needs
to be re-run if the thesis text changes.
"""
import re, sys
import numpy as np, pandas as pd
from config import DATA, YEARS

src = sys.argv[1]
lines = open(src, encoding="utf-8").read().splitlines()
s6 = pd.read_csv(DATA / "s6_scores.csv").set_index("code")
present = {c: [y for y in YEARS if not np.isnan(s6.loc[c, str(y)])] for c in s6.index}

# appendix headers -> output names
APP = {"APÉNDICE H.": "IO_CRS", "APÉNDICE I.": "OO_CRS", "APÉNDICE J.": "IO_VRS", "APÉNDICE K.": "OO_VRS"}
starts = [(i, APP[k]) for i, l in enumerate(lines) for k in APP if l.startswith(k)]
starts.sort()
bounds = [(name, i, (starts[j + 1][0] if j + 1 < len(starts) else next(k for k, l in enumerate(lines) if l.startswith("APÉNDICE L.")))) for j, (i, name) in enumerate(starts)]

row_re = re.compile(r"^([A-Z]{3})\s+(.*?)((?:\s+\d(?:\.\d+)?)+)\s*$")
for name, a, b in bounds:
    tab = {}
    for l in lines[a:b]:
        m = row_re.match(l.strip())
        if not m:
            continue
        code, _, nums = m.groups()
        if code not in present:
            continue
        vals = [float(v) for v in nums.split()]
        yrs = present[code]
        if len(vals) != len(yrs):
            print(f"  WARNING {name} {code}: {len(vals)} values for {len(yrs)} years {yrs}: {vals}")
            continue
        tab[code] = dict(zip(reversed(yrs), vals))     # values are listed 2020 -> 2015
    out = pd.DataFrame.from_dict(tab, orient="index").reindex(columns=YEARS).sort_index()
    out.index.name = ""
    missing = sorted(set(present) - set(tab))
    print(f"{name}: {len(out)} countries parsed, {int(out.notna().sum().sum())} country-years; missing countries: {missing}")
    out.to_csv(DATA / f"thesis_{name}.csv")
    if name == "IO_CRS":
        # the IO-CRS appendix must reproduce Table S6 exactly
        diff = (out[YEARS].values - s6.loc[out.index, [str(y) for y in YEARS]].values)
        print("  max |IO_CRS appendix - Table S6| =", np.nanmax(np.abs(diff)))
print("saved data/thesis_*.csv")
