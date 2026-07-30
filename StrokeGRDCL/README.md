# stroke-drg-chile

Reproducible pipeline for the study *Machine learning characterisation of stroke
in Chile using Diagnosis-Related Group records, 2019-2024*.

The workflow takes the yearly hospital discharge files published by the National
Health Fund (FONASA), identifies stroke episodes by ICD-10 code, screens roughly
ten thousand candidate diagnoses and procedures, and characterises nine
analytical scenarios through a consensus of three feature selection models over
500 balanced resamples. Models are used for feature selection only, never for
individual clinical prediction.

Only fields that any DRG or case-mix discharge system already contains are used:
coded diagnoses, coded procedures, basic demographics, length of stay and a
residence identifier. The pipeline is therefore portable to comparable
administrative data in other countries.

---

## Contents

```
stroke-drg-chile/
├── config.yml                     every path, threshold and parameter
├── run_all.R                      sequences the nine R steps
├── R/
│   ├── utils.R                    configuration, logging, DuckDB, metrics
│   ├── lib_learners.R             the three models behind one interface
│   ├── 01_ingest_grd.R            raw text to parquet, per year
│   ├── 02_clean_and_derive.R      cleaning, deduplication, derived variables
│   ├── 03_define_outcomes.R       case definition and long code table
│   ├── 04_municipal_indicators.R  territorial linkage (optional)
│   ├── 05_split_and_screen.R      70/30 partition, chi-square screening
│   ├── 06_build_model_matrix.R    indicator columns and comuna dummies
│   ├── 07_select_features.R       resampling and multimodel selection
│   ├── 08_consensus.R             consensus index, final Lasso, SHAP values
│   ├── 09_tables_and_figures.R    manuscript tables and all figures
│   ├── lib_hypervolume.R          hypervolume indicator
│   └── lib_shap.R                 exact SHAP values and the SHAP figures
└── data/                          not committed, see data/README.md
```

---

## Quick start

**Requirements.** R 4.1 or later, and nothing else. One runtime, ten packages,
all on CRAN:

```r
install.packages(c("DBI", "duckdb", "arrow", "data.table", "lubridate", "yaml",
                   "glmnet", "ranger", "caret", "ggplot2", "readr"))
```

`readr` is only used if a year turns out to be UTF-16. Everything else is either
base R or one of those ten.

**Data.** Download the six yearly files into `data/raw/grd/`. See
[`data/README.md`](data/README.md).

**Run.** Always from the repository root.

```bash
Rscript run_all.R --list          # what the steps are
Rscript run_all.R                 # the whole pipeline, steps 1 to 9
```

or step by step, which is what you want the first time:

```bash
Rscript run_all.R --to 6          # ingestion through model matrix
Rscript R/07_select_features.R    # selection, the long step
Rscript R/08_consensus.R          # consensus, final Lasso, SHAP values
Rscript R/09_tables_and_figures.R # hypervolume, tables, all figures
```

Step 7 accepts a scenario name, so a long run can be split across sessions or
machines:

```bash
Rscript R/07_select_features.R D1_ACV_GENERAL
Rscript R/07_select_features.R D1_HEM_VS_ISQ
```

Every step writes a timestamped log to `results/logs/` and a copy of the
environment that produced it to `results/run_metadata_<step>.txt`.

**Expect roughly:** 40 to 90 minutes for step 1 (about 4 GB of text), 20 to 40
minutes for steps 2 to 6, and 3 to 6 hours for step 7 on a four-core machine.
Steps 8 and 9 take minutes.

---

## The pipeline

