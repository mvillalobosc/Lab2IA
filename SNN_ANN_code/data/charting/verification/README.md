# data/charting/verification/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la segunda codificación independiente de la muestra de verificación: los 211 registros de `../verification_ids.csv`, codificados otra vez con el mismo protocolo para medir la concordancia por ítem. Ver [data/charting/](../README.md) para el contexto.

| Archivos | Contenido |
|---|---|
| `verification_1_a.tsv` a `verification_3_c.tsv` | Los tres archivos de verificación que arma `08_charting_batches.R` (de hasta 75 registros), cada uno partido en tres partes (`_a`, `_b` y `_c`) de 25 registros; la última parte, `verification_3_c.tsv`, tiene 11. |

Son 9 archivos y 211 líneas, con los mismos 18 campos que la codificación principal, separados por tabulador y sin encabezado. `09_check_charting.R` los compara con la codificación principal y escribe `data/results/field_agreement.csv` y `data/results/eligibility_disagreements.csv`; `10_build_map.R` vuelve a leerlos para aplicar las adjudicaciones con `source = second`. Los dos scripts usan el patrón `verification_N_[a-c].tsv`.

## English

This folder holds the second independent charting of the verification sample: the 211 records in `../verification_ids.csv`, charted again with the same protocol to measure item-level agreement. See [data/charting/](../README.md) for the context.

| Files | Content |
|---|---|
| `verification_1_a.tsv` to `verification_3_c.tsv` | The three verification files built by `08_charting_batches.R` (of up to 75 records), each split into three parts (`_a`, `_b` and `_c`) of 25 records; the last part, `verification_3_c.tsv`, has 11. |

There are 9 files and 211 lines, with the same 18 fields as the primary charting, tab-separated and without a header. `09_check_charting.R` compares them with the primary charting and writes `data/results/field_agreement.csv` and `data/results/eligibility_disagreements.csv`; `10_build_map.R` reads them again to apply the adjudications with `source = second`. Both scripts use the pattern `verification_N_[a-c].tsv`.
