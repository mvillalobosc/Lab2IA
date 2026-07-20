# =====================================================================
# plot_convergence.R  ·  Figuras de convergencia NIVEL PUBLICACION
# ---------------------------------------------------------------------
# Lee las trazas reales de results/ y genera figuras limpias (PNG 300dpi):
#   - NSGA-II : best-so-far vs generacion.
#   - MOSA    : solucion actual (celeste) + best-so-far (azul) vs iteracion.
# Elige la corrida con mayor HV final.
#
# Uso:  Rscript plot_convergence.R conrado_126
# =====================================================================
suppressPackageStartupMessages({library(ggplot2)})

# Directorios: si main.R ya los definio, se respetan; si no, se deducen.
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
# 1) argumento de linea de comando  2) variable DATASET si existe  3) autodetectar
dataset <- if (length(args)) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA

csvs <- list.files(RESULTS_DIR, pattern = "^conv_(NSGA|MOSA)_.*\\.csv$")
if (length(csvs) == 0) {
  stop("No hay trazas en ", RESULTS_DIR,
       ". Corre primero el algoritmo (Rscript main.R) para generar los CSV.")
}
if (is.na(dataset)) {
  # tomar el dataset del primer CSV disponible
  dataset <- sub("^conv_(NSGA|MOSA)_(.*)_run.*$", "\\2", csvs[1])
  message("Dataset no indicado; usando el disponible: ", dataset)
}
disponibles <- unique(sub("^conv_(NSGA|MOSA)_(.*)_run.*$", "\\2", csvs))
if (!(dataset %in% disponibles)) {
  stop("No hay trazas para '", dataset, "'. Disponibles en results/: ",
       paste(disponibles, collapse = ", "))
}

# ---- paleta y tema de publicacion -----------------------------------
NAVY <- "#12355B"; LB <- "#5BA4D6"
YLIM <- c(0, 4)   # eje Y comun (HV acotado por ref.point (2,2))
tema_paper <- theme_minimal(base_size = 13, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 13, hjust = 0),
    axis.title       = element_text(size = 13),
    axis.text        = element_text(size = 11, color = "grey25"),
    panel.grid.major = element_line(color = "grey88", linewidth = 0.4),
    panel.grid.minor = element_blank(),
    axis.line        = element_line(color = "grey55", linewidth = 0.5),
    legend.position  = "bottom",
    legend.title     = element_blank(),
    legend.text      = element_text(size = 11),
    plot.margin      = margin(8, 12, 6, 6))

guardar <- function(p, nombre) {
  dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(FIG_DIR, paste0(nombre, ".png"))
  ggsave(png_path, p, width = 5.4, height = 3.6, dpi = 300, bg = "white")
  message("  -> ", png_path)
}

mejor_csv <- function(patron) {
  files <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (!length(files)) return(NULL)
  files[which.max(vapply(files, function(f) max(read.csv(f)$best_so_far),
                         numeric(1)))]
}

# ---- NSGA-II --------------------------------------------------------
f_nsga <- mejor_csv(sprintf("^conv_NSGA_%s_run.*\\.csv$", dataset))
if (!is.null(f_nsga)) {
  d <- read.csv(f_nsga)
  p <- ggplot(d, aes(generation, best_so_far)) +
    geom_line(color = NAVY, linewidth = 1.2, lineend = "round") +
    labs(title = paste0(dataset, ", NSGA-II"),
         x = "Generation", y = "Hypervolume") +
    scale_y_continuous(limits = YLIM, breaks = seq(YLIM[1], YLIM[2], 1)) +
    tema_paper +
    guides(color = guide_legend(override.aes = list(linewidth = 1.4)))
  guardar(p, paste0("conv_NSGA_", dataset)); if (interactive()) print(p)
  message("OK  NSGA  -> ", f_nsga)
}

# ---- MOSA -----------------------------------------------------------
f_mosa <- mejor_csv(sprintf("^conv_MOSA_%s_run.*\\.csv$", dataset))
if (!is.null(f_mosa)) {
  d  <- read.csv(f_mosa)
  dl <- rbind(
    data.frame(iteration = d$iteration, hv = d$current,     serie = "Current solution"),
    data.frame(iteration = d$iteration, hv = d$best_so_far, serie = "Best-so-far"))
  dl$serie <- factor(dl$serie, levels = c("Current solution", "Best-so-far"))
  p <- ggplot(dl, aes(iteration, hv, color = serie, linewidth = serie)) +
    geom_line(lineend = "round") +
    scale_color_manual(values = c("Current solution" = LB, "Best-so-far" = NAVY)) +
    scale_linewidth_manual(values = c("Current solution" = 0.6, "Best-so-far" = 1.2)) +
    labs(title = paste0(dataset, ", MOSA"),
         x = "Iteration", y = "Hypervolume") +
    scale_y_continuous(limits = YLIM, breaks = seq(YLIM[1], YLIM[2], 1)) +
    tema_paper + guides(linewidth = "none",
                        color = guide_legend(override.aes = list(linewidth = 1.4)))
  guardar(p, paste0("conv_MOSA_", dataset)); if (interactive()) print(p)
  message("OK  MOSA  -> ", f_mosa)
}
message("\nFiguras (PNG) guardadas en:\n  ", FIG_DIR)
