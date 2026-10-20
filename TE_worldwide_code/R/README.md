# TE_worldwide_code/R

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los scripts del pipeline. Cada paso empieza con `source(file.path("R", "00_setup.R"))`, así que se corre desde la carpeta del proyecto (la que tiene `run_all.R`); `run_all.R` los corre en orden, cada uno en un entorno nuevo. El README del proyecto es [`../README.md`](../README.md).

### Archivos de apoyo

| Archivo | Qué hace |
|---|---|
| `00_setup.R` | comprueba y carga `lpSolve`, `AER` y `sandwich`; define las rutas (`data/`, `data/raw/`, `results/`, `results/tables/`, que crea si falta) y los cuatro archivos de entrada (`DATABASE`, `WB_FILE`, `SCORES_FILE`, `COVID_FILE`); fija los años 2015 a 2020, los insumos (`che_gdp`, `phys`, `beds`) y productos (`le`, `inf_surv`) de DEA, las semillas, los tamaños de bootstrap, la agrupación de ingresos de la metafrontera (ingreso bajo y medio bajo juntos), los predictores de segunda etapa y sus etiquetas LaTeX; define `add_rescaled()` y carga `functions.R`. Se detiene si no encuentra `data/raw/` |
| `functions.R` | los estimadores: `dea_input()` (DEA radial orientado a insumos, CRS o VRS, como programas lineales con `lpSolve`), `fit_tobit()` y `tobit_boot()` (Tobit censurado en 0 y 1 con bootstrap por casos, intervalos percentiles al 95 % y valores p por aproximación normal), `ols_hc1()`, `fit_truncreg()` (regresión normal truncada por máxima verosimilitud), `sw_algorithm1()` y `sw_algorithm2()` (Simar y Wilson 2007, sobre la distancia de Shephard 1/puntaje), `vif()` y funciones de formato para las tablas |

`add_rescaled()` crea las versiones reescaladas de los predictores que usan todos los modelos de segunda etapa: `gni_k` y `gdp_k` (miles de USD), `lf_10m` (diez millones de personas), `dens_h` (cientos de personas por km²) y `pop_m` (millones de personas, solo para la Tabla S9).

### Pasos

| Script | Lee | Escribe |
|---|---|---|
| `01_download_worldbank.R` (opcional, internet, paquete `WDI`) | la lista de los 120 países de `data/raw/published_scores_2024.csv` y, para comparar, la instantánea `data/raw/worldbank_2026-09-27.csv` | `data/raw/worldbank_<fecha de hoy>.csv`; nunca sobrescribe la instantánea |
| `02_download_owid.R` (opcional, internet) | el CSV de Our World in Data, descargado a una carpeta temporal, y los países de 2020 de `published_scores_2024.csv` | `data/raw/covid_2020_owid.csv` (lo sobrescribe) |
| `03_build_dataset.R` | los tres archivos de `data/raw/` | `data/dataset_country_year.csv` |
| `04_validate_extraction.R` | la base | `results/fresh_annual_scores.csv` |
| `05_reference_sets_and_robustness.R` | `results/fresh_annual_scores.csv` | `results/robustness.rds`, `results/robustness_scores.csv` |
| `06_second_stage.R` | `results/fresh_annual_scores.csv` | `results/second_stage.rds`, `results/second_stage_coefficients.csv`, `results/sw2_bias_corrected_scores.csv` |
| `07_covid_model.R` | la base | `results/covid_model.rds`, `results/covid_2020_model_data.csv` |
| `08_tables.R` | los tres `.rds` de `results/` y la base | los 15 fragmentos de `results/tables/`, que también imprime en la consola |
| `09_figure_S1_workflow.R` | la base | `results/Figure_S1.png` |

Varios pasos revisan con `stopifnot` que las dimensiones sean las del artículo (720 filas y 120 países en la extracción del Banco Mundial, 466 país-año en los puntajes publicados, 59 países en las variables de la pandemia, 445 observaciones en la segunda etapa, 56 de ellas en la frontera). Si los datos cambian, esos controles detienen el paso.

