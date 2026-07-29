# MOPhyloKmer

Multi-objective metaheuristics for alignment-free phylogenetic inference.

Three methods (**NSGA-II**, **MOSA** and a **Random Search** baseline) infer
phylogenetic trees from **k-mer distances**, jointly minimising two objectives:

* **LS** (least squares): difference between the original distances and the
  cophenetic distances of the tree.
* **ME** (minimum evolution): total branch length of the tree.

Quality is measured with the **hypervolume** indicator. Both objectives are
scaled by `10 x` the value of the Neighbour-Joining base tree, so the base tree
always sits at `(0.1, 0.1)` and the hypervolume is comparable across data sets
(NJ baseline = 3.61, theoretical maximum = 4).

---

## Repository layout

```
MOPhyloKmer/
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
│   ├── run_all_analysis.R   Runs 01 to 06.
│   └── output/              Figures (PNG) and tables (CSV) of the analysis.
│
├── data/                    13 data sets in .phylip format.
├── results/                 Raw output of the runs (git-ignored, see below).
└── figures/                 Figures produced by plots/ (git-ignored).
```

---

## Requirements

R 4.2 or newer, plus these packages:

```
ecr  ape  seqinr  kmer  phylotools  phangorn  stringr
phytools  treespace  igraph  ggplot2  factoextra  insect
```

Extra packages: `irace` (only for tuning), `ggtree` from Bioconductor (only for
`plots/plot_trees.R`).

`algorithms/*/R/packages.R` only loads packages, it never installs or updates
them. If one is missing it stops with the list of what to install.

---

## Quick start

```bash
# 1. One data set, to check everything works (NSGA-II + MOSA + figures)
Rscript main.R

# 2. Full experiment: 13 data sets x 3 methods, 11 runs each, + comparison table
Rscript run_experiments.R

# 3. Publication figures and tables from the results
Rscript analysis/run_all_analysis.R
```

Optional, parameter tuning with irace (long, several hours):

```bash
Rscript tuning/run_tuning.R      # produces tuning/best_nsga.csv and tuning/best_mosa.csv
```

Every script finds the repository root on its own (it walks up until it finds
`config.R`), so it works with `Rscript`, with `source()` in RStudio, and from
any working directory.

---

## Configuration

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

Current values come from the irace tuning and give all three methods a
comparable budget of about 10,000 objective-function evaluations.

---

## Output files

`results/`, one set per data set and method (`NSGA`, `MOSA`, `RS`):

| File | Content |
|---|---|
| `conv_<method>_<data set>_runNN.csv` | Convergence trace: hypervolume, best so far, spread, front size |
| `resumen_<method>_<data set>.csv` | One row per run: best hypervolume and runtime |
| `front_<method>_<data set>.csv` | Final Pareto front of the best run (`ls`, `me`) |
| `medoid_<method>_<data set>.nwk` | Medoid tree of that front, in Newick format |

`run_experiments.R` also writes `tabla_resultados.csv` with the mean
hypervolume of the three methods, the NJ baseline and the p-values.

`analysis/output/` holds the figures (PNG) and tables (CSV) of the analysis.

Everything under `results/`, `figures/` and `analysis/output/` is generated by
the scripts, so those folders are listed in `.gitignore` and are not tracked.
They are recreated when you run the pipeline.

---

## Notes on the methods

* **NSGA-II** evolves a population of distance matrices. Its front is the
  rank-1 set of the final population.
* **MOSA** explores with a single solution but keeps an archive of
  non-dominated solutions, which is what its front is built from.
* **Random Search** generates candidates with the same mutation operator as
  MOSA, with no selection and no crossover. It is the baseline that shows how
  much of the result comes from the search itself.
* The **medoid tree** is the point of the front with the smallest sum of
  distances to the other points, in normalised objective space. It is a
  representative compromise solution, not the best in either objective.
