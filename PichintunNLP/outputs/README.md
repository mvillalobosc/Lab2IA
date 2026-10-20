# outputs/

[Español](#español) · [English](#english)

## Español

Esta carpeta recibe los resultados del pipeline. En el repositorio solo está `pichintun_resultados.xlsx`. `R/00_config.R` crea `figures/` y `tables/` al correr, y el `.gitignore` de la raíz del repositorio Lab2IA ignora las dos carpetas porque `Rscript run_all.R` las vuelve a generar. Vuelve al [README del proyecto](../README.md) o al [README en inglés](../README.en.md).

| Ruta | Contenido |
|---|---|
| `pichintun_resultados.xlsx` | Copia versionada del libro Excel de 17 hojas. Sus metadatos registran como fecha de creación el 20 de agosto de 2026 a las 02:20 UTC. `R/08_export.R` escribe el libro en `tables/`, así que esta copia no cambia al volver a correr el pipeline. |
| `figures/` | 97 figuras PNG a 150 dpi, de 11 por 8 pulgadas salvo las que fijan otro tamaño. |
| `tables/` | 31 tablas CSV en UTF-8 con BOM, para que Excel lea bien las tildes, y el libro `pichintun_resultados.xlsx`. |

Cada archivo empieza con el número del módulo que lo genera. Las figuras que reúnen varios gráficos en una grilla de 2 por 2, o de 1 por 2 en `06_complejidad_temporada`, se reparten en páginas numeradas desde `_p01` cuando los gráficos no caben en una. La sección [Salidas principales](../README.md#salidas-principales) del README del proyecto explica las tablas y figuras más importantes.

### Figuras

| Módulo | Figuras | Qué muestran |
|---|---|---|
| `03_` | 30 | El keyness y la nube de palabras de cada capítulo (9 páginas cada uno), la composición léxica de cada capítulo, los dendrogramas euclidiano y de Pearson, la correlación y los clusters MST-kNN entre capítulos, las nubes y el keyness por temporada del vocabulario genérico y del cultural, y los dendrogramas y la correlación entre temporadas. |
| `04_` | 27 | Los radares de temas por capítulo (9 páginas) y por temporada, el keyness de temas por capítulo (9 páginas) y por temporada, y los mismos dendrogramas, correlaciones y clusters calculados sobre los temas. |
| `05_` | 27 | El sentimiento oración por oración y las emociones de cada capítulo (9 páginas cada uno), el sentimiento y las emociones por temporada, los dendrogramas, correlaciones y clusters, y la tendencia del sentimiento por tramos. |
| `06_` | 10 | ARI y MATTR de cada capítulo dentro de su temporada (4 páginas, una por temporada), los dendrogramas, la distancia de correlación y los clusters entre capítulos, el dendrograma de temporadas y la tendencia léxica. |
| `07_` | 3 | La importancia de los predictores en el Random Forest de likes, de suscriptores y de visualizaciones. |

### Tablas y libro Excel

Los módulos escriben 1 tabla (`01_`), 3 (`02_`), 4 (`03_`), 4 (`04_`), 4 (`05_`), 5 (`06_`), 7 (`07_`) y 3 (`08_`). El [README de R/](../R/README.md) da el nombre de cada una. `R/07_popularity.R` escribe `07_coeficientes_lm_*` solo cuando alguna variable supera el umbral de importancia. Con los datos actuales se ajustan las tres regresiones, y por eso hay 31 tablas y 17 hojas; un modelo sin variables sobre el umbral deja una tabla y una hoja menos.

Las hojas del libro son `episodios`, `temporadas`, `particion_lexica`, `temas_capitulo`, `temas_proporcion`, `temas_temporada`, `emociones_capitulo`, `emociones_temporada`, `complejidad`, `vecinos_complejidad` y `resumen_modelos`, más `imp_` y `lm_` para `likes`, `suscriptores` y `visualizaciones`. Los clusters quedan solo en los CSV `0N_clusters_capitulos.csv`.

`08_verificacion.csv` resume los chequeos de integridad de la corrida, cada uno con su valor esperado: capítulos, temporadas, palabras sin tema, valores faltantes de ARI, MATTR y sentimiento, tipos emocionales y modelos sobreparametrizados. La fila de palabras sin tema se llama `tokens sin tema`, pero cuenta palabras distintas, no apariciones. En la copia versionada del libro, los modelos de likes y de visualizaciones quedan marcados como sobreparametrizados; la [advertencia del README](../README.md#advertencia-sobre-los-modelos-de-popularidad) explica qué significa.

## English

This folder receives the pipeline results. Only `pichintun_resultados.xlsx` is in the repository. `R/00_config.R` creates `figures/` and `tables/` when the pipeline runs, and the `.gitignore` at the root of the Lab2IA repository ignores both folders because `Rscript run_all.R` generates them again. Back to the [project README](../README.en.md).

| Path | Contents |
|---|---|
| `pichintun_resultados.xlsx` | Versioned copy of the 17-sheet Excel workbook. Its metadata record 20 August 2026 at 02:20 UTC as the creation date. `R/08_export.R` writes the workbook to `tables/`, so this copy does not change when the pipeline runs again. |
| `figures/` | 97 PNG figures at 150 dpi, 11 by 8 inches except those that set another size. |
| `tables/` | 31 CSV tables in UTF-8 with a BOM, so that Excel reads accented characters correctly, and the `pichintun_resultados.xlsx` workbook. |

Each file starts with the number of the module that produces it. Figures that gather several plots in a 2 by 2 grid, or a 1 by 2 grid in `06_complejidad_temporada`, are split into pages numbered from `_p01` when the plots do not fit on one. The [Main outputs](../README.en.md#main-outputs) section of the project README explains the most important tables and figures.

### Figures

| Module | Figures | What they show |
|---|---|---|
| `03_` | 30 | The keyness and the word cloud of each episode (9 pages each), the lexical composition of each episode, the Euclidean and Pearson dendrograms, the correlation and the MST-kNN clusters between episodes, the per-season word clouds and keyness for the generic and the cultural vocabulary, and the dendrograms and correlation between seasons. |
| `04_` | 27 | The topic radar charts per episode (9 pages) and per season, the topic keyness per episode (9 pages) and per season, and the same dendrograms, correlations and clusters computed on the topics. |
| `05_` | 27 | The sentence-by-sentence sentiment and the emotions of each episode (9 pages each), sentiment and emotions per season, the dendrograms, correlations and clusters, and the sentiment trend by segment. |
| `06_` | 10 | ARI and MATTR of each episode within its season (4 pages, one per season), the dendrograms, the correlation distance and the clusters between episodes, the season dendrogram and the lexical trend. |
| `07_` | 3 | The importance of the predictors in the Random Forest for likes, for subscribers and for views. |

### Tables and Excel workbook

The modules write 1 table (`01_`), 3 (`02_`), 4 (`03_`), 4 (`04_`), 4 (`05_`), 5 (`06_`), 7 (`07_`) and 3 (`08_`). The [R/ README](../R/README.md) gives the name of each one. `R/07_popularity.R` writes `07_coeficientes_lm_*` only when some variable passes the importance threshold. With the current data the three regressions are fitted, which is why there are 31 tables and 17 sheets; a model with no variable above the threshold leaves one table and one sheet fewer.

The workbook sheets are `episodios`, `temporadas`, `particion_lexica`, `temas_capitulo`, `temas_proporcion`, `temas_temporada`, `emociones_capitulo`, `emociones_temporada`, `complejidad`, `vecinos_complejidad` and `resumen_modelos`, plus `imp_` and `lm_` for `likes`, `suscriptores` and `visualizaciones`. The clusters are only in the `0N_clusters_capitulos.csv` files.

`08_verificacion.csv` summarises the integrity checks of the run, each with its expected value: episodes, seasons, words without a topic, missing ARI, MATTR and sentiment values, emotion types and overparameterised models. The row for words without a topic is called `tokens sin tema`, but it counts distinct words, not occurrences. In the versioned copy of the workbook, the likes and views models are flagged as overparameterised; the [caveat in the README](../README.en.md#caveat-on-the-popularity-models) explains what that means.
