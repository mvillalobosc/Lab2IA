# =====================================================================
# config.R  ·  Central configuration for the whole pipeline
# ---------------------------------------------------------------------
# Edit ONLY this file. It is read by main.R, run_experiments.R,
# run_random_search.R and the scripts in tuning/.
# =====================================================================

# ============ SINGLE DATA SET (main.R) ===============================
DATASET    <- "primates_14.phylip"   # data set used by main.R
MAKE_PLOTS <- TRUE                   # make the figures when main.R finishes

# ============ FULL EXPERIMENT (run_experiments.R) ====================
DATASETS <- c("primates_14.phylip", "conrado_126.phylip", "hasegawa.phylip",
              "HIV1_192.phylip", "HIV2_72.phylip", "membracidae1_81.phylip",
              "mtDNA_186.phylip", "rbcL_55.phylip", "RDPII_218.phylip",
              "RIM15.phylip", "S1482_346.phylip", "YDR385W_menos.phylip",
              "ZILLA_500.phylip")

N_RUNS         <- 11        # independent runs per method and data set
SEQ_TYPE       <- "DNA"     # "DNA" or "AA"
K              <- 5         # k-mer word length
SEED           <- 123       # base seed (each run uses SEED + run index)
PARALLEL       <- TRUE      # distribute the runs across cores
N_CORES        <- max(1, parallel::detectCores() - 1)
RUN_ALGORITHMS <- TRUE      # TRUE runs the algorithms; FALSE only rebuilds the table
EVERY_N        <- 5         # record convergence metrics every N generations or cycles

# ============ ALGORITHM PARAMETERS ===================================
# Values below come from the irace tuning. After a new tuning, paste the
# contents of tuning/best_nsga.csv and tuning/best_mosa.csv here.

# NSGA-II            POP_SIZE x N_GEN = 10,044 evaluations
POP_SIZE <- 93              # population size
N_GEN    <- 108             # number of generations
P_CROSS  <- 0.9942          # crossover probability
P_MUT    <- 0.414           # mutation probability

# MOSA               N_INNER x N_OUTER = 9,996 evaluations
N_INNER <- 98               # inner iterations per temperature level
N_OUTER <- 102              # temperature levels (stopping criterion)
T0      <- 2974.567         # initial temperature
ALPHA   <- 0.5939           # geometric cooling factor

# Random Search      POP_RS x GEN_RS = 10,044 evaluations
POP_RS <- 93                # candidates per generation
GEN_RS <- 108               # number of generations

# ============ IRACE TUNING (tuning/) =================================
BUDGET     <- 10000   # fixed evaluations per configuration during tuning
HOURS_NSGA <- 3       # time budget for the NSGA-II tuning, in hours
HOURS_MOSA <- 3       # time budget for the MOSA tuning, in hours
N_PAR      <- 1       # cores used by irace (raise it if your system allows)
INSTANCES  <- c("primates_14.phylip",   # 14 taxa
                "rbcL_55.phylip",       # 55 taxa
                "conrado_126.phylip",   # 126 taxa
                "mtDNA_186.phylip")     # 186 taxa
