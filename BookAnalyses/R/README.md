# R/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el código del pipeline. `run_all.R` carga `config.R`, `R/utils.R` y `R/00_setup.R`, corre `tests/test_metricas.R` y después ejecuta los módulos 01 a 12 en orden, en un ambiente compartido `P` donde cada módulo deja lo que necesitan los siguientes. Los módulos escriben con `guardar_tabla()` (CSV en `output/tablas`) y `guardar_fig()` (PDF y PNG en `output/figuras`); los nombres de los archivos de salida coinciden con los de [resultados/](../resultados/). Vuelve al [README del proyecto](../README.md).

### Módulos del pipeline

| Archivo | Qué hace | Qué escribe en `output/` |
|---|---|---|
| `00_setup.R` | Instala y carga los paquetes, elige entre pdftools y el binario `pdftotext`, crea las carpetas de salida, borra los logs de la corrida anterior (el caché se conserva), descarga el modelo udpipe a `models/` y fija la semilla. | `tablas/`, `figuras/`, `logs/`, `cache/` |
| `01_ingesta.R` | Lee el catálogo, aplica los filtros y expande las obras que aparecen en varios cursos; empareja cada fila con su archivo (número de catálogo, `mapeo_confirmado.csv`, columna de archivo, título exacto, parcial o aproximado) y lee y limpia los textos. Si más del 30 % queda sin archivo y no hay mapeo por contenido, corre `emparejar_contenido.R` una vez. | `tablas/mapeo_archivos.csv`, `cache/texto/` |
| `02_validacion.R` | Cuenta palabras, marca los libros cortos, excluye los textos que no parecen español por su proporción de stopwords y detecta duplicados por título y por hash del contenido. | `tablas/duplicados.csv`, `tablas/resumen_validacion_por_nivel.csv` |
| `03_anotacion.R` | Anota el texto crudo limpio con udpipe (spanish-gsd-ud-2.5), con caché por libro y en paralelo según `config$ncores`. | `cache/anot/`, `cache/anotacion_completa.rds` |
| `04_perfil_gramatical.R` | Calcula proporciones de categorías gramaticales, razón sustantivo/verbo, nominalizaciones, distancia de dependencia, profundidad de árbol y subordinadas, y el chi-cuadrado de categoría por nivel. | `perfil_gramatical_por_libro.csv`, `pos_residuos_chi2.csv`, `pos_chi2_global.csv`, figuras `04_*` |
| `05_afectivo.R` | Mide polaridad y emociones con el léxico NRC en español (vía syuzhet), arma arcos emocionales con DCT de 100 puntos y los agrupa con k-means. | `afectivo_por_libro.csv`, `arcos_clusters.csv`, `arcos_proporcion_por_etapa.csv`, figuras `05_*` |
| `06_complejidad.R` | Calcula legibilidad (ARI, RIX, Flesch-Kincaid, Fernández Huerta, Szigriszt-Pazos y perfil mu) y diversidad léxica (MATTR, MTLD, HD-D, Yule K, entropía, hapax, Maas). | `complejidad_por_libro.csv`, figuras `06_*` |
| `07_lexico.R` | Obtiene los lemas más frecuentes por etapa, el chi-cuadrado término por nivel con y sin nombres propios, el keyness por etapa (log-likelihood) y la matriz TF-IDF. | `lexico_*.csv`, figura `07_keyness_etapas` |
| `08_semantica_clustering.R` | Construye el espacio LSA, agrupa con Ward.D2 sobre distancia chord, replica con distancia de correlación, mide ARI, silueta y Mantel contra el currículo, corre pvclust sobre el perfil de métricas y proyecta con UMAP. | `clustering_evaluacion.csv`, `clustering_membresias.csv`, figuras `08_*` |
| `09_topicos.R` | Ajusta tópicos STM sobre pasajes de `config$chunk_palabras` lemas, con el nivel como covariable de prevalencia. Se salta si `run_topicos = FALSE`. | `topicos_*.csv`, `cache/stm_effect.rds`, figura `09_topicos_tendencia` |
| `10_estadistica_nivel.R` | Arma la tabla maestra y corre Kruskal-Wallis con Dunn (Holm), epsilon cuadrado, Cliff, Jonckheere-Terpstra por permutación, un GAM por métrica, un GAM mixto por oración para la polaridad y la sensibilidad sin duplicados. | `metricas_maestras_por_libro.csv`, `estadistica_*.csv`, figura `10_gam_trayectorias` |
| `11_desajustados.R` | Predice el nivel con regresión ordinal (`MASS::polr`) y validación LOOCV, con respaldo lineal si no converge, y calcula puntajes z con mediana y MAD dentro de cada nivel (`z_robusto`). | `libros_desajustados.csv`, `desajustados_resumen_modelo.csv`, figura `11_desajustados` |
| `12_reporte.R` | Junta las tablas en un libro Excel, escribe un resumen y guarda `sessionInfo()`. | `resultados_maestros.xlsx`, `resumen.md`, `logs/sessionInfo.txt` |

