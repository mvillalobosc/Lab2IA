# Data

No data is committed to this repository. Everything the pipeline needs is either
downloaded from an open portal or produced by the pipeline itself.

```
data/
├── raw/grd/        GRD_PUBLICO_2019.txt ... GRD_PUBLICO_2024.txt   (you download)
├── external/       municipal_indicators.csv, feature_labels.csv     (you provide)
├── interim/        rebuilt by steps 1 to 3, safe to delete
└── processed/      rebuilt by steps 3 to 6, safe to delete
```

## 1. Hospital discharge records (required)

Source: open data portal of the National Health Fund (FONASA) of Chile,
<https://datosabiertos.fonasa.cl>.

Download the yearly DRG files for 2019 to 2024 and place them, uncompressed, in
`data/raw/grd/` with their original names:

```
data/raw/grd/GRD_PUBLICO_2019.txt
data/raw/grd/GRD_PUBLICO_2020.txt
data/raw/grd/GRD_PUBLICO_2021.txt
data/raw/grd/GRD_PUBLICO_2022.txt
data/raw/grd/GRD_PUBLICO_2023.txt
data/raw/grd/GRD_PUBLICO_2024.txt
```

Roughly 4 GB of text in total. The files are pipe-delimited with a header row and
about 129 columns. Their encoding is not consistent across years, which is why
step 1 detects it per file rather than assuming one.

The columns the pipeline actually reads:

| Column | Use |
|---|---|
| `FECHA_NACIMIENTO`, `FECHA_INGRESO`, `FECHAALTA` | age, length of stay, date consistency |
| `SEXO` | derived binary sex |
| `COMUNA` | territorial linkage and comuna dummies |
| `DIAGNOSTICO1` | principal diagnosis, the D1 hierarchy |
| `DIAGNOSTICO2` ... `DIAGNOSTICO35` | secondary diagnoses, the D2 hierarchy |
| `PROCEDIMIENTO1` ... `PROCEDIMIENTO30` | procedures |

Everything else is carried through step 2 and dropped at step 3.

If the file names or the year range change, edit `ingest` in `config.yml` instead
of the scripts.

## 2. Municipal indicators (optional, needed for Table 2 and Tables S2 to S4)

Step 4 does not extract the indicators from the raw survey files: it consumes an
already tabulated tidy CSV and takes care of the part that has to be auditable,
namely matching comuna names between sources. Save it as
`data/external/municipal_indicators.csv`:

```csv
comuna,indicator,value_pct,source
Puente Alto,Public health system coverage,80.32,CASEN 2022
Puente Alto,Prevalence of hypertension,9.94,CASEN 2022
Puente Alto,Population aged 65 or older,11.72,Census 2024
Coquimbo,Public health system coverage,89.27,CASEN 2022
...
```

Rules:

- One row per comuna and indicator. Duplicates stop the step with an error.
- `value_pct` is a percentage, not a fraction: 80.32, not 0.8032.
- Missing values are reported and stay missing. They are never imputed.
- `comuna` may be written in any casing, with or without accents, and with the
  mojibake that the discharge files sometimes contain. Names are normalised on
  both sides before matching, then matched exactly, then by Levenshtein distance
  up to `linkage$max_levenshtein`. Ambiguous nearest neighbours are refused
  rather than guessed. Every decision is written to
  `results/tables/comuna_match_audit.csv`.

The indicators reported in the manuscript, from the health module of the CASEN
2022 survey (<https://observatorio.ministeriodesarrollosocial.gob.cl>) and the
2024 Population and Housing Census (<https://www.ine.gob.cl>), aggregated to
comuna level as proportions:

*From CASEN 2022:* public health system coverage, private health insurance
coverage, hypertension, diabetes mellitus, acute myocardial infarction,
cataracts, self-reported ischaemic stroke.

*From the 2024 Census:* population aged 65 or older, women, low schooling,
illiteracy, disability, internet access, overcrowded dwellings, substandard
housing, dwellings without piped water, dwellings without sanitation, dwellings
without electricity.

Note that these indicators are descriptive. They are not added to the model
matrix, which is what the published run did: the only territorial features the
models see are the comuna dummies.

## 3. Feature labels (optional, cosmetic)

`data/external/feature_labels.csv` turns raw column names into readable ones in
the SHAP figures drawn by step 9, so that `PROC_87_03` prints as `Head CT (87.03)`.

Copy `feature_labels.example.csv` to `feature_labels.csv` and extend it. Rows can
be keyed either by the full column name (`PROC_87_03`) or by the bare code
(`87.03`), which is usually easier because the prefix of a column depends on
where the code was found during screening. Anything not listed keeps its raw
name, so an incomplete file is harmless.

## 4. Privacy

The discharge records are published in irreversibly anonymised form: they carry
an encrypted patient identifier and no directly or indirectly identifiable
personal data. The pipeline drops the encrypted identifier at step 3 and never
writes it to any result file. The unit of analysis is the discharge, not the
person, so repeated admissions by the same patient cannot be identified or
excluded.
