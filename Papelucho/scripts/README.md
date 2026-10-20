# scripts/

[Español](#español) · [English](#english)

## Español

Estos cuatro scripts de apoyo no forman parte de los pasos del análisis. Se corren con `Rscript` desde la carpeta del proyecto. Vuelve al [README del proyecto](../README.md) o al [README en castellano](../README.es.md).

| Script | Cuándo se usa | Qué hace |
|---|---|---|
| `download_udpipe_model.R` | Una vez, después de clonar. | Descarga con `udpipe::udpipe_download_model()` el modelo `spanish-gsd` (unos 28 MB) a `models/` y lo deja como `spanish-gsd-ud-2.5-191206.udpipe`, el nombre que fija `R/00_config.R`. Si el modelo ya está, no hace nada. El paso 04 no corre sin él. |
| `unpack_corpus.R` | Antes de la primera corrida. | Descomprime `data/raw/corpus.tar.gz` en `data/raw/papelucho/` (12 textos) y `data/raw/comparison/` (63 textos) y compara el MD5 de cada archivo con `data/metadata/corpus_checksums.csv`. Si falta un archivo o un checksum no calza, lo nombra y sale con código 1. Sin el archivo comprimido igual verifica los textos que ya estén en su lugar. |
| `audit_pipeline.R` | Antes de una corrida larga o de un commit. | Revisa el código sin ejecutar los análisis: llamadas a funciones que no resuelven, columnas que se pisan dentro de `dplyr::summarise()` y métricas de las tablas `*_results*.csv` sin etiqueta en los dos idiomas. Sale con código 1 si encuentra un problema. |
| `bundle_outputs.R` | Al final de `Rscript run_all.R` sin argumentos, o solo. | Junta las tablas LaTeX en `tables_en.tex` y `tables_es.tex` y borra los fragmentos, junta los `sessionInfo_*.txt` en `session_info.txt`, borra las copias PNG de las figuras y cuatro CSV intermedios por réplica (`02_lexical_replicate_summary`, `04_pos_counts_long`, `05_narrative_arc_by_book` y `09_author_draws_raw`), quita los `.gitkeep` de las carpetas de salida que ya tienen archivos e imprime el conteo de archivos, con un aviso si llega a 100. |

`bundle_outputs.R` borra archivos de `outputs/`, pero solo los que el pipeline regenera. Para conservar los fragmentos LaTeX, los PNG o los CSV intermedios hay que borrar el bloque correspondiente del script.

## English

These four helper scripts are not part of the analysis steps. Run them with `Rscript` from the project folder. Back to the [project README](../README.md).

| Script | When to use it | What it does |
|---|---|---|
| `download_udpipe_model.R` | Once, after cloning. | Downloads the `spanish-gsd` model (about 28 MB) to `models/` with `udpipe::udpipe_download_model()` and stores it as `spanish-gsd-ud-2.5-191206.udpipe`, the name pinned in `R/00_config.R`. If the model is already there it does nothing. Step 04 does not run without it. |
| `unpack_corpus.R` | Before the first run. | Unpacks `data/raw/corpus.tar.gz` into `data/raw/papelucho/` (12 texts) and `data/raw/comparison/` (63 texts) and compares the MD5 of each file with `data/metadata/corpus_checksums.csv`. If a file is missing or a checksum does not match, it names it and exits with code 1. Without the archive it still verifies the texts already in place. |
| `audit_pipeline.R` | Before a long run or a commit. | Checks the code without running the analyses: function calls that do not resolve, columns overwritten inside `dplyr::summarise()`, and metrics in the `*_results*.csv` tables without a label in both languages. It exits with code 1 if it finds a problem. |
| `bundle_outputs.R` | At the end of `Rscript run_all.R` without arguments, or on its own. | Merges the LaTeX tables into `tables_en.tex` and `tables_es.tex` and deletes the fragments, merges the `sessionInfo_*.txt` files into `session_info.txt`, deletes the PNG copies of the figures and four per-replicate intermediate CSVs (`02_lexical_replicate_summary`, `04_pos_counts_long`, `05_narrative_arc_by_book` and `09_author_draws_raw`), removes the `.gitkeep` files from output folders that already hold files, and prints the file count, with a warning when it reaches 100. |

`bundle_outputs.R` deletes files in `outputs/`, but only ones the pipeline regenerates. To keep the LaTeX fragments, the PNG files or the intermediate CSVs, delete the corresponding block from the script.
