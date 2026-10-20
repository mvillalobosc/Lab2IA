# outputs/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los resultados de la última corrida completa del pipeline, del 3 y 4 de agosto de 2026 según `logs/session_info.txt`, ya consolidados por `scripts/bundle_outputs.R`. `Rscript run_all.R` los sobrescribe. Los nombres empiezan con el número del paso que los produce, y [docs/RESULTS.md](../docs/RESULTS.md) resume lo que dicen. Vuelve al [README del proyecto](../README.md) o al [README en castellano](../README.es.md).

### tables/

Hay 40 CSV y dos archivos LaTeX. `tables_en.tex` y `tables_es.tex` reúnen las 27 tablas del manuscrito en inglés y en castellano (19 con el mismo nombre que un CSV y 8 versiones compactas de las tablas de resultados); cada archivo pide `\usepackage{booktabs}` y se incluye con `\input{tables_en}` o `\input{tables_es}`. Las tablas `*_results*` tienen una fila por métrica, con medianas y medias de cada grupo, el delta de Cliff con su intervalo bootstrap, la correlación rango-biserial, el p ajustado por Holm y la decisión de significancia. Las tablas `*_by_book` tienen una fila por libro.

| Paso | Archivos |
|---|---|
| 01 | `01_corpus_descriptives` (tokens, tipos y oraciones por libro), `01_corpus_qa` (lo que la limpieza eliminó de cada archivo, con una vista previa), `01_balance_length`, `01_balance_author`, `01_balance_audience` y `01_balance_translation` (el balance de los dos grupos). |
| 02 | `02_lexical_by_book`, `02_lexical_wholetext_by_book`, `02_lexical_results_controlled`, `02_lexical_results_wholetext` y `02_lexical_contrast` (cómo cambia cada índice al controlar el largo). |
| 03 | `03_readability_by_book`, `03_readability_results` y `03_inflesz_bands` (libros por banda INFLESZ en cada grupo). |
| 04 | `04_pos_by_book`, `04_pos_results` y `04_lexical_density_result`. |
| 05 | `05_sentiment_lexicon_selftest` (el autotest del léxico), `05_sentiment_by_book`, `05_sentiment_results` y `05_sentiment_chunk_check` (oraciones y segmentos por libro). |
| 06 | `06_emotions_by_book`, `06_emotions_relative_by_book`, `06_emotions_results_normalised`, `06_emotions_results_relative`, `06_emotions_results_rawcount`, `06_emotions_normalisation_contrast` y `06_emotions_density_and_valence`. |
| 07 | `07_cluster_support` (soporte bootstrap de cada clado), `07_papelucho_cluster_support`, `07_method_comparison` (Delta frente a TF-IDF), `07_dendrogram_order` y `07_cut_purity`. |
| 08 | `08_umap_stability` (las 45 corridas), `08_umap_verdict` y `08_umap_reference_coordinates`. |
| 09 | `09_sensitivity_by_design`, `09_sensitivity_summary` (con la columna `verdict` por métrica), `09_sensitivity_author_draws` y `09_comparison_corpus_composition`. |

Faltan a propósito cuatro CSV intermedios que el pipeline escribe y `bundle_outputs.R` borra: `02_lexical_replicate_summary`, `04_pos_counts_long`, `05_narrative_arc_by_book` y `09_author_draws_raw`. `docs/RESULTS.md` cita `05_narrative_arc_by_book.csv`, que por eso solo aparece después de correr el paso 05.

### figures/

Las 20 figuras están en PDF vectorial (`save_figure()` no escribe PNG salvo que se le pida):

| Paso | Figuras |
|---|---|
| 02 | `02_lexical_indices_controlled` (los índices con control de largo) y `02_lexical_length_dependence` (cómo cambia cada índice con los tokens del libro). |
| 03 | `03_readability_by_group` y `03_sentence_length_distribution`. |
| 04 | `04_pos_profile` (porcentaje de cada categoría) y `04_pos_effect_sizes` (delta de Cliff por categoría). |
| 05 | `05_narrative_arc` (arco medio por grupo), `05_narrative_arc_papelucho` (un arco por libro de Papelucho) y `05_sentiment_metrics`. |
| 06 | `06_emotions_normalised` (por cada 1.000 tokens), `06_emotions_relative_profile` y `06_emotions_normalisation_contrast` (conteo crudo frente a normalizado). |
| 07 | `07_dendrogram_delta`, `07_dendrogram_delta_support` (con el soporte de las ramas) y `07_dendrogram_tfidf_sensitivity`. |
| 08 | `08_umap_reference`, `08_umap_seed_stability` y `08_umap_parameter_stability` (silueta según los vecinos, con la del espacio Delta como referencia). |
| 09 | `09_sensitivity_designs` (delta de Cliff en cada diseño) y `09_sensitivity_author_draws` (proporción de sorteos significativos). |