`04_validate_extraction.R` imprime, por año, la correlación de Spearman y de Pearson entre los puntajes publicados y los reestimados, la diferencia absoluta media y cuántos países están en la frontera publicada, en la reestimada y en ambas; esas cifras se citan en la Sección 2.7 del artículo. `06_second_stage.R` es el paso más lento (unos 3 a 4 minutos) por los 5.000 bootstrap de cada modelo Tobit.

## English

This folder holds the pipeline scripts. Every step starts with `source(file.path("R", "00_setup.R"))`, so it runs from the project folder (the one that holds `run_all.R`); `run_all.R` runs them in order, each in a fresh environment. The project README is [`../README.md`](../README.md).

### Support files

| File | What it does |
|---|---|
| `00_setup.R` | checks and loads `lpSolve`, `AER` and `sandwich`; defines the paths (`data/`, `data/raw/`, `results/`, `results/tables/`, which it creates if missing) and the four input files (`DATABASE`, `WB_FILE`, `SCORES_FILE`, `COVID_FILE`); sets the years 2015 to 2020, the DEA inputs (`che_gdp`, `phys`, `beds`) and outputs (`le`, `inf_surv`), the seeds, the bootstrap sizes, the income grouping of the metafrontier (low and lower-middle income together), the second-stage predictors and their LaTeX labels; defines `add_rescaled()` and sources `functions.R`. It stops if it cannot find `data/raw/` |
| `functions.R` | the estimators: `dea_input()` (radial input-oriented DEA, CRS or VRS, as linear programmes with `lpSolve`), `fit_tobit()` and `tobit_boot()` (Tobit censored at 0 and 1 with case-resampling bootstrap, 95% percentile intervals and p-values from the normal approximation), `ols_hc1()`, `fit_truncreg()` (truncated normal regression by maximum likelihood), `sw_algorithm1()` and `sw_algorithm2()` (Simar and Wilson 2007, on the Shephard distance 1/score), `vif()` and formatting helpers for the tables |

`add_rescaled()` creates the rescaled predictors that every second-stage model uses: `gni_k` and `gdp_k` (thousand USD), `lf_10m` (ten million persons), `dens_h` (hundred persons per km²) and `pop_m` (million persons, only for Table S9).

### Steps

| Script | Reads | Writes |
|---|---|---|
| `01_download_worldbank.R` (optional, internet, `WDI` package) | the list of 120 countries in `data/raw/published_scores_2024.csv` and, for comparison, the snapshot `data/raw/worldbank_2026-09-27.csv` | `data/raw/worldbank_<today's date>.csv`; it never overwrites the snapshot |
| `02_download_owid.R` (optional, internet) | the Our World in Data CSV, downloaded to a temporary folder, and the 2020 countries of `published_scores_2024.csv` | `data/raw/covid_2020_owid.csv` (it overwrites it) |
| `03_build_dataset.R` | the three files in `data/raw/` | `data/dataset_country_year.csv` |
| `04_validate_extraction.R` | the database | `results/fresh_annual_scores.csv` |
| `05_reference_sets_and_robustness.R` | `results/fresh_annual_scores.csv` | `results/robustness.rds`, `results/robustness_scores.csv` |
| `06_second_stage.R` | `results/fresh_annual_scores.csv` | `results/second_stage.rds`, `results/second_stage_coefficients.csv`, `results/sw2_bias_corrected_scores.csv` |
| `07_covid_model.R` | the database | `results/covid_model.rds`, `results/covid_2020_model_data.csv` |
| `08_tables.R` | the three `.rds` files in `results/` and the database | the 15 fragments in `results/tables/`, which it also prints to the console |
| `09_figure_S1_workflow.R` | the database | `results/Figure_S1.png` |

Several steps check with `stopifnot` that the dimensions are those of the article (720 rows and 120 countries in the World Bank extraction, 466 country-years in the published scores, 59 countries in the pandemic variables, 445 observations in the second stage, 56 of them on the frontier). If the data change, those checks stop the step.

`04_validate_extraction.R` prints, by year, the Spearman and Pearson correlations between the published and the re-estimated scores, the mean absolute difference and how many countries are on the published frontier, on the re-estimated one and on both; the article quotes those figures in Section 2.7. `06_second_stage.R` is the slowest step (about 3 to 4 minutes) because of the 5,000 bootstrap replicates of every Tobit model.
