# YeastForest: R workflow for phylogenetic forests

R scripts used in the manuscript *Gene-tree discordance across yeast genomes: phylogenetic forests of Saccharomyces cerevisiae and Saccharomyces eubayanus* (Villalobos-Cid, López Neilaf, Sáez Arias, Salinas, Cubillos, Villarreal and Kessi-Pérez). From a VCF and a gene annotation, the workflow builds one neighbour-joining tree per gene and a genome-wide reference tree with the same isolates, compares every pair of trees and measures how often each branch recurs across the forest.

The results for both species can be explored in the YeastForest viewer: <https://mvillalobosc.diinf.usach.cl/YeastForest/>

## What the workflow computes

- **Gene trees and reference tree.** Genetic distances are mean absolute differences in normalised allele dosage (ALT copies divided by the ploidy declared in GT), so haploid, diploid and polyploid calls are handled without phasing. Each tree is an unrooted neighbour-joining tree; internal branches of length 1e-10 or less are collapsed.
- **Forest support.** For each branch, the percentage of the other gene trees that contain the same bipartition. This is the gene concordance factor (Baum 2007; Minh et al. 2020) computed for every branch of every tree. It is not bootstrap support.
- **Tree comparison.** Normalised Robinson-Foulds distance, RF(A,B) = (sA + sB - 2c)/(sA + sB), and directional concordance, C(A <- B) = 100 c/sA, for every pair of trees, including the reference.
- **Groups and tests.** MST-kNN groups of gene trees (package `mstknnclust`), GO/KEGG enrichment for *S. cerevisiae*, permutation tests for the chromosomal position of the groups, resolution and SNP filters, recurrent branches absent from the reference, and the comparison with an earlier alignment-based forest.

## Folder layout

```
YeastForest_code/
  Bosque_cerevisiae/
    bosque_SCerevisiae.R       forest of S. cerevisiae
    clusters_SCerevisiae.R     MST-kNN groups and GO/KEGG enrichment
    publicar_bosque.R          analyses A, B, D and F of the paper
    DATA/                      inputs: 1011Matrix.gvcf.gz and SGD_features.tab
    Arboles/                   alignment-based trees, one <ORF>.nwk per gene (analysis F only)
  Bosque_eubayanus/
    bosque_Eubayanus.R         forest of S. eubayanus
    grupos_Eubayanus.R         MST-kNN groups (no enrichment)
    publicar_bosque.R          analyses A, B and D of the paper (same file as above)
    DATA/                      inputs: filtered_eub.recode.vcf.bgz and gene_result.txt
  cepas_cerevisiae.tsv         isolate and population (Peter et al. 2018)
  cepas_eubayanus.tsv          isolate, lineage and geographic/ecological metadata
  preparar_app.R               data files of the YeastForest viewer
  figuras_MER.R                Figures 1 to 5 and the numbers reported in the text
  LICENSE
```

The `DATA/` and `Arboles/` folders are not part of this repository; see the input data section below.

## Running the workflow

Each script writes its results next to itself. The forest scripts read `DATA/` relative to the working directory, so run every script from its own folder:

```
cd Bosque_cerevisiae
Rscript bosque_SCerevisiae.R
Rscript clusters_SCerevisiae.R
Rscript publicar_bosque.R

cd ../Bosque_eubayanus
Rscript bosque_Eubayanus.R
Rscript grupos_Eubayanus.R
Rscript publicar_bosque.R

cd ..
Rscript preparar_app.R
Rscript figuras_MER.R
```

The scripts can also be run with `source()` or as RStudio Jobs. Settings are at the top of each script, in the `CONFIG` list where there is one. The forest scripts save their progress in a hidden folder and resume from the last batch if a run is interrupted. Setting the environment variable `PHYLO_LIBRARY_ONLY=1` loads the functions of a forest or cluster script without running it.

The *S. cerevisiae* forest (1,011 isolates, 6,613 ORFs) was computed on a server. The number of parallel processes is set with `workers` in `CONFIG`.

## Input data