### Funciones de apoyo

`utils.R` reúne lo que usan los módulos: el registro (`log_msg`, `registrar_exclusion`, `registrar_advertencia`), el guardado de tablas y figuras, la normalización de títulos y la lectura de niveles escolares (`parse_niveles_multi`), la lectura de txt, pdf, epub y docx con caché, el silabeo del español, las fórmulas de legibilidad y diversidad, las pruebas estadísticas programadas a mano (Dunn, Jonckheere-Terpstra, Cliff, epsilon cuadrado, V de Cramér, keyness, Rand ajustado) y `construir_catalogo()`, que lee el xlsx según `config.R`. Los tests de [tests/](../tests/) cubren estas métricas.

### Adquisición y diagnóstico

| Archivo | Para qué sirve |
|---|---|
| `paso0_traer_textos.R` | Busca el zip bajado de Drive (`drive-download*.zip` o `Libros*.zip`) en Descargas, Downloads, el home y el proyecto, y lo descomprime aplanado en `config$carpeta_textos`. En modo interactivo abre el selector de archivos si no lo encuentra. |
| `paso1_listar_drive.R` | Lista la carpeta de Drive de `config$drive_url` sin bajar nada, para confirmar el acceso. |
| `descarga_drive.R` | Baja de Drive los txt, pdf, epub y docx, exporta a txt los Google Docs, no repite archivos ya presentes y deja el detalle en `output/tablas/descarga_drive.csv`. Prueba sin autenticación y, si Google la exige, usa `drive_auth()`. |
| `prevuelo.R` | Revisa en un minuto el catálogo y el emparejamiento por número, sin leer ni anotar textos, y da un veredicto antes de la corrida larga. |
| `diagnostico.R` | Imprime un diagnóstico para pegar cuando el emparejamiento no funciona: los archivos de la carpeta de textos, si están pdftools y tesseract, una muestra de la extracción de texto, el estado de `mapeo_confirmado.csv` y las advertencias por motivo. |
| `emparejar_contenido.R` | Identifica qué obra es cada archivo por sus metadatos y sus primeras páginas, con OCR opcional de la portada. Escribe `mapeo_confirmado.csv` junto al catálogo y `output/tablas/mapeo_revision.csv` y `output/tablas/archivos_sin_obra.csv` para revisar a mano. |

Estos scripts se corren desde la raíz del proyecto, porque cargan `config.R` con una ruta relativa.

## English

This folder holds the pipeline code. `run_all.R` loads `config.R`, `R/utils.R` and `R/00_setup.R`, runs `tests/test_metricas.R` and then executes modules 01 to 12 in order, inside a shared environment `P` where each module leaves what the following ones need. Modules write through `guardar_tabla()` (CSV in `output/tablas`) and `guardar_fig()` (PDF and PNG in `output/figuras`); the output file names match those in [resultados/](../resultados/). Back to the [project README](../README.md).

### Pipeline modules