| Step | Does | Main output |
|---|---|---|
| 1 | reads each year with encoding detection, parses dates and numerics, keeps codes as text | `data/interim/grd_<year>.parquet` |
| 2 | drops empty rows and inconsistent dates, deduplicates, derives age, length of stay and binary sex | `data/interim/grd_clean.parquet` |
| 3 | applies the ICD-10 case definition, unpivots all code columns into a long table | `data/processed/discharges.parquet`, `data/interim/code_long.parquet` |
| 4 | links municipal indicators by normalised name plus Levenshtein distance | `data/processed/municipal_indicators.parquet` |
| 5 | stratified 70/30 partition, then chi-square screening inside the development subset | `results/tables/selected_features.csv` |
| 6 | builds the indicator columns, the comuna dummies and the analysis matrix | `data/processed/model_matrix.parquet` |
| 7 | 500 balanced resamples, three models on each, metrics and selection frequencies | `results/selection/*.csv` |
| 8 | consensus index, final class-weighted Lasso, exact SHAP values | `results/tables/consensus_*.csv`, `results/final_model/*.csv` |
| 9 | hypervolume, then Table 1, Table S1, Table 2 and every figure | `results/tables/*.csv` and `.tex`, `results/figures/*` |

Every intermediate file is parquet and every heavy operation runs inside DuckDB,
so R never holds the 5.8-million-row table in memory.

### Which output feeds which part of the manuscript

| Manuscript element | Produced by |
|---|---|
| Record flow (5 808 542 to 5 801 438) | `results/tables/record_flow.csv` |
| Table 1, model comparison | step 9, `table1_model_comparison.csv` / `.tex` |
| Table 2, municipal indicators | step 9, `table2_municipal_indicators.csv` / `.tex` |
| Table S1, all three models | step 9, `tableS1_all_models.csv` / `.tex` |
| Tables S2 to S4, municipal profiles | step 9, `tableS2_S4_municipal_profiles.csv` |
| Figure 1, workflow | drawn by hand, not generated |
| Figure 2 and Figures S4 to S11, SHAP | step 8 computes, step 9 draws |
| Figure 3, episodes by municipality | step 9 |
| Figures S1 to S3, subtype by municipality | step 9 |

---

## Configuration

Nothing is hard-coded in the scripts. The switches that change results rather
than plumbing:

```yaml
case_definition:
  mode: "manuscript"                          # or "extended"
  exclude_outcome_codes_from_predictors: true
model_matrix:
  provenance_aware_indicators: false
  min_comuna_records: 0
resampling:
  n_replicates: 500
  n_per_class: 100
models:
  lasso:
    selection_rule: "nonzero"
  random_forest:
    selection_rule: "top_k"                   # or "above_mean", "positive"
  knn:
    selection_rule: "top_k"                   # or "auc_above", "all_retained"
hypervolume:
  mode: "mean"                                # or "front"
```

Each is documented in place in `config.yml`, with a note on which value
reproduces the published run.

### Reproducibility

- Sampling uses R's RNG with an explicit per-replicate seed, so the same seed
  regenerates the same 500 resamples. The original drew them with
  `ORDER BY random()` inside DuckDB, which `set.seed()` in R does not control.
- The 70/30 partition and the subsample of the final fit rank records by
  `HASH(RECORD_ID, seed)` rather than by `random()`, so the result does not depend
  on the thread count.
- Random Forest runs single-threaded, which is what makes its seed meaningful.
- The three models see the same resamples and the same fold assignment, so a
  difference between models is a difference between models.
- p-values are compared on the log10 scale. At the threshold this study uses
  (5e-100) both the raw and the adjusted p-value underflow to exactly zero in
  double precision and stop being rankable.

---

## Differences between this code and the published run

This section is the reason to read the README before the code. The scripts that
were handed over consisted of `Base de datos.Rmd` and `KNN.Rmd`: the Lasso, the
Random Forest, the hypervolume, the SHAP step, the 70/30 partition and the
CASEN/Census linkage were not among them, and are reimplemented here from the
Methods section. Where a decision could not be recovered from the manuscript, the
choice made here is documented in the file that makes it.

Four of the differences are substantive.

### 1. Table 1 and Table S1 do not match the per-replicate output files

