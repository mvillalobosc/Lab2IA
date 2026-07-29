# =====================================================================
# plot_convergence.R  ·  NSGA-II vs MOSA in a single interactive plot
# ---------------------------------------------------------------------
# Best run of each algorithm, X axis = objective-function evaluations
# (NSGA: generation * POP_SIZE; MOSA: iteration). Best-so-far of
# each method, plus the MOSA current-solution oscillation as a light shadow.
# Y axis fixed with YLIM for comparison. Output: interactive HTML (ggplotly).
#
# Uso:  Rscript plots/plot_convergence.R primates_14
# =====================================================================
suppressPackageStartupMessages({
  library(ggplot2)
  for (.p in c("plotly", "htmlwidgets"))
    if (!requireNamespace(.p, quietly = TRUE)) install.packages(.p)
  library(plotly)
})

YLIM <- NULL   # NULL = auto (muestra la oscilacion del SA). Para hacer zoom al best-so-far: c(3.5, 3.72)

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
POB     <- if (exists("POP_SIZE")) POP_SIZE else 68L

csvs <- list.files(RESULTS_DIR, pattern = "^conv_(NSGA|MOSA)_.*\\.csv$")
if (length(csvs) == 0)
  stop("No traces in ", RESULTS_DIR, ". Run Rscript main.R first.")
if (is.na(dataset))
  dataset <- sub("^conv_(NSGA|MOSA)_(.*)_run.*$", "\\2", csvs[1])

best_run_file <- function(patron) {
  files <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (!length(files)) return(NULL)
  files[[which.max(vapply(files, function(f) max(read.csv(f)$best_so_far), numeric(1)))]]
}

NAVY <- "#12355B"; ORANGE <- "#EA7600"

# --- best-so-far of each algorithm (main lines) --------------
best_list <- list(); shadow <- NULL
f_nsga <- best_run_file(sprintf("^conv_NSGA_%s_run.*\\.csv$", dataset))
if (!is.null(f_nsga)) {
  d <- read.csv(f_nsga)
  best_list[[length(best_list) + 1]] <- data.frame(
    eval = d$generation * POB, hv = d$best_so_far, Algorithm = "NSGA-II")
}
f_mosa <- best_run_file(sprintf("^conv_MOSA_%s_run.*\\.csv$", dataset))
if (!is.null(f_mosa)) {
  d <- read.csv(f_mosa)
  best_list[[length(best_list) + 1]] <- data.frame(
    eval = d$iteration, hv = d$best_so_far, Algorithm = "MOSA")
  shadow <- data.frame(eval = d$iteration, hv = d$current)   # oscilacion SA
}
if (!length(best_list)) stop("No traces for '", dataset, "'.")
df <- do.call(rbind, best_list)
df$Algorithm <- factor(df$Algorithm, levels = c("NSGA-II", "MOSA"))

# --- plot ---------------------------------------------------------
p <- ggplot()
if (!is.null(shadow))                                   # shadow: current de MOSA
  p <- p + geom_line(data = shadow, aes(eval, hv, group = 1),
                     colour = ORANGE, alpha = 0.35, linewidth = 0.4)
p <- p +
  geom_line(data = df, aes(eval, hv, colour = Algorithm, group = Algorithm),
            linewidth = 0.9) +
  scale_colour_manual(values = c("NSGA-II" = NAVY, "MOSA" = ORANGE)) +
  labs(title = paste0("Convergence on ", dataset, " (best run of each algorithm)"),
       x = "Objective-function evaluations", y = "Hypervolume", colour = NULL) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

if (!is.null(YLIM)) p <- p + coord_cartesian(ylim = YLIM)

gg <- ggplotly(p, tooltip = c("colour", "x", "y")) %>%
  layout(legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.2))

out <- file.path(FIG_DIR, paste0("convergence_", dataset, ".html"))
res <- try(htmlwidgets::saveWidget(gg, out, selfcontained = TRUE), silent = TRUE)
if (inherits(res, "try-error")) htmlwidgets::saveWidget(gg, out, selfcontained = FALSE)
message("Interactive figure: ", out)
if (interactive()) print(gg)
