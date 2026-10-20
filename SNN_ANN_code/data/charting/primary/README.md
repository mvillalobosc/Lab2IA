# data/charting/primary/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la codificación principal de los 2.109 registros evaluados con el resumen completo. Ver [data/charting/](../README.md) para el contexto y [`protocols/charting_protocol.txt`](../../../protocols/charting_protocol.txt) para los vocabularios de cada ítem.

| Archivos | Contenido |
|---|---|
| `charting_01_a.tsv` a `charting_21_d.tsv` | Los lotes 01 a 21 de `charting_ids.csv`, cada uno partido en cuatro partes de 25 registros (`_a`, `_b`, `_c` y `_d`). |
| `charting_22_a.tsv` | El último lote, de 9 registros, en una sola parte. |

Son 85 archivos y 2.109 líneas en total. Cada línea tiene los 18 campos de codificación (`record_id`, `eligible`, `reason`, `categories`, `paradigm`, `architecture`, `task`, `platform_snn`, `platform_ann`, `evidence`, `metrics`, `comparison`, `sparsity_method`, `lth_variant`, `granularity`, `cost_in_objective`, `hardware_measured`, `note`), separados por tabulador, sin encabezado y en el orden del lote. Para los registros no elegibles los ítems 5 a 17 llevan `-`.

`09_check_charting.R` busca las partes de cada lote con el patrón `charting_NN_[a-d].tsv`, verifica que juntas tengan los registros del lote en el mismo orden y con vocabulario válido, y escribe la tabla consolidada `data/results/charting_primary.csv`.

## English

This folder holds the primary charting of the 2,109 records assessed on the complete abstract. See [data/charting/](../README.md) for the context and [`protocols/charting_protocol.txt`](../../../protocols/charting_protocol.txt) for the vocabulary of each item.

| Files | Content |
|---|---|
| `charting_01_a.tsv` to `charting_21_d.tsv` | Batches 01 to 21 of `charting_ids.csv`, each split into four parts of 25 records (`_a`, `_b`, `_c` and `_d`). |
| `charting_22_a.tsv` | The last batch, of 9 records, in a single part. |

There are 85 files and 2,109 lines in total. Each line has the 18 charting fields (`record_id`, `eligible`, `reason`, `categories`, `paradigm`, `architecture`, `task`, `platform_snn`, `platform_ann`, `evidence`, `metrics`, `comparison`, `sparsity_method`, `lth_variant`, `granularity`, `cost_in_objective`, `hardware_measured`, `note`), tab-separated, without a header and in batch order. For records that are not eligible, items 5 to 17 hold `-`.

`09_check_charting.R` finds the parts of each batch with the pattern `charting_NN_[a-d].tsv`, checks that together they hold the records of the batch in the same order and with valid vocabulary, and writes the consolidated table `data/results/charting_primary.csv`.