Averaging the 500 replicates in the delivered `resultados_knn_500iter_*.csv`
reproduces the precision column of the KNN rows of Table S1 in all nine
scenarios, and reproduces sensitivity, F1 and accuracy in only four.

| Scenario | Table S1, KNN | Recomputed from the CSV |
|---|---|---|
| Stroke, principal | 0.9541 / 0.7822 / 0.7678 / 0.7652 | 0.9541 / **0.5979 / 0.7190 / 0.7829** |
| Stroke, secondary | 0.9395 / 0.9114 / 0.8898 / 0.8870 | 0.9395 / **0.3993 / 0.5466 / 0.6858** |
| Haemorrhagic, principal | 0.9497 / 0.8905 / 0.8715 / 0.8692 | 0.9497 / **0.4633 / 0.6040 / 0.7180** |
| Haemorrhagic, secondary | 0.9565 / 0.3249 / 0.4758 / 0.6544 | 0.9565 / 0.3249 / 0.4758 / 0.6544 |
| Ischaemic, principal | 0.9596 / 0.8241 / 0.8010 / 0.7951 | 0.9596 / **0.6714 / 0.7773 / 0.8201** |
| Ischaemic, secondary | 0.9417 / 0.4361 / 0.5788 / 0.7031 | 0.9418 / 0.4361 / 0.5788 / 0.7031 |
| Unspecified, principal | 0.9191 / 0.6779 / 0.6629 / 0.6556 | 0.9191 / **0.6734 / 0.7641 / 0.8040** |
| Unspecified, secondary | 0.8606 / 0.4363 / 0.5611 / 0.6789 | 0.8606 / 0.4363 / 0.5611 / 0.6790 |
| Haemorrhagic vs ischaemic | 0.6574 / 0.8475 / 0.7304 / 0.6891 | 0.6574 / 0.8475 / 0.7304 / 0.6891 |

The mismatching triples are not random: they reappear elsewhere in the same
tables. `0.7822 / 0.7678 / 0.7652` is also the RF row of "Haemorrhagic versus
ischaemic" in Table S1. `0.3249 / 0.4758 / 0.6544`, which belongs to KNN on
haemorrhagic secondary, is also the RLM row of "Haemorrhagic stroke, principal" in
Table 1. `0.6734 / 0.7641 / 0.8040`, which belongs to KNN on unspecified
principal, is also the RLM row of "Stroke, principal diagnosis" in Table 1. That
pattern is the signature of a join in which the sensitivity, F1 and accuracy
columns were attached with a shifted row index while precision stayed correct.

Only KNN can be checked, because the Lasso and Random Forest per-replicate files
were not in the delivered archive. The same assembly step produced all three sets
of rows, so both tables need regenerating and the model ranking they support needs
re-examining.

The hypervolume column has an independent problem: it reports exactly 0.0625 for
four scenarios whose metric vectors differ substantially, and 0.0625 is 0.5 to the
fourth power. A hypervolume cannot be insensitive to the point it is computed
from.

Step 9 rebuilds both tables from `results/selection/metrics_*.csv` and recomputes
the hypervolume from the same files, with the reference point and the mode stated
in the configuration. Neither table is ever transcribed by hand again.

### 2. The case definition in the code is not the one in the Methods section

The Methods section states cerebral infarction I63, intracerebral haemorrhage I61
and unspecified stroke I64. The delivered code uses:

```sql
ischaemic    ^I63 OR ^I65 OR ^I66
haemorrhagic ^I60 OR ^I61 OR ^I62
unspecified  ^I64
```

The chi-square filter then excludes only `I63`, `I61` and `I64` from the candidate
predictors, so `I60.9` and `I62.0` remain features while also defining the
haemorrhagic outcome. They are present in the delivered frequency files as
`DIAG2_35_I60_9` and `DIAG2_35_I62_0`, and they are the top two features of
Supplementary Figure S11.

