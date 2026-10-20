# R/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el pipeline: la configuración, cuatro archivos de funciones y los nueve pasos del análisis. Cada paso se puede correr solo con `Rscript R/0N_*.R` desde la carpeta del proyecto, porque carga por su cuenta `00_config.R` y los `utils_*.R` que necesita, y se comunica con los demás solo a través de los archivos `.rds` de `data/derived/`. `run_all.R` los corre en orden, cada uno en un ambiente nuevo, y se detiene en el primero que falla. Vuelve al [README del proyecto](../README.md) o al [README en castellano](../README.es.md).

### Configuración y funciones

| Archivo | Qué contiene |
|---|---|
| `00_config.R` | Fuerza un locale UTF-8, define las rutas (`PATHS`) y crea las carpetas que falten, fija el modelo UDPipe (`UDPIPE_MODEL`), los parámetros (`PARAMS`: semilla 20250803, muestras de 5.000 tokens con 30 réplicas, 300 palabras más frecuentes, 1.000 réplicas bootstrap, grilla de UMAP y corrección de Holm), los grupos y colores, las etiquetas bilingües de tablas y figuras, la lista `REQUIRED_PACKAGES` con `check_dependencies()` y el registro de `sessionInfo()`. |
| `utils_text.R` | Normalización tipográfica, las dos representaciones del texto (raw y content), tokenización, segmentación en oraciones, conteo de sílabas del español y stopwords. |
| `utils_stats.R` | Delta de Cliff con intervalo bootstrap, correlación rango-biserial, comparación de grupos con Mann-Whitney y corrección por pruebas múltiples, y formato de p y de tamaños de efecto. |
| `utils_io.R` | Escritura de CSV, tablas LaTeX en inglés y en español, guardado de figuras en PDF (con `cairo_pdf` y respaldo al dispositivo `pdf`), el tema gráfico común y el formato de las tablas de resultados. |
| `utils_sentiment_es.R` | La tabla de polaridad en español construida desde el NRC de syuzhet, los valence shifters (negación, intensificación, atenuación y adversativos) y el autotest que detiene el paso 05 si el léxico no puntúa bien el español. |

### Pasos del análisis

| Paso | Qué hace | Lee de `data/derived/` | Escribe en `data/derived/` |
|---|---|---|---|
| `01_build_corpus.R` | Valida `corpus_metadata.csv` contra los archivos en disco (se detiene si falta o sobra uno), limpia los pies de scraper y el paratexto editorial, arma las dos representaciones y escribe el control de calidad y las tablas de balance del corpus. | | `corpus.rds` |
| `02_lexical_diversity.R` | Calcula 11 índices de diversidad léxica con remuestreo de tamaño fijo y sobre el texto completo, para mostrar cuánto pesa el largo. | `corpus.rds` | `lexical_controlled.rds` |
| `03_readability.R` | Calcula la complejidad estructural y las fórmulas de legibilidad para el español (y las inglesas, etiquetadas). | `corpus.rds` | `readability.rds` |
| `04_pos_analysis.R` | Etiqueta con UDPipe muestras de oraciones del texto crudo hasta un presupuesto fijo de tokens y compara los perfiles morfosintácticos. Necesita el modelo en `models/`. | `corpus.rds` | `pos_profiles.rds` |
| `05_sentiment.R` | Corre el autotest del léxico, mide el sentimiento por oración y arma arcos narrativos de 20 segmentos. | `corpus.rds` | `sentiment.rds`, `narrative_arc.rds` |
| `06_emotions.R` | Mide las emociones NRC por cada 1.000 tokens, el perfil relativo y el contraste con los conteos crudos. | `corpus.rds` | `emotions.rds` |
| `07_stylometry.R` | Agrupa con Burrows's Delta sobre las 300 palabras más frecuentes, estima el soporte de las ramas con 1.000 réplicas bootstrap y lo compara con TF-IDF. | `corpus.rds` | `stylometry.rds` |
| `08_umap.R` | Proyecta con UMAP sobre 5 semillas, 3 valores de vecinos y 3 de distancia mínima y mide la estabilidad de la separación. | `stylometry.rds` | `umap.rds` |
| `09_sensitivity.R` | Vuelve a probar cada métrica con público emparejado, solo español original y un libro por autor sorteado 200 veces. | `corpus.rds` y los `.rds` de los pasos 02 a 06 | `all_metrics.rds` |

