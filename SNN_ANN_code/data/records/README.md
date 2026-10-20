# data/records/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el conjunto de registros únicos que salió de unir y depurar las exportaciones de Scopus y Web of Science. Todos los demás archivos de la revisión se refieren a estos registros por su `record_id`. Las columnas de `records.csv` están descritas en el [README del proyecto](../../README.md#data-dictionary) (en castellano, en [README.es.md](../../README.es.md#diccionario-de-datos)).

| Archivo | Filas | Contenido | Lo escribe |
|---|---|---|---|
| `records.csv` | 6.334 | Metadatos públicos de cada registro único (identificador, base de origen, bloque de búsqueda, título, año, DOI, tipo de documento, fuente, autores, idioma, citas, acceso abierto y palabras clave de autor), sin resúmenes ni palabras clave indexadas. Hay 6.073 registros conservados desde Scopus y 261 que solo estaban en Web of Science; `wos_id` trae el identificador de Web of Science en 4.580 filas, que son los 4.319 registros de Scopus que también estaban en esa base y los 261 que solo estaban ahí. | `01_deduplicate.R` |
| `record_ids.csv` | 6.334 | Correspondencia `record_id`, `source`, `source_id` de la corrida original. `01_deduplicate.R` la lee para asignar siempre los mismos identificadores, de modo que los archivos de decisiones sigan calzando. | Ningún script: viene de la corrida original |
| `duplicates.csv` | 4.446 | Registros eliminados como duplicados, con `source`, `source_id`, `title`, `year`, `doi` y la razón: 4.286 por DOI y 160 por título normalizado. | `01_deduplicate.R` |
| `late_duplicates.csv` | 8 | Duplicados detectados después del primer cribado: títulos iguales una vez quitados espacios y puntuación (algunos títulos de Web of Science venían sin espacios entre palabras). Columnas `record_id`, `source`, `title`. | `06_rescreen_set.R` |
| `counts_identification.json` | 1 objeto | Conteos de la etapa de identificación: fecha de búsqueda, registros por base, duplicados por DOI y por título, registros únicos, y distribución por bloque, año, tipo de documento e idioma. | `01_deduplicate.R` |

Los 4.454 duplicados que informa la revisión son los 4.446 de `duplicates.csv` más los 8 de `late_duplicates.csv`. Sin las exportaciones crudas los scripts no reescriben esta carpeta.

## English

This folder holds the set of unique records obtained by merging and cleaning the Scopus and Web of Science exports. Every other file of the review refers to these records by their `record_id`. The columns of `records.csv` are described in the [project README](../../README.md#data-dictionary).

| File | Rows | Content | Written by |
|---|---|---|---|
| `records.csv` | 6,334 | Public metadata of each unique record (identifier, source database, search block, title, year, DOI, document type, venue, authors, language, citations, open access and author keywords), without abstracts or indexed keywords. 6,073 records were kept from Scopus and 261 were only in Web of Science; `wos_id` holds the Web of Science identifier in 4,580 rows, which are the 4,319 Scopus records also found in that database and the 261 found only there. | `01_deduplicate.R` |
| `record_ids.csv` | 6,334 | Mapping `record_id`, `source`, `source_id` from the original run. `01_deduplicate.R` reads it to assign the same identifiers every time, so that the decision files keep matching. | No script: it comes from the original run |
| `duplicates.csv` | 4,446 | Records removed as duplicates, with `source`, `source_id`, `title`, `year`, `doi` and the reason: 4,286 by DOI and 160 by normalised title. | `01_deduplicate.R` |
| `late_duplicates.csv` | 8 | Duplicates found after the first screening: titles that match once spaces and punctuation are removed (some Web of Science titles came without spaces between words). Columns `record_id`, `source`, `title`. | `06_rescreen_set.R` |
| `counts_identification.json` | 1 object | Counts of the identification stage: search date, records per database, duplicates by DOI and by title, unique records, and distribution by block, year, document type and language. | `01_deduplicate.R` |

The 4,454 duplicates reported by the review are the 4,446 in `duplicates.csv` plus the 8 in `late_duplicates.csv`. Without the raw exports the scripts do not rewrite this folder.
