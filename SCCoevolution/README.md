# Multi-objective ORF selection for yeast phylogenetics

Reproducible code and data for a multi-objective optimisation that selects small
sets of ORFs whose concatenated phylogeny approximates a whole-genome reference
tree of 1011 *Saccharomyces cerevisiae* strains.

Two objectives are minimised simultaneously:

| | Objective | Direction |
|---|---|---|
| 1 | Number of ORFs (normalised) | fewer is better |
| 2 | Normalised Robinson-Foulds distance to the reference tree | closer is better |

Two strategies are compared, **MOSA** (multi-objective simulated annealing) and
**NSGA-II**, and the resulting Pareto front is compared against a reference gene
set from prior work.

---

## Quick start

```bash
Rscript -e 'install.packages(c("readr","dplyr","tidyr","stringr","ggplot2",
                               "ape","phangorn","RColorBrewer","UpSetR","plotly"))'
Rscript run_all.R
```

`UpSetR` and `plotly` are optional: without them the tables are still written and
only the UpSet plot and the interactive HTML versions are skipped.

Step 04 unpacks `data/alignments_used.tar.gz` on first run and is the slow step,
since it reads 106 alignments of 1011 taxa each.

---

## Pipeline

| Step | Script | What it does |
|---|---|---|
| 01 | `01_pareto_front.R` | Pareto front and convergence across the five recorded generations |
| 02 | `02_hypervolume.R` | MOSA vs NSGA-II hypervolume, with a statistical comparison |
| 03 | `03_solution_overlap.R` | Pairwise overlap, ORF recurrence, recovery of the reference set, UpSet plot |
| 04 | `04_build_trees.R` | Neighbour-joining tree per solution from averaged Hamming distances |
| 05 | `05_colour_trees.R` | Colours a tree JSON by strain clade. Run on demand with a tree as argument |

```bash
Rscript run_all.R 02                       # a single step
Rscript R/04_build_trees.R S2 S9           # only these solutions
Rscript R/05_colour_trees.R trees/sol2_tree.json
```

---

## Data

| File | Contents |
|---|---|
| `data/solutions.csv` | The 15 ORF sets in long format. **Single source of truth.** |
| `data/pareto_fronts.csv` | 63 points across generations F0 to F4 |
| `data/hypervolume.csv` | 60 independent runs, 31 MOSA and 29 NSGA-II |
| `data/strain_metadata.csv` | 1043 strains with clade, origin and phenotype columns |
| `data/alignment_manifest.csv` | All 6015 alignments in the source database, with sizes and a flag for the 106 used here |
| `data/alignments_db/alignments_part1.zip` | 3141 alignments, 75 MB |
| `data/alignments_db/alignments_part2.zip` | 2874 alignments, 69 MB |
| `data/enrichment/` | GO, KEGG and ORF frequency tables |

### The alignment database

All **6015** alignments are included, 1011 taxa each, **8.4 GB unpacked** and
144 MB compressed. They ship as two zip parts because GitHub rejects any single
file above 100 MB. The split is by file, not by byte range, so each part is a
valid archive on its own and there is nothing to concatenate.

An earlier version of this repository shipped only the 106 alignments that the
fifteen final solutions reference. That is enough to rebuild every tree in the
paper, but not to re-run the search: MOSA and NSGA-II evaluate candidate ORF
subsets against all 6015 genes, so a reader with only 106 could verify the result
and not reproduce the method. For a methods paper that is the wrong half to ship.

`R/utils_solutions.R` extracts **only the alignments a given run needs**, so
building one tree costs one file rather than an 8.4 GB unpack. Pass no ORF list
to unpack the whole database, which is what re-running the optimisation requires.

`alignment_manifest.csv` lists all 6015 with byte sizes and a flag for the 106
used by the final solutions, and the unpacking routine checks the extracted count
against it so a truncated unpack or a full disk is caught immediately rather than
surfacing later as a missing gene.
---

## Known data issue

**Solution S10 lists `YJR138W2`, which does not exist in the alignment
database.** The nearest match is `YJR138W`, which solution S11 uses. The original
`crear_arboles.R` warned about the missing file and then built the tree from the
remaining genes, so S10's tree was constructed from **two** ORFs rather than the
three its definition states, and nothing in the output recorded that.

This pipeline does not paper over it. `04_build_trees.R` writes the requested and
actually-used ORF count for every solution to `outputs/tables/04_tree_summary.csv`
and flags any tree built from an incomplete set. Whether `YJR138W2` is a typo for
`YJR138W` or a genuinely different locus is a decision for the authors, not for
the code.

---

## What changed from the original scripts

The analyses are unchanged. The reorganisation addresses failure modes that make
results hard to trust or reproduce.

