# plots

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene tres scripts que hacen figuras rápidas de un solo conjunto de datos, comparando NSGA-II con MOSA a partir de lo que hay en `results/`. La búsqueda aleatoria no aparece en estas figuras; las figuras con los tres métodos están en [analysis/](../analysis/). Vuelve al [README del proyecto](../README.md) para ver cómo se generan los resultados.

`main.R` corre los tres scripts al final si `MAKE_PLOTS <- TRUE` en `config.R`. También se pueden correr sueltos, pasando el nombre del conjunto sin extensión. Sin ese argumento, cada script usa `DATASET` cuando lo llama `main.R` y, corrido suelto, el primer conjunto que encuentra en `results/`:

```bash
Rscript plots/plot_convergence.R primates_14
Rscript plots/plot_fronts.R primates_14
Rscript plots/plot_trees.R primates_14 rectangular   # el segundo argumento es opcional
```

Las figuras quedan en `figures/`, en la raíz del proyecto, que los scripts crean si no existe.

| Script | Qué hace | Escribe |
|---|---|---|
| `plot_convergence.R` | Dibuja la convergencia de la mejor corrida de cada algoritmo, con las evaluaciones de la función objetivo en el eje X (generación x `POP_SIZE` en NSGA-II e iteración en MOSA). Muestra el mejor valor hasta el momento de cada método y, en sombra, la oscilación de la solución actual de MOSA. `YLIM` fija el eje Y si se quiere hacer zoom. | `figures/convergence_<conjunto>.html` (gráfico interactivo con plotly) |
| `plot_fronts.R` | Superpone en un panel cuadrado los frentes de Pareto de NSGA-II y MOSA (LS contra ME, ambos a minimizar) de la corrida con mayor hipervolumen final. | `figures/fronts_<conjunto>.html` |
| `plot_trees.R` | Dibuja el árbol medoide de la mejor corrida de cada algoritmo con ggtree, en disposición de dendrograma o, con el segundo argumento `rectangular`, rectangular. | `figures/medoid_NSGA_<conjunto>.png` y `figures/medoid_MOSA_<conjunto>.png`, a 300 dpi |

Si faltan, `plot_convergence.R` y `plot_fronts.R` instalan `plotly` y `htmlwidgets`, y `plot_trees.R` instala `ggtree` desde Bioconductor con `BiocManager`. Los tres ubican la raíz del proyecto buscando `config.R`, pero no lo cargan: corrido suelto, `plot_convergence.R` usa 68 como tamaño de población para el eje X porque no conoce `POP_SIZE`, y el experimento usa 93. Desde `main.R` toma el valor correcto.

## English

This folder holds three scripts that make quick figures for a single data set, comparing NSGA-II with MOSA from what is in `results/`. Random Search does not appear in these figures; the figures with the three methods are in [analysis/](../analysis/). See the [project README](../README.md) for how the results are produced.

`main.R` runs the three scripts at the end when `MAKE_PLOTS <- TRUE` in `config.R`. They also run on their own, taking the data set name without extension. Without that argument, each script uses `DATASET` when `main.R` calls it and, when run on its own, the first data set it finds in `results/`:

```bash
Rscript plots/plot_convergence.R primates_14
Rscript plots/plot_fronts.R primates_14
Rscript plots/plot_trees.R primates_14 rectangular   # the second argument is optional
```

The figures go to `figures/`, in the project root, which the scripts create when it is missing.

| Script | What it does | Writes |
|---|---|---|
| `plot_convergence.R` | Plots the convergence of the best run of each algorithm, with objective-function evaluations on the X axis (generation x `POP_SIZE` for NSGA-II and iteration for MOSA). It shows the best-so-far value of each method and, as a light shadow, the oscillation of the MOSA current solution. `YLIM` fixes the Y axis if you want to zoom in. | `figures/convergence_<data set>.html` (interactive plotly chart) |
| `plot_fronts.R` | Overlays on one square panel the Pareto fronts of NSGA-II and MOSA (LS against ME, both minimised) from the run with the highest final hypervolume. | `figures/fronts_<data set>.html` |
| `plot_trees.R` | Draws the medoid tree of the best run of each algorithm with ggtree, as a dendrogram or, with the second argument `rectangular`, as a rectangular tree. | `figures/medoid_NSGA_<data set>.png` and `figures/medoid_MOSA_<data set>.png`, at 300 dpi |

When missing, `plot_convergence.R` and `plot_fronts.R` install `plotly` and `htmlwidgets`, and `plot_trees.R` installs `ggtree` from Bioconductor through `BiocManager`. All three find the project root by looking for `config.R`, but they do not load it: when run on its own, `plot_convergence.R` uses 68 as the population size for the X axis because it does not know `POP_SIZE`, while the experiment uses 93. When launched from `main.R` it takes the right value.
