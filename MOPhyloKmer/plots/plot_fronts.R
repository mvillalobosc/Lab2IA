# =====================================================================
# plot_fronts.R  ·  Fronteras de Pareto NSGA-II vs MOSA en UN grafico
# ---------------------------------------------------------------------
# Ambas fronteras superpuestas en un solo panel cuadrado (interactivo):
#   LS (least squares) vs ME (minimum evolution), ambos a minimizar.
# Usa la frontera de la corrida con mayor HV final de cada algoritmo.
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
  RESULTS_DIR <- file.path(dirname(ROOT), "results")
  FIG_DIR     <- file.path(dirname(ROOT), "figures")
}
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

args    <- commandArgs(trailingOnly = TRUE)
dataset <- if (length(args)) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
if (is.na(dataset)) {
  ff <- list.files(RESULTS_DIR, pattern = "^front_(NSGA|MOSA)_.*\\.csv$")
  if (!length(ff)) stop("No hay fronteras en ", RESULTS_DIR, ". Re-corre los algoritmos.")
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
load_front <- function(algo, etq) {
  canon <- file.path(RESULTS_DIR, sprintf("front_%s_%s.csv", algo, dataset))
  f <- if (file.exists(canon)) canon else {
    n <- best_run_num(algo); if (is.na(n)) return(NULL)
    file.path(RESULTS_DIR, sprintf("front_%s_%s_run%02d.csv", algo, dataset, n))
  }
  if (!file.exists(f)) return(NULL)
  d <- read.csv(f); d$Algorithm <- etq; d
}

dn <- load_front("NSGA", "NSGA-II")
dm <- load_front("MOSA", "MOSA")
df <- do.call(rbind, Filter(Negate(is.null), list(dn, dm)))
if (is.null(df) || !nrow(df))
  stop("No hay fronteras (front_*.csv) para '", dataset, "'. Re-corre los algoritmos.")
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
               width = 620, height = 620) %>%   # tamano cuadrado del widget
  layout(legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15))

out <- file.path(FIG_DIR, paste0("fronts_", dataset, ".html"))
res <- try(htmlwidgets::saveWidget(gg, out, selfcontained = TRUE), silent = TRUE)
if (inherits(res, "try-error")) htmlwidgets::saveWidget(gg, out, selfcontained = FALSE)
message("Figura interactiva: ", out)
if (interactive()) print(gg)
