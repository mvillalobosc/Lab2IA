# =====================================================================
# plot_trees.R  ·  Arboles filogeneticos NIVEL PUBLICACION (ggtree)
# ---------------------------------------------------------------------
# Grafica los arboles Newick exportados por las corridas (best tree por
# algoritmo) con estilo limpio: layout dendrograma, etiquetas de taxon
# legibles y nodos internos marcados. Salida PNG 300dpi + PDF vectorial.
#
# Requiere ggtree (Bioconductor):
#   if (!requireNamespace("BiocManager")) install.packages("BiocManager")
#   BiocManager::install("ggtree")
#
# Uso:  Rscript plot_trees.R primates_14          (dataset)
#       Rscript plot_trees.R primates_14 rectangular   (layout opcional)
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
  RESULTS_DIR <- file.path(dirname(ROOT), "results")
  FIG_DIR     <- file.path(dirname(ROOT), "figures")
}
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

args    <- commandArgs(trailingOnly = TRUE)
dataset <- if (length(args) >= 1) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
layout  <- if (length(args) >= 2) args[2] else "dendrogram"   # o "rectangular"

nwks <- list.files(RESULTS_DIR, pattern = "^tree_(NSGA|MOSA)_.*\\.nwk$")
if (length(nwks) == 0)
  stop("No hay arboles (.nwk) en ", RESULTS_DIR,
       ". Corre primero el algoritmo (Rscript main.R).")
if (is.na(dataset))
  dataset <- sub("^tree_(NSGA|MOSA)_(.*)_run.*$", "\\2", nwks[1])

NAVY <- "#12355B"; DOT <- "#2C7FB8"

# elige la mejor corrida usando el resumen (mayor HV); si no, la primera
mejor_nwk <- function(algo) {
  files <- list.files(RESULTS_DIR,
                      pattern = sprintf("^tree_%s_%s_run.*\\.nwk$", algo, dataset),
                      full.names = TRUE)
  if (!length(files)) return(NULL)
  res <- file.path(RESULTS_DIR, sprintf("resumen_%s_%s.csv", algo, dataset))
  if (file.exists(res)) {
    r  <- read.csv(res)
    hv <- if ("hv_best" %in% names(r)) r$hv_best else r$hv_max
    files[which.max(hv)]
  } else files[1]
}

dibujar <- function(nwk, titulo, nombre) {
  arbol <- read.tree(nwk)
  g <- ggtree(arbol, layout = layout, ladderize = TRUE,
              color = NAVY, linewidth = 0.7) +
    geom_tiplab(size = 3.2, color = "grey15",
                angle = if (layout == "dendrogram") 90 else 0,
                hjust = if (layout == "dendrogram") 1 else -0.05) +
    geom_nodepoint(size = 2.2, color = DOT, alpha = 0.9) +
    labs(title = titulo) +
    theme_tree() +
    theme(plot.title = element_text(face = "bold", size = 13),
          plot.margin = margin(6, 20, 40, 6))
  if (layout == "rectangular") g <- g + xlim(0, max(node.depth.edgelength(arbol)) * 1.25)
  dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(FIG_DIR, paste0(nombre, ".png"))
  ggsave(png_path, g, width = 6.2, height = 4.6, dpi = 300, bg = "white")
  message("  -> ", png_path)
  if (interactive()) print(g)
  message("OK  ", nombre, "  <- ", basename(nwk))
}

for (algo in c("NSGA", "MOSA")) {
  f <- mejor_nwk(algo)
  if (!is.null(f))
    dibujar(f, sprintf("%s  ·  %s", dataset, algo),
            sprintf("tree_%s_%s", algo, dataset))
}
message("\nArboles (PNG) guardados en:\n  ", FIG_DIR)