**The fifteen gene sets were hard-coded three times.** The same 130 lines of
literal ORF vectors appeared verbatim in `Upset/main.R` and
`Upset/interseccion.R`, with a third partial copy commented in and out at the top
of `Arboles/crear_arboles.R`. Three copies means three chances to edit one and
forget the others, and no way to tell afterwards which copy produced a published
figure. They now live in `data/solutions.csv` and every script reads from there.

**Selecting a solution meant editing a script.** `crear_arboles.R` switched
between solutions by moving comment markers, while the output filename was
separately hard-coded as `sol1_tree.nwk`. Building solution 2 and forgetting that
line silently overwrote solution 1's tree with solution 2's topology. Solutions
are now arguments and filenames derive from them.

**Missing alignments were a warning, not an error.** See the known data issue
above.

**Pareto labels were positional.** `Convergencia/grafico.R` attached solution
labels through a hand-written vector whose order had to match the row order of
`f4.csv` exactly, with nothing checking that it did. Re-sorting the CSV would move
every label to the wrong point. Labels are now derived from `solutions.csv` and
matched by objective value.

**Only the final front was plotted.** The script loaded `f0.csv` through
`f4.csv` and plotted only `f4`, so the convergence the filenames imply was never
shown. Step 01 plots all five.

**The hypervolume figure had no test behind it.** Two overlapping violins do not
answer whether one algorithm is better. Step 02 reports a Mann-Whitney test with a
rank-biserial effect size and a bootstrap confidence interval.

**The hypervolume y-axis was hard-limited to 1 to 4.** Any run outside that
window would have been dropped from the figure with only a ggplot message that is
easy to miss. Limits are now computed from the data and the observed range is
logged. On the current data nothing was being dropped.

**Overlap was measured by raw counts.** Solution sizes range from 1 to 22 ORFs,
so the largest raw intersection is dominated by whichever pair is biggest. Step 03
reports the Jaccard index alongside.

**Every script assumed its own folder was the working directory.** Paths like
`"f4.csv"` and `"../BD/Secuencias_alineadas/"` only worked when R happened to be
started in the right place. All paths now come from `00_config.R`.

**`.RData` and `.Rhistory` were committed in three folders.** Stale session
objects silently shadow a fresh run. They are gitignored.

**Colours were defined separately in each script**, so the same algorithm
appeared in different colours across figures. One palette lives in `00_config.R`.

---

## Selected results

Reproduced by `Rscript run_all.R`; tables in `outputs/tables/`.

**NSGA-II beats MOSA with perfect separation.** Rank-biserial correlation
**−1.000** (95% CI [−1.000, −1.000]), p = 3.1e-11: every NSGA-II run reaches a
higher hypervolume than every MOSA run. Median 2.811 against 1.719.

**One ORF dominates the Pareto front.** `YPL009C` is selected by **10 of the 14**
Pareto solutions (71 percent), and it is **not** in the reference set.

**The Pareto front and the reference set barely overlap.** The reference solution
has 22 ORFs. Across all 14 Pareto solutions the front recovers **1** of them
(`YHR205W`). The optimisation converges on almost entirely different genes.

**Solutions S10 and S11 are distinct sets with identical objective values**, so
14 solutions occupy 13 points on the final front.

---

## Re-running the optimisation

The search is in the pipeline, not just its outputs. Steps 10 and 11 re-run both
algorithms from scratch and rebuild `solutions.csv`, `pareto_fronts.csv` and
`hypervolume.csv` from the new runs.

```bash
# unpack the full 6015-alignment database first (needs ~8.4 GB free)
Rscript -e 'source("R/00_config.R"); source("R/utils_solutions.R"); ensure_alignments()'

# smoke test the whole loop in a few minutes on a tiny configuration
OPT_QUICK=1 Rscript run_all.R 10 11

# the real thing: 31 independent runs of each algorithm
Rscript run_all.R 10 11

Rscript R/10_run_optimisation.R nsga2      # one algorithm
Rscript R/10_run_optimisation.R mosa 5     # 5 runs only
```

Every hyperparameter lives in `OPT` in `R/00_config.R`. Steps 10 and 11 are not
in the default sequence: a full run takes many hours and rebuilding the data
files replaces the published solutions. The previous files are backed up with a
timestamp rather than overwritten.

### Seeding the initial population

`main.r` seeded the population from a spreadsheet, `Grupos y medoides.xlsx`, via
`buildTreeFromXSLX`. That file was never released with the code, so a seeded run
could not be reproduced by anyone else; the function also prepended a space to
every filename, which made `match()` return `NA` silently whenever the alignment
files did not carry that space.

Seeding now reads from `data/solutions.csv`, which is in the repository:

