# Analysis and figures

Run everything:

```bash
Rscript analysis/run_all_analysis.R
```

or one script at a time (`01_table_tests.R`, `02_violins.R`, ...).

Output goes to `analysis/output/`.

## Scripts

| Script | Output |
|---|---|
| `01_table_tests.R` | `tabla_hv.csv` (mean and sd per method), `tests_pareados.csv` (Wilcoxon + A12 effect size). Prints average rank and the Friedman test. |
| `02_violins.R` | `violin_hv.png`, `violin_spread.png`, `violin_front_size.png` |
| `03_convergence.R` | `convergencia.png`, mean and 95% confidence interval, common scale |
| `04_fronts.R` | `fronteras.png`, final fronts with normalised axes and 1:1 aspect |
| `05_epsilon.R` | `epsilon_by_dataset.png`, `indicadores_epsilon.csv` |
| `06_ranking.R` | `ranking_wins.png`, `ranking_avg.png` |

## How MOSA is measured

`_common.R` has a switch that changes the whole comparison:

```r
MOSA_METRIC <- "archive"   # "archive" or "single"
```

* `"archive"`: hypervolume of the non-dominated archive that MOSA keeps.
* `"single"`: hypervolume of the single best solution MOSA optimises.

They lead to different conclusions, so pick one before writing up results.
Note that in `"archive"` mode NSGA-II uses the front of its final population
while MOSA and RS use an archive accumulated over all evaluations.
