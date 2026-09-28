# Editorial and scientific review notes

**Target journal:** *Fungal Ecology*  
**Scope assessment:** The manuscript is thematically suitable: it addresses fungal population genomics, phylogeography, evolution, and quantitative methods. Its strongest journal-facing contribution is the demonstration that a geographic maximum should not be interpreted as an origin without explicit null controls and sampling-power checks. The story is relevant to the journal. The author confirms that both datasets are held by their research team: *S. cerevisiae* comes from the team’s published Peter et al. (2018) dataset, while the *S. eubayanus* dataset was assembled and curated by the author team. Data ownership and access are therefore not submission blockers. The assignment-label comparison has been corrected in the exported source and stored results; the revised paper reports the recalculated match rates as descriptive values. Check the current Guide for Authors in Editorial Manager at submission; this draft uses the `elsarticle` review layout and still needs the journal's final file and data requirements checked.

## Comments by manuscript section

### Abstract
- Rewritten to state the dataset denominators and main result without claiming a geographic source. The 943 *S. cerevisiae* count refers to isolates with recorded origins in locality analysis; 471 is the *S. eubayanus* dataset total.
- The abstract’s description of an open pipeline is supported by the public HTML, embedded R source and outputs. The *S. eubayanus* data are held by the author team and are available from the corresponding author on request; no third-party permission restriction applies.

### Introduction
- The narrative now runs from the biological question to known confounders, then to the platform contribution and the scale comparison. Citations support the central concepts: serial founder patterns, isolation by distance, Wahlund effects, and edge effects.
- Before submission, make the distinction between a software/platform contribution and a biological discovery explicit in the final paragraph. The present analysis does not establish a source for either species.

### Materials and methods

#### Datasets and grouping scales
- Corrected *S. cerevisiae* counts to 943 georeferenced isolates and ploidy counts to 107 haploid, 717 diploid, and 77 polyploid. Clarifies that 68 of the 1,011 isolates lack usable origins.
- Adds a provenance warning for seven inferred *S. eubayanus* micro-sites and distinguishes lineage centroids from collection coordinates. Confirm the inferred coordinates against field records before publication.
- The three grouping definitions and treatment of the Admix lineage are now explicit. Keep the lineage-centroid caveat visible anywhere geographic outputs at that scale are presented.
- The type-sensitive `identical()` comparison in the assignment script has been replaced by character-normalised label equality. I recomputed the correctness flags and per-group accuracy from the saved leave-one-out predictions and observed labels; no genotype likelihoods were changed. The paper now reports the resulting agreement rates as descriptive summaries.

#### Variant panels and resampling unit
- The strict and wide panels, their different uses, and the 100 kb block resampling unit are described. This is useful because the rare-allele statistics depend on the wide panel.
- Confirm that the random subsampling proportions and the final SNP counts are reproducible from a clean run, and report software/package versions and random seeds in the final methods or archived workflow.

#### Estimation
- The statistical descriptions are substantially clearer and identify assumptions such as majority-allele polarisation for `psi`, the limits of small groups for `f3`, and the non-likelihood ancestry factorisation.
- Resolve two methodological presentation risks before submission: the frequency-filter bias in Tajima's D and Watterson's theta should be accompanied by a clear statement of whether those outputs are interpreted anywhere; and the “common number of gene copies” rarefaction should specify its target sample size and exactly which groups are retained.
- The tree/bootstrap and years-as-bounds descriptions are appropriately cautious. Keep drift units as the principal temporal output.

#### Negative controls, model comparison and power
- The design is a strength of the paper. Ensure that every stated number of permutations/simulations, model definition, effect-size convention, and recovery threshold corresponds to the code and is reproducible from the archived run.
- The manuscript now treats the origin as unsupported when the controls do not validate it. Preserve that language in the abstract, results, and conclusion.

#### Platform
- Explain the single-file HTML, embedded code/results, language options, and offline-run/export workflow. This is useful to reviewers assessing reproducibility and usability.
- Include a stable versioned archive (for example, an institutional repository or Zenodo record) and test the public URL immediately before submission. A live web page alone is not a durable software citation.

#### Evaluation design
- The two species provide a plausible contrast: a candidate natural-range expansion and a human-dispersed/domesticated species as a negative expectation. Describe them as contrasting test cases, not as proof that the method generalises to all fungi.
- State explicitly that known lineage structure is a positive control for lineage recovery, not a ground-truth source location for the expansion analysis.

### Results and discussion

#### What the panels and groups look like
- Useful orientation to the two sampling geometries and the substantial lineage pooling at locality scale. The text now aligns with the corrected dataset counts.
- Explain “nearly isotropic” and the principal-axis ratio in a sentence or cite the precise calculation in Methods; otherwise remove the adjective.

#### Geographic signal depends on the grouping scale
- The separation of IBD, Procrustes structure, and among-continent variance is clearer. Avoid treating statistical significance as biological importance; retain the modest correlation values alongside p-values.
- Diversity maxima are interpreted as lineage mixture rather than source evidence. This is an important result and is supported by the lineage-aware comparisons.
- Figure 2 now displays the distribution of group-level heterozygosity and the `f3` signal by species and grouping scale. The caption notes that `f3` tests are not independent.

