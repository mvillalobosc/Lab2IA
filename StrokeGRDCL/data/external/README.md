# data/external

[Español](#español) · [English](#english)

## Español

Insumos que no son los archivos de egresos y que usted tiene que preparar:

| Archivo | Lo necesita | Obligatorio |
|---|---|---|
| `municipal_indicators.csv` | el paso 4, la Tabla 2 y las Tablas S2 a S4 | no |
| `feature_labels.csv` | el paso 9, para las figuras SHAP | no, es cosmético |

El formato de ambos archivos y la lista completa de indicadores están en
[`../README.md`](../README.md). El README del proyecto es
[`../../README.md`](../../README.md).

`feature_labels.example.csv` es un punto de partida construido con las etiquetas
de las figuras del manuscrito. Tiene dos columnas, `feature` y `label`, y 35
filas: la edad, los días de estada, el sexo y códigos CIE-9-CM y CIE-10 con su
nombre en inglés. Algunos códigos aparecen dos veces, truncado y completo (`99.1`
y `99.10`, `89.5` y `89.50`, `96.6` y `96.60`), para cubrir tanto las etiquetas
de la corrida publicada, que perdía el cero final de algunos procedimientos, como
los códigos completos que conserva este pipeline. Cópielo a `feature_labels.csv`
y amplíelo.

En esta carpeta solo se versionan este archivo y las plantillas `*.example.csv`;
el `.gitignore` de la raíz deja fuera `municipal_indicators.csv` y
`feature_labels.csv`.

## English

Inputs that are not the discharge files and that you have to provide:

| File | Needed by | Required |
|---|---|---|
| `municipal_indicators.csv` | step 4, Table 2, Tables S2 to S4 | no |
| `feature_labels.csv` | step 9, the SHAP figures | no, cosmetic |

Formats and the full indicator list are documented in [`../README.md`](../README.md).
The project README is [`../../README.md`](../../README.md).

`feature_labels.example.csv` is a starting point built from the labels used in the
manuscript figures. It has two columns, `feature` and `label`, and 35 rows: age,
length of stay, sex, and ICD-9-CM and ICD-10 codes with their English names. Some
codes appear twice, truncated and complete (`99.1` and `99.10`, `89.5` and
`89.50`, `96.6` and `96.60`), to cover both the labels of the published run, which
lost the trailing zero of some procedure codes, and the complete codes this
pipeline keeps. Copy it to `feature_labels.csv` and extend it.

Nothing in this folder is committed except this file and the `*.example.csv`
templates; the root `.gitignore` keeps `municipal_indicators.csv` and
`feature_labels.csv` out of git.
