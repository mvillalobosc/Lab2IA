# data/results/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los resultados consolidados de la revisión. Todos los archivos los escriben los scripts a partir de los archivos de decisiones de `data/screening/` y `data/charting/`, así que una corrida de `scripts/00_run_all.R` los sobrescribe; con los archivos distribuidos los vuelve a escribir idénticos. El significado de cada columna está en el [README del proyecto](../../README.md#results-dataresults) (en castellano, en [README.es.md](../../README.es.md#resultados-dataresults)).

| Archivo | Filas | Contenido | Lo escribe |
|---|---|---|---|
| `screening_decisions.csv` | 6.326 | Decisión final del cribado por registro: `record_id`, `batch`, `stage` (`first_pass` o `rescreened`), `decision`, `code`, `hardware_mentioned`, `note`. | `07_consolidate_screening.R` |
| `screening_disagreements.csv` | 27 | Registros de la muestra de concordancia en que la decisión final (`d1`) y el segundo cribado (`d2`) no coinciden en si el registro pasa o no a la etapa siguiente. | `07_consolidate_screening.R` |
| `counts_screening.json` | 1 objeto | Conteos del cribado: registros cribados, re-cribados, excluidos por razón, que pasan (1.701 INCLUDE y 408 UNSURE), categorías, y acuerdo y kappa (kappa binario final 0,86 sobre 428 registros). | `07_consolidate_screening.R` |
| `charting_primary.csv` | 2.109 | Codificación principal con los 18 campos y sus nombres de columna. | `09_check_charting.R` |
| `field_agreement.csv` | 15 | Acuerdo y kappa por ítem (`item`, `n`, `agreement`, `kappa`) entre la codificación principal y la de verificación; la elegibilidad se compara en 211 registros y los demás ítems en 146. | `09_check_charting.R` |
| `eligibility_disagreements.csv` | 19 | Registros de la muestra de verificación en que las dos codificaciones discrepan sobre la elegibilidad, con decisión, razón, categorías y notas de cada una. | `09_check_charting.R` |
| `mapping.csv` | 2.109 | Mapa de evidencia final: los 18 campos tras la adjudicación y la auditoría de año, más `adjudicated`, `year_audit` y los metadatos bibliográficos (`source`, `year`, `title`, `authors`, `venue`, `document_type`, `doi`, `citations`, `open_access`). `eligible == "Y"` marca los 1.471 estudios incluidos. | `10_build_map.R` |
| `counts_mapping.json` | 1 objeto | Conteos del mapa: 2.109 evaluados, 638 excluidos por razón (E0 a E7), 1.471 incluidos, categorías y los 163 candidatos a texto completo. | `10_build_map.R` |

## English

This folder holds the consolidated results of the review. The scripts write every file from the decision files in `data/screening/` and `data/charting/`, so a run of `scripts/00_run_all.R` overwrites them; with the distributed files it writes them again unchanged. The meaning of each column is in the [project README](../../README.md#results-dataresults).

| File | Rows | Content | Written by |
|---|---|---|---|
| `screening_decisions.csv` | 6,326 | Final screening decision per record: `record_id`, `batch`, `stage` (`first_pass` or `rescreened`), `decision`, `code`, `hardware_mentioned`, `note`. | `07_consolidate_screening.R` |
| `screening_disagreements.csv` | 27 | Records of the agreement sample where the final decision (`d1`) and the second screening (`d2`) differ on whether the record passes to the next stage. | `07_consolidate_screening.R` |
| `counts_screening.json` | 1 object | Screening counts: records screened, re-screened, excluded by reason, passing (1,701 INCLUDE and 408 UNSURE), categories, and agreement and kappa (final binary kappa 0.86 on 428 records). | `07_consolidate_screening.R` |
| `charting_primary.csv` | 2,109 | Primary charting with the 18 fields and their column names. | `09_check_charting.R` |
| `field_agreement.csv` | 15 | Agreement and kappa per item (`item`, `n`, `agreement`, `kappa`) between the primary and the verification charting; eligibility is compared on 211 records and the other items on 146. | `09_check_charting.R` |
| `eligibility_disagreements.csv` | 19 | Records of the verification sample where the two chartings disagree on eligibility, with the decision, reason, categories and notes of each. | `09_check_charting.R` |
| `mapping.csv` | 2,109 | Final evidence map: the 18 fields after adjudication and year audit, plus `adjudicated`, `year_audit` and the bibliographic metadata (`source`, `year`, `title`, `authors`, `venue`, `document_type`, `doi`, `citations`, `open_access`). `eligible == "Y"` marks the 1,471 included studies. | `10_build_map.R` |
| `counts_mapping.json` | 1 object | Map counts: 2,109 assessed, 638 excluded by reason (E0 to E7), 1,471 included, categories and the 163 full-text candidates. | `10_build_map.R` |
