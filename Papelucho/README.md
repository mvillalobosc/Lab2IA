# A Text Mining Analysis of the Papelucho Series

[Español](README.es.md) · **English**

Reproducible computational analysis of lexical, structural, and emotional patterns in the *Papelucho* series by Marcela Paz (12 books, 1947–1974), compared against a corpus of 63 Spanish-language novels.

---

## What this repository contains

A nine-step R pipeline that builds a curated corpus, computes lexical diversity, readability, part-of-speech profiles, sentiment, emotion, and stylometric distances, and then tests every finding against the structural imbalances in the comparison corpus.

Every table is exported three times: a machine-readable CSV, an English LaTeX table, and a Spanish LaTeX table.

---

## Quick start

```bash
# 1. Install R dependencies
Rscript -e 'install.packages(c(
  "dplyr","tidyr","readr","purrr","tibble","stringr","stringi",
  "ggplot2","tidytext","stopwords","udpipe","sentimentr","syuzhet",
  "zoo","ggdendro","ggrepel","uwot","cluster","scales"))'

# 2. Fetch the Spanish POS model (28 MB, not tracked in git)
Rscript scripts/download_udpipe_model.R

# 3. Place the corpus text files (see docs/CORPUS.md)
#    data/raw/papelucho/*.txt   12 files
#    data/raw/comparison/*.txt  63 files

# 4. Run everything
Rscript run_all.R

# ...or a single step
Rscript run_all.R 02
```

Before a long run, or before committing, the static audit catches unresolved
function calls and silent `summarise()` shadowing without executing anything:

```bash
Rscript scripts/audit_pipeline.R
```

Runtime is roughly one hour on a single core, dominated by step 04 (POS tagging) and step 05 (sentence-level sentiment).

---

## Pipeline

| Step | Script | What it does |
|---|---|---|
| 01 | `01_build_corpus.R` | Validates metadata against disk, removes scraper footers and editorial front matter, builds the raw and content representations, writes a QA report |
| 02 | `02_lexical_diversity.R` | Eleven diversity indices under fixed-size resampling to control for text length |
| 03 | `03_readability.R` | Structural complexity plus four Spanish-validated readability formulas |
| 04 | `04_pos_analysis.R` | Part-of-speech profiles from raw text, sentence-sampled to a fixed token budget |
| 05 | `05_sentiment.R` | Sentence-level sentiment with a Spanish lexicon; 20-segment narrative arcs |
| 06 | `06_emotions.R` | NRC emotion profiles normalised per 1,000 tokens |
| 07 | `07_stylometry.R` | Burrows's Delta clustering with bootstrap branch support |
| 08 | `08_umap.R` | UMAP projection with multi-seed stability assessment |
| 09 | `09_sensitivity.R` | Re-tests every finding under three restricted corpus designs |

---

## Methodological decisions

This pipeline replaces an earlier version of the analysis. The changes below are not stylistic preferences; each corrects a specific error that changed a published conclusion. They are documented here and in the header comment of every script.

### 1. Two text representations, never mixed

The pipeline keeps two versions of every book:

- **raw** — punctuation, capitalisation and function words intact. Used for readability, POS tagging, and sentiment.
- **content** — lowercased content words, stopwords removed. Used only for lexical diversity and stylometry.

The earlier analysis mixed them: sentence counts came from the raw text while token counts came from the stripped text. Since stopword removal discards roughly 55% of running words, every words-per-sentence figure was slightly under half its true value, and both readability indices inherited the error.

### 2. Length control by resampling

Papelucho books have a median of ~19,000 running tokens. Comparison novels have a median of ~102,000. Almost every classical lexical-richness measure falls as a text grows, so raw comparison measures book length and reports it as style.

Every length-sensitive index is computed on random samples of a fixed token count, repeated 30 times per book and averaged. Whole-text values are also reported so the size of the artefact is visible.

**This changes conclusions.** Seven of eleven indices flip direction or significance once length is controlled. TTR, Herdan's C, Maas, and the hapax ratio all reverse direction.

### 3. Spanish-validated readability formulas

Flesch-Kincaid and ARI were fitted on English school texts. Spanish carries roughly 15–20% more syllables per word for the same conceptual difficulty, so the English coefficients inflate estimated grade level by several years.

