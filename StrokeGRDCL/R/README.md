# StrokeGRDCL/R

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los nueve pasos del pipeline y las cuatro bibliotecas que
comparten. El README del proyecto ([`../README.md`](../README.md)) explica el
método, la configuración y las diferencias con la corrida publicada.

Cada paso es un script autónomo: carga `R/utils.R`, lee `config.yml` con
`load_config()`, abre su registro en `results/logs/<paso>.log` y al terminar
escribe `results/run_metadata_<paso>.txt`. Todos se lanzan desde la carpeta del
proyecto, por ejemplo `Rscript R/05_split_and_screen.R`, porque las rutas de
`config.yml` son relativas a ella. `run_all.R` los corre en orden, cada uno en un
entorno nuevo.

### Pasos

| Script | Lee | Escribe |
|---|---|---|
| `01_ingest_grd.R` | `data/raw/grd/GRD_PUBLICO_<año>.txt` | `data/interim/grd_<año>.parquet`, `results/tables/ingest_summary.csv` |
| `02_clean_and_derive.R` | `data/interim/grd_<año>.parquet` | `data/interim/grd_clean.parquet`, `results/tables/derived_variable_summary.csv` |
| `03_define_outcomes.R` | `data/interim/grd_clean.parquet` | `data/interim/code_long.parquet`, `data/processed/discharges.parquet`, `results/tables/code_inventory.csv`, `results/tables/outcome_counts.csv` |
| `04_municipal_indicators.R` | `data/external/municipal_indicators.csv`, `data/processed/discharges.parquet` | `data/processed/municipal_indicators.parquet`, `results/tables/comuna_match_audit.csv`, `results/tables/municipal_indicators_wide.csv` |
| `05_split_and_screen.R` | `data/processed/discharges.parquet`, `data/interim/code_long.parquet` | `data/processed/split_assignment.parquet`, `results/tables/split_summary.csv`, `imputation_medians.csv`, `screening_all_codes.csv`, `selected_features.csv` |
| `06_build_model_matrix.R` | las salidas de los pasos 3 y 5 | `data/processed/model_matrix.parquet`, `results/tables/model_matrix_columns.csv` |
| `07_select_features.R` | `data/processed/model_matrix.parquet`, `results/tables/model_matrix_columns.csv` | `results/selection/metrics_<escenario>.csv`, `results/selection/frequency_<escenario>.csv`, `results/tables/knn_k_by_scenario.csv` |
| `08_consensus.R` | `results/selection/frequency_<escenario>.csv`, `data/processed/model_matrix.parquet` | `results/tables/consensus_<escenario>.csv`, `consensus_all_scenarios.csv`, `shap_summary_<escenario>.csv`, y en `results/final_model/` los archivos `<escenario>_coefficients.csv`, `<escenario>_shap_values.csv` y `<escenario>_shap_features.csv` |
| `09_tables_and_figures.R` | las métricas del paso 7, los SHAP del paso 8, `discharges.parquet`, `municipal_indicators.parquet` (opcional) y `data/external/feature_labels.csv` (opcional) | en `results/tables/`: `hypervolume.csv`, las Tablas 1, S1 y 2 en `.csv` y `.tex`, `tableS2_S4_municipal_profiles.csv`, `episodes_by_municipality.csv` y `record_flow.tex`; en `results/figures/`: `figure_shap_<escenario>.pdf`, `figure3_episodes_by_municipality.pdf` y `figureS<i>_subtype_<comuna>.pdf` |

Los pasos 1, 2, 3 y 5 también agregan filas a `results/tables/record_flow.csv`,
que registra cuántos registros quedan después de cada regla. Ningún paso borra
ese archivo, así que conviene eliminarlo antes de repetir esos pasos.

Los pasos 7 y 8 aceptan uno o más nombres de escenario como argumentos (por
ejemplo `Rscript R/08_consensus.R D1_ACV_GENERAL`); sin argumentos procesan los
nueve escenarios de `config.yml`. El paso 9 omite, con un aviso en el registro,
lo que no puede construir: sin las métricas del paso 7 no arma las Tablas 1 y S1,
sin los tres archivos SHAP de un escenario no dibuja su figura y sin
`municipal_indicators.parquet` omite la Tabla 2 y las Tablas S2 a S4.

### Bibliotecas

Estos archivos solo definen funciones; ninguno corre análisis por sí solo.

| Archivo | Qué contiene |
|---|---|
| `utils.R` | carga de la configuración y creación de las carpetas de trabajo, registro con hora, conexión a DuckDB con los límites de memoria e hilos de `config.yml`, normalización de nombres de comuna en R y en SQL, patrones CIE-10 de los resultados, métricas de clasificación, pliegues estratificados, el registro de flujo (`record_flow_append`) y la copia del entorno (`save_run_metadata`) |
| `lib_learners.R` | los tres modelos (Lasso con `glmnet`, Random Forest con `ranger` en un solo hilo y KNN con `caret::knn3` sobre predictores estandarizados) detrás de una misma interfaz, las reglas de selección configurables y la validación cruzada fuera de pliegue que los evalúa |
| `lib_hypervolume.R` | el indicador de hipervolumen: filtro de no dominados, cálculo exacto por rebanadas y los modos `mean` y `front`; lo usa el paso 9 |
| `lib_shap.R` | valores SHAP exactos del modelo lineal final con verificación de aditividad, el resumen por variable, las etiquetas de `feature_labels.csv` y la figura SHAP; lo usan los pasos 8 y 9 |

### Paquetes por script