Cada paso escribe sus tablas en `outputs/tables` con el prefijo de su número y sus figuras en `outputs/figures`; [outputs/README.md](../outputs/README.md) describe esos archivos. La cabecera de cada script explica, en inglés y en castellano, qué corrige respecto del análisis anterior.

## English

This folder holds the pipeline: the configuration, four helper files and the nine analysis steps. Each step can run on its own with `Rscript R/0N_*.R` from the project folder, because it loads `00_config.R` and the `utils_*.R` files it needs by itself and talks to the other steps only through the `.rds` files in `data/derived/`. `run_all.R` runs them in order, each in a fresh environment, and stops at the first one that fails. Back to the [project README](../README.md).

### Configuration and helpers

| File | What it holds |
|---|---|
| `00_config.R` | Forces a UTF-8 locale, defines the paths (`PATHS`) and creates any missing folders, pins the UDPipe model (`UDPIPE_MODEL`), sets the parameters (`PARAMS`: seed 20250803, 5,000-token samples with 30 replicates, 300 most frequent words, 1,000 bootstrap replicates, the UMAP grid and Holm correction), the groups and colours, the bilingual labels for tables and figures, the `REQUIRED_PACKAGES` list with `check_dependencies()`, and the `sessionInfo()` logging. |
| `utils_text.R` | Typographic normalisation, the two text representations (raw and content), tokenisation, sentence splitting, Spanish syllable counting and stopwords. |
| `utils_stats.R` | Cliff's delta with a bootstrap interval, rank-biserial correlation, group comparison with Mann-Whitney and multiple-testing correction, and formatting of p-values and effect sizes. |
| `utils_io.R` | CSV writing, English and Spanish LaTeX tables, saving figures as PDF (with `cairo_pdf` and a fallback to the `pdf` device), the shared plot theme and the layout of the results tables. |
| `utils_sentiment_es.R` | The Spanish polarity table built from the syuzhet NRC lexicon, the valence shifters (negation, amplification, de-amplification and adversatives) and the self-test that stops step 05 if the lexicon does not score Spanish correctly. |

### Analysis steps

| Step | What it does | Reads from `data/derived/` | Writes to `data/derived/` |
|---|---|---|---|
| `01_build_corpus.R` | Checks `corpus_metadata.csv` against the files on disk (it stops if one is missing or extra), removes scraper footers and editorial front matter, builds both representations and writes the quality report and the corpus balance tables. | | `corpus.rds` |
| `02_lexical_diversity.R` | Computes 11 lexical diversity indices under fixed-size resampling and on the whole text, to show how much length weighs. | `corpus.rds` | `lexical_controlled.rds` |
| `03_readability.R` | Computes structural complexity and the Spanish readability formulas (plus the English ones, labelled as such). | `corpus.rds` | `readability.rds` |
| `04_pos_analysis.R` | Tags sentence samples of the raw text with UDPipe up to a fixed token budget and compares the part-of-speech profiles. It needs the model in `models/`. | `corpus.rds` | `pos_profiles.rds` |
| `05_sentiment.R` | Runs the lexicon self-test, measures sentence-level sentiment and builds 20-segment narrative arcs. | `corpus.rds` | `sentiment.rds`, `narrative_arc.rds` |
| `06_emotions.R` | Measures NRC emotions per 1,000 tokens, the relative profile and the contrast with raw counts. | `corpus.rds` | `emotions.rds` |
| `07_stylometry.R` | Clusters with Burrows's Delta on the 300 most frequent words, estimates branch support with 1,000 bootstrap replicates and compares it with TF-IDF. | `corpus.rds` | `stylometry.rds` |
| `08_umap.R` | Projects with UMAP over 5 seeds, 3 neighbour values and 3 minimum-distance values and measures how stable the separation is. | `stylometry.rds` | `umap.rds` |
| `09_sensitivity.R` | Re-tests every metric with audience matching, original Spanish only and one book per author drawn 200 times. | `corpus.rds` and the `.rds` files from steps 02 to 06 | `all_metrics.rds` |

Each step writes its tables to `outputs/tables` with its number as a prefix and its figures to `outputs/figures`; [outputs/README.md](../outputs/README.md) describes those files. The header of each script explains, in English and Spanish, what it corrects from the earlier analysis.
