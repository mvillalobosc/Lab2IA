# algorithms

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene los tres métodos que compara el proyecto, cada uno con su driver: [nsga2/](nsga2/) (NSGA-II), [mosa/](mosa/) (recocido simulado multiobjetivo) y [rs/](rs/) (búsqueda aleatoria, que reutiliza los módulos de `mosa/R/`). Vuelve al [README del proyecto](../README.md) para ver el experimento completo.

### Cómo están armados los drivers

Los tres drivers siguen la misma estructura. Primero ubican su carpeta y la raíz del proyecto (suben hasta encontrar `config.R`), cargan `R/packages.R` y después todos los demás módulos `R/*.R`. Luego definen sus valores por defecto con `def()`, que solo asigna una variable si todavía no existe; así, cuando `main.R`, `run_experiments.R` o `run_random_search.R` ya cargaron `config.R`, mandan los valores de `config.R`. Cada driver define una función `run_once_*()` que hace una corrida completa con la semilla `SEED + run`, y al final reparte las `N_RUNS` corridas en serie o, con `PARALLEL = TRUE`, entre núcleos con `parallel::parLapply`. Si existe `TUNE_ONLY = TRUE` en la sesión, el driver solo define las funciones y no corre nada, que es como lo usa irace en [tuning/](../tuning/).

Todos escriben en `results/` (ver [Archivos de salida](../README.md#archivos-de-salida)): una traza `conv_*_runNN.csv` por corrida, un `resumen_*.csv` con una fila por corrida, y el frente y el árbol medoide de la mejor corrida.

### Valores por defecto al correrlos sueltos

Corridos sueltos (por ejemplo `Rscript algorithms/nsga2/run_nsga.R`), los drivers no hacen `source()` de `config.R` y usan estos valores internos, que no coinciden con los del experimento:

| Variable | `config.R` | `run_nsga.R` suelto | `run_mosa.R` suelto | `run_rs.R` suelto |
|---|---|---|---|---|
| `DATASET` | `primates_14.phylip` | `conrado_126.phylip` | `primates_14.phylip` | `primates_14.phylip` |
| `POP_SIZE`, `N_GEN` | 93, 108 | 68, 50 | | |
| `P_CROSS`, `P_MUT` | 0,9942; 0,414 | 0,39; 0,40 | | |
| `N_INNER`, `N_OUTER` | 98, 102 | | 100, 75 | |
| `T0`, `ALPHA` | 2974,567; 0,5939 | | 5000; 0,69 | |
| `POP_RS`, `GEN_RS` | 93, 108 | | | 93, 108 |
| `PARALLEL` | `TRUE` | `FALSE` | `FALSE` | `FALSE` |

`N_RUNS` (11), `SEED` (123), `K` (5), `SEQ_TYPE` (`"DNA"`) y `EVERY_N` (5) valen lo mismo en los dos casos. Para reproducir los resultados del experimento, corre los drivers a través de los scripts de la raíz.

### Funciones con el mismo nombre

`nsga2/R/` y `mosa/R/` definen funciones con el mismo nombre: `read_sequences()`, `build_base_tree()` (la de `mosa` guarda además `dist_original`) y `compute_hypervolume()`, que en `nsga2` recibe una matriz con el frente y en `mosa` recibe un árbol. Cuando `main.R` o `run_experiments.R` cargan los drivers uno tras otro en la misma sesión, las últimas definiciones reemplazan a las anteriores. Funciona porque cada driver vuelve a cargar sus módulos al empezar, pero quien use una de esas funciones fuera de un driver debe revisar cuál quedó cargada. Además, `front_metrics()` y `medoid()` están copiadas dentro de cada driver.

## English

This folder holds the three methods compared by the project, each with its driver: [nsga2/](nsga2/) (NSGA-II), [mosa/](mosa/) (multi-objective simulated annealing), and [rs/](rs/) (Random Search, which reuses the modules in `mosa/R/`). See the [project README](../README.md) for the full experiment.

### How the drivers are built

The three drivers share the same structure. They first find their folder and the project root (they walk up until they find `config.R`), load `R/packages.R`, and then every other `R/*.R` module. They then set their defaults with `def()`, which only assigns a variable when it is not already defined; so when `main.R`, `run_experiments.R`, or `run_random_search.R` have already loaded `config.R`, the values from `config.R` win. Each driver defines a `run_once_*()` function that performs one full run with the seed `SEED + run`, and finally dispatches the `N_RUNS` runs serially or, with `PARALLEL = TRUE`, across cores with `parallel::parLapply`. If `TUNE_ONLY = TRUE` exists in the session, the driver only defines its functions and runs nothing, which is how irace uses it in [tuning/](../tuning/).

They all write to `results/` (see [Output files](../README.md#output-files)): one `conv_*_runNN.csv` trace per run, a `resumen_*.csv` with one row per run, and the front and medoid tree of the best run.

### Defaults when run on their own

When run on their own (for example `Rscript algorithms/nsga2/run_nsga.R`), the drivers do not `source()` `config.R` and use these internal values, which differ from those of the experiment:

| Variable | `config.R` | `run_nsga.R` alone | `run_mosa.R` alone | `run_rs.R` alone |
|---|---|---|---|---|
| `DATASET` | `primates_14.phylip` | `conrado_126.phylip` | `primates_14.phylip` | `primates_14.phylip` |
| `POP_SIZE`, `N_GEN` | 93, 108 | 68, 50 | | |
| `P_CROSS`, `P_MUT` | 0.9942, 0.414 | 0.39, 0.40 | | |
| `N_INNER`, `N_OUTER` | 98, 102 | | 100, 75 | |
| `T0`, `ALPHA` | 2974.567, 0.5939 | | 5000, 0.69 | |
| `POP_RS`, `GEN_RS` | 93, 108 | | | 93, 108 |
| `PARALLEL` | `TRUE` | `FALSE` | `FALSE` | `FALSE` |

`N_RUNS` (11), `SEED` (123), `K` (5), `SEQ_TYPE` (`"DNA"`), and `EVERY_N` (5) are the same in both cases. To reproduce the results of the experiment, run the drivers through the scripts in the project root.

### Functions with the same name

`nsga2/R/` and `mosa/R/` define functions with the same name: `read_sequences()`, `build_base_tree()` (the `mosa` one also stores `dist_original`), and `compute_hypervolume()`, which takes a front matrix in `nsga2` and a tree in `mosa`. When `main.R` or `run_experiments.R` load the drivers one after another in the same session, the last definitions replace the earlier ones. This works because each driver reloads its modules when it starts, but anyone who calls one of these functions outside a driver should check which one is loaded. `front_metrics()` and `medoid()` are also copied inside each driver.