| File | What it does | What it writes to `output/` |
|---|---|---|
| `00_setup.R` | Installs and loads the packages, picks pdftools or the `pdftotext` binary, creates the output folders, deletes the logs of the previous run (the cache is kept), downloads the udpipe model to `models/` and sets the seed. | `tablas/`, `figuras/`, `logs/`, `cache/` |
| `01_ingesta.R` | Reads the catalogue, applies the filters and expands the works listed for several grades; matches each row with its file (catalogue number, `mapeo_confirmado.csv`, file column, exact, partial or approximate title) and reads and cleans the texts. If more than 30 % end up without a file and there is no content-based mapping, it runs `emparejar_contenido.R` once. | `tablas/mapeo_archivos.csv`, `cache/texto/` |
| `02_validacion.R` | Counts words, flags short books, excludes texts that do not look like Spanish from their stopword share, and detects duplicates by title and by content hash. | `tablas/duplicados.csv`, `tablas/resumen_validacion_por_nivel.csv` |
| `03_anotacion.R` | Annotates the cleaned raw text with udpipe (spanish-gsd-ud-2.5), with a per-book cache and in parallel according to `config$ncores`. | `cache/anot/`, `cache/anotacion_completa.rds` |
| `04_perfil_gramatical.R` | Computes part-of-speech shares, noun/verb ratio, nominalisations, dependency distance, tree depth and subordinate clauses, plus the chi-squared test of category by grade. | `perfil_gramatical_por_libro.csv`, `pos_residuos_chi2.csv`, `pos_chi2_global.csv`, figures `04_*` |
| `05_afectivo.R` | Measures polarity and emotions with the Spanish NRC lexicon (through syuzhet), builds 100-point DCT emotional arcs and clusters them with k-means. | `afectivo_por_libro.csv`, `arcos_clusters.csv`, `arcos_proporcion_por_etapa.csv`, figures `05_*` |
| `06_complejidad.R` | Computes readability (ARI, RIX, Flesch-Kincaid, Fernández Huerta, Szigriszt-Pazos and the mu profile) and lexical diversity (MATTR, MTLD, HD-D, Yule's K, entropy, hapax, Maas). | `complejidad_por_libro.csv`, figures `06_*` |
| `07_lexico.R` | Gets the most frequent lemmas per stage, the term-by-grade chi-squared test with and without proper nouns, the per-stage keyness (log-likelihood) and the TF-IDF matrix. | `lexico_*.csv`, figure `07_keyness_etapas` |
| `08_semantica_clustering.R` | Builds the LSA space, clusters with Ward.D2 on chord distance, replicates with correlation distance, measures ARI, silhouette and Mantel against the curriculum, runs pvclust on the metric profile and projects with UMAP. | `clustering_evaluacion.csv`, `clustering_membresias.csv`, figures `08_*` |
| `09_topicos.R` | Fits STM topics on passages of `config$chunk_palabras` lemmas, with grade as a prevalence covariate. It is skipped when `run_topicos = FALSE`. | `topicos_*.csv`, `cache/stm_effect.rds`, figure `09_topicos_tendencia` |
| `10_estadistica_nivel.R` | Builds the master table and runs Kruskal-Wallis with Dunn (Holm), epsilon squared, Cliff, permutation Jonckheere-Terpstra, one GAM per metric, a sentence-level mixed GAM for polarity and the sensitivity check without duplicates. | `metricas_maestras_por_libro.csv`, `estadistica_*.csv`, figure `10_gam_trayectorias` |
| `11_desajustados.R` | Predicts the grade with ordinal regression (`MASS::polr`) and LOOCV, with a linear fallback when it does not converge, and computes z-scores based on the median and MAD within each grade (`z_robusto`). | `libros_desajustados.csv`, `desajustados_resumen_modelo.csv`, figure `11_desajustados` |
| `12_reporte.R` | Gathers the tables into an Excel workbook, writes a summary and saves `sessionInfo()`. | `resultados_maestros.xlsx`, `resumen.md`, `logs/sessionInfo.txt` |

### Helper functions

`utils.R` collects what the modules use: logging (`log_msg`, `registrar_exclusion`, `registrar_advertencia`), saving tables and figures, title normalisation and school-grade parsing (`parse_niveles_multi`), cached reading of txt, pdf, epub and docx files, Spanish syllable counting, the readability and diversity formulas, the hand-coded statistical tests (Dunn, Jonckheere-Terpstra, Cliff, epsilon squared, Cramér's V, keyness, adjusted Rand) and `construir_catalogo()`, which reads the workbook according to `config.R`. The tests in [tests/](../tests/) cover these metrics.

### Acquisition and diagnostics

| File | Purpose |
|---|---|
| `paso0_traer_textos.R` | Looks for the zip downloaded from Drive (`drive-download*.zip` or `Libros*.zip`) in the Downloads folders, the home folder and the project, and unpacks it flat into `config$carpeta_textos`. In interactive mode it opens the file picker if it cannot find one. |
| `paso1_listar_drive.R` | Lists the Drive folder in `config$drive_url` without downloading anything, to confirm access. |
| `descarga_drive.R` | Downloads the txt, pdf, epub and docx files from Drive, exports Google Docs to txt, skips files already present and records the details in `output/tablas/descarga_drive.csv`. It tries without authentication first and uses `drive_auth()` if Google requires it. |
| `prevuelo.R` | Checks the catalogue and the number-based matching in one minute, without reading or annotating texts, and gives a verdict before the long run. |
| `diagnostico.R` | Prints a report to paste when matching does not work: the files in the texts folder, whether pdftools and tesseract are available, a sample of the text extraction, the state of `mapeo_confirmado.csv` and the warnings grouped by reason. |
| `emparejar_contenido.R` | Works out which catalogue entry each file is from its metadata and first pages, with optional OCR of the cover. It writes `mapeo_confirmado.csv` next to the catalogue, plus `output/tablas/mapeo_revision.csv` and `output/tablas/archivos_sin_obra.csv` for manual review. |

These scripts run from the project root, because they load `config.R` through a relative path.
