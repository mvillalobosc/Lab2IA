# verification

[Español](#español) · [English](#english)

## Español

| Archivo | Contenido |
| --- | --- |
| `so_matrix.csv` | Estrategias monoobjetivo y de búsqueda local del núcleo de optimización, con algoritmo, problema, criterios, estructura de la solución, operadores, datos, fuente consultada (`source`) y evidencia textual (`evidence`) |
| `mo_matrix.csv` | Lo mismo para las estrategias multiobjetivo, incluidos los estudios que la verificación reasignó |
| `verification_corrections.csv` | Exclusiones, cambios de categoría y de número de objetivos que aplicó la verificación, con su motivo |
| `duplicates_manual.csv` | Duplicados que se eliminaron después de revisarlos a mano, con el registro que se conserva |

`05_verification.R` aplica estos archivos a la codificación del cribado. La columna `ds_diversity` registra la selección por diversidad topológica, que el artículo no analiza.

## English

| File | Content |
| --- | --- |
| `so_matrix.csv` | Single-objective and local search strategies of the optimisation core, with algorithm, problem, criteria, solution structure, operators, data, source consulted (`source`) and textual evidence (`evidence`) |
| `mo_matrix.csv` | The same for the multi-objective strategies, including the studies that the verification reassigned |
| `verification_corrections.csv` | Exclusions and changes of category and of number of objectives applied by the verification, with their reason |
| `duplicates_manual.csv` | Duplicates removed after manual review, with the record that is kept |

`05_verification.R` applies these files to the screening codes. The `ds_diversity` column records the selection by topological diversity, which the paper does not analyse.