The consequence is that "subdural and subarachnoid haemorrhage characterised the
haemorrhagic subtype" is partly circular under the definition the code actually
used: a record coded I62.0 is haemorrhagic by construction. Under the definition
the Methods section states, where haemorrhagic is I61 only, the same finding is
legitimate and reads as a co-occurring bleed.

I65 and I66 are also questionable as ischaemic stroke: they code occlusion and
stenosis of cerebral and precerebral arteries *without* infarction.

`case_definition$mode` selects between the two. The default is `manuscript`, and
`extended` reproduces the published run. Independently,
`exclude_outcome_codes_from_predictors` (default `true`) removes every code family
that defines the active outcome from the candidate set, which closes the leak in
either mode. Setting it to `false` reproduces the published behaviour. Both flags
are recorded in `results/run_metadata_*.txt` for every run.

### 3. Procedure codes ending in zero were corrupted

`Base de datos.Rmd` includes `PROCEDIMIENTO1` to `PROCEDIMIENTO11` in the list of
numeric columns:

```r
cols_num <- c(paste0("PESORN", 1:4), paste0("PROCEDIMIENTO", 1:11), ...)
```

ICD-9-CM procedure codes are not numbers. After a round trip through double
precision, 99.10 (injection of thrombolytic agent) becomes 99.1 and 89.50 becomes
89.5, while the same codes stay intact in `PROCEDIMIENTO12` to `PROCEDIMIENTO30`,
which were left as text. One code therefore becomes two different strings
depending on which column it landed in, and the indicator built from it is
undercounted.

The effect is visible in the manuscript itself: Supplementary Figure S11 labels
its features "Thrombolytic injection (99.1)" and "Non-surgical heart and vessel
examination (89.5)", neither of which is a complete ICD-9-CM code. Thrombolysis is
one of the study's headline findings for the ischaemic subtype, so the counts
behind it are worth rebuilding.

Codes are kept as character everywhere here, and no diagnosis or procedure column
is ever passed through `as.numeric`.

### 4. Two of the three selection frequencies are degenerate

The consensus index is the mean of the three per-model selection frequencies, so
it only carries information if each model's per-resample selection is a genuine
subset of the candidate features. Two of the three are not.

*KNN.* The original recorded `rownames(varImp(model)$importance)`, which is every
column that survived the near-zero-variance filter, without ever looking at the
values. The counts therefore measure survival of a variance filter, not
importance. It shows in the delivered files: dozens of features sit at exactly
500 out of 500 in `frecuencia_variables_knn_*.csv`, including things like
`PROC_90_39` that have no particular reason to be selected in every single
resample.

*Random Forest.* The obvious rule, impurity importance above zero, is almost
always true. Measured on a resample of the same shape as the real ones, 200 rows
and 122 columns after the variance filter, a forest of 500 trees gives strictly
positive importance to **122 of 122** columns.

*KNN, second attempt.* `caret::filterVarImp` reports the larger of AUC and
1 - AUC, so its score never falls below 0.5 and a 0.5 cut-off selects **114 of
122**.

With two frequencies pinned near 1 for everything, the consensus index is
effectively the Lasso frequency plus a constant, and the "consensus of three
complementary models" is one model with two abstentions.

The rule each model uses is now configurable, and the defaults are a non-zero
coefficient for the Lasso and a rank rule for the other two: a feature counts as
selected in a resample when it is among that model's top `consensus$top_n_features`
by importance. This is the usual stability-selection reading and it is comparable
across models. On the same synthetic resample the defaults select 6, 30 and 30 of
122 instead of 10, 122 and 114, all three still recover every planted informative
feature, and the consensus index spreads across 0.19 to 1.00 instead of piling up
at the top. `selection_rule: "positive"` and `selection_rule: "all_retained"`
reproduce the original behaviour.

### Smaller differences