Four Spanish formulas are used instead: Fernández Huerta (1959), Szigriszt-Pazos (1993) with the INFLESZ interpretive bands, Gutiérrez de Polini (1972), and the Mu index (Muñoz & Muñoz, 2006). Gutiérrez de Polini is the only one calibrated specifically on material for children. The English formulas are still computed and clearly labelled, so earlier values remain traceable.

### 4. POS tagging on raw text

In Spanish the stopword list consists almost entirely of function words. Tagging a text with those removed does not measure the text's grammatical profile — it measures what the stopword list happens to contain.

Tagging the same book both ways:

| Category | Raw text | Stopword-filtered | Distortion |
|---|---|---|---|
| ADP (adpositions) | 10.8% | 0.5% | ÷22 |
| CCONJ | 7.2% | 0.1% | ÷72 |
| PRON | 13.4% | 2.7% | ÷5 |
| ADJ | 3.6% | 16.7% | ×4.6 |
| VERB | 17.5% | 33.5% | ×1.9 |

Pronoun frequency is one of the few measures that speaks directly to a first-person child narrator, which is the defining formal feature of the series. Filtering pronouns out before tagging discards exactly the evidence the study needs.

### 5. Spanish sentiment lexicon with a self-test

`sentimentr::sentiment()` called without arguments silently defaults to an **English** polarity table. On Spanish input it scores almost everything at zero. Scoring *"me siento muy feliz y contento hoy"* with the default returns exactly **0.00**; the English equivalent returns 1.02.

Compounding this, the earlier pipeline computed sentiment on text whose punctuation had already been stripped, so `get_sentences()` returned **one "sentence" per book** and the 20-segment narrative arc collapsed to a single point.

This pipeline builds a Spanish polarity table (4,596 terms from the Spanish NRC list) plus 65 valence shifters covering negation, amplification, de-amplification, and adversatives. A self-test runs before any analysis and **stops the script** if the lexicon is not scoring Spanish correctly, so the silent-failure mode cannot recur.

### 6. Emotion counts normalised by length

`get_nrc_sentiment()` returns absolute counts. Feeding those into a group test when one group's books are five times longer produces eight "significant" results by construction. Counts are now expressed per 1,000 running tokens, and Holm correction is applied once across the whole family.

### 7. Burrows's Delta instead of TF-IDF clustering

TF-IDF rewards terms appearing in few documents. In a corpus of novels those are character and place names, so a TF-IDF dendrogram recovers **which books share a cast** — a fact about series membership, not style. Burrows's Delta works on the most frequent words including function words, which is where authorial style actually lives.

Branch support is estimated by bootstrapping the feature set 1,000 times. Branches below ~70% support should not be interpreted. The TF-IDF analysis is retained as a labelled sensitivity check, and `07_method_comparison.csv` quantifies how much more strongly TF-IDF tracks series membership.

### 8. UMAP stability instead of one projection

UMAP is stochastic. With 75 points, a single run can produce a visually convincing separation that vanishes under a different seed. Publishing one plot from one seed is one draw from a distribution of possible pictures, not evidence of structure.

UMAP is run across five seeds × three neighbour settings × three min-distance settings. Two quantities are reported: neighbourhood preservation (is the projection faithful at all?) and group silhouette (does separation hold?), both benchmarked against the silhouette in the original Delta space. **UMAP is used for display only** — every statistical claim rests on the distance matrix, never on projection coordinates.

### 9. Effect sizes alongside every p-value

With n = 12 versus n = 63, a significant p-value says almost nothing about how large a difference is. Every comparison reports Cliff's delta with a bootstrap 95% CI and the rank-biserial correlation. A result is called significant only when the adjusted p-value is below 0.05 **and** the effect size is at least small.

---

## Corpus composition: read this before interpreting anything

The comparison corpus has three structural imbalances that no statistical adjustment can fully remove.

| Issue | Magnitude |
|---|---|
| Authorship concentration | R. A. Salvatore contributes 16 of 63 books (25.4%); the top 5 authors contribute 38 |
| Translation | 60 of 63 comparison books are translations; Papelucho is original Chilean Spanish |
| Target audience | Most comparison books are adult fiction; Papelucho is children's literature |

Mann-Whitney assumes independent observations. Sixteen novels by one author sharing a setting and narrative voice are not sixteen independent draws, so p-values on the full corpus are anticonservative. Translated prose also differs systematically from original prose in the target language (the *translation universals* documented in translation studies), so lexical differences may be translation effects rather than Papelucho effects.

