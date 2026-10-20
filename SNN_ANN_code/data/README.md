# data/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda todos los datos de la revisión, desde las cadenas de búsqueda hasta el mapa de evidencia. Algunos archivos los escriben los scripts de [`scripts/`](../scripts/) y otros registran las decisiones de los revisores, que los scripts solo leen y validan. El resumen del estudio está en el [README del proyecto](../README.md).

### Subcarpetas, en el orden en que se usan

| Carpeta | Qué contiene | Quién lo produce |
|---|---|---|
| [raw/](raw/) | Cadenas de búsqueda e instrucciones de exportación. Las exportaciones de Scopus y Web of Science no se distribuyen. | Los autores |
| [records/](records/) | Metadatos públicos de los 6.334 registros únicos, duplicados eliminados y conteos de identificación. | `01_deduplicate.R` y `06_rescreen_set.R` |
| [screening/](screening/) | Asignación de lotes y decisiones del cribado por título y resumen: primer paso, piloto, muestra de concordancia y re-cribado. | Las listas, `02` y `06`; las decisiones, los revisores |
| [charting/](charting/) | Codificación de los 2.109 registros evaluados con el resumen completo, muestra de verificación, adjudicaciones y auditoría de año. | Las listas, `08`; las decisiones, los revisores |
| [results/](results/) | Decisiones consolidadas, mapa de evidencia, concordancia y conteos. | `07`, `09` y `10` |
| [fulltext/](fulltext/) | Lista de candidatos y evaluaciones a texto completo. | La lista, `11`; las evaluaciones, los revisores |

### Lo que no está en el repositorio

Las exportaciones crudas (`raw/Scopus.csv`, `raw/Wos1.xls` a `raw/Wos5.xls`) y la carpeta `processed/`, donde los scripts dejan el corpus con resúmenes y los lotes de texto, no se distribuyen porque contienen resúmenes que pertenecen a las bases de datos. El `.gitignore` del proyecto las excluye.

### Formatos

Los archivos de decisiones (`screening/` y `charting/`) son TSV sin encabezado, en el orden exacto de cada lote. Las listas de identificadores y las tablas de resultados son CSV con encabezado. Los TSV de `fulltext/` llevan encabezado.

## English

This folder holds all the data of the review, from the search strings to the evidence map. Some files are written by the scripts in [`scripts/`](../scripts/) and others record the reviewers' decisions, which the scripts only read and validate. The study summary is in the [project README](../README.md).

### Subfolders, in the order they are used

| Folder | What it holds | Who produces it |
|---|---|---|
| [raw/](raw/) | Search strings and export instructions. The Scopus and Web of Science exports are not distributed. | The authors |
| [records/](records/) | Public metadata of the 6,334 unique records, removed duplicates and identification counts. | `01_deduplicate.R` and `06_rescreen_set.R` |
| [screening/](screening/) | Batch assignment and title/abstract screening decisions: first pass, pilot, agreement sample and re-screening. | The lists, `02` and `06`; the decisions, the reviewers |
| [charting/](charting/) | Charting of the 2,109 records assessed on the complete abstract, verification sample, adjudications and year audit. | The lists, `08`; the decisions, the reviewers |
| [results/](results/) | Consolidated decisions, evidence map, agreement and counts. | `07`, `09` and `10` |
| [fulltext/](fulltext/) | Candidate list and full-text assessments. | The list, `11`; the assessments, the reviewers |

### What is not in the repository

The raw exports (`raw/Scopus.csv`, `raw/Wos1.xls` to `raw/Wos5.xls`) and the `processed/` folder, where the scripts leave the corpus with abstracts and the text batches, are not distributed because they contain abstracts that belong to the databases. The project `.gitignore` excludes them.

### Formats

Decision files (`screening/` and `charting/`) are TSV without a header, in the exact order of each batch. Identifier lists and result tables are CSV with a header. The TSV files in `fulltext/` have a header.
