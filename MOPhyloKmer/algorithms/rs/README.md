# rs

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene la línea base de búsqueda aleatoria, `run_rs.R`. No tiene módulos propios: carga los de [../mosa/R/](../mosa/R/). Vuelve al [README de algorithms/](../README.md) para ver lo que comparten los tres drivers.

### Qué hace una corrida

`run_once_rs(run)` fija la semilla `SEED + run`, lee `data/<DATASET>`, construye el árbol base por Neighbour-Joining y normaliza los objetivos con 10 veces el LS y el ME de ese árbol, igual que MOSA. En cada una de las `GEN_RS` generaciones genera `POP_RS` candidatos con `perturb_tree()`, siempre a partir del árbol base, sin selección ni cruza, y actualiza un archivo acumulado de soluciones no dominadas. Al cerrar cada generación calcula el hipervolumen, el spread y el tamaño de ese archivo, de modo que su hipervolumen nunca baja. El presupuesto es `POP_RS` x `GEN_RS` evaluaciones (93 x 108 = 10.044 con `config.R`).

### Archivos que escribe en results/

| Archivo | Contenido |
|---|---|
| `conv_RS_<conjunto>_runNN.csv` | Una fila cada `EVERY_N` generaciones (más la primera y la última): `generation`, `hypervolume`, `best_so_far`, `spread`, `front_size` |
| `front_RS_<conjunto>.csv` | Archivo de no dominadas de la mejor corrida, con `ls` y `me` sin normalizar |
| `medoid_RS_<conjunto>.nwk` | Árbol medoide de la mejor corrida |
| `resumen_RS_<conjunto>.csv` | Una fila por corrida: `run`, `hv_max`, `seconds` |

Igual que los otros drivers, al terminar conserva solo el frente y el medoide de la mejor corrida.

### Cómo se corre

`run_experiments.R` la corre después de NSGA-II y MOSA en cada conjunto. Para correr solo la línea base sobre los 13 conjuntos de `config.R`:

```bash
Rscript run_random_search.R
```

## English

This folder holds the Random Search baseline, `run_rs.R`. It has no modules of its own: it loads those in [../mosa/R/](../mosa/R/). See the [algorithms/ README](../README.md) for what the three drivers share.

### What one run does

`run_once_rs(run)` sets the seed `SEED + run`, reads `data/<DATASET>`, builds the base tree by Neighbour-Joining, and normalises the objectives with 10 times the LS and ME of that tree, as MOSA does. In each of the `GEN_RS` generations it draws `POP_RS` candidates with `perturb_tree()`, always from the base tree, with no selection and no crossover, and updates a cumulative archive of non-dominated solutions. At the end of each generation it computes the hypervolume, spread, and size of that archive, so its hypervolume never decreases. The budget is `POP_RS` x `GEN_RS` evaluations (93 x 108 = 10,044 with `config.R`).

### Files written to results/

| File | Content |
|---|---|
| `conv_RS_<data set>_runNN.csv` | One row every `EVERY_N` generations (plus the first and the last): `generation`, `hypervolume`, `best_so_far`, `spread`, `front_size` |
| `front_RS_<data set>.csv` | Non-dominated archive of the best run, with unnormalised `ls` and `me` |
| `medoid_RS_<data set>.nwk` | Medoid tree of the best run |
| `resumen_RS_<data set>.csv` | One row per run: `run`, `hv_max`, `seconds` |

Like the other drivers, when it finishes it keeps only the front and the medoid of the best run.

### How to run it

`run_experiments.R` runs it after NSGA-II and MOSA on each data set. To run only the baseline over the 13 data sets in `config.R`:

```bash
Rscript run_random_search.R
```
