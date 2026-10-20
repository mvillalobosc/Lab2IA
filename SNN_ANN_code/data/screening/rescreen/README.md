# data/screening/rescreen/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el re-cribado con el resumen completo de los registros excluidos en el primer paso cuyo resumen superaba los 1.400 caracteres mostrados y cuya parte oculta contenía términos de líneas base ANN, métricas de eficiencia, plataformas de hardware o esparsidad. La regla final la fija `06_rescreen_set.R` y cubre 1.114 registros; la decisión de esta etapa reemplaza la del primer paso en `07_consolidate_screening.R`. Ver [data/screening/](../README.md) para el contexto.

| Archivo | Filas | Contenido | Lo escribe |
|---|---|---|---|
| `rescreen_a_ids.csv` | 235 | Registros de la primera ronda, elegidos con una versión preliminar de la regla. Su única columna se llama `id`, no `record_id`; los scripts leen la primera columna por posición. | Ningún script |
| `rescreen_a_1.tsv`, `rescreen_a_2a.tsv`, `rescreen_a_2b.tsv`, `rescreen_a_3.tsv` | 80, 40, 40 y 75 | Decisiones de la primera ronda sobre esos 235 registros (cinco campos, sin encabezado). | Los revisores |
| `rescreen_rule_ids.csv` | 1.114 | Registros que cubre la regla final. | `06_rescreen_set.R` |
| `rescreen_b_ids.csv` | 881 | Registros de la regla final que no estaban en la primera ronda y quedaron para la segunda. | `06_rescreen_set.R` |
| `rescreen_b_01.tsv` a `rescreen_b_09.tsv` | 100 cada uno, salvo el último con 81 | Decisiones de la segunda ronda sobre esos 881 registros (cinco campos, sin encabezado). | Los revisores |

Los 1.114 registros de la regla final son 233 de la primera ronda más los 881 de la segunda. Los otros 2 registros de la primera ronda quedan fuera de la regla final, y `07_consolidate_screening.R` descarta sus decisiones de re-cribado.

## English

This folder holds the re-screening, with the complete abstract, of the records excluded in the first pass whose abstract exceeded the 1,400 characters shown and whose hidden part contained terms related to ANN baselines, efficiency metrics, hardware platforms or sparsity. `06_rescreen_set.R` fixes the final rule, which covers 1,114 records; the decision of this stage replaces the first-pass one in `07_consolidate_screening.R`. See [data/screening/](../README.md) for the context.

| File | Rows | Content | Written by |
|---|---|---|---|
| `rescreen_a_ids.csv` | 235 | Records of the first round, chosen with a preliminary version of the rule. Its only column is named `id`, not `record_id`; the scripts read the first column by position. | No script |
| `rescreen_a_1.tsv`, `rescreen_a_2a.tsv`, `rescreen_a_2b.tsv`, `rescreen_a_3.tsv` | 80, 40, 40 and 75 | Decisions of the first round on those 235 records (five fields, no header). | The reviewers |
| `rescreen_rule_ids.csv` | 1,114 | Records covered by the final rule. | `06_rescreen_set.R` |
| `rescreen_b_ids.csv` | 881 | Records of the final rule that were not in the first round and were left for the second. | `06_rescreen_set.R` |
| `rescreen_b_01.tsv` to `rescreen_b_09.tsv` | 100 each, except the last with 81 | Decisions of the second round on those 881 records (five fields, no header). | The reviewers |

The 1,114 records of the final rule are 233 from the first round plus the 881 of the second. The other 2 records of the first round fall outside the final rule, and `07_consolidate_screening.R` discards their re-screening decisions.
