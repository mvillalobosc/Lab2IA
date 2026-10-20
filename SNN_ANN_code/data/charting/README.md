# data/charting/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la confirmación de elegibilidad y la codificación de los 2.109 registros que pasaron el cribado (INCLUDE o UNSURE), hechas sobre el resumen completo con los 18 ítems de [`protocols/charting_protocol.txt`](../../protocols/charting_protocol.txt). También guarda la muestra de verificación y dos archivos con decisiones de los revisores que cambian el mapa final. Los campos se describen en el [README del proyecto](../../README.md#charting-files-datacharting) (en castellano, en [README.es.md](../../README.es.md#archivos-de-codificación-datacharting)).

| Archivo o carpeta | Contenido | Lo escribe |
|---|---|---|
| `charting_ids.csv` | Asigna cada uno de los 2.109 registros a su lote de codificación (`record_id`, `batch`): 21 lotes de 100 y uno de 9. | `08_charting_batches.R` |
| `verification_ids.csv` | Los 211 registros (10 %) de la muestra de verificación, en una sola columna `record_id`, sorteados con la semilla que recibe `08` (20261015 en la revisión). | `08_charting_batches.R` |
| [primary/](primary/) | Codificación principal de los 2.109 registros. | Los revisores |
| [verification/](verification/) | Segunda codificación independiente de los 211 registros de la muestra. | Los revisores |
| `eligibility_adjudication.csv` | Decisión del tercer revisor sobre los 19 desacuerdos de elegibilidad de la muestra (`record_id`, `decision`, `source`, `reason`, `justification`). `source` dice qué hacer: `primary` (8 casos) conserva la codificación principal, `second` (6) usa entera la segunda codificación y `exclude` (5) marca el registro como no elegible con la razón indicada. | Los revisores |
| `year_audit.csv` | Auditoría del año de publicación (`record_id`, `exported_year`, `actual_year`, `evidence`, `decision`): R00069 (trabajo de 2019 exportado como 2020) y R06322 y R06331 (año 2027 en la exportación) reciben el código E0 y salen del mapa. | Los revisores |

`10_build_map.R` aplica primero las adjudicaciones y después la auditoría de año (a los registros de esta lista y a todo registro de `records.csv` con año fuera de 2020-2026), y se detiene si el mapa no queda con exactamente 2.109 filas. Cambiar estos dos archivos cambia el mapa final.

## English

This folder holds the eligibility confirmation and charting of the 2,109 records that passed screening (INCLUDE or UNSURE), done on the complete abstract with the 18 items in [`protocols/charting_protocol.txt`](../../protocols/charting_protocol.txt). It also holds the verification sample and two files with reviewer decisions that change the final map. The fields are described in the [project README](../../README.md#charting-files-datacharting).

| File or folder | Content | Written by |
|---|---|---|
| `charting_ids.csv` | Assigns each of the 2,109 records to its charting batch (`record_id`, `batch`): 21 batches of 100 and one of 9. | `08_charting_batches.R` |
| `verification_ids.csv` | The 211 records (10 %) of the verification sample, in a single `record_id` column, drawn with the seed passed to `08` (20261015 in the review). | `08_charting_batches.R` |
| [primary/](primary/) | Primary charting of the 2,109 records. | The reviewers |
| [verification/](verification/) | Second independent charting of the 211 sample records. | The reviewers |
| `eligibility_adjudication.csv` | Decision of the third reviewer on the 19 eligibility disagreements of the sample (`record_id`, `decision`, `source`, `reason`, `justification`). `source` says what to do: `primary` (8 cases) keeps the primary charting, `second` (6) uses the second charting in full and `exclude` (5) marks the record as not eligible with the given reason. | The reviewers |
| `year_audit.csv` | Publication-year audit (`record_id`, `exported_year`, `actual_year`, `evidence`, `decision`): R00069 (a 2019 paper exported as 2020) and R06322 and R06331 (year 2027 in the export) get code E0 and leave the map. | The reviewers |

`10_build_map.R` applies the adjudications first and then the year audit (to the records in this list and to every record in `records.csv` with a year outside 2020-2026), and stops if the map does not end with exactly 2,109 rows. Changing these two files changes the final map.
