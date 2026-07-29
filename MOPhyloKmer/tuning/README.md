# Parameter tuning with irace

Two scripts, one per algorithm, plus a runner that executes both:

```bash
Rscript tuning/run_tuning.R      # NSGA-II first, then MOSA
```

or one at a time:

```bash
Rscript tuning/irace_nsga.R      # -> tuning/best_nsga.csv
Rscript tuning/irace_mosa.R      # -> tuning/best_mosa.csv
```

## How it works

Tuning runs at a **fixed evaluation budget** (`BUDGET` in `config.R`), so irace
optimises quality and cannot win by simply spending more evaluations. The
derived counts are:

* NSGA-II: tunes `POP_SIZE`, `P_CROSS`, `P_MUT`; `N_GEN = BUDGET / POP_SIZE`.
* MOSA: tunes `N_INNER`, `T0`, `ALPHA`; `N_OUTER = BUDGET / N_INNER`.
  MOSA has no mutation probability, its perturbation is fixed.

The cost given to irace is the fraction of improvement over the Neighbour-Joining
baseline:

```
cost = -(HV - 3.61) / (4 - 3.61)
```

Because of the `10 x base` normalisation the NJ tree always sits at
hypervolume 3.61, so this fraction is on the same [0, 1] scale for every data
set and no single data set dominates the tuning.

## Settings (in `config.R`)

| Variable | Meaning |
|---|---|
| `BUDGET` | Fixed number of evaluations per configuration |
| `HOURS_NSGA`, `HOURS_MOSA` | Time budget in hours for each tuning |
| `N_PAR` | Cores used by irace |
| `INSTANCES` | Training data sets (4 by default, from small to medium-large) |

When it finishes, copy the values from `best_nsga.csv` and `best_mosa.csv` into
the algorithm block of `config.R`.
