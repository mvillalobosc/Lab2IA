# =====================================================================
# main.R  ·  Punto de entrada unico
# ---------------------------------------------------------------------
# Edita el bloque CONFIG y ejecuta:   Rscript main.R
# Corre un caso (un algoritmo sobre un dataset) y, opcionalmente,
# genera las figuras de convergencia y de arboles.
# =====================================================================

# ============================ CONFIG =================================
ALGO    <- "MOSA"                 # "NSGA"  o  "MOSA"
DATASET <- "primates_14.phylip"   # archivo en data/
TIPO    <- "DNA"                  # "DNA" o "AA"
K       <- 5                      # longitud de k-mer
N_CORRIDAS <- 11                  # repeticiones
SEMILLA <- 123

# -- paralelismo: reparte las N corridas entre nucleos (gran aceleracion) --
PARALELO <- TRUE                  # si falla en Windows, ponlo en FALSE
N_CORES  <- max(1, parallel::detectCores() - 1)

# -- parámetros NSGA-II --
POBLACION   <- 68
GENERACIONES <- 50
P_CROSS     <- 0.39
P_MUTA      <- 0.40

# 68 evaluaciones iniciales + 68 * 50 descendientes
MAX_EVAL <- POBLACION * (GENERACIONES + 1L)  # 3468

# -- parámetros MOSA --
PARADA      <- 250
N_INTERNAS  <- 339
T0          <- 50
ALPHA       <- 0.01
P_MUTA_MOSA <- 0.40

GRAFICAR <- TRUE                  # TRUE = generar figuras al terminar
# =====================================================================

# --- raiz del proyecto (variable PROPIA; los run scripts usan 'ROOT',
#     asi que aqui usamos APP para que no la sobreescriban al hacer source) ---
.md <- commandArgs(FALSE); .m <- grep("^--file=", .md)
APP <- if (length(.m)) dirname(normalizePath(sub("^--file=", "", .md[.m]))) else getwd()

# directorios absolutos y fiables (se pasan a los run/plot scripts)
DATA_DIR    <- file.path(APP, "data")
RESULTS_DIR <- file.path(APP, "results")
FIG_DIR     <- file.path(APP, "figures")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR,     recursive = TRUE, showWarnings = FALSE)

ds <- tools::file_path_sans_ext(DATASET)

# --- ejecutar el algoritmo elegido -----------------------------------
if (ALGO == "NSGA") {
  source(file.path(APP, "NSGA-II", "run_nsga.R"))
} else if (ALGO == "MOSA") {
  source(file.path(APP, "SA", "run_sa.R"))
} else {
  stop("ALGO debe ser 'NSGA' o 'MOSA'.")
}

# --- figuras (opcional) ----------------------------------------------
# En el mismo proceso (source), no con system2/Rscript, para que
# funcione aunque Rscript no este en el PATH (tipico en Windows).
if (isTRUE(GRAFICAR)) {
  message("\nGenerando figuras...")
  ok1 <- try(source(file.path(APP, "plots", "plot_convergence.R")), silent = TRUE)
  if (inherits(ok1, "try-error"))
    message("  (convergencia) error: ", conditionMessage(attr(ok1, "condition")))
  ok2 <- try(source(file.path(APP, "plots", "plot_trees.R")), silent = TRUE)
  if (inherits(ok2, "try-error"))
    message("  (arboles) error: ", conditionMessage(attr(ok2, "condition")))
}
