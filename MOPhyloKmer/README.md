# MOPhyloKmer · Multi-objective metaheuristics for alignment-free phylogenetic inference

Two multi-objective metaheuristics — **NSGA-II** and **Multi-Objective
Simulated Annealing (MOSA)** — that infer phylogenetic trees from
**alignment-free k-mer distances**, jointly optimising **Least Squares (LS)**
and **Minimum Evolution (ME)**.

This is a cleaned, documented and optimised implementation of the code
behind the thesis of Ayrton Huenchual San Juan (USACH, 2024).

---

## How it works

1. Sequences are read from a `.phylip` file and turned into a **k-mer
   distance matrix** (no multiple sequence alignment required).
2. A **Neighbour-Joining** tree seeds the search.
3. Each candidate tree is scored on two objectives:
   * **ME** = sum of branch lengths,
   * **LS** = |original distances − cophenetic distances|.
   Both are normalised and combined through the **hypervolume** indicator
   (reference point `(2, 2)`, so hypervolume is bounded in `[0, 4]`; higher
   is better).
4. **NSGA-II** evolves a population (crossover + mutation + random trees,
   non-dominated sorting + crowding distance).
   **MOSA** perturbs a single tree and accepts moves with a Metropolis
   criterion under a geometric cooling schedule.

Both algorithms export their **convergence trace** so the figures are fully
reproducible from real runs.

---

## Repository layout

```
MOPhyloKmer/
├── main.R                 Single entry point (edit the CONFIG block)
├── NSGA-II/
│   ├── run_nsga.R         NSGA-II driver
│   └── R/                 11 modular, commented functions
├── SA/
│   ├── run_sa.R           MOSA driver
│   └── R/                 7 modular, commented functions
├── plots/
│   ├── plot_convergence.R Convergence figures from results/  (PNG, 300 dpi)
│   └── plot_trees.R       Phylogenetic trees with ggtree      (PNG, 300 dpi)
├── data/                  13 benchmark datasets (.phylip)
├── results/               CSV traces + best trees (created on run)
└── figures/               PNG figures (created on plotting)
```

---

## Requirements

**R ≥ 4.0.** Packages are installed automatically on first run:

`ecr, ape, seqinr, kmer, phylotools, phangorn, stringr, phytools,
treespace, igraph, ggplot2, factoextra, insect`.

The tree plots use **ggtree** (Bioconductor); `plot_trees.R` installs it on
first use via `BiocManager`.

---

## Usage

### Option A — everything from `main.R`

Edit the `CONFIG` block at the top of `main.R` and run:

```bash
Rscript main.R
```

Key options in the `CONFIG` block:

| Variable        | Meaning                                   | Default             |
|-----------------|-------------------------------------------|---------------------|
| `ALGO`          | `"NSGA"` or `"MOSA"`                       | `"NSGA"`            |
| `DATASET`       | file inside `data/`                       | `"conrado_126.phylip"` |
| `TIPO`          | `"DNA"` or `"AA"`                          | `"DNA"`             |
| `K`             | k-mer length                              | `5`                 |
| `N_CORRIDAS`    | independent repetitions                   | `11`                |
| `POBLACION` / `GENERACIONES` | NSGA-II population / generations | `68` / `50`   |
| `N_INTERNAS` / `PARADA` / `T0` / `ALPHA` | MOSA inner iters / cooling levels / initial T / cooling factor | `100` / `75` / `5000` / `0.69` |
| `GRAFICAR`      | generate figures when the run finishes    | `TRUE`              |

### Option B — run a step on its own

```bash
Rscript NSGA-II/run_nsga.R                  # or SA/run_sa.R
Rscript plots/plot_convergence.R conrado_126
Rscript plots/plot_trees.R primates_14      # add "rectangular" for that layout
```

If you omit the dataset name, the plotting scripts auto-detect it from the
CSVs available in `results/`. In RStudio you can also open a plotting script
and press **Source** to see the figure in the *Plots* pane.

---

## Outputs

Each run writes, per repetition, to `results/`:

* `conv_NSGA_<dataset>_run<NN>.csv` — `generation, hypervolume, best_so_far`
  (generation **0** = initial front, so the curve starts at x = 0).
* `conv_MOSA_<dataset>_run<NN>.csv` — `iteration, current, best_so_far`
  (`current` = light line, `best_so_far` = dark line).
