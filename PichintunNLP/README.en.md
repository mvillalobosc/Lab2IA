# pichintun-nlp

**English** | [Español](README.md)

Reproducible R pipeline for the natural language analysis of the 34 episodes across four seasons of the Chilean children's television series *Pichintún*.

The analysis covers five dimensions: lexical composition (standard Spanish against Indigenous vocabulary and Chilean idioms), thematic structure over 16 categories, sentiment and emotion, lexical complexity and diversity, and the factors associated with the show's reception on YouTube.

---

## Repository layout

```
pichintun-nlp/
├── run_all.R                  Single entry point
├── R/
│   ├── 00_config.R            Paths, parameters and styling
│   ├── 01_ingest.R            Load dialogues, metadata and lexicons
│   ├── 02_clean.R             Cleaning, tokenisation, lexical partition
│   ├── 03_frequency.R         Word frequency, keyness, distances
│   ├── 04_topics.R            The 16 topics by episode and season
│   ├── 05_sentiment.R         Sentiment and 16 emotion types
│   ├── 06_readability.R       ARI and MATTR
│   ├── 07_popularity.R        Random Forest and multiple regression
│   ├── 08_export.R            Consolidation and verification
│   └── lib/
│       ├── packages.R         Single dependency declaration
│       ├── io.R               Reading, writing and caching
│       ├── text.R             Normalisation and tokenisation
│       └── stats_helpers.R    Distances, dendrograms, clustering
├── data/
│   ├── raw/                   Input data, versioned
│   └── processed/             Intermediate artefacts (.rds), regenerable
├── outputs/
│   ├── figures/               97 PNG figures
│   └── tables/                31 CSV tables and 1 Excel workbook
└── report/
    └── pichintun_report.Rmd   HTML report built from the outputs
```

---

## Installation and execution

Requires **R 4.2 or later**. Verified on R 4.3.3 under Ubuntu 24.04.

```r
# 1. Install dependencies (once)
source("R/lib/packages.R")
check_packages(install_missing = TRUE)

# 2. Run the full pipeline
```

```bash
Rscript run_all.R
```

Each module writes its result to `data/processed`, so a module can be re-run without repeating the previous ones:

```bash
Rscript run_all.R 5 6 7     # sentiment, readability and popularity only
```

Full runtime: roughly **6 minutes** on an ordinary desktop machine. Module 03 dominates, because of the 34 word clouds.

### Dependencies

`dplyr`, `tidyr`, `purrr`, `readr`, `stringr`, `tibble`, `ggplot2`, `tokenizers`, `tm`, `hunspell`, `quanteda`, `quanteda.textstats`, `quanteda.textplots`, `sentimentr`, `koRpus`, `koRpus.lang.es`, `fmsb`, `corrplot`, `dendextend`, `amap`, `mstknnclust`, `ggwordcloud`, `patchwork`, `gridExtra`, `scales`, `igraph`, `caret`, `randomForest`, `writexl`.

`koRpus.lang.es` is not on CRAN. Install it from the maintainer's repository:

```r
install.packages("koRpus.lang.es",
                 repos = c(l10n = "https://undocumeantit.github.io/repos/l10n"))
```

### File count

The versioned repository is **29 files**: 14 of code, 9 of data, 5 of documentation and 1 report, plus the `.gitkeep` placeholders. The 97 figures and 31 tables under `outputs/` regenerate with `Rscript run_all.R` and are excluded by `.gitignore`, keeping the repository below the 100-file limit of GitHub's web uploader.

---

## Data

All input data is included under `data/raw`, in UTF-8.

| Path | Contents |
|---|---|
| `metadata/episodes.csv` | Master key: 34 episodes with season, order, title, YouTube id, ISO date and animation team |
| `metadata/youtube_stats.csv` | Views, likes, subscribers, impressions and CTR per episode |
| `dialogues_es.csv` | Spanish transcripts, one row per episode |
| `dialogues_en.csv` | English translations, one row per episode, required by `sentimentr` |
| `lexicons/word_topics.csv` | 3,051 words classified into 16 topics plus "sin definir" |
| `lexicons/stopwords_extra.csv` | 450 domain-specific stopwords, added to those from `tm` |
| `dictionaries/es_ES.dic`, `.aff` | Spanish hunspell dictionary |

The four files join on `episode_id`. `episodes.csv` is the single source of truth: to add an episode, append one row to each of the four CSVs. No script contains hand-written title lists, file paths or row ranges.

Dialogues live in two CSVs rather than 68 loose files so the repository stays under the 100-file limit imposed by GitHub's web uploader. Each text occupies a single line, so diffs remain readable episode by episode.

---

## The 16 topics

geography, ecosystem, learning, work, culture/traditions, cooking, artistic expression, activities, identity, everyday life, descriptions, relationships, feelings, experiences, health/wellbeing, urban infrastructure.

Words falling outside all 16 are held under `sin definir` and excluded from the topic matrices. Effective coverage: **94.1 %** of tokens.

Topic labels are kept in Spanish throughout the code and the output tables, since they are part of the annotated lexicon rather than of the software interface.

---

## Main outputs

**Tables** (`outputs/tables/`)

- `08_maestro_capitulos.csv`: one row per episode with every metric in the pipeline
- `08_maestro_temporadas.csv`: the same aggregated by season
- `pichintun_resultados.xlsx`: 17 sheets covering the above plus importances, coefficients and clusters
- `08_verificacion.csv`: integrity checks for the run

**Diagnostics** (relevant when interpreting results)

- `02_diag_palabras_sin_tema.csv`: vocabulary outside the topic lexicon
- `02_diag_forzar_culturales.csv`: effect of reclassifying words as culturally marked
- `07_resumen_modelos.csv`: adjusted R², residual degrees of freedom and an overparameterisation flag

