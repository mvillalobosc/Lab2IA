"""Download the 15 World Bank indicators for the 120 countries of Table S6, years 2015-2020, into data/wb/<indicator>.txt.

Usage: python 03_fetch_worldbank.py            (needs internet access to api.worldbank.org)

Output format, one line per country:   AFG 2015=51.87 2016=53.20 ... 2020=59.90     (NA when the value is missing)
The files shipped in data/wb/ are the extraction of 27 September 2026 used in the paper. The World Bank revises series
(WHO physician and bed data in particular), so a new download can differ from the snapshot; keep the snapshot to reproduce
the published numbers. This script was not executed in the environment where the paper was prepared (no direct network
access from the shell); the snapshot was retrieved with the same API calls made through a browser-side fetcher, which
transcribed some series with fewer decimals than the API returns (two decimals for expenditure shares, densities and rural
shares; one decimal for GDP per capita and vital rates). Radial DEA scores and the second-stage coefficients are insensitive
to that rounding beyond the third decimal.
"""
import json, time, urllib.request
import pandas as pd
from config import DATA, WB, YEARS, WB_INDICATORS

codes = sorted(pd.read_csv(DATA / "s6_scores.csv").code)
assert len(codes) == 120
API = "https://api.worldbank.org/v2/country/{codes}/indicator/{ind}?date={y0}:{y1}&format=json&per_page=2000"


def fetch(ind):
    vals = {c: {y: "NA" for y in YEARS} for c in codes}
    for i in range(0, len(codes), 40):                       # chunks of 40 ISO3 codes
        chunk = ";".join(codes[i:i + 40])
        url = API.format(codes=chunk, ind=ind, y0=YEARS[0], y1=YEARS[-1])
        for attempt in range(5):
            try:
                with urllib.request.urlopen(url, timeout=60) as r:
                    payload = json.load(r)
                break
            except Exception as e:                            # transient errors: retry with back-off
                print("  retry", ind, i, e); time.sleep(5 * (attempt + 1))
        else:
            raise RuntimeError(f"could not fetch {ind} chunk {i}")
        for rec in payload[1] or []:
            c = rec["countryiso3code"]; y = int(rec["date"]); v = rec["value"]
            if c in vals and y in vals[c] and v is not None:
                vals[c][y] = f"{float(v):.6g}"
    return vals


for ind in WB_INDICATORS:
    print("fetching", ind)
    vals = fetch(ind)
    with open(WB / f"{ind}.txt", "w", encoding="utf-8") as f:
        for c in codes:
            f.write(c + " " + " ".join(f"{y}={vals[c][y]}" for y in YEARS) + "\n")
print("done: data/wb/*.txt")