* `tree_<algo>_<dataset>_run<NN>.nwk` — best tree found (Newick).
* `resumen_<algo>_<dataset>.csv` — per-run best hypervolume and runtime.

By default the convergence script plots the **median run** (the real run at
the 50th percentile by final hypervolume). Set `MODO_GRAFICO <- "mejor"` for
the best run, or `"agregado"` for the point-wise median + min-max band across
runs. Figures go to `figures/*.png`.

---

## Notes on the metrics (read before comparing)

* **NSGA-II vs MOSA within one dataset — comparable.** Both start from the
  same NJ base tree and use the same normalisation constants
  (`max_ls = 10·ls_base`, `max_me = 10·me_base`) and the same reference point, so their hypervolumes are on the same scale. Both
  measure LS against the **same fixed original k-mer distances** (the observed
  data), so the objective space is identical.
* **NSGA-II hypervolume is measured over the whole rank-1 front**, whereas
  **MOSA reports a single solution**. A front dominates more area than one
  point, so part of NSGA-II's hypervolume advantage comes from comparing a
  *set* against a *point* — standard in multi-objective work, but worth
  keeping in mind.
* **Across datasets — same bounded range, not identical absolute meaning.**
  Every hypervolume lives in `[0, 4]`, but the normalisation constants
  depend on each dataset's base tree, so `3.6` in one dataset is not exactly
  equivalent to `3.6` in another.
* **The y-axis never reaches 0.** Hypervolume is the area dominated relative
  to `(2, 2)`; even the initial NJ-seeded front already dominates ≈ `3.6`.

---


## Performance (parallel runs)

The `N` independent repetitions are **embarrassingly parallel**, so they are
distributed across CPU cores. Enable it in the `CONFIG` block of `main.R`:

```r
PARALELO <- TRUE                          # runs in parallel
N_CORES  <- max(1, parallel::detectCores() - 1)
```

It uses a Windows-safe PSOCK cluster (`parallel::parLapply`); each worker
loads the modules and runs whole repetitions. Results are identical to the
serial mode (each run uses seed `SEMILLA + run`). Expect up to ~`min(N_CORES,
N_CORRIDAS)`x speed-up. Live progress bars are shown only in serial mode
(parallel workers cannot stream to the console); a summary is printed at the end.

**Within a single run:** NSGA-II could be partly parallelised per generation,
but MOSA is a sequential Markov chain, so run-level parallelism is the right
granularity for both.

**GPU:** not applicable here. The cost is dominated by phylogenetic operations
(k-mer distances, Neighbour Joining, cophenetic distances, tree edits via
`ape`/`phangorn`), which are CPU/C routines with no GPU backend in R. The only
matrix-heavy steps (crossover/mutation) are already vectorised and cheap, so a
GPU would not speed up the bottleneck.

## Datasets

13 alignment-free benchmarks (7–1011 sequences):
`conrado_126`, `hasegawa`, `HIV1_192`, `HIV2_72`, `membracidae1_81`,
`mtDNA_186`, `primates_14`, `rbcL_55`, `RDPII_218`, `RIM15`, `S1482_346`,
`YDR385W_menos`, `ZILLA_500`.

---

## Main improvements over the original code

* Portable **relative paths** (no hard-coded `C:/Users/...`).
* All parameters in a single **CONFIG block** (`main.R`).
* **Vectorised** crossover and mutation (nested `for` loops removed).
* Pre-allocated vectors/matrices instead of growing with `c()`/`rbind()`.
* Bug fixes: `k` honoured in `kdistance`; `$score`→`$scores`; removed
  undefined `tiempoYDRGA`; hypervolume reset per run; generation 0 logged.
* **MOSA now measures LS against the fixed original distances** (same objective
  as NSGA-II, so the two are directly comparable and MOSA can no longer lower
  its error by drifting its own distance matrix).
* NSGA-II random-tree matrices are now **symmetric with zero diagonal** (valid
  distance matrices).
* **Convergence traces + best trees exported** for reproducible figures.
* Progress reporting in the console (`VERBOSE`).
* Every function commented; debug lines removed.

---

## Reference

Huenchual San Juan, A. (2024). *Multi-objective metaheuristics for
alignment-free phylogenetic inference* (undergraduate thesis).
Universidad de Santiago de Chile (USACH).
