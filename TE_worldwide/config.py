"""Shared paths and constants for the TE_worldwide analysis pipeline.

Layout (all paths relative to this file):
  data/            inputs: World Bank extracts (data/wb/*.txt), published scores parsed from the paper and the thesis,
                   OWID COVID-19 extract for the 2020 model
  results/         everything the scripts produce (CSV, JSON, LaTeX table fragments in results/tables/)

Run order (see run_all.sh):
  01_parse_table_s6.py            Table S6 of the supplementary -> data/s6_scores.csv, data/s6_fixed_set.csv
  02_parse_thesis_appendices.py   thesis appendices H-K (text) -> data/thesis_*.csv        [needs the thesis text file]
  03_fetch_worldbank.py           World Bank API -> data/wb/*.txt                          [network; snapshot shipped]
  04_build_dataset.py             -> data/dataset_country_year.csv
  05_validate_extraction.py       -> data/fresh_annual_scores.csv (fresh frontiers vs published scores)
  06_robustness.py                -> results/robustness_results.json (+ score CSVs)          Tables S10-S13
  07_second_stage.py full|reduced|extra|assemble -> results/second_stage_results.json        Table 2, S9, S14, S15
  08_fetch_owid.py                OWID CSV -> data/covid_2020_sample.csv                    [network; extract shipped]
  09_covid_model.py               -> results/covid_tobit_results.json                        Table 3
  10_tables.py                    -> results/tables/*.tex (LaTeX rows for Table 1 and Tables S6-S15)
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
WB = DATA / "wb"
RESULTS = ROOT / "results"
TABLES = RESULTS / "tables"
for p in (DATA, WB, RESULTS, TABLES):
    p.mkdir(parents=True, exist_ok=True)

YEARS = [2015, 2016, 2017, 2018, 2019, 2020]
INPUTS = ["che_gdp", "phys", "beds"]          # current health expenditure (% GDP), physicians per 1,000, beds per 1,000
OUTPUTS = ["le", "inf_surv"]                   # life expectancy at birth, 1 / infant mortality rate
SEED = 20260927                                # seed of every bootstrap in the second stage
SEED_COVID = 2020

# World Bank indicators of the September 2026 extraction (data/wb/<code>.txt)
WB_INDICATORS = {
    "SH.XPD.CHEX.GD.ZS": "che_gdp", "SH.XPD.CHEX.PP.CD": "che_pc_ppp", "SH.MED.PHYS.ZS": "phys", "SH.MED.BEDS.ZS": "beds",
    "SP.DYN.LE00.IN": "le", "SP.DYN.IMRT.IN": "imr", "SP.DYN.CBRT.IN": "cbr", "SP.DYN.CDRT.IN": "cdr",
    "NY.GNP.PCAP.CD": "gni_pc", "SL.TLF.TOTL.IN": "lf", "SE.XPD.TOTL.GD.ZS": "edu", "NY.GDP.PCAP.CD": "gdp_pc",
    "EN.POP.DNST": "dens", "SP.RUR.TOTL.ZS": "rur", "SP.POP.TOTL": "pop",
}

# Second-stage predictors after rescaling (see 07_second_stage.py)
PRED_FULL = ["cbr", "cdr", "gni_k", "lf_m", "edu", "gdp_k", "dens_h", "rur"]
PRED_MAIN = ["cbr", "cdr", "lf_m", "edu", "gdp_k", "dens_h", "rur"]      # main model: GNI per capita dropped (VIF about 50)
LABELS = {
    "cbr": "Crude birth rate (per 1,000 population)", "cdr": "Crude death rate (per 1,000 population)",
    "gni_k": "GNI per capita (thousand USD)", "lf_m": "Labour force (ten million persons)",
    "edu": "Public education expenditure (\\% of GDP)", "gdp_k": "GDP per capita (thousand USD)",
    "dens_h": "Population density (hundred persons per km\\textsuperscript{2})", "rur": "Rural population (\\% of total)",
    "Intercept": "Intercept",
}
# lf_m is stored in millions of persons; the tables report it per ten million (coefficients multiplied by 10)
REPORT_SCALE = {"lf_m": 10.0}


def add_rescaled(df):
    """Rescaled predictors used in every second-stage model."""
    df = df.copy()
    df["gni_k"] = df.gni_pc / 1000.0          # thousand USD
    df["gdp_k"] = df.gdp_pc / 1000.0          # thousand USD
    df["lf_m"] = df.lf / 1e6                  # million persons
    df["dens_h"] = df.dens / 100.0            # hundred persons per km2
    df["pop_m"] = df["pop"] / 1e6
    return df
