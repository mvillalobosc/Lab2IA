# MOPhyloKmer

[Español](#español) · [English](#english)

## Español

MOPhyloKmer compara metaheurísticas multiobjetivo para inferir filogenias sin alineamiento.

Tres métodos (**NSGA-II**, **MOSA** y una **búsqueda aleatoria** como línea base) infieren árboles filogenéticos a partir de **distancias de k-meros** y minimizan a la vez dos objetivos:

* **LS** (mínimos cuadrados): diferencia entre las distancias originales y las distancias cofenéticas del árbol.
* **ME** (evolución mínima): largo total de las ramas del árbol.

La calidad se mide con el indicador de **hipervolumen**, con punto de referencia (2, 2). Los dos objetivos se escalan por `10 x` el valor del árbol base de Neighbour-Joining, así que el árbol base queda siempre en `(0.1, 0.1)` y el hipervolumen se puede comparar entre conjuntos de datos (línea base NJ = 3,61, máximo teórico = 4).

### Estructura del repositorio

```
MOPhyloKmer/
├── LICENSE                  Licencia MIT del código.
├── config.R                 Configuración central. Es el único archivo que se edita.
├── main.R                   Un conjunto de datos: NSGA-II + MOSA + figuras.
├── run_experiments.R        Todos los conjuntos x 3 métodos + tabla comparativa.
├── run_random_search.R      Solo la línea base RS sobre todos los conjuntos.
│
├── algorithms/
│   ├── nsga2/
│   │   ├── run_nsga.R       Driver de NSGA-II (11 corridas, en serie o en paralelo).
│   │   └── R/               Operadores: cruza, mutación, ordenamiento, objetivos.
│   ├── mosa/
│   │   ├── run_mosa.R       Driver del recocido simulado multiobjetivo.
│   │   └── R/               Perturbación, objetivos, hipervolumen, lectura.
│   └── rs/
│       └── run_rs.R         Línea base de búsqueda aleatoria (reutiliza los módulos de mosa).
│
├── tuning/
│   ├── irace_nsga.R         Afinado de parámetros de NSGA-II (presupuesto fijo).
│   ├── irace_mosa.R         Afinado de parámetros de MOSA (presupuesto fijo).
│   └── run_tuning.R         Corre los dos afinados, uno después del otro.
│
├── plots/                   Figuras rápidas de un conjunto (NSGA-II vs MOSA).
│   ├── plot_convergence.R   Curva de convergencia de la mejor corrida.
│   ├── plot_fronts.R        Frentes de Pareto de la mejor corrida.
│   └── plot_trees.R         Árboles medoide (ggtree).
│
├── analysis/                Figuras y tablas para publicación (los tres métodos).
│   ├── _common.R            Configuración, paleta y carga de datos del análisis.
│   ├── 01_table_tests.R     Tabla de hipervolumen + pruebas estadísticas.
│   ├── 02_violins.R         Violines: HV, spread, tamaño del frente.
│   ├── 03_convergence.R     Curvas de convergencia, media e IC 95 %.
│   ├── 04_fronts.R          Frentes de Pareto finales, ejes normalizados.
│   ├── 05_epsilon.R         Indicador épsilon aditivo.
│   ├── 06_ranking.R         Victorias por método y rango medio.
│   └── run_all_analysis.R   Corre 01 a 06.
│
└── data/                    13 conjuntos de datos en formato .phylip.
```

Cada carpeta tiene su propio `README.md` con el detalle de sus archivos: [algorithms/](algorithms/), [analysis/](analysis/), [data/](data/), [plots/](plots/) y [tuning/](tuning/). Las carpetas `results/`, `figures/` y `analysis/output/` no vienen en el repositorio: los scripts las crean al correr (ver [Archivos de salida](#archivos-de-salida)).

### Requisitos

R 4.2 o superior, más estos paquetes:

```
ecr  ape  seqinr  kmer  phylotools  phangorn  stringr
phytools  treespace  igraph  ggplot2  factoextra  insect
```

`algorithms/*/R/packages.R` solo carga esos paquetes, nunca los instala ni los actualiza: si falta alguno, se detiene con la lista de lo que hay que instalar. Antes de cargarlos, antepone a `.libPaths()` la biblioteca de usuario `~/R/x86_64-pc-linux-gnu-library/4.3` y la crea si no existe, aunque el sistema no sea Linux ni R 4.3.

Los paquetes extra sí se instalan solos si faltan: `irace` (solo para el afinado), `plotly` y `htmlwidgets` (para `plots/plot_convergence.R` y `plots/plot_fronts.R`) y `ggtree` de Bioconductor, con `BiocManager` (solo para `plots/plot_trees.R`). El análisis de `analysis/` necesita `ggplot2` y usa `dplyr`, `tidyr` y `scales` cuando están instalados. `PARALLEL = TRUE` usa el paquete base `parallel`.

### Inicio rápido

```bash
# 1. Un conjunto, para comprobar que todo funciona (NSGA-II + MOSA + figuras)
Rscript main.R

# 2. Experimento completo: 13 conjuntos x 3 métodos, 11 corridas cada uno, + tabla comparativa
Rscript run_experiments.R

# 3. Figuras y tablas para publicación a partir de los resultados
Rscript analysis/run_all_analysis.R
```

`main.R` corre solo NSGA-II y MOSA sobre `DATASET`; la búsqueda aleatoria se corre con `run_experiments.R` o, sola sobre los 13 conjuntos, con `Rscript run_random_search.R`.

Opcional, afinado de parámetros con irace (largo, varias horas):

```bash
Rscript tuning/run_tuning.R      # produce tuning/best_nsga.csv y tuning/best_mosa.csv
```

Cada script encuentra por sí mismo la raíz del repositorio (sube carpetas hasta dar con `config.R`), así que funciona con `Rscript`, con `source()` en RStudio y desde cualquier directorio de trabajo.

Los drivers de `algorithms/` también corren sueltos (por ejemplo `Rscript algorithms/nsga2/run_nsga.R`), pero en ese caso no leen `config.R`: usan sus valores internos, que no coinciden con los de `config.R`. El [README de algorithms/](algorithms/README.md) los lista. Para reproducir el experimento, lánzalos siempre desde `main.R`, `run_experiments.R` o `run_random_search.R`.

### Configuración

La configuración completa está en **`config.R`**:

| Bloque | Qué controla |
|---|---|
| Un conjunto | `DATASET`, `MAKE_PLOTS` |
| Experimento completo | `DATASETS`, `N_RUNS`, `SEQ_TYPE`, `K`, `SEED`, `RUN_ALGORITHMS` |
| Paralelismo | `PARALLEL`, `N_CORES` (las corridas se reparten entre núcleos) |
| Registro | `EVERY_N` (las métricas se registran cada N generaciones o ciclos) |
| NSGA-II | `POP_SIZE`, `N_GEN`, `P_CROSS`, `P_MUT` |
| MOSA | `N_INNER`, `N_OUTER`, `T0`, `ALPHA` |
| Búsqueda aleatoria | `POP_RS`, `GEN_RS` |
| Afinado | `BUDGET`, `HOURS_NSGA`, `HOURS_MOSA`, `N_PAR`, `INSTANCES` |

Los valores actuales vienen del afinado con irace y dan a los tres métodos un presupuesto comparable de unas 10.000 evaluaciones de la función objetivo (NSGA-II 93 x 108 = 10.044, MOSA 98 x 102 = 9.996 y RS 93 x 108 = 10.044). Con `PARALLEL = TRUE`, las corridas se reparten en hasta `N_CORES` núcleos, que por defecto son todos menos uno.

`SEQ_TYPE` es un solo valor (`"DNA"`) para los 13 conjuntos, aunque `conrado_126.phylip` trae secuencias de aminoácidos; con esa configuración ese archivo también se lee con `ape::read.dna()`.

### Archivos de salida

`results/`, un conjunto de archivos por conjunto de datos y método (`NSGA`, `MOSA`, `RS`):

| Archivo | Contenido |
|---|---|
| `conv_<método>_<conjunto>_runNN.csv` | Traza de convergencia de cada corrida: hipervolumen, mejor hasta ahora, spread y tamaño del frente |
| `resumen_<método>_<conjunto>.csv` | Una fila por corrida: `run`, mejor hipervolumen y `seconds`. La columna del hipervolumen se llama `hv_max` en NSGA y RS y `hv_best` en MOSA |
| `front_<método>_<conjunto>.csv` | Frente de Pareto final de la mejor corrida (`ls`, `me`) |
| `medoid_<método>_<conjunto>.nwk` | Árbol medoide de ese frente, en formato Newick |

Al terminar, cada driver conserva el frente y el medoide de la mejor corrida y borra los `front_*_runNN.csv` y `medoid_*_runNN.nwk` de las demás; las trazas `conv_*_runNN.csv` de las 11 corridas se quedan.

`run_experiments.R` escribe además, en la raíz del proyecto, `tabla_resultados.csv` (hipervolumen medio de los tres métodos, línea base NJ, valor p de Kruskal-Wallis, valores p por pares, corrección de Holm y mejor método) y `tabla_hv.tex` (la misma tabla en LaTeX, lista para pegar). `plots/` escribe en `figures/` y el análisis en `analysis/output/` (figuras PNG y tablas CSV).

Los scripts generan los archivos de `results/`, `figures/` y `analysis/output/`, además de `tabla_resultados.csv`, `tabla_hv.tex` y los resultados del afinado (`tuning/best_*.csv`, `tuning/*.Rdata`). Por eso el `.gitignore` de la raíz del monorepo los excluye y no se versionan; se vuelven a crear al correr el pipeline.

### Notas sobre los métodos

* **NSGA-II** hace evolucionar una población de matrices de distancia. En cada generación arma los hijos con cerca de un 40 % de cruzas, un 40 % de mutaciones y el resto con matrices aleatorias, y elige la siguiente población por frentes no dominados y distancia de crowding. Su frente es el conjunto de rango 1 de la población final.
* En el código, `P_CROSS` funciona como el peso `w` de la cruza convexa (hijo = `w` x padre1 + (1 - `w`) x padre2), aunque `config.R` lo describe como probabilidad de cruza, y `P_MUT` es a la vez la probabilidad de mutar cada celda de la matriz y la amplitud del ruido uniforme.
* **MOSA** explora con una sola solución: multiplica cada celda de su matriz de distancias por un factor U(0,9; 1,1), rehace el árbol con NJ y acepta el candidato con el criterio de Metropolis sobre su hipervolumen. Además guarda un archivo de soluciones no dominadas, y de ese archivo sale su frente.
* La **búsqueda aleatoria** genera candidatos con el mismo operador de perturbación que MOSA, siempre a partir del árbol base, sin selección ni cruza. Es la línea base que muestra cuánto del resultado viene de la búsqueda misma.
* El **árbol medoide** es el punto del frente con la menor suma de distancias a los demás puntos, en el espacio de objetivos normalizado. Es una solución de compromiso representativa, no la mejor en ninguno de los dos objetivos.
* Cada corrida usa la semilla `SEED + run`, así que los resultados son los mismos en serie y en paralelo.

### Licencia

El código se distribuye con licencia MIT ([LICENSE](LICENSE)). Los alineamientos de `data/` conservan los términos de sus fuentes originales.

## English

MOPhyloKmer compares multi-objective metaheuristics for alignment-free phylogenetic inference.

Three methods (**NSGA-II**, **MOSA** and a **Random Search** baseline) infer phylogenetic trees from **k-mer distances**, jointly minimising two objectives:

* **LS** (least squares): difference between the original distances and the cophenetic distances of the tree.
* **ME** (minimum evolution): total branch length of the tree.

Quality is measured with the **hypervolume** indicator, with reference point (2, 2). Both objectives are scaled by `10 x` the value of the Neighbour-Joining base tree, so the base tree always sits at `(0.1, 0.1)` and the hypervolume is comparable across data sets (NJ baseline = 3.61, theoretical maximum = 4).

### Repository layout

```
MOPhyloKmer/
├── LICENSE                  MIT licence of the code.
├── config.R                 Central configuration. The only file you edit.
├── main.R                   One data set: NSGA-II + MOSA + figures.
├── run_experiments.R        All data sets x 3 methods + comparison table.
├── run_random_search.R      Only the RS baseline over all data sets.
│
├── algorithms/
│   ├── nsga2/
│   │   ├── run_nsga.R       NSGA-II driver (11 runs, serial or parallel).
│   │   └── R/               Operators: crossover, mutation, sorting, objectives.
│   ├── mosa/
│   │   ├── run_mosa.R       Multi-objective simulated annealing driver.
│   │   └── R/               Perturbation, objectives, hypervolume, I/O.
│   └── rs/
│       └── run_rs.R         Random Search baseline (reuses the mosa modules).
│
├── tuning/
│   ├── irace_nsga.R         Parameter tuning for NSGA-II (fixed budget).
│   ├── irace_mosa.R         Parameter tuning for MOSA (fixed budget).
│   └── run_tuning.R         Runs both tunings, one after the other.
│
├── plots/                   Quick figures for one data set (NSGA-II vs MOSA).
│   ├── plot_convergence.R   Convergence curve of the best run.
│   ├── plot_fronts.R        Pareto fronts of the best run.
│   └── plot_trees.R         Medoid trees (ggtree).
│
├── analysis/                Publication figures and tables (the three methods).
│   ├── _common.R            Config, palette and data loading for the analysis.
│   ├── 01_table_tests.R     Table of hypervolume + statistical tests.
│   ├── 02_violins.R         Violin plots: HV, spread, front size.
│   ├── 03_convergence.R     Convergence curves, mean and 95% CI.
│   ├── 04_fronts.R          Final Pareto fronts, normalised axes.
│   ├── 05_epsilon.R         Additive epsilon indicator.
│   ├── 06_ranking.R         Wins per method and average rank.
│   └── run_all_analysis.R   Runs 01 to 06.
│
└── data/                    13 data sets in .phylip format.
```

Each folder has its own `README.md` with the details of its files: [algorithms/](algorithms/), [analysis/](analysis/), [data/](data/), [plots/](plots/), and [tuning/](tuning/). The `results/`, `figures/` and `analysis/output/` folders are not in the repository: the scripts create them when they run (see [Output files](#output-files)).

### Requirements

R 4.2 or newer, plus these packages:

```
ecr  ape  seqinr  kmer  phylotools  phangorn  stringr
phytools  treespace  igraph  ggplot2  factoextra  insect
```

`algorithms/*/R/packages.R` only loads these packages, it never installs or updates them: if one is missing it stops with the list of what to install. Before loading them, it puts the user library `~/R/x86_64-pc-linux-gnu-library/4.3` first in `.libPaths()` and creates it if it does not exist, even on systems that are not Linux or R 4.3.

The extra packages do install themselves when missing: `irace` (only for tuning), `plotly` and `htmlwidgets` (for `plots/plot_convergence.R` and `plots/plot_fronts.R`), and `ggtree` from Bioconductor, through `BiocManager` (only for `plots/plot_trees.R`). The analysis in `analysis/` needs `ggplot2` and uses `dplyr`, `tidyr` and `scales` when they are installed. `PARALLEL = TRUE` uses the base `parallel` package.

### Quick start

```bash
# 1. One data set, to check everything works (NSGA-II + MOSA + figures)
Rscript main.R

# 2. Full experiment: 13 data sets x 3 methods, 11 runs each, + comparison table
Rscript run_experiments.R

# 3. Publication figures and tables from the results
Rscript analysis/run_all_analysis.R
```

`main.R` runs only NSGA-II and MOSA on `DATASET`; the Random Search baseline runs with `run_experiments.R` or, alone over the 13 data sets, with `Rscript run_random_search.R`.

Optional, parameter tuning with irace (long, several hours):

```bash
Rscript tuning/run_tuning.R      # produces tuning/best_nsga.csv and tuning/best_mosa.csv
```

Every script finds the repository root on its own (it walks up until it finds `config.R`), so it works with `Rscript`, with `source()` in RStudio, and from any working directory.

The drivers in `algorithms/` also run on their own (for example `Rscript algorithms/nsga2/run_nsga.R`), but then they do not read `config.R`: they use their internal defaults, which differ from `config.R`. The [algorithms/ README](algorithms/README.md) lists them. To reproduce the experiment, always launch them through `main.R`, `run_experiments.R` or `run_random_search.R`.

### Configuration

Everything is set in **`config.R`**:

| Block | What it controls |
|---|---|
| Single data set | `DATASET`, `MAKE_PLOTS` |
| Full experiment | `DATASETS`, `N_RUNS`, `SEQ_TYPE`, `K`, `SEED`, `RUN_ALGORITHMS` |
| Parallelism | `PARALLEL`, `N_CORES` (runs are distributed across cores) |
| Recording | `EVERY_N` (metrics are recorded every N generations or cycles) |
| NSGA-II | `POP_SIZE`, `N_GEN`, `P_CROSS`, `P_MUT` |
| MOSA | `N_INNER`, `N_OUTER`, `T0`, `ALPHA` |
| Random Search | `POP_RS`, `GEN_RS` |
| Tuning | `BUDGET`, `HOURS_NSGA`, `HOURS_MOSA`, `N_PAR`, `INSTANCES` |

Current values come from the irace tuning and give all three methods a comparable budget of about 10,000 objective-function evaluations (NSGA-II 93 x 108 = 10,044, MOSA 98 x 102 = 9,996, and RS 93 x 108 = 10,044). With `PARALLEL = TRUE`, the runs are spread over up to `N_CORES` cores, which by default are all cores but one.

`SEQ_TYPE` is a single value (`"DNA"`) for the 13 data sets, although `conrado_126.phylip` holds amino acid sequences; with this configuration that file is also read with `ape::read.dna()`.

### Output files

`results/`, one set per data set and method (`NSGA`, `MOSA`, `RS`):

| File | Content |
|---|---|
| `conv_<method>_<data set>_runNN.csv` | Convergence trace of each run: hypervolume, best so far, spread, front size |
| `resumen_<method>_<data set>.csv` | One row per run: `run`, best hypervolume and `seconds`. The hypervolume column is `hv_max` for NSGA and RS and `hv_best` for MOSA |
| `front_<method>_<data set>.csv` | Final Pareto front of the best run (`ls`, `me`) |
| `medoid_<method>_<data set>.nwk` | Medoid tree of that front, in Newick format |

When it finishes, each driver keeps the front and the medoid of the best run and deletes the `front_*_runNN.csv` and `medoid_*_runNN.nwk` files of the other runs; the `conv_*_runNN.csv` traces of the 11 runs are kept.

`run_experiments.R` also writes, in the project root, `tabla_resultados.csv` (mean hypervolume of the three methods, the NJ baseline, the Kruskal-Wallis p-value, pairwise p-values, Holm correction, and the best method) and `tabla_hv.tex` (the same table in LaTeX, ready to paste). `plots/` writes to `figures/` and the analysis to `analysis/output/` (PNG figures and CSV tables).

Everything under `results/`, `figures/` and `analysis/output/`, plus `tabla_resultados.csv`, `tabla_hv.tex` and the tuning outputs (`tuning/best_*.csv`, `tuning/*.Rdata`), is generated by the scripts, so the `.gitignore` at the root of the monorepo excludes them and they are not tracked. They are recreated when you run the pipeline.

### Notes on the methods

* **NSGA-II** evolves a population of distance matrices. Each generation builds the offspring with about 40% crossovers, 40% mutations and the rest random matrices, and selects the next population by non-dominated fronts and crowding distance. Its front is the rank-1 set of the final population.
* In the code, `P_CROSS` works as the weight `w` of the convex crossover (child = `w` x parent1 + (1 - `w`) x parent2), although `config.R` describes it as a crossover probability, and `P_MUT` is both the probability of mutating each cell of the matrix and the amplitude of the uniform noise.
* **MOSA** explores with a single solution: it multiplies each cell of its distance matrix by a U(0.9, 1.1) factor, rebuilds the tree with NJ, and accepts the candidate with the Metropolis criterion on its hypervolume. It also keeps an archive of non-dominated solutions, which is what its front is built from.
* **Random Search** generates candidates with the same perturbation operator as MOSA, always starting from the base tree, with no selection and no crossover. It is the baseline that shows how much of the result comes from the search itself.
* The **medoid tree** is the point of the front with the smallest sum of distances to the other points, in normalised objective space. It is a representative compromise solution, not the best in either objective.
* Each run uses the seed `SEED + run`, so results are the same in serial and in parallel mode.

### Licence

The code is distributed under the MIT licence ([LICENSE](LICENSE)). The alignments in `data/` keep the terms of their original sources.
