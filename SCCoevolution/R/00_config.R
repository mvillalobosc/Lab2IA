# =============================================================================
# 00_config.R
# -----------------------------------------------------------------------------
# EN: Global configuration. Paths, parameters and the shared plotting theme.
#     Every other script starts by sourcing this file, so no script contains a
#     hard-coded path or a magic number of its own.
# ES: Configuracion global. Rutas, parametros y el tema grafico compartido.
#     Todos los demas scripts parten cargando este archivo, asi ningun script
#     tiene rutas escritas a mano ni numeros magicos propios.
#
# EN: All paths are relative to the repository root. Run scripts from there:
#         Rscript run_all.R
#     The original scripts used relative paths like "f4.csv" and
#     "../BD/Secuencias_alineadas/", which only worked when R's working
#     directory happened to be the folder containing that particular script.
# ES: Todas las rutas son relativas a la raiz del repositorio. Correr los
#     scripts desde ahi. Los scripts originales usaban rutas como "f4.csv" y
#     "../BD/Secuencias_alineadas/", que solo funcionaban cuando el directorio
#     de trabajo de R era justo la carpeta de ese script en particular.
# =============================================================================

options(stringsAsFactors = FALSE)

.set_utf8_locale <- function() {
  for (loc in c("es_CL.UTF-8", "es_ES.UTF-8", "en_US.UTF-8", "C.UTF-8", "C.utf8")) {
    ok <- suppressWarnings(try(Sys.setlocale("LC_CTYPE", loc), silent = TRUE))
    if (!inherits(ok, "try-error") && nzchar(ok)) return(invisible(loc))
  }
  invisible(NA_character_)
}
.set_utf8_locale()

# -----------------------------------------------------------------------------
# 1. Paths
# -----------------------------------------------------------------------------

PATHS <- list(
  data       = "data",
  alignments    = file.path("data", "alignments"),
  alignments_db = file.path("data", "alignments_db"),
  trees      = "trees",
  figures    = file.path("outputs", "figures"),
  tables     = file.path("outputs", "tables"),
  logs       = file.path("outputs", "logs"),
  runs       = file.path("outputs", "runs")
)

for (p in PATHS) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

FILES <- list(
  solutions      = file.path(PATHS$data, "solutions.csv"),
  pareto         = file.path(PATHS$data, "pareto_fronts.csv"),
  hypervolume    = file.path(PATHS$data, "hypervolume.csv"),
  strains        = file.path(PATHS$data, "strain_metadata.csv"),
  manifest       = file.path(PATHS$data, "alignment_manifest.csv"),
  alignments_db  = PATHS$alignments_db
)

# -----------------------------------------------------------------------------
# 2. Parameters
# -----------------------------------------------------------------------------

PARAMS <- list(
  seed = 20250803L,

  # EN: The reference solution is the gene set from prior work that the Pareto
  #     front is compared against. Naming it here rather than assuming it is
  #     called "Sv" in fifteen places keeps the comparison explicit.
  # ES: La solucion de referencia es el conjunto de genes de trabajo previo
  #     contra el que se compara el frente de Pareto. Nombrarla aca en vez de
  #     asumir que se llama "Sv" en quince lugares deja explicita la comparacion.
  reference_solution = "SV",

  # Neighbour-joining trees
  distance_model = "hamming",

  # UpSet
  upset_n_intersections = 40L,

  # Figure size
  fig_width  = 10,
  fig_height = 7
)

# -----------------------------------------------------------------------------
# 2b. Optimiser settings
# -----------------------------------------------------------------------------
# EN: Every hyperparameter of the search lives here, not inside the algorithm
#     files. In the original code they were literals in the call at the bottom of
#     main.r and nsga2.r, in two places that disagreed with each other, so which
#     values produced a given result could not be recovered from the code.
#
#     The defaults reproduce the published configuration: 19 generations, a
#     population of 14, mutation rate 0.6, at most 22 genes per solution, and 31
#     independent runs.
# ES: Todo hiperparametro de la busqueda vive aca, no dentro de los archivos de
#     algoritmo. En el codigo original eran literales en la llamada al final de
#     main.r y nsga2.r, en dos lugares que no coincidian entre si, asi que no se
#     podia recuperar del codigo que valores produjeron un resultado dado.
#
#     Los valores por defecto reproducen la configuracion publicada.
# EN: OPT_QUICK=1 in the environment gives a fast smoke test of the whole
#     pipeline on a tiny configuration. Never use it for results.
# ES: OPT_QUICK=1 en el entorno da una prueba rapida de todo el pipeline con una
#     configuracion minima. Nunca usarlo para resultados.
.quick <- nzchar(Sys.getenv("OPT_QUICK"))

