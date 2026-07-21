# =====================================================================
# plot_convergence.R  ·  NSGA-II vs MOSA en un solo grafico (interactivo)
# ---------------------------------------------------------------------
# Mejor corrida de cada algoritmo, eje X = evaluaciones de la funcion
# objetivo (NSGA: generacion*POBLACION; MOSA: iteracion). Best-so-far de
# cada uno + la oscilacion "current" de MOSA como sombra clara detras.
# Eje Y fijo (YLIM) para comparar. Salida: HTML interactivo (ggplotly).
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
  RESULTS_DIR <- file.path(dirname(ROOT), "results")
  FIG_DIR     <- file.path(dirname(ROOT), "figures")
}
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

args    <- commandArgs(trailingOnly = TRUE)
dataset <- if (length(args)) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
POB     <- if (exists("POBLACION")) POBLACION else 68L

csvs <- list.files(RESULTS_DIR, pattern = "^conv_(NSGA|MOSA)_.*\\.csv$")
if (length(csvs) == 0)
  stop("No hay trazas en ", RESULTS_DIR, ". Corre primero Rscript main.R.")
if (is.na(dataset))
  dataset <- sub("^conv_(NSGA|MOSA)_(.*)_run.*$", "\\2", csvs[1])

mejor_corrida <- function(patron) {
  files <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (!length(files)) return(NULL)
  files[[which.max(vapply(files, function(f) max(read.csv(f)$best_so_far), numeric(1)))]]
}

NAVY <- "#12355B"; ORANGE <- "#EA7600"

# --- best-so-far de cada algoritmo (lineas principales) --------------
mejores <- list(); sombra <- NULL
f_nsga <- mejor_corrida(sprintf("^conv_NSGA_%s_run.*\\.csv$", dataset))
if (!is.null(f_nsga)) {
  d <- read.csv(f_nsga)
  mejores[[length(mejores) + 1]] <- data.frame(
    eval = d$generation * POB, hv = d$best_so_far, Algorithm = "NSGA-II")
}
f_mosa <- mejor_corrida(sprintf("^conv_MOSA_%s_run.*\\.csv$", dataset))
if (!is.null(f_mosa)) {
  d <- read.csv(f_mosa)
  mejores[[length(mejores) + 1]] <- data.frame(
    eval = d$iteration, hv = d$best_so_far, Algorithm = "MOSA")
  sombra <- data.frame(eval = d$iteration, hv = d$current)   # oscilacion SA
}
if (!length(mejores)) stop("No hay trazas para '", dataset, "'.")
df <- do.call(rbind, mejores)
df$Algorithm <- factor(df$Algorithm, levels = c("NSGA-II", "MOSA"))

# --- grafico ---------------------------------------------------------
p <- ggplot()
if (!is.null(sombra))                                   # sombra: current de MOSA
  p <- p + geom_line(data = sombra, aes(eval, hv, group = 1),
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
message("Figura interactiva: ", out)
if (interactive()) print(gg)
