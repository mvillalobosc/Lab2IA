# nsga2

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el driver de NSGA-II, `run_nsga.R`, y sus módulos en [R/](R/). Vuelve al [README de algorithms/](../README.md) para ver lo que comparten los tres drivers.

### Qué hace una corrida

`run_once_nsga(run)` fija la semilla `SEED + run` y lee `data/<DATASET>` con `read_sequences()`. Con las distancias de k-meros (`K`) construye el árbol base por Neighbour-Joining y arma una población inicial de `POP_SIZE` árboles: el primero es el árbol base y los demás salen de sumarle a su matriz un ruido uniforme de más o menos 0,01. Los dos objetivos se normalizan dividiendo por 10 veces el LS y el ME del árbol base.

En cada una de las `N_GEN` generaciones, el driver arma la descendencia con cerca de un 40 % de cruzas entre padres elegidos por torneo binario (`crossover()` con peso `P_CROSS`), un 40 % de mutaciones de individuos de la población actual (`mutation()` con tasa `P_MUT`) y el resto con matrices aleatorias (`generate_random_tree()`). Cada matriz nueva pasa por NJ para volver a ser un árbol. Después une padres e hijos, los ordena por frentes no dominados y distancia de crowding, y se queda con la mejor mitad. En cada generación registra el hipervolumen, el spread y el tamaño del frente de rango 1.

Al final, el frente es el conjunto de rango 1 de la población final y el árbol medoide es el punto de ese frente con la menor suma de distancias a los demás.

### Archivos que escribe en results/

| Archivo | Contenido |
|---|---|
| `conv_NSGA_<conjunto>_runNN.csv` | Una fila cada `EVERY_N` generaciones (más la primera y la última): `generation`, `hypervolume`, `best_so_far`, `spread`, `front_size` |
| `front_NSGA_<conjunto>.csv` | Frente de la mejor corrida, con `ls` y `me` sin normalizar |
| `medoid_NSGA_<conjunto>.nwk` | Árbol medoide de la mejor corrida |
| `resumen_NSGA_<conjunto>.csv` | Una fila por corrida: `run`, `hv_max`, `seconds` |

Durante la corrida también escribe `front_NSGA_<conjunto>_runNN.csv` y `medoid_NSGA_<conjunto>_runNN.nwk`, pero al terminar copia los de la mejor corrida a los nombres sin `_runNN` y borra el resto.

### Parámetros que usa

`DATASET`, `SEQ_TYPE`, `K`, `POP_SIZE`, `N_GEN`, `P_CROSS`, `P_MUT`, `N_RUNS`, `SEED`, `PARALLEL`, `N_CORES`, `EVERY_N` y `VERBOSE`. Desde los scripts de la raíz los toma de `config.R`; corrido suelto usa sus propios valores por defecto (ver el [README de algorithms/](../README.md#valores-por-defecto-al-correrlos-sueltos)).

## English

This folder holds the NSGA-II driver, `run_nsga.R`, and its modules in [R/](R/). See the [algorithms/ README](../README.md) for what the three drivers share.

### What one run does

`run_once_nsga(run)` sets the seed `SEED + run` and reads `data/<DATASET>` with `read_sequences()`. From the k-mer distances (`K`) it builds the base tree by Neighbour-Joining and creates an initial population of `POP_SIZE` trees: the first is the base tree and the others come from adding a uniform noise of plus or minus 0.01 to its matrix. The two objectives are normalised by dividing by 10 times the LS and ME of the base tree.

In each of the `N_GEN` generations, the driver builds the offspring with about 40% crossovers between parents chosen by binary tournament (`crossover()` with weight `P_CROSS`), 40% mutations of individuals of the current population (`mutation()` with rate `P_MUT`), and the rest from random matrices (`generate_random_tree()`). Each new matrix goes through NJ to become a tree again. It then joins parents and offspring, sorts them by non-dominated fronts and crowding distance, and keeps the best half. In every generation it records the hypervolume, the spread, and the size of the rank-1 front.

At the end, the front is the rank-1 set of the final population and the medoid tree is the point of that front with the smallest sum of distances to the others.

### Files written to results/

| File | Content |
|---|---|
| `conv_NSGA_<data set>_runNN.csv` | One row every `EVERY_N` generations (plus the first and the last): `generation`, `hypervolume`, `best_so_far`, `spread`, `front_size` |
| `front_NSGA_<data set>.csv` | Front of the best run, with unnormalised `ls` and `me` |
| `medoid_NSGA_<data set>.nwk` | Medoid tree of the best run |
| `resumen_NSGA_<data set>.csv` | One row per run: `run`, `hv_max`, `seconds` |

During the run it also writes `front_NSGA_<data set>_runNN.csv` and `medoid_NSGA_<data set>_runNN.nwk`, but when it finishes it copies those of the best run to the names without `_runNN` and deletes the rest.

### Parameters it uses

`DATASET`, `SEQ_TYPE`, `K`, `POP_SIZE`, `N_GEN`, `P_CROSS`, `P_MUT`, `N_RUNS`, `SEED`, `PARALLEL`, `N_CORES`, `EVERY_N`, and `VERBOSE`. When launched from the scripts in the project root it takes them from `config.R`; when run on its own it uses its own defaults (see the [algorithms/ README](../README.md#defaults-when-run-on-their-own)).
