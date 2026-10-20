# Data

[Español](#español) · [English](#english)

## Español

Este repositorio no guarda datos. Lo que necesita el pipeline se descarga de un
portal abierto o lo produce el propio pipeline. El README del proyecto está en
[`../README.md`](../README.md).

```
data/
├── README.md
├── raw/grd/        GRD_PUBLICO_2019.txt ... GRD_PUBLICO_2024.txt   (usted los descarga)
├── external/       municipal_indicators.csv, feature_labels.csv     (usted los prepara)
├── interim/        lo rehacen los pasos 1 a 3, se puede borrar
└── processed/      lo rehacen los pasos 3 a 6, se puede borrar
```

`load_config()` crea `interim/` y `processed/` (y las carpetas de `results/`),
pero no `raw/grd/`: esa carpeta hay que crearla a mano antes de copiar los
archivos. En el repositorio solo están `README.md`, `external/README.md` y
`external/feature_labels.example.csv`; el `.gitignore` de la raíz deja fuera de
git `raw/`, `interim/`, `processed/` y los dos archivos que usted crea en
`external/`.

### 1. Registros de egresos hospitalarios (obligatorio)

Fuente: portal de datos abiertos del Fondo Nacional de Salud (FONASA) de Chile,
<https://datosabiertos.fonasa.cl>.

Descargue los archivos GRD anuales de 2019 a 2024 y déjelos, sin comprimir, en
`data/raw/grd/` con sus nombres originales:

```
data/raw/grd/GRD_PUBLICO_2019.txt
data/raw/grd/GRD_PUBLICO_2020.txt
data/raw/grd/GRD_PUBLICO_2021.txt
data/raw/grd/GRD_PUBLICO_2022.txt
data/raw/grd/GRD_PUBLICO_2023.txt
data/raw/grd/GRD_PUBLICO_2024.txt
```

Suman unos 4 GB de texto. Los archivos están delimitados por `|`, traen una fila
de encabezado y cerca de 129 columnas. Su codificación no es la misma todos los
años, por eso el paso 1 la detecta archivo por archivo en vez de suponer una.

Las columnas que el pipeline lee de verdad:

| Columna | Uso |
|---|---|
| `FECHA_NACIMIENTO`, `FECHA_INGRESO`, `FECHAALTA` | edad, días de estada, consistencia de fechas |
| `SEXO` | sexo binario derivado |
| `COMUNA` | vínculo territorial y dummies de comuna |
| `DIAGNOSTICO1` | diagnóstico principal, la jerarquía D1 |
| `DIAGNOSTICO2` ... `DIAGNOSTICO35` | diagnósticos secundarios, la jerarquía D2 |
| `PROCEDIMIENTO1` ... `PROCEDIMIENTO30` | procedimientos |

Las demás columnas pasan por el paso 2 y se descartan en el paso 3.

Si cambian los nombres de archivo o el rango de años, edite `ingest` en
`config.yml` en vez de los scripts.

### 2. Indicadores comunales (opcional, necesarios para la Tabla 2 y las Tablas S2 a S4)

El paso 4 no extrae los indicadores de los archivos crudos de las encuestas:
consume un CSV ordenado ya tabulado y se encarga de la parte que tiene que ser
auditable, que es emparejar los nombres de comuna entre fuentes. Guárdelo como
`data/external/municipal_indicators.csv`:

```csv
comuna,indicator,value_pct,source
Puente Alto,Public health system coverage,80.32,CASEN 2022
Puente Alto,Prevalence of hypertension,9.94,CASEN 2022
Puente Alto,Population aged 65 or older,11.72,Census 2024
Coquimbo,Public health system coverage,89.27,CASEN 2022
...
```

Reglas:

- Una fila por comuna e indicador. Las filas duplicadas detienen el paso con un
  error.
- `value_pct` es un porcentaje, no una fracción: 80.32, no 0.8032.
- Los valores faltantes se informan y siguen faltando. Nunca se imputan.
- `comuna` puede venir en mayúsculas o minúsculas, con o sin tildes y con los
  caracteres mal codificados que a veces traen los archivos de egresos. Los
  nombres se normalizan en ambos lados antes de emparejar, luego se emparejan de
  forma exacta y después por distancia de Levenshtein hasta
  `linkage$max_levenshtein`. Cuando el vecino más cercano es ambiguo, el paso lo
  rechaza en vez de adivinar. Cada decisión queda en
  `results/tables/comuna_match_audit.csv`.

Los indicadores que informa el manuscrito, del módulo de salud de la encuesta
CASEN 2022 (<https://observatorio.ministeriodesarrollosocial.gob.cl>) y del Censo
de Población y Vivienda 2024 (<https://www.ine.gob.cl>), agregados a nivel de
comuna como proporciones:

*De CASEN 2022:* cobertura del sistema público de salud, cobertura de seguro de
salud privado, hipertensión, diabetes mellitus, infarto agudo al miocardio,
cataratas y ACV isquémico autoinformado.

*Del Censo 2024:* población de 65 años o más, mujeres, baja escolaridad,
analfabetismo, discapacidad, acceso a internet, viviendas con hacinamiento,
viviendas precarias, viviendas sin agua por cañería, viviendas sin saneamiento y
viviendas sin electricidad.

Estos indicadores son descriptivos. No entran a la matriz de modelos, y la
corrida publicada tampoco los usaba ahí: las únicas variables territoriales que
ven los modelos son las dummies de comuna.

### 3. Etiquetas de variables (opcional, cosmético)

`data/external/feature_labels.csv` convierte los nombres crudos de columna en
nombres legibles en las figuras SHAP que dibuja el paso 9, para que `PROC_87_03`
aparezca como `Head CT (87.03)`.

Copie `feature_labels.example.csv` a `feature_labels.csv` y amplíelo. Las filas
pueden usar el nombre completo de la columna (`PROC_87_03`) o el código solo
(`87.03`), que suele ser más fácil porque el prefijo de una columna depende de
dónde se encontró el código durante el tamizaje. Lo que no aparezca conserva su
nombre crudo, así que un archivo incompleto no causa problemas.

### 4. Privacidad

Los registros de egresos se publican anonimizados de forma irreversible: traen un
identificador de paciente encriptado y ningún dato personal que identifique de
forma directa o indirecta. El pipeline descarta el identificador encriptado en el
paso 3 y nunca lo escribe en un archivo de resultados. La unidad de análisis es
el egreso, no la persona, así que los ingresos repetidos de un mismo paciente no
se pueden identificar ni excluir.

## English

No data is committed to this repository. Everything the pipeline needs is either
downloaded from an open portal or produced by the pipeline itself. The project
README is [`../README.md`](../README.md).

```
data/
├── README.md
├── raw/grd/        GRD_PUBLICO_2019.txt ... GRD_PUBLICO_2024.txt   (you download)
├── external/       municipal_indicators.csv, feature_labels.csv     (you provide)
├── interim/        rebuilt by steps 1 to 3, safe to delete
└── processed/      rebuilt by steps 3 to 6, safe to delete
```

`load_config()` creates `interim/` and `processed/` (and the `results/` folders),
but not `raw/grd/`: create that folder by hand before copying the files. The
repository only tracks `README.md`, `external/README.md` and
`external/feature_labels.example.csv`; the root `.gitignore` keeps `raw/`,
`interim/`, `processed/` and the two files you create in `external/` out of git.

### 1. Hospital discharge records (required)

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

### 2. Municipal indicators (optional, needed for Table 2 and Tables S2 to S4)

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

These indicators are descriptive. They are not added to the model matrix, and
the published run did not add them either: the only territorial features the
models see are the comuna dummies.

### 3. Feature labels (optional, cosmetic)

`data/external/feature_labels.csv` turns raw column names into readable ones in
the SHAP figures drawn by step 9, so that `PROC_87_03` prints as `Head CT (87.03)`.

Copy `feature_labels.example.csv` to `feature_labels.csv` and extend it. Rows can
be keyed either by the full column name (`PROC_87_03`) or by the bare code
(`87.03`), which is usually easier because the prefix of a column depends on
where the code was found during screening. Anything not listed keeps its raw
name, so an incomplete file is harmless.

### 4. Privacy

The discharge records are published in irreversibly anonymised form: they carry
an encrypted patient identifier and no directly or indirectly identifiable
personal data. The pipeline drops the encrypted identifier at step 3 and never
writes it to any result file. The unit of analysis is the discharge, not the
person, so repeated admissions by the same patient cannot be identified or
excluded.
