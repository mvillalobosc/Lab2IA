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

Si el paquete `irace` no está instalado, cada script lo instala. Con los valores de `config.R` el afinado toma unas 6 horas (3 por algoritmo).

### Cómo funciona

El afinado corre con un **presupuesto fijo de evaluaciones** (`BUDGET` en `config.R`), así que irace mejora la calidad y no puede ganar solo por gastar más evaluaciones. Los conteos derivados son:

* NSGA-II: afina `POP_SIZE` (entero entre 20 y 120), `P_CROSS` y `P_MUT` (reales entre 0 y 1); `N_GEN = BUDGET / POP_SIZE`.
* MOSA: afina `N_INNER` (entero entre 50 y 500), `T0` (real entre 10 y 5000) y `ALPHA` (real entre 0,50 y 0,99); `N_OUTER = BUDGET / N_INNER`. MOSA no tiene probabilidad de mutación: su perturbación es fija.

Cada evaluación de irace hace una sola corrida (`N_RUNS <- 1`) con `K <- 5`, fijado dentro de los scripts, y escribe sus archivos en una carpeta temporal (`tempdir()`), no en `results/`. El tipo de secuencia sale de `SEQ_TYPE` en `config.R`, así que `conrado_126` se lee como proteína.

El costo que recibe irace es la fracción de mejora sobre la línea base de Neighbour-Joining:

```
costo = -(HV - 3.61) / (4 - 3.61)
```

Por la normalización `10 x base`, el árbol NJ queda siempre en hipervolumen 3,61, así que esta fracción está en la misma escala [0, 1] para todos los conjuntos y ninguno domina el afinado.

En NSGA-II, `HV` es `hv_max`, el hipervolumen de su frente. En MOSA es `hv_best`, el hipervolumen de su mejor solución individual: MOSA se afinó con irace sobre `hv_best`, aunque `run_experiments.R` y `analysis/` lo comparan con el hipervolumen de su archivo de soluciones no dominadas (`hv_archive`).

Los parámetros que hoy tiene `config.R` y los archivos `best_*.csv` e `irace_*.Rdata` que se hayan generado antes salieron del código anterior, que calculaba mal el árbol base y leía `conrado_126` como ADN (ver [Cambios respecto de la versión anterior](../README.md#cambios-respecto-de-la-versión-anterior)). Hay que volver a correr el afinado y después `run_experiments.R`.

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

If the `irace` package is not installed, each script installs it. With the values in `config.R` the tuning takes about 6 hours (3 per algorithm).

### How it works

Tuning runs at a **fixed evaluation budget** (`BUDGET` in `config.R`), so irace optimises quality and cannot win by simply spending more evaluations. The derived counts are:

* NSGA-II: tunes `POP_SIZE` (integer from 20 to 120), `P_CROSS` and `P_MUT` (reals from 0 to 1); `N_GEN = BUDGET / POP_SIZE`.
* MOSA: tunes `N_INNER` (integer from 50 to 500), `T0` (real from 10 to 5000) and `ALPHA` (real from 0.50 to 0.99); `N_OUTER = BUDGET / N_INNER`. MOSA has no mutation probability, its perturbation is fixed.

Each irace evaluation is a single run (`N_RUNS <- 1`) with `K <- 5`, set inside the scripts, and writes its files to a temporary folder (`tempdir()`), not to `results/`. The sequence type comes from `SEQ_TYPE` in `config.R`, so `conrado_126` is read as protein.

The cost given to irace is the fraction of improvement over the Neighbour-Joining baseline:

```
cost = -(HV - 3.61) / (4 - 3.61)
```

Because of the `10 x base` normalisation the NJ tree always sits at hypervolume 3.61, so this fraction is on the same [0, 1] scale for every data set and no single data set dominates the tuning.

For NSGA-II, `HV` is `hv_max`, the hypervolume of its front. For MOSA it is `hv_best`, the hypervolume of its best single solution: MOSA was tuned with irace on `hv_best`, although `run_experiments.R` and `analysis/` compare it with the hypervolume of its archive of non-dominated solutions (`hv_archive`).

The parameters now in `config.R` and any `best_*.csv` and `irace_*.Rdata` files generated before came from the previous code, which computed the base tree wrongly and read `conrado_126` as DNA (see [Changes from the previous version](../README.md#changes-from-the-previous-version)). The tuning has to be run again, followed by `run_experiments.R`.

### Settings (in `config.R`)

| Variable | Meaning |
|---|---|
| `BUDGET` | Fixed number of evaluations per configuration (10,000) |
| `HOURS_NSGA`, `HOURS_MOSA` | Time budget in hours for each tuning (3 and 3) |
| `N_PAR` | Cores used by irace (1) |
| `INSTANCES` | Training data sets: `primates_14`, `rbcL_55`, `conrado_126` and `mtDNA_186` (from 14 to 186 taxa) |

When it finishes, copy the values from `best_nsga.csv` and `best_mosa.csv` into the algorithm block of `config.R`.
