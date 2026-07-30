# data/external

Inputs that are not the discharge files and that you have to provide:

| File | Needed by | Required |
|---|---|---|
| `municipal_indicators.csv` | step 4, Table 2, Tables S2 to S4 | no |
| `feature_labels.csv` | step 9, the SHAP figures | no, cosmetic |

Formats and the full indicator list are documented in [`../README.md`](../README.md).

`feature_labels.example.csv` is a starting point built from the labels used in the
manuscript figures. Copy it to `feature_labels.csv` and extend it.

Nothing in this folder is committed except this file and the `*.example.csv`
templates.
