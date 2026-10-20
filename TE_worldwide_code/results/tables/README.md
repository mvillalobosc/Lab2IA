# TE_worldwide_code/results/tables

[Español](#español) · [English](#english)

## Español

`R/08_tables.R` escribe aquí un fragmento LaTeX por cada tabla del artículo, con los datos de `../robustness.rds`, `../second_stage.rds`, `../covid_model.rds` y la base `../../data/dataset_country_year.csv`. Un fragmento no es una tabla completa: trae las filas, con celdas separadas por `&` y terminadas en `\\`, y líneas de comentario que empiezan con `%` y dicen qué es cada columna y qué números citan las notas de la tabla. Los entornos, títulos y notas de las tablas del manuscrito se armaron a partir de estos fragmentos. El README de los resultados es [`../README.md`](../README.md) y el del proyecto, [`../../README.md`](../../README.md).

| Fragmento | Tabla | Contenido |
|---|---|---|
| `table1_rows.tex` | Tabla 1 | por año, el tamaño y la media y mediana de la frontera anual, los países que la definen por grupo de ingreso, la frontera agrupada, la muestra fija y las correlaciones de rango; además, la transición entre los modelos de 2019 y 2020 |
| `table2_rows.tex` | Tabla 2 | la eficiencia de escala por grupo de ingreso y las fronteras por grupo de ingreso con sus razones de brecha tecnológica |
| `table3_rows.tex` | Tabla 3 | el Tobit principal (coeficiente, IC 95 % y p, en negrita cuando p < 0,05) junto al algoritmo 2 de Simar y Wilson en escala de distancia de Shephard |
| `S6_rows.tex` | Tabla S6 | el puntaje IO-CRS publicado de los 120 países en cada año (`--` donde no hay puntaje) |
| `S7_rows.tex` | Tabla S7 | la media del IO-CRS publicado por grupo de ingreso y año, con la media, mediana y desviación estándar de todos los países |
| `S8_rows.tex` | Tabla S8 | los países que definen la frontera cada año y el grupo de 39 países con puntaje en todos los años |
| `S9_rows.tex` | Tabla S9 | las correlaciones entre los predictores de la segunda etapa y sus VIF con ocho y con siete predictores |
| `S10_rows.tex` | Tabla S10 | por año, las medias y medianas CRS, VRS y de eficiencia de escala, los países en cada frontera y la correlación de Spearman entre CRS y VRS |
| `S11_rows.tex` | Tabla S11 | la frontera agrupada y la de muestra fija por año |
| `S12_rows.tex` | Tabla S12 | la frontera con gasto en salud per cápita (PPP) como insumo, por año y grupo de ingreso |
| `S13_rows.tex` | Tabla S13 | las fronteras por grupo de ingreso por año y ejemplos de países |
| `S14_rows.tex` | Tabla S14 | la comparación de estimadores: Tobit con ocho predictores, principal y sin Singapur; mínimos cuadrados con HC1 y los algoritmos 1 y 2 de Simar y Wilson |
| `S15_rows.tex` | Tabla S15 | el Tobit de cada año, con asteriscos de significancia y el número de observaciones en total y en la frontera |
| `S16_rows.tex` | Tabla S16 | las especificaciones DEA (IO-CRS y OO-CRS, IO-VRS, OO-VRS) por año: media, mediana, mínimo, coeficiente de variación y países en la frontera |
| `S17_rows.tex` | Tabla S17 | el modelo de la pandemia de 2020: coeficiente, error estándar, IC 95 % y p de casos, muertes y número reproductivo |

En las Tablas 1, S10 y S16 las medias y medianas anuales se recalculan desde los puntajes publicados con dos decimales, así que pueden diferir hasta en 0,005 de los valores sin redondear de la tesis que muestra el artículo; cada uno de esos fragmentos lo dice en una línea de comentario.

## English

`R/08_tables.R` writes here one LaTeX fragment per table of the article, from `../robustness.rds`, `../second_stage.rds`, `../covid_model.rds` and the database `../../data/dataset_country_year.csv`. A fragment is not a full table: it holds the rows, with cells separated by `&` and ending in `\\`, and comment lines that start with `%` and state what each column is and which numbers the table notes quote. The table environments, captions and notes of the manuscript were assembled from these fragments. The results README is [`../README.md`](../README.md) and the project README is [`../../README.md`](../../README.md).

| Fragment | Table | Content |
|---|---|---|
| `table1_rows.tex` | Table 1 | by year, the size and the mean and median of the annual frontier, the frontier-defining countries by income group, the pooled frontier, the fixed sample and the rank correlations; then the transition between the 2019 and 2020 models |
| `table2_rows.tex` | Table 2 | scale efficiency by income group and the income-group frontiers with their technology gap ratios |
| `table3_rows.tex` | Table 3 | the main Tobit model (coefficient, 95% CI and p, in bold when p < 0.05) next to Simar and Wilson's Algorithm 2 on the Shephard distance scale |
| `S6_rows.tex` | Table S6 | the published IO-CRS score of the 120 countries in each year (`--` where there is no score) |
| `S7_rows.tex` | Table S7 | the mean published IO-CRS score by income group and year, with the mean, median and standard deviation of all countries |
| `S8_rows.tex` | Table S8 | the frontier-defining countries of each year and the set of 39 countries with a score in every year |
| `S9_rows.tex` | Table S9 | the correlations between the second-stage predictors and their VIFs with eight and with seven predictors |
| `S10_rows.tex` | Table S10 | by year, the CRS, VRS and scale efficiency means and medians, the countries on each frontier and the Spearman correlation between CRS and VRS |
| `S11_rows.tex` | Table S11 | the pooled frontier and the fixed-sample frontier by year |
| `S12_rows.tex` | Table S12 | the frontier with per-capita health expenditure (PPP) as input, by year and income group |
| `S13_rows.tex` | Table S13 | the income-group frontiers by year and country examples |
| `S14_rows.tex` | Table S14 | the comparison of estimators: Tobit with eight predictors, main and without Singapore; least squares with HC1 and Simar and Wilson's Algorithms 1 and 2 |
| `S15_rows.tex` | Table S15 | the year-specific Tobit models, with significance stars and the number of observations in total and on the frontier |
| `S16_rows.tex` | Table S16 | the DEA specifications (IO-CRS and OO-CRS, IO-VRS, OO-VRS) by year: mean, median, minimum, coefficient of variation and countries on the frontier |
| `S17_rows.tex` | Table S17 | the 2020 pandemic model: coefficient, standard error, 95% CI and p for cases, deaths and reproduction number |

In Tables 1, S10 and S16 the annual means and medians are recomputed from the two-decimal published scores, so they can differ by up to 0.005 from the unrounded thesis values that the article shows; each of those fragments says so in a comment line.
