# resultados/tablas/

[Español](#español) · [English](#english)

## Español

Estas 24 tablas CSV (UTF-8, separadas por coma) salen de la corrida del manuscrito y llevan los mismos nombres que escriben los módulos en `output/tablas`. La columna "Módulo" dice qué script de [R/](../../R/) produce cada una. Los libros se identifican con `id_libro` (o `doc_id`, el mismo código `L0001`, `L0002`...) y los niveles van de 1 a 12. Vuelve a [resultados/](../README.md).

| Archivo | Filas | Qué contiene | Módulo |
|---|---|---|---|
| `mapeo_archivos.csv` | 721 | Cada fila obra-nivel del catálogo con su archivo y el tipo de emparejamiento: 704 por número de catálogo y 17 sin archivo para su número. | 01 |
| `duplicados.csv` | 125 | Libros con título o contenido repetido (`titulo_duplicado`, `contenido_duplicado` y el hash `md5`). | 02 |
| `resumen_validacion_por_nivel.csv` | 12 | Libros, palabras totales y mediana de palabras por nivel. | 02 |
| `perfil_gramatical_por_libro.csv` | 577 | Proporción de cada categoría gramatical (`prop_ADJ` a `prop_VERB`), razón sustantivo/verbo, nominalizaciones por mil palabras, distancia de dependencia, profundidad de árbol y subordinadas por oración. | 04 |
| `pos_residuos_chi2.csv` | 144 | Residuos estandarizados del chi-cuadrado de categoría gramatical por nivel (12 niveles por 12 categorías). | 04 |
| `pos_chi2_global.csv` | 1 | El chi-cuadrado global de esa tabla, con grados de libertad, p y V de Cramér. | 04 |
| `afectivo_por_libro.csv` | 577 | Polaridad media y su desviación, proporción de oraciones negativas, y el conteo (`n_anger` a `n_trust`) y la proporción (`prop_ira` a `prop_confianza`) de las ocho emociones NRC por libro. | 05 |
| `arcos_clusters.csv` | 531 | El cluster de arco emocional (1 a 5) de cada libro que tuvo oraciones suficientes para armar el arco. | 05 |
| `arcos_proporcion_por_etapa.csv` | 15 | La proporción de cada cluster de arco dentro de cada etapa escolar. | 05 |
| `complejidad_por_libro.csv` | 577 | Legibilidad (ARI, RIX, Flesch-Kincaid, Fernández Huerta, Szigriszt-Pazos, perfil mu y banda INFLESZ) y diversidad léxica (TTR, MTLD, HD-D, Yule K, entropía, hapax, Maas, MATTR 50 y 100, pendiente de Zipf). | 06 |
| `lexico_top20_por_etapa.csv` | 60 | Los 20 lemas más frecuentes de cada etapa. | 07 |
| `lexico_chi2_global_sin_propn.csv` | 1 | Chi-cuadrado global de lema por nivel sobre los 500 lemas más frecuentes, sin nombres propios. | 07 |
| `lexico_chi2_global_con_propn.csv` | 1 | Lo mismo con nombres propios. | 07 |
| `lexico_residuos_top_sin_propn.csv` | 180 | Los 15 lemas con mayor residuo en cada nivel, sin nombres propios. | 07 |
| `lexico_residuos_top_con_propn.csv` | 180 | Lo mismo con nombres propios. | 07 |
| `lexico_keyness_por_etapa.csv` | 90 | Los 30 lemas más característicos de cada etapa según log-likelihood (`ll`). | 07 |
| `clustering_evaluacion.csv` | 2 | Comparación del agrupamiento con el currículo para LSA con distancia chord y para TF-IDF con distancia de correlación: ARI contra nivel y etapa, silueta y Mantel. | 08 |
| `clustering_membresias.csv` | 576 | El cluster de cada libro en las soluciones LSA de 3 y 12 grupos y en la réplica por correlación. | 08 |
| `metricas_maestras_por_libro.csv` | 577 | La tabla maestra, con 69 columnas: la identificación de cada obra (`id_libro`, `titulo`, `titulo_norm`, `nivel`, `etapa`) y las métricas de los módulos 04 a 06. Es el listado que promete el apéndice. | 10 |
| `estadistica_kw_jt_completo.csv` | 24 | Por métrica: Kruskal-Wallis (H, p y p Holm), epsilon cuadrado, Jonckheere-Terpstra con 2000 permutaciones y su dirección, y delta de Cliff entre los niveles 1 y 12 y entre básica inicial y media. | 10 |
| `estadistica_dunn_significativos_completo.csv` | 323 | Los pares de niveles que difieren en la prueba de Dunn con corrección de Holm. | 10 |
| `estadistica_gam_por_metrica.csv` | 24 | El suavizado del GAM de cada métrica sobre el nivel: grados efectivos, F, p y desviación explicada. | 10 |
| `gam_predicciones.csv` | 1.080 | Las trayectorias ajustadas por el GAM para las 24 métricas, del nivel 1 al 12 cada 0,25, con error estándar (`metrica`, `nivel`, `ajuste`, `se`). | 10 |
| `libros_desajustados.csv` | 577 | Nivel asignado y nivel predicho por la regresión ordinal con LOOCV, la diferencia, el modelo usado (575 con `polr`) y las métricas extremas según un puntaje z con mediana y MAD dentro del nivel. | 11 |

## English

These 24 CSV tables (UTF-8, comma separated) come from the manuscript run and carry the same names the modules write to `output/tablas`. The "Module" column says which script in [R/](../../R/) produces each one. Books are identified by `id_libro` (or `doc_id`, the same `L0001`, `L0002`... code) and grades run from 1 to 12. Back to [resultados/](../README.md).

| File | Rows | What it holds | Module |
|---|---|---|---|
| `mapeo_archivos.csv` | 721 | Each work-grade row of the catalogue with its file and the type of match: 704 by catalogue number and 17 without a file for their number. | 01 |
| `duplicados.csv` | 125 | Books with a repeated title or content (`titulo_duplicado`, `contenido_duplicado` and the `md5` hash). | 02 |
| `resumen_validacion_por_nivel.csv` | 12 | Books, total words and median words per grade. | 02 |
| `perfil_gramatical_por_libro.csv` | 577 | Share of each part of speech (`prop_ADJ` to `prop_VERB`), noun/verb ratio, nominalisations per thousand words, dependency distance, tree depth and subordinate clauses per sentence. | 04 |
| `pos_residuos_chi2.csv` | 144 | Standardised residuals of the part-of-speech by grade chi-squared test (12 grades by 12 categories). | 04 |
| `pos_chi2_global.csv` | 1 | The chi-squared statistic for the whole table, with degrees of freedom, p and Cramér's V. | 04 |
| `afectivo_por_libro.csv` | 577 | Mean polarity and its standard deviation, share of negative sentences, and the count (`n_anger` to `n_trust`) and share (`prop_ira` to `prop_confianza`) of the eight NRC emotions per book. | 05 |
| `arcos_clusters.csv` | 531 | The emotional-arc cluster (1 to 5) of each book that had enough sentences to build an arc. | 05 |
| `arcos_proporcion_por_etapa.csv` | 15 | The share of each arc cluster within each school stage. | 05 |
| `complejidad_por_libro.csv` | 577 | Readability (ARI, RIX, Flesch-Kincaid, Fernández Huerta, Szigriszt-Pazos, mu profile and INFLESZ band) and lexical diversity (TTR, MTLD, HD-D, Yule's K, entropy, hapax, Maas, MATTR 50 and 100, Zipf slope). | 06 |
| `lexico_top20_por_etapa.csv` | 60 | The 20 most frequent lemmas in each stage. | 07 |
| `lexico_chi2_global_sin_propn.csv` | 1 | Lemma by grade chi-squared test for the whole table, over the 500 most frequent lemmas, without proper nouns. | 07 |
| `lexico_chi2_global_con_propn.csv` | 1 | The same with proper nouns. | 07 |
| `lexico_residuos_top_sin_propn.csv` | 180 | The 15 lemmas with the largest residual in each grade, without proper nouns. | 07 |
| `lexico_residuos_top_con_propn.csv` | 180 | The same with proper nouns. | 07 |
| `lexico_keyness_por_etapa.csv` | 90 | The 30 most characteristic lemmas of each stage by log-likelihood (`ll`). | 07 |
| `clustering_evaluacion.csv` | 2 | How the clustering compares with the curriculum for LSA with chord distance and for TF-IDF with correlation distance: ARI against grade and stage, silhouette and Mantel. | 08 |
| `clustering_membresias.csv` | 576 | The cluster of each book in the 3-group and 12-group LSA solutions and in the correlation replica. | 08 |
| `metricas_maestras_por_libro.csv` | 577 | The master table, with 69 columns: the identification of each work (`id_libro`, `titulo`, `titulo_norm`, `nivel`, `etapa`) and the metrics from modules 04 to 06. It is the listing promised in the appendix. | 10 |
| `estadistica_kw_jt_completo.csv` | 24 | Per metric: Kruskal-Wallis (H, p and Holm p), epsilon squared, Jonckheere-Terpstra with 2000 permutations and its direction, and Cliff's delta between grades 1 and 12 and between early primary and secondary. | 10 |
| `estadistica_dunn_significativos_completo.csv` | 323 | The pairs of grades that differ in Dunn's test with Holm correction. | 10 |
| `estadistica_gam_por_metrica.csv` | 24 | The GAM smooth of each metric over grade: effective degrees of freedom, F, p and deviance explained. | 10 |
| `gam_predicciones.csv` | 1,080 | The GAM-fitted trajectories for the 24 metrics, from grade 1 to 12 every 0.25, with standard error (`metrica`, `nivel`, `ajuste`, `se`). | 10 |
| `libros_desajustados.csv` | 577 | Assigned grade and the grade predicted by ordinal regression with LOOCV, the difference, the model used (575 with `polr`) and the extreme metrics according to a z-score based on the median and MAD within the grade. | 11 |