| What | Published run | Here |
|---|---|---|
| Age | `DATE_DIFF('year', birth, admission)`, which counts calendar-year boundaries and overstates age by one year for anyone whose birthday falls after the admission date | completed years |
| Age 0 | mapped to missing, then median-imputed, which pushes obstetric and neonatal discharges to the middle of the adult distribution | kept as valid, since age 0 means under one year. `cleaning$treat_age_zero_as_missing` restores the old behaviour |
| Missing principal diagnosis | `REGEXP_MATCHES(NULL, ...)` returns NULL, so `WHERE outcome = 0` silently dropped those records from the control pool | outcome flags are 0, not NULL; only the haemorrhagic-versus-ischaemic contrast keeps NULLs, where they mean "not comparable" |
| Imputation of age and length of stay | median of each resample, so the imputed value depends on the resample | median of the development subset, computed once in step 5 |
| 70/30 partition | not present in the delivered code, although the Methods section reports it | step 5, stratified, hash-based |
| Chi-square screening | one SQL query per code and per outcome, roughly twenty thousand scans of a 5.8-million-row table, then `chisq.test()` on each 2x2 table | one grouped join over the long code table, closed-form statistic, vectorised |
| Screening scope | run over the whole dataset | development subset only, as the Methods section describes |
| Number of k candidates for KNN | `seq(3, 25, by = 2)`, twelve values; the delivered result files have no `K_usado` column, so they come from an earlier version that retuned k inside every replicate | five values, as the Methods section reports, tuned once per scenario and then held fixed |
| Records coded with both subtypes | assigned to ischaemic by the order of the `CASE WHEN` | excluded from the subtype contrast as not comparable |
| Comuna dummies | one per distinct raw string, so `CONCEPCION`, `CONCEPCIÓN` and `CONCEPCI<D3>N` produced separate columns; the delivered code repairs this for the dummy names but the same normalisation is not applied consistently upstream | one normalisation function, used for the dummies, the linkage and the figures |
| Territorial linkage | not present in the delivered code | step 4, with an audit file for every matching decision |

### One provenance note

The delivered `Base de datos.Rmd` recomputes the chi-square screening, but the
`origen` column that the published feature names imply (`DIAG1`, `DIAG2_35`,
`PROC`) is created by a branch that only fires when the column is absent, and it
would produce `D` and `PROC` rather than the observed prefixes. The published run
therefore read its significant-code list from a pre-existing CSV
(`chi2_sig_corregido_final.csv`) rather than from the code as delivered. This
matters for the "code available from the corresponding author on request"
statement: what was handed over is a reconstruction of the analysis, not the
script that produced the published numbers. The pipeline here regenerates the
screening from the raw files, so its feature list is derivable end to end.

---

## What has been verified

The numerical core was checked against independent references rather than only
read over:

| Component | Check | Result |
|---|---|---|
| chi-square screening | statistic, p-value and minimum expected count against `chisq.test(correct = FALSE)` on 300 random 2x2 tables | agrees to 1e-8 |
| log-scale p-values | a table of the size this study produces | chi-square 4 019 873, log10(p) = -872 908, where the raw p-value is exactly 0 in double precision |
| integer overflow | the product of the four marginals with integer inputs | caught and fixed; the function coerces to double first |
| hypervolume | 2, 3 and 4 dimensions against values computed by inclusion and exclusion, plus a non-origin reference point and points below the reference | exact |
| SHAP additivity | base value plus contributions against the linear predictor | maximum error 1.8e-15, and the script refuses to write output above 1e-8 |
| 70/30 partition | the same split recomputed with 1 and with 8 DuckDB threads | identical record sets |
| SQL dialect | every generated statement run against DuckDB 1.5.5 on a synthetic table: `union_by_name`, `QUALIFY` deduplication over all payload columns, `HASH` ranking, `DATE_DIFF` with `STRFTIME`, the unpivot, `REGEXP_MATCHES`, the comuna normalisation chain, `* EXCLUDE`, `COPY ... COMPRESSION ZSTD` | all execute |
| SHAP figure | structure of the built plot object: two boxes per feature, both group colours, zero line, ordering, and which rows collapse to flat markers | 14 boxes for 7 features, 10 of them flat, exactly the binary indicators |
| the three models | fitted on synthetic resamples of the real shape, with three informative features planted | all three recover them; Lasso and Random Forest reproduce exactly from a seed |
| metrics and folds | precision, sensitivity, F1, accuracy and AUC against hand-computed values; folds for reproducibility and stratification | exact |
| comuna normalisation | `CONCEPCION`, `CONCEPCIÓN` and `CONCEPCI<D3>N` | collapse to one key |

