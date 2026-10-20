# Análisis y figuras / Analysis and figures

[Español](#español) · [English](#english)

## Español

Esta carpeta arma las figuras y tablas para publicación a partir de lo que los drivers dejaron en `results/`, con los tres métodos (NSGA-II, MOSA y búsqueda aleatoria). Vuelve al [README del proyecto](../README.md) para ver cómo se generan esos resultados.

Para correr el análisis completo:

```bash
Rscript analysis/run_all_analysis.R
```

o un script a la vez (`01_table_tests.R`, `02_violins.R`, ...).

Las salidas quedan en `analysis/output/`, que `_common.R` crea si no existe. El análisis necesita que exista `results/` (si no, se detiene y pide correr `run_experiments.R`) y toma como conjuntos de datos los que tienen un `resumen_NSGA_<conjunto>.csv` ahí, en orden alfabético. Requiere `ggplot2` y usa `dplyr`, `tidyr` y `scales` cuando están instalados.

### Scripts

| Script | Salida |
|---|---|
| `_common.R` | No escribe nada. Define `MOSA_METRIC`, los tamaños de población para el eje de evaluaciones (`POB_NSGA <- 93`, `POP_RS <- 93`), la paleta pastel, el tema de las figuras y las funciones que leen `results/`. Los demás scripts lo cargan. |
| `01_table_tests.R` | `tabla_hv.csv` (media y desviación estándar por método, mejor método y p de Kruskal-Wallis con y sin corrección de Holm) y `tests_pareados.csv` (Wilcoxon por pares con corrección de Holm, tamaño de efecto A12 y diferencia de medias). Imprime el rango medio y la prueba de Friedman. |
| `02_violins.R` | `violin_hv.png`, `violin_spread.png`, `violin_front_size.png` |
| `03_convergence.R` | `convergence.png`: media e intervalo de confianza del 95 %, con la misma escala en todos los paneles |
| `04_fronts.R` | `fronts.png`: frentes finales con ejes normalizados y aspecto 1:1, leídos desde `results/front_<método>_<conjunto>.csv` |
| `05_epsilon.R` | `epsilon_by_dataset.png` e `indicadores_epsilon.csv`: épsilon aditivo de cada método respecto del frente combinado |
| `06_ranking.R` | `ranking_wins.png` y `ranking_avg.png`: conjuntos ganados por cada método y rango medio |
| `run_all_analysis.R` | Corre 01 a 06 en orden; si uno falla, informa el error y sigue con el siguiente. |

Las figuras se guardan en PNG a 300 dpi, con etiquetas en inglés.

### Cómo se mide MOSA

`_common.R` tiene un interruptor que cambia toda la comparación:

```r
MOSA_METRIC <- "archive"   # "archive" o "single"
```

* `"archive"`: hipervolumen del archivo de soluciones no dominadas que mantiene MOSA, leído de las trazas `conv_*`.
* `"single"`: hipervolumen de la mejor solución individual que optimiza MOSA, leído de `resumen_MOSA_*.csv`.

Los dos modos llevan a conclusiones distintas, así que hay que elegir uno antes de redactar los resultados. En el modo `"archive"`, NSGA-II usa el frente de su población final, mientras MOSA y la búsqueda aleatoria usan un archivo acumulado durante todas las evaluaciones.

## English

This folder builds the publication figures and tables from what the drivers left in `results/`, with the three methods (NSGA-II, MOSA, and Random Search). See the [project README](../README.md) for how those results are produced.

Run everything:

```bash
Rscript analysis/run_all_analysis.R
```

or one script at a time (`01_table_tests.R`, `02_violins.R`, ...).

Output goes to `analysis/output/`, which `_common.R` creates when it is missing. The analysis needs `results/` to exist (otherwise it stops and asks you to run `run_experiments.R`) and takes as data sets those that have a `resumen_NSGA_<data set>.csv` there, in alphabetical order. It requires `ggplot2` and uses `dplyr`, `tidyr` and `scales` when they are installed.

### Scripts

| Script | Output |
|---|---|
| `_common.R` | Writes nothing. It defines `MOSA_METRIC`, the population sizes for the evaluation axis (`POB_NSGA <- 93`, `POP_RS <- 93`), the pastel palette, the figure theme, and the functions that read `results/`. The other scripts load it. |
| `01_table_tests.R` | `tabla_hv.csv` (mean and standard deviation per method, best method, and Kruskal-Wallis p with and without Holm correction) and `tests_pareados.csv` (pairwise Wilcoxon with Holm correction, A12 effect size, and difference of means). It prints the average rank and the Friedman test. |
| `02_violins.R` | `violin_hv.png`, `violin_spread.png`, `violin_front_size.png` |
| `03_convergence.R` | `convergence.png`: mean and 95% confidence interval, with the same scale in every panel |
| `04_fronts.R` | `fronts.png`: final fronts with normalised axes and 1:1 aspect, read from `results/front_<method>_<data set>.csv` |
| `05_epsilon.R` | `epsilon_by_dataset.png` and `indicadores_epsilon.csv`: additive epsilon of each method with respect to the combined front |
| `06_ranking.R` | `ranking_wins.png` and `ranking_avg.png`: data sets won by each method and average rank |
| `run_all_analysis.R` | Runs 01 to 06 in order; if one fails, it reports the error and moves on to the next. |

Figures are saved as PNG at 300 dpi, with English labels.

### How MOSA is measured

`_common.R` has a switch that changes the whole comparison:

```r
MOSA_METRIC <- "archive"   # "archive" or "single"
```

* `"archive"`: hypervolume of the non-dominated archive that MOSA keeps, read from the `conv_*` traces.
* `"single"`: hypervolume of the single best solution MOSA optimises, read from `resumen_MOSA_*.csv`.

They lead to different conclusions, so pick one before writing up results. In `"archive"` mode NSGA-II uses the front of its final population, while MOSA and RS use an archive accumulated over all evaluations.
