# data/screening/kappa_sample/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la muestra de concordancia: 430 registros elegidos al azar fuera del piloto, que un segundo revisor volvió a cribar de forma independiente con el resumen completo. `07_consolidate_screening.R` compara ese segundo cribado con la decisión final de cada registro y escribe el acuerdo y el kappa en `data/results/counts_screening.json`. Ver [data/screening/](../README.md) para el contexto.

| Archivo | Contenido | Lo escribe |
|---|---|---|
| `kappa_ids.csv` | Los 430 registros de la muestra con su lote del primer paso (`record_id`, `batch`), sorteados con semilla 7. | `02_screening_batches.R` |
| `kappa_1_reviewer2.tsv` a `kappa_5_reviewer2.tsv` | Segundo cribado de la muestra en cinco archivos de 86 registros, con los cinco campos del cribado y sin encabezado. Los lotes con el resumen completo los arma `05_full_abstract_batches.R` con tamaño 86. | Los revisores |

La concordancia final se calcula sobre 428 registros, porque dos de los 430 son duplicados tardíos (`data/records/late_duplicates.csv`) y salen del conjunto final.

## English

This folder holds the agreement sample: 430 records drawn at random outside the pilot, which a second reviewer screened again independently with the complete abstract. `07_consolidate_screening.R` compares that second screening with the final decision of each record and writes the agreement and kappa to `data/results/counts_screening.json`. See [data/screening/](../README.md) for the context.

| File | Content | Written by |
|---|---|---|
| `kappa_ids.csv` | The 430 records of the sample with their first-pass batch (`record_id`, `batch`), drawn with seed 7. | `02_screening_batches.R` |
| `kappa_1_reviewer2.tsv` to `kappa_5_reviewer2.tsv` | Second screening of the sample in five files of 86 records, with the five screening fields and no header. `05_full_abstract_batches.R` builds the batches with the complete abstract using a size of 86. | The reviewers |

The final agreement is computed on 428 records, because two of the 430 are late duplicates (`data/records/late_duplicates.csv`) and leave the final set.
