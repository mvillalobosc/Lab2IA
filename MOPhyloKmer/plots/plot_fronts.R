# =====================================================================
# plot_fronts.R  ·  Pareto fronts of NSGA-II vs MOSA in a single plot
# ---------------------------------------------------------------------
# Both fronts overlaid on one square panel (interactive):
#   LS (least squares) vs ME (minimum evolution), both to be minimised.
# Uses the front of the run with the highest final hypervolume, per algorithm.
#
# Uso:  Rscript plots/plot_fronts.R primates_14
# =====================================================================
suppressPackageStartupMessages({
  library(ggplot2)
  for (.p in c("plotly", "htmlwidgets"))
    if (!requireNamespace(.p, quietly = TRUE)) install.packages(.p)
  library(plotly)
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
dataset <- if (length(args)) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
if (is.na(dataset)) {
  ff <- list.files(RESULTS_DIR, pattern = "^front_(NSGA|MOSA)_.*\\.csv$")
  if (!length(ff)) stop("No fronts in ", RESULTS_DIR, ". Re-run the algorithms.")
  dataset <- sub("\\.csv$", "", sub("_run[0-9]+$", "", sub("^front_(NSGA|MOSA)_", "", ff[1])))
}

best_run_num <- function(algo) {
  files <- list.files(RESULTS_DIR,
                      pattern = sprintf("^conv_%s_%s_run.*\\.csv$", algo, dataset),
                      full.names = TRUE)
  if (!length(files)) return(NA_integer_)
  i <- which.max(vapply(files, function(f) max(read.csv(f)$best_so_far), numeric(1)))
  as.integer(sub(".*_run(\\d+)\\.csv$", "\\1", files[i]))
}
load_front <- function(algo, label) {
  canon <- file.path(RESULTS_DIR, sprintf("front_%s_%s.csv", algo, dataset))
  f <- if (file.exists(canon)) canon else {
    n <- best_run_num(algo); if (is.na(n)) return(NULL)
    file.path(RESULTS_DIR, sprintf("front_%s_%s_run%02d.csv", algo, dataset, n))
  }
  if (!file.exists(f)) return(NULL)
  d <- read.csv(f); d$Algorithm <- label; d
}

dn <- load_front("NSGA", "NSGA-II")
dm <- load_front("MOSA", "MOSA")
df <- do.call(rbind, Filter(Negate(is.null), list(dn, dm)))
if (is.null(df) || !nrow(df))
  stop("No fronts (front_*.csv) for '", dataset, "'. Re-run the algorithms.")
df$Algorithm <- factor(df$Algorithm, levels = c("NSGA-II", "MOSA"))
df <- df[order(df$Algorithm, df$ls, df$me), ]

NAVY <- "#12355B"; ORANGE <- "#EA7600"
p <- ggplot(df, aes(ls, me, colour = Algorithm, group = Algorithm)) +
  geom_line(linewidth = 0.6, alpha = 0.6) +
  geom_point(size = 1.9) +
  scale_colour_manual(values = c("NSGA-II" = NAVY, "MOSA" = ORANGE)) +
  labs(title = paste0("Pareto fronts on ", dataset, " (best run)"),
       x = "Least-squares error", y = "Minimum evolution", colour = NULL) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

gg <- ggplotly(p, tooltip = c("colour", "x", "y"),
               width = 620, height = 620) %>%   # square widget size
  layout(legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15))

out <- file.path(FIG_DIR, paste0("fronts_", dataset, ".html"))
res <- try(htmlwidgets::saveWidget(gg, out, selfcontained = TRUE), silent = TRUE)
if (inherits(res, "try-error")) htmlwidgets::saveWidget(gg, out, selfcontained = FALSE)
message("Interactive figure: ", out)
if (interactive()) print(gg)
