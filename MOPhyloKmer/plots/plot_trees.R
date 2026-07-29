# =====================================================================
# plot_trees.R  ·  Publication-quality phylogenetic trees (ggtree)
# ---------------------------------------------------------------------
# Draws the MEDOID tree (centre of the front) of each algorithm,
# taken from the best run, with a clean style: dendrogram layout, taxon labels
# readable labels and marked internal nodes. Output: PNG at 300 dpi.
#
# Requiere ggtree (Bioconductor):
#   if (!requireNamespace("BiocManager")) install.packages("BiocManager")
#   BiocManager::install("ggtree")
#
# Uso:  Rscript plot_trees.R primates_14          (dataset)
#       Rscript plot_trees.R primates_14 rectangular   (optional layout)
# =====================================================================
suppressPackageStartupMessages({
  library(ape); library(ggplot2)
  if (!requireNamespace("ggtree", quietly = TRUE)) {
    if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
    BiocManager::install("ggtree", update = FALSE, ask = FALSE)
  }
  library(ggtree)
})

if (!exists("RESULTS_DIR") || !exists("FIG_DIR")) {
  .this_dir <- function() {
    fr <- rev(seq_len(sys.nframe()))
    for (i in fr) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
    a <- commandArgs(FALSE); m <- grep("^--file=", a)
    if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
  }
  ROOT <- .this_dir()
# --- repository root: walk up until config.R is found -----------------
# Works with Rscript, with source() in RStudio and from any folder.
.script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
.project_root <- function(d = .script_dir()) {
  for (i in 1:8) {
    if (file.exists(file.path(d, "config.R"))) return(normalizePath(d))
    p <- dirname(d); if (identical(p, d)) break; d <- p
  }
  stop("config.R not found: run this from inside the MOPhyloKmer repository.")
}
  PROJ <- .project_root(ROOT)
  RESULTS_DIR <- file.path(PROJ, "results")
  FIG_DIR     <- file.path(PROJ, "figures")
}
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

args    <- commandArgs(trailingOnly = TRUE)
dataset <- if (length(args) >= 1) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
layout  <- if (length(args) >= 2) args[2] else "dendrogram"   # o "rectangular"

nwks <- list.files(RESULTS_DIR, pattern = "^medoid_(NSGA|MOSA)_.*\\.nwk$")
if (length(nwks) == 0)
  stop("No medoid trees (medoid_*.nwk) in ", RESULTS_DIR,
       ". Run the algorithm first (Rscript main.R).")
if (is.na(dataset))
  dataset <- sub("\\.nwk$", "", sub("^medoid_(NSGA|MOSA)_", "", nwks[1]))

NAVY <- "#12355B"; DOT <- "#2C7FB8"

# pick the best run from the summary file (highest HV); otherwise the first
best_nwk <- function(algo) {
  # consolidated file of the best run
  canon <- file.path(RESULTS_DIR, sprintf("medoid_%s_%s.nwk", algo, dataset))
  if (file.exists(canon)) return(canon)
  # fallback: pick the best among the per-run files
  files <- list.files(RESULTS_DIR,
                      pattern = sprintf("^medoid_%s_%s_run.*\\.nwk$", algo, dataset),
                      full.names = TRUE)
  if (!length(files)) return(NULL)
  res <- file.path(RESULTS_DIR, sprintf("resumen_%s_%s.csv", algo, dataset))
  if (file.exists(res)) {
    r  <- read.csv(res)
    hv <- if ("hv_best" %in% names(r)) r$hv_best else r$hv_max
    files[which.max(hv)]
  } else files[1]
}

draw_tree <- function(nwk, titulo, nombre) {
  tree <- read.tree(nwk)
  g <- ggtree(tree, layout = layout, ladderize = TRUE,
              color = NAVY, linewidth = 0.7) +
    geom_tiplab(size = 3.2, color = "grey15",
                angle = if (layout == "dendrogram") 90 else 0,
                hjust = if (layout == "dendrogram") 1 else -0.05) +
    geom_nodepoint(size = 2.2, color = DOT, alpha = 0.9) +
    labs(title = titulo) +
    theme_tree() +
    theme(plot.title = element_text(face = "bold", size = 13),
          plot.margin = margin(6, 20, 40, 6))
  if (layout == "rectangular") g <- g + xlim(0, max(node.depth.edgelength(tree)) * 1.25)
  dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(FIG_DIR, paste0(nombre, ".png"))
  ggsave(png_path, g, width = 6.2, height = 4.6, dpi = 300, bg = "white")
  message("  -> ", png_path)
  if (interactive()) print(g)
  message("OK  ", nombre, "  <- ", basename(nwk))
}

for (algo in c("NSGA", "MOSA")) {
  f <- best_nwk(algo)
  if (!is.null(f)) {
    label <- if (algo == "NSGA") "NSGA-II" else "MOSA"
    draw_tree(f, sprintf("%s - %s medoid tree", dataset, label),
            sprintf("medoid_%s_%s", algo, dataset))
  }
}
message("\nMedoid trees (PNG) saved in:\n  ", FIG_DIR)