```bash
Rscript R/10_run_optimisation.R nsga2 31 SV     # seed from the reference set
Rscript R/10_run_optimisation.R nsga2 31 S2     # seed from a Pareto solution
Rscript R/10_run_optimisation.R nsga2 31 none   # random start (default)
```

The seed is validated before the run starts, not halfway through: an unknown
solution name, a solution larger than `OPT$max_genes`, or ORFs missing from the
gene pool all produce an immediate and specific error. ORFs absent from the pool
are dropped with a message naming them, which is how the missing `YJR138W2` in
S10 surfaces rather than silently shrinking the seed.

### Fixes to the optimiser

**The simulated annealing had no working temperature schedule.** In the original
`simAnnMO.r` the acceptance test was a separate top-level function reading `T`:

```r
checkTemperature <- function(deltaE){ prob = exp((-deltaE/T)); ... }
simulatedAnnealingMO <- function(..., T, alpha, ...){ ... T = T * alpha }
```

R scopes lexically, so that `T` never resolved to the local temperature. It
resolved in the global environment, where `T` is R's built-in alias for `TRUE`,
that is **1**. Measured: with `T = 1000, alpha = 0.8` the acceptance function
sees `1` at every iteration; for an energy gap of 5 the acceptance probability
was 0.0067 instead of 0.995, about **150 times smaller**. MOSA ran as a near-pure
hill climber. Temperature is now an explicit argument and the trace is returned
so the schedule can be inspected.

**Solutions were integer indices into `list.files()`.** That listing is sorted by
the current locale's collation, so index 500 is a different gene on a Spanish
Windows machine than on a C-locale Linux server, and stored solutions were only
decodable on the machine that produced them. Solutions are now ORF names, and the
gene pool is read from the manifest and sorted with `method = "radix"`, which is
locale-independent.

**No seed anywhere, and `foreach %dopar%` without `doRNG`.** No run could be
repeated even on the same machine. Every run now takes a seed derived
deterministically from `PARAMS$seed` and the run index, so run 7 is the same
everywhere and can be repeated on its own. Verified: same seed gives an identical
front, a different seed gives a different one.

**The evaluation budgets were not comparable.** NSGA-II ran 19 generations of 14
individuals; MOSA ran `external_loops = 2, internal_loops = 2`, four proposed
moves in total. `OPT` now gives both **532 evaluations**.

**Sourcing a module launched an experiment.** The last line of both `nsga2.r` and
`simAnnMO.r` executed a full run with hard-coded `C:/Users/Vichi/...` paths, so
`source()`-ing them from `main.r` started an unwanted run. The algorithm files now
only define functions.

**MOSA returned one solution, not a front.** It kept only the current solution,
which cannot be compared to NSGA-II on hypervolume. It now maintains a
non-dominated archive.

**Crossover discarded one child by RF alone.** In a two-objective search that
biases every generation toward one objective and against small gene sets. Both
children are returned and survival is decided by non-dominated sorting.

**Dominance used `<=` on both objectives**, so two identical solutions were
reported as one dominating the other. Now strict Pareto dominance.

**`buildTree` wrote `out.txt` on every fitness evaluation**, with five parallel
workers racing on the same file. Removed.

**Objectives were rescaled against a moving population inside the search.**
`MaOEA::Normalize` was applied over the whole generation history at plotting
time, and that history was never saved, which is why the published front
coordinates cannot be recomputed from the released data. Raw objective values are
now stored, normalisation happens only at reporting time, and the constants are
written to `11_normalisation_constants.csv`.

**Alignments were re-read on every evaluation.** Per-gene distance matrices are
now cached in memory with a bounded LRU, `OPT$cache_size`. Observed hit rate on a
short run: about 80 percent.

---

## Layout

```
├── R/
│   ├── 00_config.R            Paths, parameters, palette, dependency check
│   ├── utils_solutions.R      Loads the solutions and checks alignment availability
│   └── 01_…05_*.R             Analysis steps
├── data/                      Tidy CSVs, packed alignments, enrichment tables
├── trees/                     Newick and phylocanvas JSON, plain and coloured
├── outputs/
│   ├── figures/               PDF
│   ├── tables/                CSV
│   └── logs/                  sessionInfo per step
├── run_all.R
└── docs/
```

## Citation

```bibtex
@misc{orf_selection_yeast,
  author = {Hernández Herrera, Vicente Luciano and Villalobos-Cid, Manuel},
  title  = {Multi-objective ORF selection for yeast phylogenetics},
  year   = {2026},
  note   = {Departamento de Ingeniería Informática, Universidad de Santiago de Chile}
}
```

## License

MIT for the code. The 1011 genomes alignments derive from the 1002 Yeast Genomes
Project and remain subject to that project's terms.
