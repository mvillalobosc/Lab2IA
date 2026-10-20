# data/screening/pilot/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los dos cribados independientes del piloto, que permiten medir la concordancia entre dos revisores. Los 200 registros del piloto, sorteados en cada bloque de búsqueda en proporción a su tamaño, están listados en `../pilot_ids.csv` y `02_screening_batches.R` los reparte en dos tandas de 100. Ver [data/screening/](../README.md) para el contexto.

| Archivo | Contenido |
|---|---|
| `pilot_1_reviewer1.tsv` | Cribado del revisor 1 sobre la primera tanda de 100 registros. |
| `pilot_2_reviewer1.tsv` | Cribado del revisor 1 sobre la segunda tanda de 100 registros. |
| `pilot_1_reviewer2.tsv` | Cribado del revisor 2 sobre la primera tanda. |
| `pilot_2_reviewer2.tsv` | Cribado del revisor 2 sobre la segunda tanda. |

Cada archivo tiene 100 líneas con los cinco campos del cribado, sin encabezado. `00_run_all.R` compara los dos revisores con `03_screening_agreement.R`, que imprime el acuerdo, el kappa de Cohen y los desacuerdos en la consola sin escribir archivos:

```
Rscript scripts/03_screening_agreement.R \
  data/screening/pilot/pilot_1_reviewer1.tsv data/screening/pilot/pilot_2_reviewer1.tsv -- \
  data/screening/pilot/pilot_1_reviewer2.tsv data/screening/pilot/pilot_2_reviewer2.tsv
```

## English

This folder holds the two independent screenings of the pilot, which measure the agreement between two reviewers. The 200 pilot records, drawn from each search block in proportion to its size, are listed in `../pilot_ids.csv`, and `02_screening_batches.R` splits them into two sets of 100. See [data/screening/](../README.md) for the context.

| File | Content |
|---|---|
| `pilot_1_reviewer1.tsv` | Screening by reviewer 1 of the first set of 100 records. |
| `pilot_2_reviewer1.tsv` | Screening by reviewer 1 of the second set of 100 records. |
| `pilot_1_reviewer2.tsv` | Screening by reviewer 2 of the first set. |
| `pilot_2_reviewer2.tsv` | Screening by reviewer 2 of the second set. |

Each file has 100 lines with the five screening fields, without a header. `00_run_all.R` compares the two reviewers with `03_screening_agreement.R`, which prints the agreement, Cohen's kappa and the disagreements to the console without writing files:

```
Rscript scripts/03_screening_agreement.R \
  data/screening/pilot/pilot_1_reviewer1.tsv data/screening/pilot/pilot_2_reviewer1.tsv -- \
  data/screening/pilot/pilot_1_reviewer2.tsv data/screening/pilot/pilot_2_reviewer2.tsv
```
