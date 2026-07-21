# =====================================================================
# packages.R  ·  Carga de dependencias
# ---------------------------------------------------------------------
# Instala (si falta) y carga cada paquete de forma silenciosa.
# =====================================================================
.deps <- c("ecr", "ape", "seqinr", "kmer", "phylotools", "phangorn",
           "stringr", "phytools", "treespace", "igraph", "ggplot2",
           "factoextra", "insect")

for (.p in .deps) {
  if (!requireNamespace(.p, quietly = TRUE)) install.packages(.p)
  suppressPackageStartupMessages(library(.p, character.only = TRUE))
}
rm(.deps, .p)
