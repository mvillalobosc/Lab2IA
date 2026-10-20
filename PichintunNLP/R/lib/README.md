# R/lib/

[Español](#español) · [English](#english)

## Español

Estas son las funciones que comparten los módulos. `run_all.R` carga los cuatro archivos antes de correr el primer módulo. Vuelve a [R/](../README.md).

| Archivo | Funciones |
|---|---|
| `packages.R` | `PKGS_CRAN` es la lista única de los 29 paquetes del pipeline. `check_packages()` detiene la corrida si falta alguno, y con `install_missing = TRUE` intenta instalarlos (con `dependencies = TRUE`); `load_packages()` los carga todos. `koRpus.lang.es` no está en CRAN y hay que instalarlo aparte, como explica el README del proyecto. |
| `io.R` | `save_step()` y `load_step()` guardan y leen los resultados de cada módulo en `data/processed/<módulo>.rds`, y `load_step()` falla con un mensaje claro si falta uno. `write_table_out()` escribe CSV en UTF-8 con BOM (para que Excel lea bien las tildes) en `outputs/tables`, `write_workbook_out()` escribe el libro Excel con writexl, `save_fig()` guarda un gráfico como PNG y `save_fig_grid()` reparte varios gráficos en páginas de una grilla (con sufijo `_p01`, `_p02` cuando hay más de una). `step_exists()` y `parse_fecha_es()` no las llama ningún módulo: las fechas ya vienen en ISO en `episodes.csv`. |
| `text.R` | `patron_intro()` y `quitar_intro()` eliminan la canción de entrada con un patrón que tolera tildes, `limpiar_texto()` prepara el texto para tokenizar, `particion_lexica()` separa los tokens en genéricos (reconocidos por hunspell) y culturales (voces indígenas, chilenismos y nombres propios), `tramos_oraciones()` y `n_oraciones()` dividen un texto en tramos con el mismo número de oraciones, y `abreviar_temas()` acorta los nombres largos de tema para los gráficos. |
| `stats_helpers.R` | `keyness_de()` calcula el keyness chi-cuadrado de un documento contra el resto, `plot_dendrograma()` dibuja dendrogramas coloreados por temporada, `matriz_correlacion()` y `plot_corrplot()` arman y dibujan correlaciones de Pearson, `clusters_mst_knn()`, `plot_clusters_mst_knn()` y `tabla_clusters()` agrupan con MST-kNN y tabulan el resultado, y `rescale01()` reescala a [0, 1] devolviendo 0 si el vector es constante. |

## English

These are the functions the modules share. `run_all.R` loads the four files before running the first module. Back to [R/](../README.md).

| File | Functions |
|---|---|
| `packages.R` | `PKGS_CRAN` is the single list of the 29 pipeline packages. `check_packages()` stops the run if one is missing, and with `install_missing = TRUE` it tries to install them (with `dependencies = TRUE`); `load_packages()` loads them all. `koRpus.lang.es` is not on CRAN and must be installed separately, as the project README explains. |
| `io.R` | `save_step()` and `load_step()` store and read each module's result in `data/processed/<module>.rds`, and `load_step()` fails with a clear message when one is missing. `write_table_out()` writes UTF-8 CSV with a BOM (so Excel reads accented characters correctly) to `outputs/tables`, `write_workbook_out()` writes the Excel workbook with writexl, `save_fig()` saves a plot as PNG and `save_fig_grid()` lays several plots out as pages of a grid (with a `_p01`, `_p02` suffix when there is more than one page). `step_exists()` and `parse_fecha_es()` are not called by any module: dates already come in ISO format in `episodes.csv`. |
| `text.R` | `patron_intro()` and `quitar_intro()` remove the opening song with an accent-tolerant pattern, `limpiar_texto()` prepares the text for tokenisation, `particion_lexica()` splits tokens into generic (recognised by hunspell) and cultural (Indigenous words, Chilean idioms and proper nouns), `tramos_oraciones()` and `n_oraciones()` divide a text into segments with the same number of sentences, and `abreviar_temas()` shortens long topic names for the plots. |
| `stats_helpers.R` | `keyness_de()` computes the chi-squared keyness of one document against the rest, `plot_dendrograma()` draws dendrograms coloured by season, `matriz_correlacion()` and `plot_corrplot()` build and plot Pearson correlations, `clusters_mst_knn()`, `plot_clusters_mst_knn()` and `tabla_clusters()` cluster with MST-kNN and tabulate the result, and `rescale01()` rescales to [0, 1], returning 0 when the vector is constant. |