`utils.R` usa `yaml`, `DBI` y `duckdb`. Además, el paso 1 usa `data.table`,
`lubridate` y `arrow` (y `readr` solo si un año viene en UTF-16), el paso 4 usa
`arrow`, el paso 7 usa `caret`, `glmnet` y `ranger`, el paso 8 usa `glmnet` y el
paso 9 usa `ggplot2`. Si falta un paquete, `require_pkgs()` detiene el paso y
muestra la llamada a `install.packages()` para instalarlo.

## English

This folder holds the nine pipeline steps and the four libraries they share. The
project README ([`../README.md`](../README.md)) explains the method, the
configuration and the differences from the published run.

Every step is a standalone script: it sources `R/utils.R`, reads `config.yml`
with `load_config()`, opens its log in `results/logs/<step>.log` and, when it
finishes, writes `results/run_metadata_<step>.txt`. All of them are launched from
the project folder, for example `Rscript R/05_split_and_screen.R`, because the
paths in `config.yml` are relative to it. `run_all.R` runs them in order, each in
a fresh environment.

### Steps

| Script | Reads | Writes |
|---|---|---|
| `01_ingest_grd.R` | `data/raw/grd/GRD_PUBLICO_<year>.txt` | `data/interim/grd_<year>.parquet`, `results/tables/ingest_summary.csv` |
| `02_clean_and_derive.R` | `data/interim/grd_<year>.parquet` | `data/interim/grd_clean.parquet`, `results/tables/derived_variable_summary.csv` |
| `03_define_outcomes.R` | `data/interim/grd_clean.parquet` | `data/interim/code_long.parquet`, `data/processed/discharges.parquet`, `results/tables/code_inventory.csv`, `results/tables/outcome_counts.csv` |
| `04_municipal_indicators.R` | `data/external/municipal_indicators.csv`, `data/processed/discharges.parquet` | `data/processed/municipal_indicators.parquet`, `results/tables/comuna_match_audit.csv`, `results/tables/municipal_indicators_wide.csv` |
| `05_split_and_screen.R` | `data/processed/discharges.parquet`, `data/interim/code_long.parquet` | `data/processed/split_assignment.parquet`, `results/tables/split_summary.csv`, `imputation_medians.csv`, `screening_all_codes.csv`, `selected_features.csv` |
| `06_build_model_matrix.R` | the outputs of steps 3 and 5 | `data/processed/model_matrix.parquet`, `results/tables/model_matrix_columns.csv` |
| `07_select_features.R` | `data/processed/model_matrix.parquet`, `results/tables/model_matrix_columns.csv` | `results/selection/metrics_<scenario>.csv`, `results/selection/frequency_<scenario>.csv`, `results/tables/knn_k_by_scenario.csv` |
| `08_consensus.R` | `results/selection/frequency_<scenario>.csv`, `data/processed/model_matrix.parquet` | `results/tables/consensus_<scenario>.csv`, `consensus_all_scenarios.csv`, `shap_summary_<scenario>.csv`, and in `results/final_model/` the files `<scenario>_coefficients.csv`, `<scenario>_shap_values.csv` and `<scenario>_shap_features.csv` |
| `09_tables_and_figures.R` | the step 7 metrics, the step 8 SHAP files, `discharges.parquet`, `municipal_indicators.parquet` (optional) and `data/external/feature_labels.csv` (optional) | in `results/tables/`: `hypervolume.csv`, Tables 1, S1 and 2 as `.csv` and `.tex`, `tableS2_S4_municipal_profiles.csv`, `episodes_by_municipality.csv` and `record_flow.tex`; in `results/figures/`: `figure_shap_<scenario>.pdf`, `figure3_episodes_by_municipality.pdf` and `figureS<i>_subtype_<comuna>.pdf` |

Steps 1, 2, 3 and 5 also append rows to `results/tables/record_flow.csv`, which
records how many records remain after each rule. No step deletes that file, so
remove it before re-running those steps.

Steps 7 and 8 accept one or more scenario names as arguments (for example
`Rscript R/08_consensus.R D1_ACV_GENERAL`); without arguments they process the
nine scenarios in `config.yml`. Step 9 skips, with a warning in its log, whatever
it cannot build: without the step 7 metrics it does not build Tables 1 and S1,
without the three SHAP files of a scenario it does not draw that figure, and
without `municipal_indicators.parquet` it skips Table 2 and Tables S2 to S4.

### Libraries

These files only define functions; none of them runs an analysis on its own.

| File | Contents |
|---|---|
| `utils.R` | configuration loading and creation of the working folders, timestamped logging, the DuckDB connection with the memory and thread limits of `config.yml`, comuna name normalisation in R and in SQL, the ICD-10 outcome patterns, classification metrics, stratified folds, the record flow (`record_flow_append`) and the environment copy (`save_run_metadata`) |
| `lib_learners.R` | the three models (Lasso with `glmnet`, single-threaded Random Forest with `ranger` and KNN with `caret::knn3` on standardised predictors) behind one interface, the configurable selection rules and the out-of-fold cross-validation that evaluates them |
| `lib_hypervolume.R` | the hypervolume indicator: non-dominated filter, exact slicing computation and the `mean` and `front` modes; used by step 9 |
| `lib_shap.R` | exact SHAP values of the final linear model with an additivity check, the per-feature summary, the labels from `feature_labels.csv` and the SHAP figure; used by steps 8 and 9 |

### Packages by script

`utils.R` uses `yaml`, `DBI` and `duckdb`. On top of that, step 1 uses
`data.table`, `lubridate` and `arrow` (and `readr` only when a year comes in
UTF-16), step 4 uses `arrow`, step 7 uses `caret`, `glmnet` and `ranger`, step 8
uses `glmnet` and step 9 uses `ggplot2`. When a package is missing,
`require_pkgs()` stops the step and prints the `install.packages()` call that
installs it.