### logs/

`session_info.txt` junta los nueve `sessionInfo()` de la corrida (R 4.3.3 sobre Ubuntu 24.04.4, semilla 20250803). Una corrida completa también deja aquí `pipeline_timings.csv` con el tiempo de cada paso.

## English

This folder holds the results of the last full pipeline run, from 3 and 4 August 2026 according to `logs/session_info.txt`, already consolidated by `scripts/bundle_outputs.R`. `Rscript run_all.R` overwrites them. File names start with the number of the step that produces them, and [docs/RESULTS.md](../docs/RESULTS.md) summarises what they show. Back to the [project README](../README.md).

### tables/

There are 40 CSV files and two LaTeX files. `tables_en.tex` and `tables_es.tex` gather the 27 manuscript tables in English and in Spanish (19 named like a CSV and 8 compact versions of the results tables); each file needs `\usepackage{booktabs}` and is included with `\input{tables_en}` or `\input{tables_es}`. The `*_results*` tables have one row per metric, with the medians and means of each group, Cliff's delta with its bootstrap interval, the rank-biserial correlation, the Holm-adjusted p-value and the significance decision. The `*_by_book` tables have one row per book.

| Step | Files |
|---|---|
| 01 | `01_corpus_descriptives` (tokens, types and sentences per book), `01_corpus_qa` (what cleaning removed from each file, with a preview), `01_balance_length`, `01_balance_author`, `01_balance_audience` and `01_balance_translation` (the balance between the two groups). |
| 02 | `02_lexical_by_book`, `02_lexical_wholetext_by_book`, `02_lexical_results_controlled`, `02_lexical_results_wholetext` and `02_lexical_contrast` (how each index changes once length is controlled). |
| 03 | `03_readability_by_book`, `03_readability_results` and `03_inflesz_bands` (books per INFLESZ band in each group). |
| 04 | `04_pos_by_book`, `04_pos_results` and `04_lexical_density_result`. |
| 05 | `05_sentiment_lexicon_selftest` (the lexicon self-test), `05_sentiment_by_book`, `05_sentiment_results` and `05_sentiment_chunk_check` (sentences and segments per book). |
| 06 | `06_emotions_by_book`, `06_emotions_relative_by_book`, `06_emotions_results_normalised`, `06_emotions_results_relative`, `06_emotions_results_rawcount`, `06_emotions_normalisation_contrast` and `06_emotions_density_and_valence`. |
| 07 | `07_cluster_support` (bootstrap support of each clade), `07_papelucho_cluster_support`, `07_method_comparison` (Delta against TF-IDF), `07_dendrogram_order` and `07_cut_purity`. |
| 08 | `08_umap_stability` (the 45 runs), `08_umap_verdict` and `08_umap_reference_coordinates`. |
| 09 | `09_sensitivity_by_design`, `09_sensitivity_summary` (with the `verdict` column per metric), `09_sensitivity_author_draws` and `09_comparison_corpus_composition`. |

Four intermediate CSVs that the pipeline writes and `bundle_outputs.R` deletes are missing on purpose: `02_lexical_replicate_summary`, `04_pos_counts_long`, `05_narrative_arc_by_book` and `09_author_draws_raw`. `docs/RESULTS.md` cites `05_narrative_arc_by_book.csv`, which for that reason only appears after running step 05.

### figures/

The 20 figures are vector PDFs (`save_figure()` writes no PNG unless asked to):

| Step | Figures |
|---|---|
| 02 | `02_lexical_indices_controlled` (the indices under length control) and `02_lexical_length_dependence` (how each index changes with the tokens in a book). |
| 03 | `03_readability_by_group` and `03_sentence_length_distribution`. |
| 04 | `04_pos_profile` (percentage of each category) and `04_pos_effect_sizes` (Cliff's delta per category). |
| 05 | `05_narrative_arc` (mean arc per group), `05_narrative_arc_papelucho` (one arc per Papelucho book) and `05_sentiment_metrics`. |
| 06 | `06_emotions_normalised` (per 1,000 tokens), `06_emotions_relative_profile` and `06_emotions_normalisation_contrast` (raw counts against normalised). |
| 07 | `07_dendrogram_delta`, `07_dendrogram_delta_support` (with branch support) and `07_dendrogram_tfidf_sensitivity`. |
| 08 | `08_umap_reference`, `08_umap_seed_stability` and `08_umap_parameter_stability` (silhouette by number of neighbours, with the Delta-space value as reference). |
| 09 | `09_sensitivity_designs` (Cliff's delta in each design) and `09_sensitivity_author_draws` (share of significant draws). |

### logs/

`session_info.txt` gathers the nine `sessionInfo()` records of the run (R 4.3.3 on Ubuntu 24.04.4, seed 20250803). A full run also leaves `pipeline_timings.csv` here, with the time taken by each step.