What has not been run is the pipeline on the real files, which needs the 4 GB of
FONASA data. Runtimes in this README are estimates.

---

## Method summary

**Case identification.** ICD-10 codes per `case_definition$mode`. The principal
diagnosis (`DIAGNOSTICO1`) is distinguished from the secondary diagnoses
(`DIAGNOSTICO2` to `DIAGNOSTICO35`), a contrast referred to throughout as the
diagnostic hierarchy.

**Screening.** Records are split 70/30, stratified by stroke presence. Inside the
development subset, every distinct diagnosis and procedure code is tested against
stroke presence with a Pearson chi-square test on a 2x2 table, without continuity
correction, discarding tables with any expected count below five. p-values are
Bonferroni-adjusted over the number of codes tested and compared on the log10
scale against 5e-100. This is a pragmatic high-dimensional screening rule, not
formal control of the family-wise error rate.

**Selection.** For each of nine scenarios, 500 resamples of 100 cases and 100
controls are drawn from the development subset. On each resample, three models are
fitted: a Lasso-penalised logistic model (`glmnet`, lambda by internal
cross-validation), a Random Forest (`ranger`, 500 trees, mtry = sqrt(p)) and
K-nearest neighbours (`caret::knn3` on standardised predictors). Selection
frequency is the share of resamples in which a model selected the feature, and the
consensus index is the mean of the three frequencies. The 30 highest-consensus
features are retained per scenario.

**Comparison.** Precision, sensitivity, F1 and accuracy come from pooled
out-of-fold predictions of a shared stratified 10-fold split, and are combined by
the hypervolume indicator, which is monotone with respect to Pareto dominance and
needs no weights. These are diagnostics of the selection workflow. They are not
claims about clinical utility.

**Interpretation.** A class-weighted Lasso is fitted on the development subset
restricted to the consensus features. Because the model is linear, SHAP values are
exact and closed form, `phi_ij = beta_j * (x_ij - E[x_j])`, on the log-odds scale,
so no approximation and no external SHAP implementation are involved. Step 8
verifies that the contributions add up to the linear predictor and refuses to write
anything if they do not.

**Reading the SHAP figures.** A binary indicator in a linear model can take only
two SHAP values, so its row is two thin markers, while a continuous feature such
as age spreads into a box and whiskers. The width of a row reflects the value range
of the feature, not its importance. The ordering does that.

---

## Limitations inherited from the data source

DRG records carry no NIHSS score, no symptom onset time, no prehospital delay, no
imaging detail, no treatment timing, no functional status at discharge and no
follow-up. Severity can only be approximated through procedures such as
ventilation and critical care. Coding practice varies between facilities and over
time, and an unspecified code may reflect clinical uncertainty, incomplete
documentation or local coding behaviour.

The unit of analysis is the discharge, not a uniquely linked person: repeated
admissions cannot be excluded, and episode counts are not counts of individuals.
Municipal indicators are aggregate and cannot be transferred to individuals
without risking ecological bias. Absolute counts by comuna are not incidence: no
population denominators and no age standardisation are applied.

---

## Citation

See [`CITATION.cff`](CITATION.cff). The author list and the Zenodo DOI still need
completing before release.

## Licence

Code under the MIT licence, see [`LICENSE`](LICENSE). The data sources carry their
own terms of use.
