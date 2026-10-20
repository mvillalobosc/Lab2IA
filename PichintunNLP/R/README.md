# R/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los ocho módulos del pipeline y su configuración. `run_all.R` carga los paquetes con `R/lib/packages.R`, después `00_config.R` y las funciones de [lib/](lib/), y corre los módulos en el orden de su número, en el ambiente global. Cada módulo lee lo que necesita de `data/processed/<módulo>.rds` con `load_step()` y guarda su propio resultado con `save_step()`, de modo que `Rscript run_all.R 5 6 7` repite solo esos módulos. Los módulos no se corren sueltos con `Rscript`, porque no cargan por su cuenta la configuración ni las funciones. Vuelve al [README del proyecto](../README.md) o al [README en inglés](../README.en.md).

| Archivo | Qué hace | Tablas en `outputs/tables` |
|---|---|---|
| `00_config.R` | Busca la raíz del proyecto (la carpeta que tiene `run_all.R`), fuerza un locale UTF-8 y define `CFG`: rutas, la canción de entrada que se elimina, las palabras que se reclasifican como culturales (`chile`), la fecha de corte de YouTube (2023-04-13), la ventana de MATTR (200), el umbral de importancia de Random Forest (20 %), las semillas y los colores y tamaños de las figuras. Crea `data/processed`, `outputs/figures` y `outputs/tables`. | |
| `01_ingest.R` | Lee `episodes.csv`, los diálogos en castellano e inglés, las estadísticas de YouTube, las stopwords propias y el léxico temático, y valida que no falten capítulos, que no haya textos vacíos ni palabras repetidas en el léxico. | `01_episodios` |
| `02_clean.R` | Quita la canción de entrada, limpia y tokeniza, separa el vocabulario genérico del cultural con el diccionario hunspell y reclasifica una sola vez las palabras de `forzar_culturales`. | `02_particion_lexica`, `02_diag_forzar_culturales`, `02_diag_palabras_sin_tema` |
| `03_frequency.R` | Calcula frecuencias por capítulo y temporada, nubes de palabras, keyness, dendrogramas (euclidiano y Pearson), correlaciones y clusters MST-kNN. | `03_matriz_frecuencias`, `03_frecuencias_temporada`, `03_keyness_top15_capitulo`, `03_clusters_capitulos` |
| `04_topics.R` | Arma las matrices de los 16 temas por capítulo (conteo y proporción) y por temporada, con radar charts, keyness, dendrogramas, correlaciones y clusters. | `04_temas_por_capitulo`, `04_temas_por_capitulo_proporcion`, `04_temas_por_temporada`, `04_clusters_capitulos` |
| `05_sentiment.R` | Mide el sentimiento por oración y los 16 tipos emocionales con sentimentr sobre las traducciones al inglés, por capítulo, temporada y tramo. | `05_sentimiento_emociones_capitulo`, `05_sentimiento_emociones_temporada`, `05_sentimiento_por_tramo`, `05_clusters_capitulos` |
| `06_readability.R` | Calcula ARI sobre el inglés y MATTR sobre el castellano, ambos con el texto sin limpiar, los vecinos más cercanos por complejidad y la tendencia léxica. | `06_complejidad_capitulo`, `06_complejidad_temporada`, `06_vecinos_complejidad`, `06_tendencia_lexica`, `06_clusters_capitulos` |
| `07_popularity.R` | Normaliza likes, suscriptores y visualizaciones por meses de exposición, ajusta un Random Forest para cada uno y una regresión lineal con las variables sobre el umbral, y avisa con `warning()` si un modelo queda sobreparametrizado. | `07_importancia_rf_*`, `07_coeficientes_lm_*`, `07_resumen_modelos` |
| `08_export.R` | Arma las tablas maestras por capítulo y temporada, el libro Excel de 17 hojas y la verificación de integridad de la corrida. | `08_maestro_capitulos`, `08_maestro_temporadas`, `08_verificacion`, `pichintun_resultados.xlsx` |

Cada módulo de 03 a 07 también guarda sus figuras PNG en `outputs/figures`, con el mismo prefijo numérico. La cabecera de cada script explica qué cambió respecto del `Pichintun.Rmd` original.

## English

This folder holds the eight pipeline modules and their configuration. `run_all.R` loads the packages through `R/lib/packages.R`, then `00_config.R` and the functions in [lib/](lib/), and runs the modules in numeric order, in the global environment. Each module reads what it needs from `data/processed/<module>.rds` with `load_step()` and stores its own result with `save_step()`, so `Rscript run_all.R 5 6 7` repeats only those modules. The modules do not run on their own with `Rscript`, because they do not load the configuration or the functions themselves. Back to the [project README](../README.en.md).

| File | What it does | Tables in `outputs/tables` |
|---|---|---|
| `00_config.R` | Finds the project root (the folder holding `run_all.R`), forces a UTF-8 locale and defines `CFG`: paths, the opening song to remove, the words reclassified as cultural (`chile`), the YouTube cut-off date (2023-04-13), the MATTR window (200), the Random Forest importance threshold (20 %), the seeds and the colours and sizes of the figures. It creates `data/processed`, `outputs/figures` and `outputs/tables`. | |
| `01_ingest.R` | Reads `episodes.csv`, the Spanish and English dialogues, the YouTube statistics, the extra stopwords and the topic lexicon, and checks that no episode is missing, that no text is empty and that no word repeats in the lexicon. | `01_episodios` |
| `02_clean.R` | Removes the opening song, cleans and tokenises, splits generic from cultural vocabulary with the hunspell dictionary and reclassifies the words in `forzar_culturales` once. | `02_particion_lexica`, `02_diag_forzar_culturales`, `02_diag_palabras_sin_tema` |
| `03_frequency.R` | Computes frequencies per episode and season, word clouds, keyness, dendrograms (Euclidean and Pearson), correlations and MST-kNN clusters. | `03_matriz_frecuencias`, `03_frecuencias_temporada`, `03_keyness_top15_capitulo`, `03_clusters_capitulos` |
| `04_topics.R` | Builds the matrices of the 16 topics per episode (counts and proportions) and per season, with radar charts, keyness, dendrograms, correlations and clusters. | `04_temas_por_capitulo`, `04_temas_por_capitulo_proporcion`, `04_temas_por_temporada`, `04_clusters_capitulos` |
| `05_sentiment.R` | Measures sentence-level sentiment and the 16 emotion types with sentimentr on the English translations, per episode, season and segment. | `05_sentimiento_emociones_capitulo`, `05_sentimiento_emociones_temporada`, `05_sentimiento_por_tramo`, `05_clusters_capitulos` |
| `06_readability.R` | Computes ARI on the English text and MATTR on the Spanish text, both on the uncleaned text, the nearest neighbours by complexity and the lexical trend. | `06_complejidad_capitulo`, `06_complejidad_temporada`, `06_vecinos_complejidad`, `06_tendencia_lexica`, `06_clusters_capitulos` |
| `07_popularity.R` | Normalises likes, subscribers and views by months of exposure, fits a Random Forest for each one and a linear regression with the variables above the threshold, and raises a `warning()` when a model is overparameterised. | `07_importancia_rf_*`, `07_coeficientes_lm_*`, `07_resumen_modelos` |
| `08_export.R` | Builds the master tables per episode and season, the 17-sheet Excel workbook and the integrity check of the run. | `08_maestro_capitulos`, `08_maestro_temporadas`, `08_verificacion`, `pichintun_resultados.xlsx` |

Each module from 03 to 07 also saves its PNG figures to `outputs/figures`, with the same numeric prefix. The header of each script explains what changed from the original `Pichintun.Rmd`.
