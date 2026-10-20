# Measured or assumed? Energy-efficiency evidence for spiking versus artificial neural networks

Data, protocols and R scripts of the systematic review *Measured or assumed? A systematic review of the energy-efficiency evidence for spiking versus artificial neural networks* (Baladrón Pezoa, Aravena Karstegl, Gulppi Paredes, Inostroza-Ponta and Villalobos Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile; manuscript submitted to *Neural Computing and Applications*, 2026).

[Versión en español](README.es.md)

The review follows PRISMA 2020. It searched Scopus and Web of Science on 14 October 2026 for studies published between 2020 and 2026 that compare artificial neural networks (ANNs) and spiking neural networks (SNNs) on an efficiency metric, or that apply pruning, sparsity or lottery-ticket methods to either paradigm. Every record was screened on title and abstract, every record that passed was charted on its complete abstract with eighteen items, and a small set of full texts was assessed for ANN-SNN pairs with energy measured on hardware on both sides.

## Headline numbers

| Stage | Records |
|---|---|
| Identified (Scopus 6,092; Web of Science 4,688) | 10,780 |
| Duplicates removed | 4,454 |
| Screened on title and abstract | 6,326 |
| Excluded at screening | 4,217 |
| Assessed on the complete abstract and charted | 2,109 |
| Excluded at that stage (E0 to E7) | 638 |
| Included in the evidence map | 1,471 |
| Candidates for the full-text stage | 163 |
| Full texts assessed / included | 5 / 3 |

Categories of the 1,471 included studies (a study may belong to several): C1 ANN-SNN efficiency comparison 727; C2 pruning or sparsity in SNNs 383; C3 lottery tickets in ANNs 331; C4 lottery tickets in SNNs 6; C5 reviews 58; C6 benchmarking methodology 46.

## Repository layout

```
scripts/      R scripts, numbered in execution order (see below)
protocols/    written protocols applied at each stage
data/
  raw/        search strings and export instructions (the exports themselves are not distributed)
  records/    public metadata of the 6,334 unique records (no abstracts) and identification counts
  screening/  title/abstract decisions, pilot, agreement sample and re-screening files
  charting/   charting of the 2,109 records assessed on the complete abstract, verification sample, adjudications
  fulltext/   candidate list and completed full-text assessments
  results/    consolidated decisions, evidence map, agreement statistics and counts
figures/      Figures 2 to 5 of the manuscript (vector PDF)
```

Each folder has its own README (in Spanish and English) that describes its files one by one: [scripts/](scripts/), [protocols/](protocols/), [data/](data/) and its subfolders [raw/](data/raw/), [records/](data/records/), [screening/](data/screening/), [charting/](data/charting/), [fulltext/](data/fulltext/) and [results/](data/results/), and [figures/](figures/).

### Scripts

| Script | Purpose |
|---|---|
| `00_run_all.R` | Runs the pipeline in order; skips the steps that need the raw exports when they are absent |
| `01_deduplicate.R` | Merges the exports, removes duplicates by DOI and normalised title, assigns search blocks, writes `records.csv` and the identification counts |
| `02_screening_batches.R` | Builds the screening batches (abstract shown up to 1,400 characters), the stratified pilot of 200 records and the random agreement sample of 430 records |
| `03_screening_agreement.R` | Agreement and Cohen's kappa between two independent screenings; prints the result to the console and writes no file |
| `04_check_screening_batches.R` | Validates the screening files against the batch definitions |
| `05_full_abstract_batches.R` | Batches with the complete abstract for a list of records |
| `06_rescreen_set.R` | Late duplicates and the reproducible rule that defines the 1,114 records re-screened with the complete abstract |
| `07_consolidate_screening.R` | Final screening decision per record, agreement with the second screening, screening counts |
| `08_charting_batches.R` | Charting batches (complete abstract) and the 10 % verification sample |
| `09_check_charting.R` | Validates the charting files and computes item-level agreement with the second charting |
| `10_build_map.R` | Applies the eligibility adjudications and the publication-year audit and writes the evidence map |
| `11_fulltext_candidates.R` | Lists the candidates for the full-text stage |
| `12_figures.R` | Figures 2 to 5 |

### Reproducing the analysis

Requirements: R 4.x with `data.table`, `readxl`, `stringi`, `jsonlite`, `ggplot2`, `patchwork` and `scales`. `12_figures.R` writes the figures with the `cairo_pdf` device, so R must have Cairo support. Run from the repository root:

```
Rscript scripts/00_run_all.R
```

Without the raw exports the pipeline starts from the distributed decision files and rebuilds every result in `data/results/` and the figures. With the exports in place (see `data/raw/search_strings.txt`), it also rebuilds the record set and every batch file, and checks that the batches match the decision files record by record. Record identifiers are fixed by `data/records/record_ids.csv`, so the decision files keep matching whatever the locale of the machine.

A run overwrites the tracked files in `data/results/`, `data/fulltext/candidates.csv` and the four PDFs in `figures/`. With the distributed decision files and without the exports, the steps that run (03, 04, 07, 09, 10 and 11) reproduce `data/results/` and `data/fulltext/candidates.csv` byte for byte (checked with R 4.3.3 on Linux, data.table 1.14.10 and jsonlite 1.8.8). Step 11 also writes the full-text batch files to `data/processed/fulltext_batches/`, a folder that `.gitignore` excludes, even when the exports are absent.

Screening and charting decisions were produced by large language models (Claude Opus 5.5, Claude Fable 5.1 and Claude Sonnet 5.5, Anthropic, October 2026) applying the written protocols in `protocols/`, under the supervision of the authors, who verified random samples and adjudicated the disagreements. The pilot, the agreement sample and the verification sample are included so that the reliability of each stage can be recomputed.