OPT <- list(
  n_runs        = if (.quick) 3L else 31L,   # independent repetitions per algorithm

  # --- shared ---
  min_genes     = 1L,
  max_genes     = if (.quick) 8L else 22L,
  mutation_rate = 0.6,

  # --- NSGA-II ---
  generations   = if (.quick) 3L else 19L,
  pop_size      = if (.quick) 6L else 14L,

  # --- MOSA ---
  # EN: outer_loops x inner_loops is the total number of proposed moves. It is
  #     set so MOSA evaluates a comparable number of candidate solutions to
  #     NSGA-II (generations x pop_size x 2), because a comparison between a
  #     method given 532 evaluations and one given 4 is not a comparison of
  #     methods. The original ran external_loops = 2, internal_loops = 2, that
  #     is four evaluations in total.
  # ES: outer_loops x inner_loops es el numero total de movimientos propuestos. Se
  #     fija para que MOSA evalue una cantidad de soluciones candidatas comparable
  #     a NSGA-II (generations x pop_size x 2), porque comparar un metodo al que
  #     se le dan 532 evaluaciones con otro al que se le dan 4 no es comparar
  #     metodos. El original corria external_loops = 2, internal_loops = 2, o sea
  #     cuatro evaluaciones en total.
  outer_loops   = if (.quick) 6L else 38L,
  inner_loops   = if (.quick) 3L else 14L,
  temperature   = 1000,
  alpha         = 0.8,

  # --- performance ---
  # Per-gene distance matrices cached in memory. Each is about 4 MB for 1011
  # taxa, so 150 entries is roughly 600 MB.
  cache_size    = 150L,

  # EN: Name of a solution in data/solutions.csv to seed the initial population
  #     with, or NULL for a random start. Overridden by the third command-line
  #     argument to 10_run_optimisation.R.
  # ES: Nombre de una solucion de data/solutions.csv con la que sembrar la
  #     poblacion inicial, o NULL para arranque aleatorio. Se sobrescribe con el
  #     tercer argumento de linea de comandos de 10_run_optimisation.R.
  seed_solution = NULL,

  # Reference point for hypervolume, in normalised objective space.
  hv_reference  = c(1.1, 1.1)
)

set.seed(PARAMS$seed)

# -----------------------------------------------------------------------------
# 3. Palette
# -----------------------------------------------------------------------------
# EN: One palette for the whole project. The original scripts each defined their
#     own colours inline, so the same algorithm appeared in a different colour
#     from one figure to the next.
# ES: Una sola paleta para todo el proyecto. Los scripts originales definian sus
#     colores por separado, asi que el mismo algoritmo aparecia de un color
#     distinto de una figura a otra.

COLOURS <- list(
  pareto     = "#66C2A5",
  reference  = "#DE2D26",
  mosa       = "#A6CEE3",
  nsga2      = "#66C2A5",
  bars_sets  = "#C36A77",
  bars_inter = "darkcyan",
  neutral    = "gray40"
)

ALGORITHM_COLOURS <- c("MOSA" = COLOURS$mosa, "NSGA-II" = COLOURS$nsga2)

theme_orf <- function(base_size = 16) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      legend.position = "none",
      plot.title      = ggplot2::element_text(hjust = 0.5, face = "plain"),
      axis.title      = ggplot2::element_text(face = "plain"),
      axis.text       = ggplot2::element_text(colour = "gray20")
    )
}

# -----------------------------------------------------------------------------
# 4. Dependencies
# -----------------------------------------------------------------------------

# EN: Packages every script needs. UpSetR and plotly are listed separately
#     because only one script each depends on them; a missing plotting package
#     should not stop the whole pipeline from running.
# ES: Paquetes que necesitan todos los scripts. UpSetR y plotly se listan aparte
#     porque solo un script depende de cada uno; que falte un paquete de graficos
#     no deberia impedir que corra todo el pipeline.
REQUIRED_PACKAGES <- c(
  "readr", "dplyr", "tidyr", "stringr", "ggplot2",
  "ape", "phangorn", "RColorBrewer"
)

OPTIONAL_PACKAGES <- c(
  UpSetR = "03_solution_overlap.R draws the UpSet plot with it; the overlap tables are still written without it",
  plotly = "01 and 02 export interactive HTML versions with it; the static PDF figures do not need it"
)

has_package <- function(pkg) requireNamespace(pkg, quietly = TRUE)

check_dependencies <- function(quiet = FALSE) {
  missing <- setdiff(REQUIRED_PACKAGES, rownames(utils::installed.packages()))
  if (length(missing) > 0) {
    stop("Missing R packages / Faltan paquetes de R:\n  ",
         paste(missing, collapse = ", "),
         "\n\nInstall with / Instala con:\n  install.packages(c(",
         paste0('"', missing, '"', collapse = ", "), "))", call. = FALSE)
  }
  if (!quiet) {
    message("[config] ", length(REQUIRED_PACKAGES), " required packages available.")
    absent <- names(OPTIONAL_PACKAGES)[!vapply(names(OPTIONAL_PACKAGES), has_package, logical(1))]
    for (p in absent) {
      message("[config] optional package '", p, "' not installed: ", OPTIONAL_PACKAGES[[p]])
    }
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# 5. Logging
# -----------------------------------------------------------------------------

log_msg <- function(...) {
  message(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

write_session_info <- function(step) {
  path <- file.path(PATHS$logs, paste0("sessionInfo_", step, ".txt"))
  con  <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(c(paste("Step:", step),
               paste("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
               paste("Seed:", PARAMS$seed), ""), con)
  utils::capture.output(utils::sessionInfo(), file = con)
  invisible(path)
}

save_figure <- function(plot, name, width = PARAMS$fig_width,
                        height = PARAMS$fig_height) {
  path <- file.path(PATHS$figures, paste0(name, ".pdf"))
  ok <- suppressWarnings(try(
    ggplot2::ggsave(path, plot, width = width, height = height,
                    device = grDevices::cairo_pdf), silent = TRUE))
  if (inherits(ok, "try-error")) {
    ggplot2::ggsave(path, plot, width = width, height = height)
  }
  invisible(path)
}