#### No expansion origin survives the controls
- This is the manuscript's central conclusion and the text correctly distinguishes a permutation result from source identifiability. The *S. eubayanus* locality-by-lineage result has a low permutation p-value but fails the no-expansion and power/identifiability checks.
- Recheck distances and coordinates for the inferred micro-sites and any “this study” exclusion before submission. Clarify which tests define “passed the edge-effect test,” since that check alone does not validate an origin.
- The optimal-design recommendation is interesting but should be described as model-conditional. Report how candidate sites were scored and avoid implying that a single new collection will in practice guarantee the stated region reduction.

#### Admixture and phylogenetic patterns align with reported structure
- Removed a duplicated nearest-neighbour passage and aligned the ancestry proportions with the table at all three scales. These are descriptive summaries, not estimates of migration direction.
- Verify each nearest-neighbour statistic against the same denominator used in the table. Ensure that the manuscript does not conflate a genetic nearest neighbour with a direct ancestor or dispersal event.
- Tree topology is compared with published structure; the broad claim is appropriately limited. Check the split order and drift values against the tree output once the pipeline is rerun.

#### What the checklist reports
- The checklist result is presented as a decision aid rather than a claim that failed runs are useless. This framing should remain.
- Confirm that the number of checks and pass/warning/fail counts in the text match the full output for all six runs, and define any blocking criteria in the methods or a supplement.

#### Using the platform
- The reader/reviewer use cases and the link between map, validation panel, and embedded code are clearer. The demonstration should include the durable archive and software version.
- Avoid implying that a click-through interface alone establishes reproducibility; point readers to the exact input files, code, and saved run used for every reported number.

#### Limitations and scope
- The limitations now cover ancestral-state uncertainty, filtered-site bias, factorisation limits, per-site diversity, ploidy, coordinate precision, and the simplified no-expansion simulation.
- The assignment-label comparison was corrected in the embedded R code and the saved output; the manuscript reports the recalculated descriptive match rates. The authors’ ownership and access to both datasets are clear and do not require a new deposit or permission.
- Scope claims should remain bounded to these datasets and this implementation until the workflow has been independently tested on additional fungal datasets.

### Figures and tables
- Replaced the manuscript's schematic/placeholder figure references with four project-based figures: framework, grouping-scale summaries, sample geography/diversity, and origin checks. Captions explain what each panel encodes.
- Figure 3 is a coordinate plot without a coastline/basemap. Add a properly sourced, licensed coastline layer if geographic interpretation or the journal's production standards require it; retain the present coordinate-only design if the figure is explicitly described as a sampling-coordinate view.
- Figure 4 makes the mixed evidence visible, including the one permutation result below 0.05 that still fails other validation criteria. Keep the exact p-values and error units legible at journal column width.
- The three main tables remain editable LaTeX tables. Check their width and font size in the journal's final template; no PDF was placed in the Overleaf package.

### Declarations and back matter

#### CRediT authorship contribution statement
- The statement is formatted in a recognisable CRediT style. Confirm each role with all co-authors and adjust to the journal's current taxonomy and policy.

#### Declaration of competing interest
- Standard declaration is present. Confirm it remains accurate for all authors.

#### Funding
- “No specific grant” is stated. Confirm institutional, infrastructure, or project support has not been omitted.

#### Data and code availability
- The statement now identifies the *S. cerevisiae* data as the team’s 1,011-genome dataset published by Peter et al. (2018), with raw-read accession ERP014555 and the processed matrix file (`1011Matrix.gvcf.gz`) listed at the 1002 Yeast Genome project site. It states that the *S. eubayanus* dataset was assembled and curated by the author team and is available from the corresponding author on request. No third-party permission restriction or mandatory new data deposit is asserted.
- Archive the exact HTML, R scripts, input manifests/checksums, and version information. Confirm that the manuscript URL resolves externally and that the archived version is immutable.

#### Acknowledgements
- Generic acknowledgement is present. Name data providers or funders who require acknowledgement and obtain their approval where needed.

## Reference audit

- Cross-checked every citation key in the manuscript against `references.bib`: **47 cited keys, 47 bibliography records, no missing keys, no uncited records, and no duplicate keys**.
- Added three missing methodological references used in the text: Hurlbert (1971), Kalinowski (2004), and Shannon (1948). The first is a general rarefaction reference; cite Kalinowski for allele/private-allele rarefaction.
- Checked DOI/title/journal/year metadata for the focal records most central to the argument and dataset: Peter et al. (2018), Kemppainen et al. (2024), Nespolo et al. (2020), Peris et al. (2014, 2016), Eizaguirre et al. (2018), Saitou and Nei (1987), Peter (2013), Hurlbert (1971), and Kalinowski (2004). The classic book and Mantel (1967) do not have DOI fields in this bibliography.
- One citation deserves a content check: cite Hurlbert for general rarefaction, but keep Kalinowski as the direct support for rarefaction of alleles/private alleles. Verify every page range, author accent, title capitalisation, and DOI against the final publisher records before submission; the reference crosswalk itself is complete, but the final production export should be checked after applying the journal's style.

## Submission readiness

**Current assessment: the paper fits the journal scope, and the data access statement is resolved. The factor/character assignment comparison has been corrected in the embedded source and saved output. The corrected match rates are included as descriptive results; they do not affect the geographic origin analyses. The manuscript and project package can now be reviewed together. Check the final journal-specific figure and reference formatting when uploading to Editorial Manager.
