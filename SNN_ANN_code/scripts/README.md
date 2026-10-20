# scripts/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los 13 scripts en R de la revisión, numerados en el orden en que corren. Todos se lanzan desde la raíz del proyecto, porque usan rutas relativas como `data/...` y `scripts/...`, y todos, salvo `00_run_all.R`, fijan la configuración regional `C.UTF-8` al empezar. La forma normal de correrlos es `Rscript scripts/00_run_all.R`; el [README del proyecto](../README.md#reproducing-the-analysis) (en castellano, en [README.es.md](../README.es.md#cómo-reproducir-el-análisis)) explica qué se reconstruye con y sin las exportaciones crudas.

| Script | Argumentos (valores de la revisión) | Lee | Escribe | Paquetes |
|---|---|---|---|---|
| `00_run_all.R` | ninguno | la existencia de `data/raw/Scopus.csv` | nada propio: lanza los demás con `Rscript` y se detiene en el primero que falle | ninguno |
| `01_deduplicate.R` | ninguno | `data/raw/Scopus.csv`, `data/raw/Wos*.xls`, `data/records/record_ids.csv` | `data/processed/corpus.csv` (con resúmenes, no se distribuye), `data/records/records.csv`, `duplicates.csv`, `counts_identification.json` | data.table, readxl, stringi, jsonlite |
| `02_screening_batches.R` | `100 200 20261014` (tamaño de lote, tamaño del piloto, semilla) | `data/processed/corpus.csv` | lotes de texto en `data/processed/`, `data/screening/batch_ids.csv`, `pilot_ids.csv`, `kappa_sample/kappa_ids.csv` | data.table |
| `03_screening_agreement.R` | archivos del revisor 1, `--`, archivos del revisor 2 | los TSV que recibe | nada: imprime acuerdo, kappa y desacuerdos en la consola | data.table |
| `04_check_screening_batches.R` | ninguno | `data/screening/batch_ids.csv`, `title_abstract/batch_NNN.tsv` | nada: imprime los lotes con problemas y un resumen | data.table |
| `05_full_abstract_batches.R` | `<ids.csv> <prefijo> <tamaño>` | `data/processed/corpus.csv` y la lista de ids | lotes con el resumen completo, `<prefijo>_NN.txt` | data.table |
| `06_rescreen_set.R` | ninguno | `corpus.csv`, `title_abstract/*.tsv`, `rescreen/rescreen_a_ids.csv` | `data/records/late_duplicates.csv`, `rescreen/rescreen_rule_ids.csv`, `rescreen/rescreen_b_ids.csv`, lotes `data/processed/rescreen_b_NN.txt` | data.table, stringi |
| `07_consolidate_screening.R` | ninguno | `records.csv`, `counts_identification.json`, `late_duplicates.csv` y los archivos de `data/screening/` | `data/results/screening_decisions.csv`, `screening_disagreements.csv`, `counts_screening.json` | data.table, jsonlite |
| `08_charting_batches.R` | `20261015` (semilla) | `corpus.csv`, `data/results/screening_decisions.csv` | lotes `data/processed/charting_batches/`, `data/charting/charting_ids.csv`, `verification_ids.csv` | data.table |
| `09_check_charting.R` | ninguno | `charting_ids.csv`, `primary/charting_NN_x.tsv`, `verification_ids.csv`, `verification/verification_N_x.tsv` | `data/results/charting_primary.csv`, `field_agreement.csv`, `eligibility_disagreements.csv` | data.table |
| `10_build_map.R` | ninguno | `charting_primary.csv`, `verification/*.tsv`, `eligibility_adjudication.csv`, `year_audit.csv`, `records.csv` | `data/results/mapping.csv`, `counts_mapping.json` | data.table, jsonlite |
| `11_fulltext_candidates.R` | `5` (tamaño de lote) | `data/results/mapping.csv` | `data/fulltext/candidates.csv` y lotes `data/processed/fulltext_batches/fulltext_NN.txt` | data.table |
| `12_figures.R` | `figures` (carpeta de salida) | `data/results/mapping.csv` | las cuatro figuras PDF en la carpeta indicada | data.table, ggplot2, patchwork, scales |

### Qué corre sin las exportaciones

`00_run_all.R` corre `01`, `02`, `05`, `06` y `08` solo si existe `data/raw/Scopus.csv`, porque necesitan los resúmenes. Sin las exportaciones corre `04`, `03` (sobre el piloto), `07`, `09`, `10`, `11` y `12`, que trabajan con los archivos de decisiones distribuidos.

### Detalles que conviene saber

