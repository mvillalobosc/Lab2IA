# =====================================================================
# _common.R  ·  Configuration, plotting theme and data loading for the analysis
# ---------------------------------------------------------------------
# Sourced by the other scripts. Set paths and the MOSA switch here.
# =====================================================================

# ---------- CONFIG (edit here) ------------------------------------------
# (paths resolved automatically from the repository root)

MOSA_METRIC <- "archive"           # "archive" (non-dominated archive) or "single" (single best solution)
POB_NSGA     <- 93                 # population NSGA (para el eje de evaluaciones)
POP_RS       <- 93                 # population RS
# ---------------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
  for (.p in c("dplyr", "tidyr", "scales"))
    if (requireNamespace(.p, quietly = TRUE)) library(.p, character.only = TRUE)
})

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
PROJ        <- .project_root()
RESULTS_DIR <- file.path(PROJ, "results")
OUT_DIR     <- file.path(PROJ, "analysis", "output")

# comprobacion
if (!dir.exists(RESULTS_DIR))
  stop("results folder not found at '", RESULTS_DIR, "'. Run run_experiments.R first.")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---------- publication style ------------------------------------
PAL <- c("NSGA-II" = "#8CA9D6", "MOSA" = "#EFA98A", "RS" = "#8EC9AE")  # pastel refinado (daltonico-amable)
ORD <- c("NSGA-II", "MOSA", "RS")
theme_pub <- function(base = 12) {
  theme_bw(base_size = base) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(linewidth = 0.25, colour = "grey90"),
          panel.border     = element_rect(colour = "grey65"),
          strip.background = element_rect(fill = "grey96", colour = "grey65"),
          strip.text       = element_text(face = "bold", size = base - 1),
          legend.position  = "top",
          legend.title     = element_blank(),
          legend.margin    = margin(b = 2),
          plot.title       = element_text(face = "bold"))
}
save_plot <- function(plot, nombre, w = 8, h = 6) {
  ggsave(file.path(OUT_DIR, paste0(nombre, ".png")), plot, width = w, height = h, dpi = 300, bg = "white")
  message("  figure -> ", file.path(OUT_DIR, nombre), ".png")
}

# ---------- data ----------------------------------------------------
KEY      <- c("NSGA-II" = "NSGA", "MOSA" = "MOSA", "RS" = "RS")
datasets <- sub("^resumen_NSGA_(.*)\\.csv$", "\\1",
                list.files(RESULTS_DIR, "^resumen_NSGA_.*\\.csv$"))
datasets <- datasets[order(tolower(datasets))]   # orden alfabetico
if (!length(datasets)) stop("No resumen_NSGA_*.csv files in ", RESULTS_DIR)

# hypervolume per run for a method and data set (honours MOSA_METRIC)
hv_runs <- function(ds, method) {
  if (MOSA_METRIC == "archive") {
    # front for all three: maximum front hypervolume per run (from conv files)
    fs <- list.files(RESULTS_DIR, sprintf("^conv_%s_%s_run.*\\.csv$", KEY[[method]], ds), full.names = TRUE)
    if (length(fs)) return(vapply(fs, function(f) max(read.csv(f)$hypervolume), numeric(1)))
  }
  # single (or fallback): taken from the summary file
  col <- if (method == "MOSA") "hv_best" else "hv_max"
  read.csv(file.path(RESULTS_DIR, sprintf("resumen_%s_%s.csv", KEY[[method]], ds)))[[col]]
}

# long hypervolume table: data set, method, run, hv
hv_table_long <- function() {
  out <- list()
  for (ds in datasets) for (m in ORD) {
    v <- tryCatch(hv_runs(ds, m), error = function(e) numeric(0))
    if (length(v)) out[[length(out) + 1]] <-
      data.frame(dataset = ds, method = m, run = seq_along(v), hv = as.numeric(v))
  }
  d <- do.call(rbind, out)
  d$method  <- factor(d$method, levels = ORD)
  d$dataset <- factor(d$dataset, levels = datasets)
  d
}

# long convergence trace: data set, method, run, eval, hv
convergence_long <- function() {
  out <- list()
  for (ds in datasets) for (m in ORD) {
    fs <- list.files(RESULTS_DIR, sprintf("^conv_%s_%s_run.*\\.csv$", KEY[[m]], ds), full.names = TRUE)
    for (k in seq_along(fs)) {
      d <- read.csv(fs[k])
      if (m == "MOSA") {
        ev <- d$iteration
        hv <- if (MOSA_METRIC == "archive") d$hypervolume else d$best_so_far
      } else {
        pob <- if (m == "NSGA-II") POB_NSGA else POP_RS
        ev <- d$generation * pob
        hv <- d$best_so_far
      }
      out[[length(out) + 1]] <- data.frame(dataset = ds, method = m, run = k,
                                           eval = ev, hv = hv)
    }
  }
  d <- do.call(rbind, out)
  d$method  <- factor(d$method, levels = ORD)
  d$dataset <- factor(d$dataset, levels = datasets)
  d
}

# metric (spread or front_size) of the FINAL front, per run
final_metric_long <- function(cual = "spread") {
  out <- list()
  for (ds in datasets) for (m in ORD) {
    fs <- list.files(RESULTS_DIR, sprintf("^conv_%s_%s_run.*\\.csv$", KEY[[m]], ds), full.names = TRUE)
    for (k in seq_along(fs)) {
      d <- read.csv(fs[k]); v <- d[[cual]][nrow(d)]
      out[[length(out) + 1]] <- data.frame(dataset = ds, method = m, run = k, value = v)
    }
  }
  d <- do.call(rbind, out)
  d$method  <- factor(d$method, levels = ORD)
  d$dataset <- factor(d$dataset, levels = datasets)
  d
}

MOSA_LAB <- if (MOSA_METRIC == "archive") "archive front" else "single solution"
message("_common.R loaded | datasets: ", length(datasets), " | MOSA metric: ", MOSA_LAB)
