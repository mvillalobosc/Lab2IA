#!/bin/bash
# Full pipeline of the TE_worldwide analysis (Python 3.11, numpy, pandas, scipy >= 1.9 for the HiGHS solver).
# Steps 02, 03 and 08 need inputs that are not in this folder (thesis text) or network access; their outputs are shipped in
# data/, so the pipeline below runs from the shipped data. Uncomment them to regenerate the inputs.
set -e
cd "$(dirname "$0")"
python3 01_parse_table_s6.py                                                # Table S6 from data/supplementary_TE_worldwide.tex
# python3 02_parse_thesis_appendices.py /path/to/thesis.txt                 # thesis PDF exported as plain text
# python3 03_fetch_worldbank.py                                             # World Bank API (snapshot of 27 Sep 2026 shipped)
python3 04_build_dataset.py
python3 05_validate_extraction.py
python3 06_robustness.py
python3 07_second_stage.py full &                                           # about 20-40 min each; independent, run in parallel
python3 07_second_stage.py reduced &
python3 07_second_stage.py extra &
wait
python3 07_second_stage.py assemble
# python3 08_fetch_owid.py                                                  # downloads owid-covid-data.csv (about 100 MB)
python3 09_covid_model.py
python3 10_tables.py
echo "pipeline finished; see results/"
