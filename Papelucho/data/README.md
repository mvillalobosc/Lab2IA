# data/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el corpus y su metadata. [docs/CORPUS.md](../docs/CORPUS.md) explica en detalle cómo se arma, se verifica y se amplía, y la advertencia sobre derechos de autor. Vuelve al [README del proyecto](../README.md) o al [README en castellano](../README.es.md).

### metadata/

| Archivo | Contenido |
|---|---|
| `corpus_metadata.csv` | Una fila por libro (75: 12 de Papelucho y 63 de comparación), curada a mano, con `book_id`, `group`, `filename`, `title_es`, `title_en`, `author`, `series`, `series_position`, `year_first_edition`, `audience`, `original_language`, `translated` y `notes`. Decide qué libros entran: el paso 01 se detiene si un archivo listado falta en disco o si hay un archivo que no está listado. El paso 09 usa `audience`, `original_language` y `translated` para armar los diseños restringidos. |
| `corpus_checksums.csv` | El tamaño en bytes y el MD5 de cada uno de los 75 textos (`book_id`, `group`, `filename`, `bytes`, `md5`), con los que `scripts/unpack_corpus.R` comprueba que el corpus es idéntico al analizado. |

### raw/

`corpus.tar.gz` (15 MB) trae los 75 textos en UTF-8 dentro de dos carpetas, `papelucho/` y `comparison/`, cada una con su `.gitkeep`. Se versiona como un solo archivo para no sumar 75 archivos sueltos al repositorio. `Rscript scripts/unpack_corpus.R` lo descomprime en `raw/papelucho/` y `raw/comparison/`, que el `.gitignore` de la raíz del repositorio Lab2IA ignora. Los nombres de archivo no llevan tildes y deben coincidir exactamente con la columna `filename` de la metadata. Los textos tienen derechos de autor vigentes: antes de compartir una copia del repositorio conviene leer [docs/CORPUS.md](../docs/CORPUS.md).

### derived/

Los pasos crean esta carpeta al correr y dejan ahí los objetos `.rds` que pasan de un paso a otro: `corpus.rds` (paso 01), `lexical_controlled.rds` (02), `readability.rds` (03), `pos_profiles.rds` (04), `sentiment.rds` y `narrative_arc.rds` (05), `emotions.rds` (06), `stylometry.rds` (07), `umap.rds` (08) y `all_metrics.rds` (09). No está en el repositorio y el `.gitignore` de la raíz la ignora; se regenera completa con `Rscript run_all.R`.

## English

This folder holds the corpus and its metadata. [docs/CORPUS.md](../docs/CORPUS.md) explains in detail how the corpus is built, verified and extended, together with the copyright warning. Back to the [project README](../README.md).

### metadata/

| File | Contents |
|---|---|
| `corpus_metadata.csv` | One row per book (75: 12 Papelucho books and 63 comparison books), curated by hand, with `book_id`, `group`, `filename`, `title_es`, `title_en`, `author`, `series`, `series_position`, `year_first_edition`, `audience`, `original_language`, `translated` and `notes`. It decides which books enter: step 01 stops if a listed file is missing from disk or if there is a file that is not listed. Step 09 uses `audience`, `original_language` and `translated` to build the restricted designs. |
| `corpus_checksums.csv` | The size in bytes and the MD5 of each of the 75 texts (`book_id`, `group`, `filename`, `bytes`, `md5`), which `scripts/unpack_corpus.R` uses to check that the corpus is identical to the one analysed. |

### raw/

`corpus.tar.gz` (15 MB) holds the 75 UTF-8 texts in two folders, `papelucho/` and `comparison/`, each with its `.gitkeep`. It is versioned as a single file so the repository does not gain 75 loose files. `Rscript scripts/unpack_corpus.R` unpacks it into `raw/papelucho/` and `raw/comparison/`, which the `.gitignore` at the root of the Lab2IA repository ignores. File names carry no accents and must match the `filename` column of the metadata exactly. The texts are under copyright: read [docs/CORPUS.md](../docs/CORPUS.md) before sharing a copy of the repository.

### derived/

The steps create this folder when they run and leave in it the `.rds` objects that pass from one step to the next: `corpus.rds` (step 01), `lexical_controlled.rds` (02), `readability.rds` (03), `pos_profiles.rds` (04), `sentiment.rds` and `narrative_arc.rds` (05), `emotions.rds` (06), `stylometry.rds` (07), `umap.rds` (08) and `all_metrics.rds` (09). It is not in the repository and the root `.gitignore` ignores it; `Rscript run_all.R` regenerates it in full.