All outputs regenerate with `Rscript run_all.R` and are excluded from version control by `.gitignore`.

**Figures** (`outputs/figures/`): word clouds, keyness plots, topic radar charts, sentiment curves, dendrograms, correlation matrices, MST-kNN clusters and trend curves.

---

## Methodological decisions

**Affective analysis runs on English.** `sentimentr` only ships English lexicons, so the dialogues are analysed through their translations. This is inherited from the original design and is a genuine limitation: translation can shift affective load, particularly in passages carrying Indigenous vocabulary with no direct equivalent.

**ARI on English, MATTR on Spanish.** `quanteda` does not provide a Spanish parameterisation of ARI, so complexity is measured on the translation. Lexical diversity (MATTR, 200-word window) is measured on the Spanish text, which is where it matters.

**Both metrics use the uncleaned text.** ARI and MATTR require punctuation, capitalisation and sentence segmentation to be intact. The pipeline keeps the original text alongside the cleaned one.

**Normalisation by exposure time.** Likes, subscribers and views are divided by the months elapsed between publication and the cut-off date (`CFG$fecha_corte`, 13 April 2023) before rescaling to [0, 1].

**Topics enter as proportions, not frequencies.** Episodes differ in length, so a topic's absolute frequency conflates thematic presence with episode length.

---

## Caveat on the popularity models

The original criterion feeds the linear regression every variable with Random Forest importance above 20 %. With 34 episodes that admits **27 predictors for Likes (6 residual degrees of freedom) and 26 for Views (7 df)**.

Those two models are overparameterised: the adjusted R² (0.79 and 0.65) is inflated and the p-values are not interpretable in the usual sense. The Subscribers model lands at 13 residual df, which is defensible.

The pipeline does not change the criterion, but it does declare the problem: it raises a `warning()` and sets the `sobreparametrizado` column in `07_resumen_modelos.csv`. For publication, raise `CFG$umbral_importancia_rf` or apply regularisation.

---

## Changes from the original code

The starting point was a single 2,098-line `Pichintun.Rmd` with 61 chunks. The substantive changes:

**Errors that prevented execution**

1. Dates arrived as `"Mayo 2, 2016"` and were parsed with `as.Date(x, "%B %d, %Y")`, which is locale-dependent. Under the C locale, standard on Linux servers, this returns `NA` and the entire popularity module silently collapsed to `NA`. Dates are now ISO 8601.
2. `tokenize_sentence()` (singular) does not exist in the `tokenizers` package. The function is `tokenize_sentences()`.
3. `plotly::as.widget()` has been removed from the package. Trend curves are now produced with `ggplot2`.
4. `if (is.na(temas_cap[i, tema]))` with a zero-length index is an error, not a warning, from R 4.2 onwards.
5. Dependencies were used but absent from the install vector (`dendextend`, `amap`, `quanteda.textstats`, `quanteda.textplots`, `koRpus.lang.es`, `tibble`), and unused packages were loaded (`xlsx`, which pulls in Java, `syuzhet`, `wordcloud2`, `varImp`).

**Errors that silently altered results**

6. **The opening song was not removed from 18 of the 34 episodes.** The pattern was applied with `stringr::fixed()` against a string whose accents did not match those in the file, leaving residue ("islas", "pampa", "salar") contaminating the frequency counts. Worth noting: season 3 does not carry the song at all.
7. `as.integer(labels(dend))` returned `NA` when the matrix carried row names, so dendrogram colouring by season was misassigned.
8. Reclassifying "chile" as culturally marked happened midway through the frequency module, **after** computing the idiom percentage that feeds the models. Season word clouds and the Random Forest were therefore using different lexical partitions. It now happens once, in `02_clean.R`. Quantified effect: up to 3.3 percentage points across 10 episodes, tabulated in `02_diag_forzar_culturales.csv`.

**Structural fragility**

9. The 34 episodes were opened with 34 hand-written `read_lines()` calls, with a different filename prefix per season (`C-`, `A-`, none). Replaced by `episodes.csv` plus two dialogue CSVs joined on `episode_id`, with validation for missing episodes and empty texts.
10. Season blocks were hard-coded as fixed row ranges (`1:6`, `7:16`, `17:26`, `27:34`) over a date-ordered data frame. They happen to line up today, so the published results are correct, but adding an episode would have corrupted them silently. Replaced by `split()` on the `season` column.
11. Series ordering depended on the alphabetical tie-break left behind by `merge()`, which is not stable across R versions. It is now explicit: date, then title.
12. The absolute path `C:/Users/ekama/Documents/Pichintún/` was hard-coded. Paths now resolve from the repository root.

**Performance and cleanup**

13. Word-to-topic assignment used `temas_palabra$tema[temas_palabra$palabra == p]` inside a nested loop, on the order of 1.2 × 10⁵ data frame subsets. Replaced by a named vector and grouped `rowsum`.
14. A UTF-8 locale is now enforced at startup. Without it R emits hundreds of `unable to translate` warnings and degrades accented labels.
15. Removed the `test`, `test32`, `test33`, `test322` and `test342` chunks, which duplicated analyses already present.
16. The three near-identical Random Forest and regression blocks (likes, subscribers, views) were unified into a single function.

---

## Reproducibility

Seeds for the three Random Forest models are fixed in `R/00_config.R` (`seed_likes`, `seed_subscribers`, `seed_views`). The rest of the pipeline is deterministic, apart from word cloud layout and clustering graph layout, both purely visual.

`08_export.R` runs an integrity check at the end and writes `08_verificacion.csv`.

---

## Citation

See `CITATION.cff`.

## Licence

Code released under the MIT licence. The series dialogues are third-party material included for academic research purposes. See `LICENSE`.