- `12_figures.R` guarda las figuras con `cairo_pdf`, con 131 mm de ancho (el ancho de texto de la clase `sn-jnl`), así que R necesita soporte para Cairo.
- `11_fulltext_candidates.R` escribe sus lotes en `data/processed/fulltext_batches/` aunque no estén las exportaciones; esa carpeta está excluida por el `.gitignore` del proyecto.
- `10_build_map.R` se detiene si el mapa no tiene exactamente 2.109 filas; si se cambian los archivos de decisiones, hay que revisar esa comprobación.
- Algunas funciones se repiten en varios scripts (por ejemplo `kappa()` en `03`, `07` y `09`), así que un cambio en una de ellas debe repetirse en cada copia.

## English

This folder holds the 13 R scripts of the review, numbered in the order they run. All of them are run from the project root, because they use relative paths such as `data/...` and `scripts/...`, and all of them except `00_run_all.R` set the `C.UTF-8` locale when they start. The normal way to run them is `Rscript scripts/00_run_all.R`; the [project README](../README.md#reproducing-the-analysis) explains what is rebuilt with and without the raw exports.

| Script | Arguments (review values) | Reads | Writes | Packages |
|---|---|---|---|---|
| `00_run_all.R` | none | whether `data/raw/Scopus.csv` exists | nothing of its own: it launches the others with `Rscript` and stops at the first one that fails | none |
| `01_deduplicate.R` | none | `data/raw/Scopus.csv`, `data/raw/Wos*.xls`, `data/records/record_ids.csv` | `data/processed/corpus.csv` (with abstracts, not distributed), `data/records/records.csv`, `duplicates.csv`, `counts_identification.json` | data.table, readxl, stringi, jsonlite |
| `02_screening_batches.R` | `100 200 20261014` (batch size, pilot size, seed) | `data/processed/corpus.csv` | text batches in `data/processed/`, `data/screening/batch_ids.csv`, `pilot_ids.csv`, `kappa_sample/kappa_ids.csv` | data.table |
| `03_screening_agreement.R` | reviewer 1 files, `--`, reviewer 2 files | the TSV files it receives | nothing: prints agreement, kappa and disagreements to the console | data.table |
| `04_check_screening_batches.R` | none | `data/screening/batch_ids.csv`, `title_abstract/batch_NNN.tsv` | nothing: prints the batches with problems and a summary | data.table |
| `05_full_abstract_batches.R` | `<ids.csv> <prefix> <size>` | `data/processed/corpus.csv` and the id list | batches with the complete abstract, `<prefix>_NN.txt` | data.table |
| `06_rescreen_set.R` | none | `corpus.csv`, `title_abstract/*.tsv`, `rescreen/rescreen_a_ids.csv` | `data/records/late_duplicates.csv`, `rescreen/rescreen_rule_ids.csv`, `rescreen/rescreen_b_ids.csv`, batches `data/processed/rescreen_b_NN.txt` | data.table, stringi |
| `07_consolidate_screening.R` | none | `records.csv`, `counts_identification.json`, `late_duplicates.csv` and the files in `data/screening/` | `data/results/screening_decisions.csv`, `screening_disagreements.csv`, `counts_screening.json` | data.table, jsonlite |
| `08_charting_batches.R` | `20261015` (seed) | `corpus.csv`, `data/results/screening_decisions.csv` | batches in `data/processed/charting_batches/`, `data/charting/charting_ids.csv`, `verification_ids.csv` | data.table |
| `09_check_charting.R` | none | `charting_ids.csv`, `primary/charting_NN_x.tsv`, `verification_ids.csv`, `verification/verification_N_x.tsv` | `data/results/charting_primary.csv`, `field_agreement.csv`, `eligibility_disagreements.csv` | data.table |
| `10_build_map.R` | none | `charting_primary.csv`, `verification/*.tsv`, `eligibility_adjudication.csv`, `year_audit.csv`, `records.csv` | `data/results/mapping.csv`, `counts_mapping.json` | data.table, jsonlite |
| `11_fulltext_candidates.R` | `5` (batch size) | `data/results/mapping.csv` | `data/fulltext/candidates.csv` and batches `data/processed/fulltext_batches/fulltext_NN.txt` | data.table |
| `12_figures.R` | `figures` (output folder) | `data/results/mapping.csv` | the four PDF figures in the given folder | data.table, ggplot2, patchwork, scales |

### What runs without the exports

`00_run_all.R` runs `01`, `02`, `05`, `06` and `08` only when `data/raw/Scopus.csv` exists, because they need the abstracts. Without the exports it runs `04`, `03` (on the pilot), `07`, `09`, `10`, `11` and `12`, which work from the distributed decision files.

### Details worth knowing

- `12_figures.R` saves the figures with `cairo_pdf` at 131 mm wide (the text width of the `sn-jnl` class), so R needs Cairo support.
- `11_fulltext_candidates.R` writes its batches to `data/processed/fulltext_batches/` even when the exports are absent; the project `.gitignore` excludes that folder.
- `10_build_map.R` stops if the map does not have exactly 2,109 rows; if the decision files change, that check has to be reviewed.
- Some functions are repeated in several scripts (for example `kappa()` in `03`, `07` and `09`), so a change to one of them must be repeated in every copy.
