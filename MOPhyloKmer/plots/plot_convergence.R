# =====================================================================
# plot_convergence.R  ·  Figuras de convergencia (nivel publicacion)
# ---------------------------------------------------------------------
# Agrega las N corridas (por defecto) y grafica la MEDIANA con una banda
# de variabilidad (min-max) sobre el eje comun de hipervolumen:
#   - NSGA-II : best-so-far vs generacion.
#   - MOSA    : solucion actual (celeste) + best-so-far (azul) vs iteracion.
#
# MODO:
#   "agregado" -> mediana + banda min-max de las N corridas   (recomendado)
#   "mejor"    -> solo la corrida con mayor HV final
#
# Uso:  Rscript plots/plot_convergence.R conrado_126
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
dataset <- if (length(args)) args[1] else
           if (exists("DATASET")) tools::file_path_sans_ext(DATASET) else NA
SOLO <- if (exists("ALGO")) ALGO else NA          # solo ese algoritmo si viene de main.R
MODO <- if (exists("MODO_GRAFICO")) MODO_GRAFICO else "mediana"
# "mediana" = corrida real en la mediana | "mejor" = mejor corrida | "agregado" = mediana punto-a-punto + banda

csvs <- list.files(RESULTS_DIR, pattern = "^conv_(NSGA|MOSA)_.*\\.csv$")
if (length(csvs) == 0)
  stop("No hay trazas en ", RESULTS_DIR,
       ". Corre primero el algoritmo (Rscript main.R).")
if (is.na(dataset)) {
  dataset <- sub("^conv_(NSGA|MOSA)_(.*)_run.*$", "\\2", csvs[1])
  message("Dataset no indicado; usando: ", dataset)
}

# ---- estilo de publicacion ------------------------------------------
NAVY <- "#12355B"; LB <- "#5BA4D6"
YLIM <- c(0, 4)   # eje Y comun (HV acotado por ref.point (2,2))
tema_paper <- theme_minimal(base_size = 13, base_family = "sans") +
  theme(plot.title = element_text(face = "bold", size = 13, hjust = 0),
        axis.title = element_text(size = 13),
        axis.text  = element_text(size = 11, color = "grey25"),
        panel.grid.major = element_line(color = "grey88", linewidth = 0.4),
        panel.grid.minor = element_blank(),
        axis.line = element_line(color = "grey55", linewidth = 0.5),
        legend.position = "bottom", legend.title = element_blank(),
        legend.text = element_text(size = 11), plot.margin = margin(8, 12, 6, 6))

guardar <- function(p, nombre) {
  dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(FIG_DIR, paste0(nombre, ".png"))
  ggsave(png_path, p, width = 5.4, height = 3.6, dpi = 300, bg = "white")
  message("  -> ", png_path)
  if (interactive()) print(p)
}

# --- lee todas las corridas y devuelve una matriz (filas=x, cols=corrida) ---
leer_matriz <- function(patron, columna) {
  files <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (!length(files)) return(NULL)
  lst <- lapply(files, function(f) read.csv(f)[[columna]])
  n   <- min(lengths(lst))                 # recorta a la longitud comun
  do.call(cbind, lapply(lst, function(v) v[seq_len(n)]))
}

# --- elige la corrida (mejor o mediana) por HV final -----------------
elegir_corrida <- function(files, modo) {
  finals <- vapply(files, function(f) max(read.csv(f)$best_so_far), numeric(1))
  if (modo == "mejor") which.max(finals)
  else                 order(finals)[ceiling(length(finals) / 2)]  # ejecucion mediana
}

# --- resumen (mediana + min/max) por fila (por x) --------------------
resumen_filas <- function(M) {
  data.frame(med = apply(M, 1, median),
             lo  = apply(M, 1, min),
             hi  = apply(M, 1, max))
}

# =====================================================================
# NSGA-II
# =====================================================================
if (is.na(SOLO) || SOLO == "NSGA") {
  patron <- sprintf("^conv_NSGA_%s_run.*\\.csv$", dataset)
  files  <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (length(files)) {
    x <- read.csv(files[1])$generation
    if (MODO == "agregado") {
      r  <- resumen_filas(leer_matriz(patron, "best_so_far"))
      df <- data.frame(x = x, r); sub <- sprintf("(mediana punto a punto, %d corridas)", length(files))
    } else {
      d  <- read.csv(files[[elegir_corrida(files, MODO)]])
      df <- data.frame(x = d$generation, med = d$best_so_far, lo = d$best_so_far, hi = d$best_so_far)
      sub <- if (MODO == "mejor") "(mejor corrida)" else "(corrida mediana)"
    }
    p <- ggplot(df, aes(x, med)) +
      geom_ribbon(aes(ymin = lo, ymax = hi), fill = NAVY, alpha = 0.15) +
      geom_line(color = NAVY, linewidth = 1.2, lineend = "round") +
      scale_y_continuous(limits = YLIM, breaks = seq(YLIM[1], YLIM[2], 1)) +
      labs(title = paste(dataset, "· NSGA-II", sub),
           x = "Generation", y = "Hypervolume") + tema_paper
    guardar(p, paste0("conv_NSGA_", dataset))
  }
}

# =====================================================================
# MOSA
# =====================================================================
if (is.na(SOLO) || SOLO == "MOSA") {
  patron <- sprintf("^conv_MOSA_%s_run.*\\.csv$", dataset)
  files  <- list.files(RESULTS_DIR, pattern = patron, full.names = TRUE)
  if (length(files)) {
    x <- read.csv(files[1])$iteration
    if (MODO == "agregado") {
      best <- data.frame(x = x, resumen_filas(leer_matriz(patron, "best_so_far")))
      cur  <- data.frame(x = x, resumen_filas(leer_matriz(patron, "current")))
      sub  <- sprintf("(mediana punto a punto, %d corridas)", length(files))
    } else {
      d    <- read.csv(files[[elegir_corrida(files, MODO)]])
      best <- data.frame(x = d$iteration, med = d$best_so_far, lo = d$best_so_far, hi = d$best_so_far)
      cur  <- data.frame(x = d$iteration, med = d$current,     lo = d$current,     hi = d$current)
      sub  <- if (MODO == "mejor") "(mejor corrida)" else "(corrida mediana)"
    }
    lineas <- rbind(
      data.frame(x = cur$x,  med = cur$med,  serie = "Current solution"),
      data.frame(x = best$x, med = best$med, serie = "Best-so-far"))
    lineas$serie <- factor(lineas$serie, levels = c("Current solution", "Best-so-far"))
    p <- ggplot() +
      geom_ribbon(data = cur,  aes(x, ymin = lo, ymax = hi), fill = LB,   alpha = 0.18) +
      geom_ribbon(data = best, aes(x, ymin = lo, ymax = hi), fill = NAVY, alpha = 0.15) +
      geom_line(data = lineas, aes(x, med, color = serie, linewidth = serie)) +
      scale_color_manual(values = c("Current solution" = LB, "Best-so-far" = NAVY)) +
      scale_linewidth_manual(values = c("Current solution" = 0.7, "Best-so-far" = 1.2)) +
      scale_y_continuous(limits = YLIM, breaks = seq(YLIM[1], YLIM[2], 1)) +
      labs(title = paste(dataset, "· MOSA", sub),
           x = "Iteration", y = "Hypervolume") + tema_paper +
      guides(linewidth = "none",
             color = guide_legend(override.aes = list(linewidth = 1.4)))
    guardar(p, paste0("conv_MOSA_", dataset))
  }
}
message("\nFiguras (PNG) guardadas en:\n  ", FIG_DIR)
