# =====================================================================
# packages.R  ·  Dependencias del SA
# =====================================================================
.deps <- c("ecr", "ape", "seqinr", "kmer", "phylotools",
           "phangorn", "stringr", "phytools", "insect")
for (.p in .deps) {
  if (!requireNamespace(.p, quietly = TRUE)) install.packages(.p)
  suppressPackageStartupMessages(library(.p, character.only = TRUE))
}
rm(.deps, .p)