- ***S. cerevisiae* genotypes:** `1011Matrix.gvcf.gz`, the genotype matrix of the 1,011 isolates of Peter et al. (2018), available at <http://1002genomes.u-strasbg.fr/files/>.
- ***S. cerevisiae* annotation:** `SGD_features.tab`, the chromosomal features file of the Saccharomyces Genome Database (<https://www.yeastgenome.org>).
- ***S. eubayanus* genotypes:** `filtered_eub.recode.vcf.bgz`, the variant call set of 471 isolates on the CBS 12357 assembly (GCA_003327605.1). It will be deposited in Zenodo with the derived forests, the isolate metadata, the alignment-based forest of analysis F and an archived release of this code.
- ***S. eubayanus* annotation:** `gene_result.txt`, the tabular gene list of NCBI Gene (Send to > File > Tabular). Its coordinates refer to the FM1318 assembly (GCF_001298625.1), so `bosque_Eubayanus.R` downloads both genomes from NCBI into `DATA/` on its first run and locates each gene on CBS 12357 by sequence. Genes that cannot be located unambiguously are listed in `Eubayanus_genes_sin_ubicar.tsv` with the reason.

Other species can be analysed by changing `CONFIG` in a forest script: the VCF, the annotation (`SGD_features.tab`, a GFF3 or a table with chromosome, start, end and gene ID) and, if chromosome names differ between them, a chromosome map.

## Main output files

File and column names keep the Spanish names used during the project.

| File | Content |
| --- | --- |
| `<prefix>_arboles.nwk` | line 1 is the reference tree, then one tree per gene; node labels hold the forest support |
| `<prefix>_resumen.tsv` | one row per tree: SNPs, resolution, mean support, RF to the reference; genes without a tree carry the reason |
| `<prefix>_RF.csv.gz` | normalised RF distances, all against all |
| `<prefix>_concordancia.csv.gz` | directional concordance: % of the branches of the row tree present in the column tree |
| `<prefix>_distancias_geneticas.csv.gz` | genetic distances between isolates used by the reference tree |
| `<prefix>_clusters.tsv`, `<prefix>_clusters_resumen.tsv` | MST-kNN group of each gene tree and summary per group |
| `<prefix>_enriquecimiento.tsv` | every GO/KEGG enrichment test (*S. cerevisiae*) |
| `<prefix>_pub_A_*`, `_pub_B_*`, `_pub_D_*`, `_pub_F_*` | tables of the analyses A, B, D and F reported in the paper |
| `data/` | data files of the YeastForest viewer |
| `figs/` | Figures 1 to 5, supporting tables and `cifras.tsv` with the numbers of the text |

The prefix is `SCerevisiae` or `Eubayanus`. Spanish words in the file names: arboles = trees, resumen = summary, concordancia = concordance, distancias geneticas = genetic distances, enriquecimiento = enrichment, cepas = strains.

## Requirements

R with the CRAN packages `ape`, `data.table`, `Matrix`, `Rcpp`, `digest`, `R.utils`, `igraph`, `mstknnclust`, `jsonlite`, `Rtsne` and `uwot`, and the Bioconductor packages `VariantAnnotation`, `Rsamtools`, `GenomicRanges`, `GenomeInfoDb`, `IRanges`, `SummarizedExperiment`, `S4Vectors`, `Biostrings`, `AnnotationDbi`, `org.Sc.sgd.db`, `GO.db` and `KEGGREST`. The scripts try to install missing packages. The KEGG pathways and the NCBI genomes are downloaded, so those steps need internet access. The C++ distance functions are compiled with Rcpp, which requires a C++ compiler.

## Licence and contact

MIT licence (see `LICENSE`). Manuel Villalobos-Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile: manuel.villalobos@usach.cl

## References

- Baum DA (2007) Concordance trees, concordance factors, and the exploration of reticulate genealogy. *Taxon* 56: 417-426.
- Minh BQ, Hahn MW, Lanfear R (2020) New methods to calculate concordance factors for phylogenomic datasets. *Molecular Biology and Evolution* 37: 2727-2733.
- Peter J, De Chiara M, Friedrich A, et al. (2018) Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature* 556: 339-344.
