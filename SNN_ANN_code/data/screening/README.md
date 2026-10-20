# data/screening/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el cribado por título y resumen de los 6.334 registros únicos: la asignación de lotes, las decisiones del primer paso, el piloto, la muestra de concordancia y las dos rondas de re-cribado con el resumen completo. El formato de las decisiones y los códigos están en el [README del proyecto](../../README.md#screening-files-datascreening) (en castellano, en [README.es.md](../../README.es.md#archivos-de-cribado-datascreening)) y los criterios, en [`protocols/screening_protocol.txt`](../../protocols/screening_protocol.txt).

Todos los TSV de esta carpeta y de sus subcarpetas tienen el mismo formato: separados por tabulador, sin encabezado y con cinco campos (`record_id`, `decision`, `code`, `hardware`, `note`), un registro por línea y en el orden del lote.

| Archivo o carpeta | Contenido | Lo escribe |
|---|---|---|
| `batch_ids.csv` | Asigna cada uno de los 6.334 registros a su lote (`record_id`, `batch`): 63 lotes de 100 y uno de 34. | `02_screening_batches.R` |
| `pilot_ids.csv` | Los 200 registros del piloto con su bloque de búsqueda (`record_id`, `block`), en un muestreo estratificado (125 del bloque A, 50 del B, 23 de A+B y 2 sin bloque). | `02_screening_batches.R` |
| [title_abstract/](title_abstract/) | Decisiones del primer paso, un archivo por lote. | Los revisores |
| [pilot/](pilot/) | Los dos cribados independientes del piloto. | Los revisores |
| [kappa_sample/](kappa_sample/) | Segundo cribado independiente, con el resumen completo, de una muestra aleatoria de 430 registros. | La lista, `02`; las decisiones, los revisores |
| [rescreen/](rescreen/) | Las dos rondas de re-cribado con el resumen completo y las listas que las definen. | Las listas, `06` (salvo la de la primera ronda); las decisiones, los revisores |

`04_check_screening_batches.R` comprueba los lotes del primer paso contra `batch_ids.csv` y `07_consolidate_screening.R` reúne todo en `data/results/screening_decisions.csv`. Los scripts leen cada archivo por su nombre exacto, así que un archivo extra en estas carpetas no altera el resultado.

## English

This folder holds the title and abstract screening of the 6,334 unique records: the batch assignment, the first-pass decisions, the pilot, the agreement sample and the two rounds of re-screening with the complete abstract. The decision format and the codes are in the [project README](../../README.md#screening-files-datascreening) and the criteria in [`protocols/screening_protocol.txt`](../../protocols/screening_protocol.txt).

Every TSV file in this folder and its subfolders has the same format: tab-separated, no header, five fields (`record_id`, `decision`, `code`, `hardware`, `note`), one record per line in batch order.

| File or folder | Content | Written by |
|---|---|---|
| `batch_ids.csv` | Assigns each of the 6,334 records to its batch (`record_id`, `batch`): 63 batches of 100 and one of 34. | `02_screening_batches.R` |
| `pilot_ids.csv` | The 200 pilot records with their search block (`record_id`, `block`), drawn by stratified sampling (125 from block A, 50 from B, 23 from A+B and 2 without a block). | `02_screening_batches.R` |
| [title_abstract/](title_abstract/) | First-pass decisions, one file per batch. | The reviewers |
| [pilot/](pilot/) | The two independent screenings of the pilot. | The reviewers |
| [kappa_sample/](kappa_sample/) | Second independent screening, with the complete abstract, of a random sample of 430 records. | The list, `02`; the decisions, the reviewers |
| [rescreen/](rescreen/) | The two rounds of re-screening with the complete abstract and the lists that define them. | The lists, `06` (except the first-round list); the decisions, the reviewers |

`04_check_screening_batches.R` checks the first-pass batches against `batch_ids.csv`, and `07_consolidate_screening.R` gathers everything into `data/results/screening_decisions.csv`. The scripts read each file by its exact name, so an extra file in these folders does not change the result.
