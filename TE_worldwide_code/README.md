# TE_worldwide_code

[Español](#español) · [English](#english)

## Español

Este proyecto contiene el pipeline en R del artículo *How much does the reference set matter? Benchmarking national health-system efficiency on a global frontier, 2015-2020* (Valenzuela-Silva et al.). El código reproduce las reestimaciones, los análisis de robustez y los modelos de segunda etapa del artículo a partir de dos fuentes: los puntajes de eficiencia técnica publicados en la tesis fuente (Valenzuela-Silva 2024, apéndices H a K, con dos decimales) y una extracción del Banco Mundial del 27 de septiembre de 2026.

El análisis principal estima con DEA (análisis envolvente de datos) fronteras anuales para 120 países entre 2015 y 2020, con tres insumos (gasto corriente en salud como porcentaje del PIB, médicos por 1.000 habitantes y camas hospitalarias por 1.000 habitantes) y dos productos (esperanza de vida al nacer y supervivencia infantil, que es el inverso de la mortalidad infantil). Sobre esa base, el pipeline compara conjuntos de referencia (frontera anual, frontera agrupada intertemporal, muestra fija de 39 países, gasto per cápita como insumo y fronteras por grupo de ingreso con razones de brecha tecnológica), ajusta modelos de segunda etapa (Tobit con bootstrap, mínimos cuadrados con errores HC1 y los algoritmos 1 y 2 de Simar y Wilson), estima un modelo Tobit de 2020 con variables de la pandemia y escribe los fragmentos LaTeX de todas las tablas del artículo y la Figura S1.

El proyecto trae los datos de entrada y los resultados ya generados, así que corre completo sin internet.

### Contenido

```
TE_worldwide_code/
├── LICENSE
├── README.md
├── run_all.R                            corre los pasos en orden
├── R/                                   ver R/README.md
│   ├── 00_setup.R                       paquetes, rutas, constantes y semillas
│   ├── functions.R                      estimadores DEA y de segunda etapa
│   ├── 01_download_worldbank.R          opcional: vuelve a descargar los indicadores del Banco Mundial
│   ├── 02_download_owid.R               opcional: rehace las variables de la pandemia desde OWID
│   ├── 03_build_dataset.R               arma la base de datos del análisis
│   ├── 04_validate_extraction.R         compara la extracción de 2026 con los puntajes publicados
│   ├── 05_reference_sets_and_robustness.R conjuntos de referencia y robustez de la frontera
│   ├── 06_second_stage.R                modelos de segunda etapa
│   ├── 07_covid_model.R                 modelo de la pandemia, 2020
│   ├── 08_tables.R                      fragmentos LaTeX de las tablas
│   └── 09_figure_S1_workflow.R          Figura S1
├── data/                                ver data/README.md
│   ├── dataset_country_year.csv         la base de datos del análisis
│   └── raw/                             las tres fuentes de la base, ver data/raw/README.md
└── results/                             ver results/README.md
    ├── *.csv, *.rds, Figure_S1.png
    └── tables/                          15 fragmentos LaTeX, ver results/tables/README.md
```

### Requisitos

R y tres paquetes de CRAN:

```r
install.packages(c("lpSolve", "AER", "sandwich"))
```

`lpSolve` resuelve los programas lineales de DEA, `AER` ajusta los modelos Tobit (envuelve `survival::survreg`, que se instala con él) y `sandwich` calcula los errores HC1. El paquete `WDI` solo hace falta para el paso 01. Ningún paquete se instala solo: si falta uno, `00_setup.R` se detiene y dice cuál instalar.

La Figura S1 (paso 09) se dibuja con `png(type = "cairo")` y la familia tipográfica `Helvetica`, que el sistema resuelve a Helvetica, Arial o una fuente con las mismas métricas (TeX Gyre Heros, Liberation Sans). Sus etiquetas necesitan una configuración regional UTF-8; si R no está en UTF-8, el script cambia `LC_CTYPE` a `C.UTF-8`.

### Ejecución

```bash
Rscript run_all.R
```

`run_all.R` se puede lanzar desde cualquier carpeta, porque se mueve a la suya. En R o RStudio:

```r
setwd("<carpeta de run_all.R>"); source("run_all.R")
```

Un paso suelto se corre desde la carpeta del proyecto, por ejemplo `Rscript R/04_validate_extraction.R`; desde otra carpeta el script no encuentra `R/00_setup.R` ni `data/raw/` y se detiene. Como `data/` y `results/` vienen completos, cualquier paso desde el 04 se puede correr solo: cada uno lee lo que dejaron los anteriores.

La corrida completa toma unos 4 a 5 minutos en un núcleo. La mayor parte del tiempo se va en el bootstrap de `06_second_stage.R` (unos 3 a 4 minutos) y de `07_covid_model.R` (cerca de un minuto).

Correr `run_all.R` sobrescribe los archivos de `results/`. Si quiere comparar una corrida nueva con la incluida, copie antes la carpeta.

#### Volver a descargar los datos

`run_all.R` empieza con `DOWNLOAD <- FALSE`. Con `TRUE`, antepone los pasos 01 y 02, que necesitan internet:

- `01_download_worldbank.R` descarga los 15 indicadores con el paquete `WDI` y escribe un archivo nuevo, `data/raw/worldbank_<fecha de hoy>.csv`. Nunca sobrescribe la instantánea del artículo (se detiene si el nombre coincide) y muestra, por indicador, cuántas celdas difieren de ella. Para usar el archivo nuevo hay que apuntar `WB_FILE` en `R/00_setup.R` hacia él y volver a correr `run_all.R`.
- `02_download_owid.R` descarga el CSV completo de Our World in Data (unos 100 MB, a una carpeta temporal) y **sobrescribe** `data/raw/covid_2020_owid.csv`, que es el archivo que usó el artículo. OWID sigue actualizando sus datos, así que el resultado puede cambiar; copie el archivo antes si quiere conservarlo.

### Los pasos

| Paso | Qué hace | Escribe | Partes del artículo |
|---|---|---|---|
| `01_download_worldbank.R` | descarga los 15 indicadores del Banco Mundial para los 120 países, 2015-2020 (opcional) | `data/raw/worldbank_<fecha>.csv` | Tabla S3 (lista de indicadores) |
| `02_download_owid.R` | rehace las variables de la pandemia de los 59 países de la frontera de 2020 (opcional) | `data/raw/covid_2020_owid.csv` | insumo de la Tabla S17 |
| `03_build_dataset.R` | une las tres fuentes en una base de 720 filas (120 países por 6 años, 466 del análisis principal), interpola el único dato imputado (médicos de Albania 2018) y revisa dimensiones y faltantes | `data/dataset_country_year.csv` | base de los pasos siguientes |
| `04_validate_extraction.R` | reestima por año las fronteras IO-CRS e IO-VRS con la extracción de 2026 y las compara con los puntajes publicados | `results/fresh_annual_scores.csv` | Sección 2.7 y apéndice de datos |
| `05_reference_sets_and_robustness.R` | describe las fronteras publicadas y calcula la eficiencia de escala, la frontera agrupada, la muestra fija de 39 países, la frontera con gasto per cápita y las fronteras por grupo de ingreso con sus razones de brecha tecnológica | `results/robustness.rds`, `results/robustness_scores.csv` | Tablas 1 y 2, S6 a S8 y S10 a S13 |
| `06_second_stage.R` | ajusta Tobit con bootstrap, mínimos cuadrados con errores HC1, Simar-Wilson 1 y 2, Tobit sin Singapur y Tobit por año sobre los 445 país-año con todas las covariables | `results/second_stage.rds`, `results/second_stage_coefficients.csv`, `results/sw2_bias_corrected_scores.csv` | Tabla 3, S9, S14 y S15 |
| `07_covid_model.R` | ajusta los modelos Tobit de 2020 sobre casos, muertes y número reproductivo (58 países con las tres variables, porque Laos no tiene número reproductivo, y 59 sin él) | `results/covid_model.rds`, `results/covid_2020_model_data.csv` | Tabla S17 |
| `08_tables.R` | escribe las filas LaTeX de cada tabla y los números citados en sus notas | `results/tables/*.tex` | todas las tablas |
| `09_figure_S1_workflow.R` | dibuja el diagrama de flujo del estudio | `results/Figure_S1.png` | Figura S1 |

[`results/tables/README.md`](results/tables/README.md) indica qué tabla del artículo sale de cada fragmento.

### Reproducibilidad

Las semillas y los tamaños de bootstrap están en `R/00_setup.R`: `SEED = 20260927` para los bootstrap de la segunda etapa, `SEED_COVID = 2020` para el modelo de la pandemia, 5.000 réplicas en cada Tobit (`B_TOBIT`), 2.000 en el algoritmo 1 de Simar y Wilson (`L_SW1`) y 100 y 1.000 en el algoritmo 2 (`L1_SW2`, `L2_SW2`).

En una corrida con R 4.3.3 en Linux, `run_all.R` volvió a producir `results/` tal como está en el repositorio: los CSV, `Figure_S1.png` y los 15 fragmentos `.tex` salieron idénticos byte a byte, y los tres `.rds` con el mismo contenido (solo cambia su compresión).

Las medias y medianas anuales de los puntajes publicados que muestran las Tablas 1, S10 y S16 se recalculan aquí desde los valores con dos decimales, así que pueden diferir hasta en 0,005 de los valores sin redondear de la tesis que informa el artículo. Los fragmentos lo anotan en una línea de comentario.

### Lo que conviene saber antes de usar los resultados

- Los coeficientes de Simar y Wilson modelan la distancia de Shephard, 1/puntaje, que es mayor o igual a 1: un coeficiente negativo significa un puntaje de eficiencia mayor. El signo es el opuesto al de los modelos Tobit y de mínimos cuadrados, que modelan el puntaje.
- La segunda etapa usa los 445 país-año del análisis principal que tienen todas las covariables (a los otros 21 les falta el gasto público en educación); 56 de ellos están en la frontera. El modelo principal omite el INB per cápita por su colinealidad con el PIB per cápita (VIF cercano a 50).
- La Figura S1 describe el flujo completo del estudio fuente, no solo lo que calcula este código: incluye un panel balanceado de 34 países (fijado a mano en el script como `N_PANEL`), la descomposición de Malmquist, pruebas de Kruskal-Wallis y un análisis de sensibilidad iterativo que este pipeline no calcula. Los otros tamaños de muestra de las cajas salen de la base.
- `data/raw/worldbank_2026-09-27.csv` y `data/raw/published_scores_2024.csv` tienen fin de línea CRLF; `read.csv` los lee igual.

### Licencia y cita

El código se distribuye con licencia MIT ([LICENSE](LICENSE)) y la carpeta no trae archivo de cita. Los datos de entrada vienen del Banco Mundial, de Our World in Data y de la tesis fuente, y conservan sus propios términos.

## English

This project holds the R pipeline of the article *How much does the reference set matter? Benchmarking national health-system efficiency on a global frontier, 2015-2020* (Valenzuela-Silva et al.). The code reproduces the re-estimations, robustness analyses and second-stage models of the article from two sources: the technical efficiency scores published in the source thesis (Valenzuela-Silva 2024, appendices H to K, two decimals) and a World Bank extraction of 27 September 2026.

The main analysis estimates annual DEA (data envelopment analysis) frontiers for 120 countries between 2015 and 2020, with three inputs (current health expenditure as a share of GDP, physicians per 1,000 people and hospital beds per 1,000 people) and two outputs (life expectancy at birth and infant survival, the inverse of infant mortality). On that basis the pipeline compares reference sets (annual frontier, pooled intertemporal frontier, fixed sample of 39 countries, per-capita expenditure as input and income-group frontiers with technology gap ratios), fits second-stage models (bootstrapped Tobit, least squares with HC1 errors and Simar and Wilson's Algorithms 1 and 2), estimates a 2020 Tobit model with pandemic variables, and writes the LaTeX fragments of every table of the article and Figure S1.

The project ships its input data and the results already generated, so it runs end to end without internet access.

### Contents

```
TE_worldwide_code/
├── LICENSE
├── README.md
├── run_all.R                            runs the steps in order
├── R/                                   see R/README.md
│   ├── 00_setup.R                       packages, paths, constants and seeds
│   ├── functions.R                      DEA and second-stage estimators
│   ├── 01_download_worldbank.R          optional: downloads the World Bank indicators again
│   ├── 02_download_owid.R               optional: rebuilds the pandemic variables from OWID
│   ├── 03_build_dataset.R               builds the analysis database
│   ├── 04_validate_extraction.R         compares the 2026 extraction with the published scores
│   ├── 05_reference_sets_and_robustness.R reference sets and frontier robustness
│   ├── 06_second_stage.R                second-stage models
│   ├── 07_covid_model.R                 pandemic model, 2020
│   ├── 08_tables.R                      LaTeX fragments of the tables
│   └── 09_figure_S1_workflow.R          Figure S1
├── data/                                see data/README.md
│   ├── dataset_country_year.csv         the analysis database
│   └── raw/                             the three sources of the database, see data/raw/README.md
└── results/                             see results/README.md
    ├── *.csv, *.rds, Figure_S1.png
    └── tables/                          15 LaTeX fragments, see results/tables/README.md
```

### Requirements

R and three CRAN packages:

```r
install.packages(c("lpSolve", "AER", "sandwich"))
```

`lpSolve` solves the DEA linear programmes, `AER` fits the Tobit models (it wraps `survival::survreg`, which is installed with it) and `sandwich` computes the HC1 errors. The `WDI` package is only needed for step 01. No package is installed automatically: when one is missing, `00_setup.R` stops and names it.

Figure S1 (step 09) is drawn with `png(type = "cairo")` and the `Helvetica` font family, which the system resolves to Helvetica, Arial or a metric-compatible font (TeX Gyre Heros, Liberation Sans). Its labels need a UTF-8 locale; when R is not in UTF-8, the script switches `LC_CTYPE` to `C.UTF-8`.

### Running the pipeline

```bash
Rscript run_all.R
```

`run_all.R` can be launched from any folder, because it moves to its own. In R or RStudio:

```r
setwd("<folder of run_all.R>"); source("run_all.R")
```

A single step runs from the project folder, for example `Rscript R/04_validate_extraction.R`; from any other folder the script cannot find `R/00_setup.R` or `data/raw/` and stops. Since `data/` and `results/` ship complete, any step from 04 onwards can run on its own: each one reads what the previous steps left.

The full run takes about 4 to 5 minutes on one core. Almost all of that time goes to the bootstrap of `06_second_stage.R` (about 3 to 4 minutes) and of `07_covid_model.R` (about one minute).

Running `run_all.R` overwrites the files in `results/`. Copy the folder first if you want to compare a new run with the shipped one.

#### Downloading the data again

`run_all.R` starts with `DOWNLOAD <- FALSE`. With `TRUE` it runs steps 01 and 02 first, which need internet access:

- `01_download_worldbank.R` downloads the 15 indicators with the `WDI` package and writes a new file, `data/raw/worldbank_<today's date>.csv`. It never overwrites the snapshot of the article (it stops if the name matches) and reports, per indicator, how many cells differ from it. To use the new file, point `WB_FILE` in `R/00_setup.R` to it and run `run_all.R` again.
- `02_download_owid.R` downloads the full Our World in Data CSV (about 100 MB, to a temporary folder) and **overwrites** `data/raw/covid_2020_owid.csv`, the file the article used. OWID keeps updating its data, so the result can change; copy the file first if you want to keep it.

### The steps

| Step | What it does | Writes | Parts of the article |
|---|---|---|---|
| `01_download_worldbank.R` | downloads the 15 World Bank indicators for the 120 countries, 2015-2020 (optional) | `data/raw/worldbank_<date>.csv` | Table S3 (list of indicators) |
| `02_download_owid.R` | rebuilds the pandemic variables of the 59 countries of the 2020 frontier (optional) | `data/raw/covid_2020_owid.csv` | input of Table S17 |
| `03_build_dataset.R` | joins the three sources into a 720-row database (120 countries by 6 years, 466 in the main analysis), interpolates the only imputed value (physicians of Albania 2018) and checks dimensions and missing values | `data/dataset_country_year.csv` | basis of the following steps |
| `04_validate_extraction.R` | re-estimates the annual IO-CRS and IO-VRS frontiers with the 2026 extraction and compares them with the published scores | `results/fresh_annual_scores.csv` | Section 2.7 and the data appendix |
| `05_reference_sets_and_robustness.R` | describes the published frontiers and computes scale efficiency, the pooled frontier, the fixed sample of 39 countries, the per-capita expenditure frontier and the income-group frontiers with their technology gap ratios | `results/robustness.rds`, `results/robustness_scores.csv` | Tables 1 and 2, S6 to S8 and S10 to S13 |
| `06_second_stage.R` | fits bootstrapped Tobit, least squares with HC1 errors, Simar-Wilson 1 and 2, Tobit without Singapore and year-specific Tobit on the 445 country-years with every covariate | `results/second_stage.rds`, `results/second_stage_coefficients.csv`, `results/sw2_bias_corrected_scores.csv` | Table 3, S9, S14 and S15 |
| `07_covid_model.R` | fits the 2020 Tobit models on cases, deaths and reproduction number (58 countries with the three variables, because Laos has no reproduction number, and 59 without it) | `results/covid_model.rds`, `results/covid_2020_model_data.csv` | Table S17 |
| `08_tables.R` | writes the LaTeX rows of each table and the numbers quoted in their notes | `results/tables/*.tex` | every table |
| `09_figure_S1_workflow.R` | draws the workflow diagram of the study | `results/Figure_S1.png` | Figure S1 |

[`results/tables/README.md`](results/tables/README.md) lists which table of the article comes from each fragment.

### Reproducibility

Seeds and bootstrap sizes are set in `R/00_setup.R`: `SEED = 20260927` for the second-stage bootstraps, `SEED_COVID = 2020` for the pandemic model, 5,000 replicates for every Tobit model (`B_TOBIT`), 2,000 for Simar and Wilson's Algorithm 1 (`L_SW1`) and 100 and 1,000 for Algorithm 2 (`L1_SW2`, `L2_SW2`).

In a run with R 4.3.3 on Linux, `run_all.R` produced `results/` again exactly as it is in the repository: the CSV files, `Figure_S1.png` and the 15 `.tex` fragments came out byte-identical, and the three `.rds` files with the same content (only their compression differs).

The annual means and medians of the published scores shown in Tables 1, S10 and S16 are recomputed here from the two-decimal values, so they can differ by up to 0.005 from the unrounded thesis values that the article reports. The fragments note this in a comment line.

### What to know before using the results

- The Simar and Wilson coefficients model the Shephard distance, 1/score, which is at least 1: a negative coefficient means a higher efficiency score. The sign is the opposite of the Tobit and least squares models, which model the score.
- The second stage uses the 445 country-years of the main analysis that have every covariate (the other 21 lack public education expenditure); 56 of them are on the frontier. The main model drops GNI per capita because of its collinearity with GDP per capita (VIF about 50).
- Figure S1 describes the full workflow of the source study, not only what this code computes: it includes a balanced panel of 34 countries (set by hand in the script as `N_PANEL`), the Malmquist decomposition, Kruskal-Wallis tests and an iterative sensitivity analysis that this pipeline does not compute. The other sample sizes in its boxes come from the database.
- `data/raw/worldbank_2026-09-27.csv` and `data/raw/published_scores_2024.csv` use CRLF line endings; `read.csv` reads them all the same.

### Licence and citation

The code is distributed under the MIT licence ([LICENSE](LICENSE)) and the folder has no citation file. The input data come from the World Bank, Our World in Data and the source thesis, and keep their own terms.
