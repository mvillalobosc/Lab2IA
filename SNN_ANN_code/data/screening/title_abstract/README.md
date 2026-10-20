# data/screening/title_abstract/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las decisiones del primer paso del cribado, en el que los revisores vieron el título, las palabras clave de autor (hasta 200 caracteres) y el resumen (hasta 1.400 caracteres) de cada registro. Ver [data/screening/](../README.md) para el contexto.

| Archivos | Contenido |
|---|---|
| `batch_001.tsv` a `batch_064.tsv` | Un archivo por lote de `batch_ids.csv`: 63 lotes de 100 registros y el último de 34, en total 6.334 líneas. Cada línea tiene los cinco campos del cribado (`record_id`, `decision`, `code`, `hardware`, `note`), sin encabezado y en el orden del lote. |

`04_check_screening_batches.R` verifica que cada archivo tenga exactamente los registros de su lote, sin repetidos y con decisiones y códigos válidos; `06_rescreen_set.R` y `07_consolidate_screening.R` los leen por nombre (`batch_%03d.tsv`). En `07`, la decisión del re-cribado reemplaza la de este paso para los 1.114 registros que se volvieron a cribar.

## English

This folder holds the decisions of the first screening pass, in which the reviewers saw the title, the author keywords (up to 200 characters) and the abstract (up to 1,400 characters) of each record. See [data/screening/](../README.md) for the context.

| Files | Content |
|---|---|
| `batch_001.tsv` to `batch_064.tsv` | One file per batch in `batch_ids.csv`: 63 batches of 100 records and a last one of 34, 6,334 lines in total. Each line has the five screening fields (`record_id`, `decision`, `code`, `hardware`, `note`), without a header and in batch order. |

`04_check_screening_batches.R` checks that each file holds exactly the records of its batch, without repeats and with valid decisions and codes; `06_rescreen_set.R` and `07_consolidate_screening.R` read them by name (`batch_%03d.tsv`). In `07`, the re-screening decision replaces the one from this pass for the 1,114 records that were screened again.