**Step 09 re-tests every finding under three restricted designs:** audience-matched, original-Spanish-only, and one-book-per-author repeated 200 times. A finding that survives all three is robust to corpus composition. A finding that appears only on the full corpus is a statement about how the comparison group was assembled.

If the headline findings do not survive step 09, the corpus needs rebuilding. No amount of careful statistics fixes a comparison group that differs in more ways than the one being studied.

---

## Known limitations

- **Syllable counting** is rule-based (vowel-group counting with hiatus correction). Accuracy against hand-checked Spanish is around 96%, adequate for corpus-level indices but not for word-level claims.
- **The NRC Spanish lexicon** is a machine translation of the English original. It inherits translation errors and does not cover Chilean usage, which matters for a corpus of Chilean children's literature.
- **The NRC lexicon assigns emotions out of context.** Irony, negation, and figurative language are invisible to it. For a narrator whose humour depends on saying the opposite of what is meant, this is a real constraint.
- **No published Spanish valence-shifter list exists for `sentimentr`.** The one in `utils_sentiment_es.R` was assembled from standard Spanish grammar of negation and degree modification. It has not been externally validated.
- **Sentiment results should be read as a coarse signal**, not a precise measurement.

---

## Repository layout

```
├── R/
│   ├── 00_config.R              Paths, parameters, bilingual labels, dependency check
│   ├── utils_text.R             Normalisation, sentence splitting, syllable counting
│   ├── utils_stats.R            Cliff's delta, bootstrap CIs, multiple-testing correction
│   ├── utils_io.R               CSV + bilingual LaTeX export, figure saving
│   ├── utils_sentiment_es.R     Spanish polarity table and valence shifters
│   └── 01_…09_*.R               Analysis steps
├── data/
│   ├── metadata/corpus_metadata.csv   Curated: author, series, year, audience, language
│   ├── raw/                     Book texts (not tracked; see docs/CORPUS.md)
│   └── derived/                 Pipeline intermediates (regenerated)
├── outputs/
│   ├── tables/                  CSV + *_en.tex + *_es.tex
│   ├── figures/                 PDF (vector) + PNG (300 dpi)
│   └── logs/                    sessionInfo per step, pipeline timings
├── scripts/
│   ├── download_udpipe_model.R
│   └── audit_pipeline.R         Static checks: unresolved calls, shadowing, labels
├── docs/
├── run_all.R
└── LICENSE
```

---

## Reproducibility

- All randomness is seeded from `PARAMS$seed` in `R/00_config.R`.
- `sessionInfo()` is written to `outputs/logs/` for every step.
- The UDPipe model is pinned to `spanish-gsd-ud-2.5-191206`, not resolved by the generic `"spanish"` string, which can change between package versions and would silently alter tagging results.
- A UTF-8 locale is forced at startup; `LC_COLLATE=C` keeps file ordering byte-stable across machines.

---

## Corpus availability

The book texts are copyrighted and are **not** distributed with this repository. `data/metadata/corpus_metadata.csv` lists every title, author, and edition so the corpus can be reconstructed. See `docs/CORPUS.md`.

---

## Citation

```bibtex
@misc{papelucho_textmining,
  author = {Villalobos-Pérez, Sebastián and Chourio-Acevedo, Luz and
            Leiva-Lobos, Edmundo and Villalobos-Cid, Manuel},
  title  = {A text mining analysis of the Papelucho series},
  year   = {2026},
  note   = {Departamento de Ingeniería Informática, Universidad de Santiago de Chile}
}
```

## License

Code released under the MIT License. Corpus texts are not covered by this license and are not distributed here.

---

## Publishing to GitHub

The repository is **97 files** and uploads in one go, including by drag-and-drop
on github.com, which accepts at most 100 files at a time.

```bash
git init
git add .
git commit -m "Text mining analysis of the Papelucho series"
git branch -M main
git remote add origin https://github.com/<user>/papelucho-textmining.git
git push -u origin main
```

`run_all.R` calls `scripts/bundle_outputs.R` at the end to keep the count down:
the 54 individual LaTeX tables are merged into `tables_en.tex` and
`tables_es.tex`, the nine `sessionInfo` files into `session_info.txt`, PNG
figure previews are dropped in favour of the PDF vector versions, and four
per-replicate intermediate CSVs are removed. Everything removed is regenerated by
re-running the pipeline. To keep it all instead, delete the corresponding blocks
from `scripts/bundle_outputs.R`; the repository then has about 180 files, which
git handles fine but which must be pushed from the command line.
