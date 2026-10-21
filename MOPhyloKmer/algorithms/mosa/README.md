# mosa

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el driver del recocido simulado multiobjetivo, `run_mosa.R`, y sus módulos en [R/](R/), que también usa la búsqueda aleatoria de [rs/](../rs/). Vuelve al [README de algorithms/](../README.md) para ver lo que comparten los tres drivers.

### Qué hace una corrida

`run_once_mosa(run)` fija la semilla `SEED + run`, lee `data/<DATASET>`, construye el árbol base por Neighbour-Joining sobre las distancias de k-meros y normaliza los dos objetivos dividiendo por 10 veces el LS y el ME de ese árbol. La solución actual parte del árbol base.

La corrida recorre `N_OUTER` niveles de temperatura con `N_INNER` iteraciones cada uno, empezando en `T0`. En cada iteración, `perturb_tree()` produce un candidato a partir de la solución actual y el driver calcula su hipervolumen individual. Si el candidato no queda dominado, entra a un archivo de soluciones no dominadas y saca de ahí a las que domina. La solución actual pasa a ser el candidato cuando su hipervolumen es mayor o igual, o, si es menor, con probabilidad `exp(-delta / T)` (criterio de Metropolis). Al cerrar cada nivel, la temperatura se multiplica por `ALPHA`.

El frente de MOSA es ese archivo de no dominadas, y el árbol medoide es el punto del archivo con la menor suma de distancias a los demás en el espacio normalizado.

### Archivos que escribe en results/

| Archivo | Contenido |
|---|---|
| `conv_MOSA_<conjunto>_runNN.csv` | Una fila cada `EVERY_N` niveles (más el primero y el último): `iteration` (iteraciones acumuladas), `current`, `best_so_far` (hipervolumen de la solución actual y de la mejor), y `hypervolume`, `spread` y `front_size` del archivo |
| `front_MOSA_<conjunto>.csv` | Archivo de no dominadas de la mejor corrida, con `ls` y `me` sin normalizar |
| `medoid_MOSA_<conjunto>.nwk` | Árbol medoide de la mejor corrida |
| `resumen_MOSA_<conjunto>.csv` | Una fila por corrida: `run`, `hv_best` (hipervolumen de la mejor solución individual), `hv_archive` (hipervolumen del archivo de no dominadas, el máximo de `hypervolume` en su traza `conv`), `seconds` |

Igual que los otros drivers, escribe los archivos `_runNN` de frente y medoide de cada corrida y al terminar se queda solo con los de la mejor, que es la de mayor `hv_archive`. `run_experiments.R` y `analysis/_common.R` también miden a MOSA con el hipervolumen de su archivo, leído de las trazas `conv`. `hv_best` es la medida con que irace afinó MOSA (ver [tuning/](../../tuning/README.md)).

### Parámetros que usa

`DATASET`, `SEQ_TYPE`, `K`, `N_INNER`, `N_OUTER`, `T0`, `ALPHA`, `N_RUNS`, `SEED`, `PARALLEL`, `N_CORES`, `EVERY_N` y `VERBOSE`. Salvo `VERBOSE`, los toma de `config.R`, también cuando se corre suelto (ver el [README de algorithms/](../README.md#valores-por-defecto-al-correrlos-sueltos)).

## English

This folder holds the multi-objective simulated annealing driver, `run_mosa.R`, and its modules in [R/](R/), which the Random Search in [rs/](../rs/) also uses. See the [algorithms/ README](../README.md) for what the three drivers share.

### What one run does

`run_once_mosa(run)` sets the seed `SEED + run`, reads `data/<DATASET>`, builds the base tree by Neighbour-Joining on the k-mer distances, and normalises the two objectives by dividing by 10 times the LS and ME of that tree. The current solution starts at the base tree.

The run goes through `N_OUTER` temperature levels with `N_INNER` iterations each, starting at `T0`. In each iteration, `perturb_tree()` produces a candidate from the current solution and the driver computes its single-solution hypervolume. If the candidate is not dominated, it enters an archive of non-dominated solutions and removes from it the ones it dominates. The current solution becomes the candidate when its hypervolume is greater or equal or, if it is lower, with probability `exp(-delta / T)` (Metropolis criterion). At the end of each level the temperature is multiplied by `ALPHA`.

The MOSA front is that non-dominated archive, and the medoid tree is the point of the archive with the smallest sum of distances to the others in normalised space.

### Files written to results/

| File | Content |
|---|---|
| `conv_MOSA_<data set>_runNN.csv` | One row every `EVERY_N` levels (plus the first and the last): `iteration` (cumulative iterations), `current`, `best_so_far` (hypervolume of the current and of the best solution), and `hypervolume`, `spread`, and `front_size` of the archive |
| `front_MOSA_<data set>.csv` | Non-dominated archive of the best run, with unnormalised `ls` and `me` |
| `medoid_MOSA_<data set>.nwk` | Medoid tree of the best run |
| `resumen_MOSA_<data set>.csv` | One row per run: `run`, `hv_best` (hypervolume of the best single solution), `hv_archive` (hypervolume of the non-dominated archive, the maximum of `hypervolume` in its `conv` trace), `seconds` |

Like the other drivers, it writes the per-run `_runNN` front and medoid files and keeps only those of the best run when it finishes, which is the one with the largest `hv_archive`. `run_experiments.R` and `analysis/_common.R` also measure MOSA with the hypervolume of its archive, read from the `conv` traces. `hv_best` is the measure irace used to tune MOSA (see [tuning/](../../tuning/README.md)).

### Parameters it uses

`DATASET`, `SEQ_TYPE`, `K`, `N_INNER`, `N_OUTER`, `T0`, `ALPHA`, `N_RUNS`, `SEED`, `PARALLEL`, `N_CORES`, `EVERY_N`, and `VERBOSE`. Except for `VERBOSE`, it takes them from `config.R`, also when run on its own (see the [algorithms/ README](../README.md#defaults-when-run-on-their-own)).