## Data dictionary

### `data/records/records.csv` (6,334 rows, one per unique record)

| Column | Content |
|---|---|
| `record_id` | Identifier used in every other file (R00001 to R06334) |
| `source`, `source_id` | Database of the retained record and its native identifier (Scopus EID or WoS UT) |
| `wos_id` | WoS identifier when the record was found in both databases |
| `block` | Search block matched: A (ANN-SNN comparison with an efficiency term), B (sparsity and lottery tickets), A+B, none |
| `title`, `year`, `doi`, `document_type`, `venue`, `authors`, `language`, `citations`, `open_access`, `author_keywords` | Bibliographic metadata as exported |

Abstracts and indexed keywords are not redistributed; they belong to the databases and can be regenerated from the exports.

### Screening files (`data/screening/`)

Tab-separated, no header, five fields: `record_id`, `decision` (INCLUDE, EXCLUDE, UNSURE), `code` (categories C1 to C6 joined by `+`, or one exclusion reason E1 to E7), `hardware` mentioned, `note`. `batch_ids.csv` maps records to batches; `title_abstract/` holds the 64 first-pass batches; `pilot/` holds the two independent screenings of the pilot; `kappa_sample/` the second screening of the agreement sample; `rescreen/` the two rounds of re-screening with the complete abstract and the identifier lists that define them. No script writes `rescreen/rescreen_a_ids.csv`: it is the list of the first round, chosen with a preliminary version of the rule, and `06_rescreen_set.R` reads it to fix the final rule.

### Charting files (`data/charting/`)

Tab-separated, no header, eighteen fields in the order given in `protocols/charting_protocol.txt`: `record_id`, `eligible`, `reason`, `categories`, `paradigm`, `architecture`, `task`, `platform_snn`, `platform_ann`, `evidence`, `metrics`, `comparison`, `sparsity_method`, `lth_variant`, `granularity`, `cost_in_objective`, `hardware_measured`, `note`. `primary/` is the charting of all 2,109 records; `verification/` the independent second charting of 211 records; `eligibility_adjudication.csv` the decision of the third reviewer on the nineteen eligibility disagreements; `year_audit.csv` the three records excluded with code E0 because their bibliographic year lies outside 2020-2026. No script writes these last two files: they record decisions made by the reviewers.

`08_charting_batches.R` writes charting batches of 100 records and verification files of up to 75, but the decision files are split into parts of 25 records: `primary/charting_NN_a.tsv` to `charting_NN_d.tsv` for batches 01 to 21 plus `charting_22_a.tsv` (9 records), and `verification/verification_N_a.tsv` to `verification_N_c.tsv` for the three verification files (the last part has 11 records). `09_check_charting.R` reads the parts with the patterns `charting_NN_[a-d].tsv` and `verification_N_[a-c].tsv`, and `10_build_map.R` reads the verification parts with the second pattern.

### Results (`data/results/`)

| File | Content |
|---|---|
| `screening_decisions.csv` | Final title/abstract decision for each of the 6,326 screened records, with the stage that produced it |
| `charting_primary.csv` | Primary charting of the 2,109 records, with column names |
| `mapping.csv` | Final evidence map: charting after adjudication and year audit, joined with the bibliographic metadata; `eligible == "Y"` marks the 1,471 included studies |
| `field_agreement.csv` | Agreement and kappa per charted item on the verification sample |
| `screening_disagreements.csv`, `eligibility_disagreements.csv` | Records on which the two screenings or the two chartings disagreed |
| `counts_screening.json`, `counts_mapping.json` | Counts used in the PRISMA flow diagram and in the tables |

### Full-text stage (`data/fulltext/`)

`candidates.csv` lists the 163 studies whose abstract indicated or suggested energy measured on hardware on both sides, plus the six studies in category C4. `assessment.tsv` records the five full texts assessed (three included, two excluded), `pairs.tsv` the eight ANN-SNN pairs extracted from the included studies, and `within_snn_control.tsv` the same recurrent SNN run on a GPU and on Loihi, which is a substrate control rather than an ANN-SNN pair. `historical_2019_blouw_*.tsv` hold the assessment of a 2019 workshop paper exported with the year 2020 and excluded from the window by the year audit. The remaining candidates have not been assessed on the full text; the manuscript presents the assessed set as illustrative and not as an exhaustive synthesis.

Unlike the screening and charting files, the TSV files of this stage have a header row. The assessment files have the 8 fields and the pair files the 26 fields defined in `protocols/fulltext_protocol.txt`; the protocol describes files written per batch without a header, while the distributed files keep one file per type. No script reads or writes these TSV files.

## Codes

Inclusion categories: C1 empirical ANN-SNN comparison with an efficiency metric; C2 pruning, sparsity or activity reduction in SNNs; C3 lottery-ticket family in ANNs; C4 lottery-ticket family in SNNs; C5 review or survey; C6 benchmarking or measurement methodology. Exclusion reasons: E0 publication year outside 2020-2026 (year audit); E1 not a research or review paper; E2 device, material or circuit level without a network-level evaluation; E3 neuroscience modelling without a machine-learning task; E4 SNN-only work without an ANN efficiency comparison and without sparsity content; E5 ANN-only work without SNN and without lottery-ticket content; E6 off-topic; E7 general ANN pruning outside the lottery-ticket family and without SNNs. The vocabularies of the charted items are listed in `protocols/charting_protocol.txt`.

## Licence and citation

Code is released under the MIT licence (`LICENSE`); the data files and protocols under CC BY 4.0. Please cite the manuscript when using the data; a citation entry will be added once the article is published.
