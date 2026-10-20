# Afinado de parámetros con irace / Parameter tuning with irace

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene dos scripts, uno por algoritmo, y un tercero que corre los dos. Vuelve al [README del proyecto](../README.md) para ver dónde se usan los parámetros resultantes.

```bash
Rscript tuning/run_tuning.R      # primero NSGA-II, después MOSA
```

o uno a la vez:

```bash
Rscript tuning/irace_nsga.R      # -> tuning/best_nsga.csv y tuning/irace_nsga.Rdata
Rscript tuning/irace_mosa.R      # -> tuning/best_mosa.csv y tuning/irace_mosa.Rdata
```

Si el paquete `irace` no está instalado, cada script lo instala. Con los valores de `config.R` el afinado toma unas 6 horas (3 por algoritmo). Al terminar, `run_tuning.R` anuncia `tuning/best_sa.csv`, que es un nombre antiguo: el archivo de MOSA que se escribe es `tuning/best_mosa.csv`. Del mismo modo, la cabecera de `irace_nsga.R` dice `tune/irace_nsga.Rdata`, pero el registro queda en `tuning/irace_nsga.Rdata`.

### Cómo funciona

El afinado corre con un **presupuesto fijo de evaluaciones** (`BUDGET` en `config.R`), así que irace mejora la calidad y no puede ganar solo por gastar más evaluaciones. Los conteos derivados son:

* NSGA-II: afina `POP_SIZE` (entero entre 20 y 120), `P_CROSS` y `P_MUT` (reales entre 0 y 1); `N_GEN = BUDGET / POP_SIZE`.
* MOSA: afina `N_INNER` (entero entre 50 y 500), `T0` (real entre 10 y 5000) y `ALPHA` (real entre 0,50 y 0,99); `N_OUTER = BUDGET / N_INNER`. MOSA no tiene probabilidad de mutación: su perturbación es fija.

Cada evaluación de irace hace una sola corrida (`N_RUNS <- 1`) con `SEQ_TYPE <- "DNA"` y `K <- 5`, fijados dentro de los scripts, y escribe sus archivos en una carpeta temporal (`tempdir()`), no en `results/`.

El costo que recibe irace es la fracción de mejora sobre la línea base de Neighbour-Joining:

```
costo = -(HV - 3.61) / (4 - 3.61)
```

Por la normalización `10 x base`, el árbol NJ queda siempre en hipervolumen 3,61, así que esta fracción está en la misma escala [0, 1] para todos los conjuntos y ninguno domina el afinado.

### Ajustes (en `config.R`)

| Variable | Significado |
|---|---|
| `BUDGET` | Número fijo de evaluaciones por configuración (10.000) |
| `HOURS_NSGA`, `HOURS_MOSA` | Presupuesto de tiempo, en horas, de cada afinado (3 y 3) |
| `N_PAR` | Núcleos que usa irace (1) |
| `INSTANCES` | Conjuntos de entrenamiento: `primates_14`, `rbcL_55`, `conrado_126` y `mtDNA_186` (de 14 a 186 taxones) |

Cuando termine, copia los valores de `best_nsga.csv` y `best_mosa.csv` en el bloque de parámetros de los algoritmos en `config.R`.

## English

This folder has two scripts, one per algorithm, plus a third one that runs both. See the [project README](../README.md) for where the resulting parameters are used.

```bash
Rscript tuning/run_tuning.R      # NSGA-II first, then MOSA
```

or one at a time:

```bash
Rscript tuning/irace_nsga.R      # -> tuning/best_nsga.csv and tuning/irace_nsga.Rdata
Rscript tuning/irace_mosa.R      # -> tuning/best_mosa.csv and tuning/irace_mosa.Rdata
```

If the `irace` package is not installed, each script installs it. With the values in `config.R` the tuning takes about 6 hours (3 per algorithm). When it finishes, `run_tuning.R` announces `tuning/best_sa.csv`, an old name: the MOSA file that is written is `tuning/best_mosa.csv`. Likewise, the header of `irace_nsga.R` says `tune/irace_nsga.Rdata`, but the log is written to `tuning/irace_nsga.Rdata`.

### How it works

Tuning runs at a **fixed evaluation budget** (`BUDGET` in `config.R`), so irace optimises quality and cannot win by simply spending more evaluations. The derived counts are:

* NSGA-II: tunes `POP_SIZE` (integer from 20 to 120), `P_CROSS` and `P_MUT` (reals from 0 to 1); `N_GEN = BUDGET / POP_SIZE`.
* MOSA: tunes `N_INNER` (integer from 50 to 500), `T0` (real from 10 to 5000) and `ALPHA` (real from 0.50 to 0.99); `N_OUTER = BUDGET / N_INNER`. MOSA has no mutation probability, its perturbation is fixed.

Each irace evaluation is a single run (`N_RUNS <- 1`) with `SEQ_TYPE <- "DNA"` and `K <- 5`, set inside the scripts, and writes its files to a temporary folder (`tempdir()`), not to `results/`.

The cost given to irace is the fraction of improvement over the Neighbour-Joining baseline:

```
cost = -(HV - 3.61) / (4 - 3.61)
```

Because of the `10 x base` normalisation the NJ tree always sits at hypervolume 3.61, so this fraction is on the same [0, 1] scale for every data set and no single data set dominates the tuning.

### Settings (in `config.R`)

| Variable | Meaning |
|---|---|
| `BUDGET` | Fixed number of evaluations per configuration (10,000) |
| `HOURS_NSGA`, `HOURS_MOSA` | Time budget in hours for each tuning (3 and 3) |
| `N_PAR` | Cores used by irace (1) |
| `INSTANCES` | Training data sets: `primates_14`, `rbcL_55`, `conrado_126` and `mtDNA_186` (from 14 to 186 taxa) |

When it finishes, copy the values from `best_nsga.csv` and `best_mosa.csv` into the algorithm block of `config.R`.
