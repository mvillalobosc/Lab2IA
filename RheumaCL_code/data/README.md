# data

[Español](#español) · [English](#english)

## Español

El repositorio no trae datos en esta carpeta. La encuesta tiene una fila por persona y no se distribuye con el código. Para el contexto general, revisa el [README del proyecto](../README.md).

| Ruta | Qué es | Quién la escribe |
|---|---|---|
| `raw/data_encuesta_filtrado.xlsx` | La encuesta: una fila por persona y una columna por pregunta, con los nombres `V1`, `V2`, etc. La base usada en el análisis tiene 1.151 filas y 116 columnas. | Se copia a mano |
| `processed/encuesta_modelo.rds` | La base de modelamiento que deja el paso 1. | `R/01_preparar_datos.R` |
| `etiquetas_variables.csv` | Opcional. Textos para las figuras SHAP. | Se escribe a mano |

El nombre y la ubicación del archivo de la encuesta se cambian en `config.R` (`archivo_encuesta`). El `.gitignore` de la raíz del repositorio ignora `raw/` y `processed/`, así que la encuesta no se sube por error.

### Variables que usa el análisis

- **Enfermedades** (una columna SI/NO por enfermedad): V8 artritis idiopática juvenil, V9 artritis psoriática, V10 artritis reumatoide, V11 artrosis, V12 esclerodermia, V13 espondilitis, V14 fibromialgia, V15 lupus, V16 miositis, V17 Raynaud, V18 Sjögren y V20 uveítis.
- **Fuera del análisis**: V5 (comuna, redundante con la región y con 199 valores distintos), V19 (VKH), V21 (vasculitis) y V22 (otra enfermedad reumática). La lista y sus razones están en `config.R` (`variables_excluidas`).
- **Candidatas a predictoras**: todas las demás columnas. Al analizar una enfermedad, las otras 11 enfermedades también son candidatas.

### `etiquetas_variables.csv`

Las figuras SHAP nombran cada variable con el código de su columna one-hot, por ejemplo `V15.SI`. Para mostrar un texto legible se puede crear este archivo con dos columnas, `variable` y `etiqueta`, en UTF-8:

```
variable,etiqueta
V15.SI,Lupus
```

El paso 4 avisa qué variables se quedaron sin etiqueta y las dibuja con su código.

## English

The repository ships no data in this folder. The survey has one row per person and is not distributed with the code. For the general context, see the [project README](../README.md).

| Path | What it is | Written by |
|---|---|---|
| `raw/data_encuesta_filtrado.xlsx` | The survey: one row per person and one column per question, named `V1`, `V2` and so on. The dataset used in the analysis has 1,151 rows and 116 columns. | Copied by hand |
| `processed/encuesta_modelo.rds` | The modelling dataset written by step 1. | `R/01_preparar_datos.R` |
| `etiquetas_variables.csv` | Optional. Texts for the SHAP figures. | Written by hand |

The name and location of the survey file are set in `config.R` (`archivo_encuesta`). The `.gitignore` at the root of the repository ignores `raw/` and `processed/`, so the survey is not committed by mistake.

### Variables used by the analysis

- **Diseases** (one SI/NO column per disease): V8 juvenile idiopathic arthritis, V9 psoriatic arthritis, V10 rheumatoid arthritis, V11 osteoarthritis, V12 scleroderma, V13 spondylitis, V14 fibromyalgia, V15 lupus, V16 myositis, V17 Raynaud, V18 Sjögren and V20 uveitis.
- **Left out of the analysis**: V5 (commune, redundant with the region and with 199 distinct values), V19 (VKH), V21 (vasculitis) and V22 (other rheumatic disease). The list and its reasons are in `config.R` (`variables_excluidas`).
- **Candidate predictors**: every other column. When one disease is analysed, the other 11 diseases are candidates too.

### `etiquetas_variables.csv`

The SHAP figures name each variable with the code of its one-hot column, for instance `V15.SI`. To show a readable text, create this file with two columns, `variable` and `etiqueta`, in UTF-8:

```
variable,etiqueta
V15.SI,Lupus
```

Step 4 reports which variables have no label and draws them with their code.
