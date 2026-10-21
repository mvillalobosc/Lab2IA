# data/processed

[Español](#español) · [English](#english)

## Español

Bases que escriben los scripts. Todas se distribuyen sin las columnas de resumen y de palabras clave indexadas; conservan las palabras clave de los autores y los demás metadatos bibliográficos. El identificador `id` (R00001 a R08868) une todos los archivos.

| Archivo | Lo escribe | Contenido |
| --- | --- | --- |
| `db_unique.csv` | `01_merge.R` | Los 8.868 registros únicos, con sus bloques de búsqueda (`blocks`), bases (`dbs`), metadatos y la ola de exportación (`wave`) |
| `counts_raw.csv` | `01_merge.R` | Registros recuperados por bloque y base |
| `db_screened.csv` | `02_screen.R` | Registros únicos con los filtros automáticos (`f_*`), el diccionario de descriptores (`dict_*`) y la ronda de cribado |
| `candidates_for_llm.csv`, `candidates_round2.csv`, `candidates_round3.csv` | `02_screen.R` | Registros que evaluó el protocolo en las rondas 1, 2 y 3, en el orden de los lotes |
| `near_duplicate_pairs.csv` | `03_merge_coding.R` | Los 80 pares de casi duplicados revisados, con su similitud y la decisión |
| `db_final_all.csv` | `05_verification.R` | Todos los registros únicos con su etapa PRISMA (`stage`), su decisión y sus códigos |
| `db_included_screened.csv` | `03_merge_coding.R` | Los 2.560 incluidos en el cribado, antes de la verificación |
| `db_included_coded.csv` | `05_verification.R` | Los 2.557 estudios incluidos con sus códigos verificados, los 61 caracteres binarios (`cat_*`, `crit_*`, `alg_*`, `rep_*`, `ops_*`, `data_*`, `type_*`, `obj_*`, `soft_yes`), el bloque principal (`main_block`) y la etiqueta del árbol (`label`) |
| `verification_log.csv` | `05_verification.R` | Códigos de cada estudio del núcleo antes y después de la verificación |
| `agreement.rds` | `03_merge_coding.R` | Concordancia entre el diccionario y la decisión asistida |
| `verify.rds` | `04_verify_sample.R` | Concordancia y kappa de la segunda lectura, y concordancia del bloque principal |

## English

Databases written by the scripts. All of them are distributed without the abstract and indexed keyword columns; they keep the author keywords and the other bibliographic metadata. The identifier `id` (R00001 to R08868) links all the files.

| File | Written by | Content |
| --- | --- | --- |
| `db_unique.csv` | `01_merge.R` | The 8,868 unique records, with their search blocks (`blocks`), databases (`dbs`), metadata and export wave (`wave`) |
| `counts_raw.csv` | `01_merge.R` | Records retrieved per block and database |
| `db_screened.csv` | `02_screen.R` | Unique records with the automated filters (`f_*`), the descriptor dictionary (`dict_*`) and the screening round |
| `candidates_for_llm.csv`, `candidates_round2.csv`, `candidates_round3.csv` | `02_screen.R` | Records assessed by the protocol in rounds 1, 2 and 3, in batch order |
| `near_duplicate_pairs.csv` | `03_merge_coding.R` | The 80 near-duplicate pairs reviewed, with their similarity and decision |
| `db_final_all.csv` | `05_verification.R` | All unique records with their PRISMA stage (`stage`), decision and codes |
| `db_included_screened.csv` | `03_merge_coding.R` | The 2,560 records included at screening, before the verification |
| `db_included_coded.csv` | `05_verification.R` | The 2,557 included studies with their verified codes, the 61 binary characters (`cat_*`, `crit_*`, `alg_*`, `rep_*`, `ops_*`, `data_*`, `type_*`, `obj_*`, `soft_yes`), the main block (`main_block`) and the tree label (`label`) |
| `verification_log.csv` | `05_verification.R` | Codes of each study of the optimisation core before and after the verification |
| `agreement.rds` | `03_merge_coding.R` | Agreement between the dictionary and the assisted decision |
| `verify.rds` | `04_verify_sample.R` | Agreement and kappa of the second screening, and agreement of the main block |
