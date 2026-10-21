# data/raw

[Español](#español) · [English](#english)

## Español

| Archivo | Contenido |
| --- | --- |
| `search_strings.csv` | Cadena de búsqueda de cada bloque (Q1 a Q7) en cada base, tal como se ejecutó (columnas `block`, `database`, `query`) |

Las exportaciones no se distribuyen porque traen los resúmenes y las palabras clave indexadas bajo las licencias de Scopus y Web of Science. Para correr la revisión desde el principio, se ejecutan las cadenas de `search_strings.csv` con los filtros de año, idioma y tipo de documento que indica el artículo, y se guardan las exportaciones completas en `scopus/` y en `wos/`. La revisión usó un CSV de Scopus por bloque (`Q1_SCOPUS.csv` a `Q7_SCOPUS.csv`, con `Q4A` y `Q4B`) y los XLS de Web of Science de cada bloque, partidos en dos archivos cuando superaban el límite de exportación (`Q1_WoS.xls`, `Q2_WoS.xls`, `Q3_WoS1.xls` y `Q3_WoS2.xls`, y así hasta `Q7_WoS2.xls`). `Q7_WoS1_partial.xls` fue una primera descarga incompleta del bloque Q7 (registros 1 a 50) que se cribó antes que el resto: `01_merge.R` la usa solo para asignar la ola de exportación (`wave`) y la deja fuera de los conteos. El script lee todo lo que encuentra en esas dos carpetas y toma el bloque del comienzo del nombre del archivo.

## English

| File | Content |
| --- | --- |
| `search_strings.csv` | Search string of each block (Q1 to Q7) in each database, as it was run (columns `block`, `database`, `query`) |

The exports are not distributed because they contain abstracts and indexed keywords under the licences of Scopus and Web of Science. To run the review from the beginning, run the strings of `search_strings.csv` with the year, language and document type filters given in the paper, and save the complete exports in `scopus/` and `wos/`. The review used one Scopus CSV per block (`Q1_SCOPUS.csv` to `Q7_SCOPUS.csv`, with `Q4A` and `Q4B`) and the Web of Science XLS files of each block, split into two files when they exceeded the export limit (`Q1_WoS.xls`, `Q2_WoS.xls`, `Q3_WoS1.xls` and `Q3_WoS2.xls`, and so on up to `Q7_WoS2.xls`). `Q7_WoS1_partial.xls` was a first incomplete download of block Q7 (records 1 to 50) that was screened before the rest: `01_merge.R` uses it only to assign the export wave (`wave`) and leaves it out of the counts. The script reads everything it finds in those two folders and takes the block from the beginning of the file name.
