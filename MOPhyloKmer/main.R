# =====================================================================
# main.R  ·  Punto de entrada unico
# ---------------------------------------------------------------------
# Edita el bloque CONFIG y ejecuta:   Rscript main.R
# Corre AMBOS algoritmos (NSGA-II y MOSA) sobre el dataset y genera los
# cuatro graficos: convergencia, fronteras y los dos arboles medoide.
# =====================================================================

# ============================ CONFIG =================================
DATASET <- "primates_14.phylip"   # archivo en data/
TIPO    <- "DNA"                  # "DNA" o "AA"
K       <- 5                      # longitud de k-mer
N_CORRIDAS <- 11                  # repeticiones
SEMILLA <- 123

# -- paralelismo: reparte las N corridas entre nucleos (gran aceleracion) --
PARALELO <- TRUE                  # si falla en Windows, ponlo en FALSE
N_CORES  <- max(1, parallel::detectCores() - 1)

# -- parametros NSGA-II --
POBLACION    <- 68
GENERACIONES <- 150
P_CROSS      <- 0.39
P_MUTA       <- 0.40

# -- parametros MOSA --
PARADA       <- 25
N_INTERNAS   <- 450
T0           <- 50
ALPHA        <- 0.01
P_MUTA_MOSA  <- 0.40

GRAFICAR <- TRUE                  # TRUE = generar los 4 graficos al terminar
# =====================================================================

# --- raiz del proyecto (variable PROPIA; los run scripts usan 'ROOT',
#     asi que aqui usamos APP para que no la sobreescriban al hacer source) ---
.md <- commandArgs(FALSE); .m <- grep("^--file=", .md)
APP <- if (length(.m)) dirname(normalizePath(sub("^--file=", "", .md[.m]))) else getwd()

DATA_DIR    <- file.path(APP, "data")
RESULTS_DIR <- file.path(APP, "results")
FIG_DIR     <- file.path(APP, "figures")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR,     recursive = TRUE, showWarnings = FALSE)

ds <- tools::file_path_sans_ext(DATASET)

# --- correr AMBOS algoritmos -----------------------------------------
message("\n===== NSGA-II =====")
source(file.path(APP, "NSGA-II", "run_nsga.R"))

message("\n===== MOSA =====")
source(file.path(APP, "SA", "run_sa.R"))

# --- los 4 graficos (en el mismo proceso; robusto en Windows) --------
if (isTRUE(GRAFICAR)) {
  message("\nGenerando figuras...")
  correr_plot <- function(archivo, etiqueta) {
    ok <- try(source(file.path(APP, "plots", archivo)), silent = TRUE)
    if (inherits(ok, "try-error"))
      message("  (", etiqueta, ") error: ", conditionMessage(attr(ok, "condition")))
  }
  correr_plot("plot_convergence.R", "convergencia")
  correr_plot("plot_fronts.R",      "fronteras")
  #correr_plot("plot_trees.R",       "arboles medoide")
}
