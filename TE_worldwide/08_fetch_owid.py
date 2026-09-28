"""Pandemic variables for the 2020 model (Table 3) from the Our World in Data COVID-19 dataset.

Usage: python 08_fetch_owid.py [path/to/owid-covid-data.csv]
Without an argument the script downloads the file (about 100 MB) from
https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/owid-covid-data.csv into data/.
For the 59 countries of the 2020 frontier it extracts
  cases_pm   cumulative confirmed cases per million people on the last reported day of 2020 (31 December 2020)
  deaths_pm  cumulative confirmed deaths per million people on that day
  r_mean     mean over the days of 2020 of the daily effective reproduction number (Arroyo-Marioli et al., 2021, as
             distributed by OWID); r_days = number of days with an estimate (Laos has none)
Output: data/covid_2020_sample.csv (shipped; extraction of 27 September 2026).
"""
import sys, urllib.request
import pandas as pd
from config import DATA

URL = "https://raw.githubusercontent.com/owid/covid-19-data/master/public/data/owid-covid-data.csv"
src = sys.argv[1] if len(sys.argv) > 1 else DATA / "owid-covid-data.csv"
if not (len(sys.argv) > 1) and not src.exists():
    print("downloading", URL); urllib.request.urlretrieve(URL, src)

cols = ["iso_code", "location", "date", "total_cases_per_million", "total_deaths_per_million", "reproduction_rate"]
parts = []
for ch in pd.read_csv(src, usecols=cols, chunksize=200000, dtype={"iso_code": str}):
    ch = ch[(ch.date >= "2020-01-01") & (ch.date <= "2020-12-31") & (~ch.iso_code.str.startswith("OWID", na=False))]
    parts.append(ch)
d = pd.concat(parts)
s = pd.read_csv(DATA / "fresh_annual_scores.csv"); codes = set(s[s.year == 2020].code)
last = d.sort_values("date").groupby("iso_code").last()
rr = d.groupby("iso_code").reproduction_rate.agg(["mean", "count"])
out = pd.DataFrame({"cases_pm": last.total_cases_per_million, "deaths_pm": last.total_deaths_per_million, "r_mean": rr["mean"], "r_days": rr["count"]})
out = out.loc[sorted(c for c in codes if c in out.index)]
out.index.name = "code"
missing = sorted(codes - set(out.index))
print("2020 sample covered:", len(out), "of", len(codes), "| missing:", missing)
print(out.describe().round(2))
out.to_csv(DATA / "covid_2020_sample.csv")
print("saved data/covid_2020_sample.csv")
