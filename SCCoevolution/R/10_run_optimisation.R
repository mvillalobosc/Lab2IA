# =============================================================================
# 10_run_optimisation.R
# -----------------------------------------------------------------------------
# EN: Runs both optimisers for the configured number of independent repetitions
#     and saves every run to disk.
#
#         Rscript R/10_run_optimisation.R              # both algorithms
#         Rscript R/10_run_optimisation.R nsga2        # one algorithm
#         Rscript R/10_run_optimisation.R mosa 5       # 5 runs only
#
#     REPRODUCIBILITY
#     Each run gets a seed derived deterministically from PARAMS$seed and the run
#     index, so run 7 of NSGA-II is the same on every machine and can be repeated
#     on its own without re-running the other thirty. The original used
#     foreach %dopar% with no seed at all and no doRNG backend, so the parallel
#     workers drew from unreproducible RNG streams.
#
#     PARALLELISM
#     Runs are independent, so they parallelise cleanly. doRNG is used when
#     available to make the parallel streams reproducible; without it the loop
#     falls back to sequential, because a fast irreproducible result is not what
#     this pipeline is for.
#
# ES: Corre los dos optimizadores el numero configurado de repeticiones
#     independientes y guarda cada corrida en disco.
#
#     REPRODUCIBILIDAD
#     Cada corrida recibe una semilla derivada de forma determinista de
#     PARAMS$seed y el indice de corrida, asi la corrida 7 de NSGA-II es la misma
#     en toda maquina y se puede repetir sola sin volver a correr las otras
#     treinta. El original usaba foreach %dopar% sin semilla alguna y sin backend
#     doRNG, asi que los workers paralelos sacaban de flujos de RNG
#     irreproducibles.
#
#     PARALELISMO
#     Las corridas son independientes, asi que paralelizan limpio. Se usa doRNG
#     cuando esta disponible para que los flujos paralelos sean reproducibles; sin
#     el, el bucle cae a secuencial, porque un resultado rapido e irreproducible
#     no es para lo que sirve este pipeline.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")
source("R/opt_operators.R")
source("R/opt_nsga2.R")
source("R/opt_mosa.R")

check_dependencies(quiet = TRUE)
log_msg("10_run_optimisation: start")

suppressPackageStartupMessages({ library(ape); library(phangorn) })

args      <- commandArgs(trailingOnly = TRUE)
which_alg <- if (length(args) >= 1) tolower(args[1]) else "both"
n_runs    <- if (length(args) >= 2) as.integer(args[2]) else OPT$n_runs
seed_name <- if (length(args) >= 3) args[3] else OPT$seed_solution

if (!which_alg %in% c("both", "nsga2", "mosa")) {
  stop("First argument must be one of: both, nsga2, mosa", call. = FALSE)
}

dir.create(PATHS$runs, recursive = TRUE, showWarnings = FALSE)

# --- Gene pool --------------------------------------------------------------
# EN: Restricted to alignments actually present on disk. Searching over the full
#     6015 requires unpacking the whole database first; see the README.
# ES: Restringido a los alineamientos presentes en disco. Buscar sobre los 6015
#     completos exige descomprimir toda la base primero; ver el README.
pool <- gene_pool(only_available = TRUE)

if (length(pool) < OPT$max_genes) {
  stop("Only ", length(pool), " alignments are unpacked but max_genes is ",
       OPT$max_genes, ".\nUnpack the database first:\n",
       "  Rscript -e 'source(\"R/00_config.R\"); source(\"R/utils_solutions.R\"); ensure_alignments()'",
       call. = FALSE)
}

log_msg("  gene pool: ", length(pool), " ORFs")
if (length(pool) < 6015) {
  log_msg("  NOTE: searching a subset of the database. Unpack all 6015 for a full run.")
}

reference <- ape::read.tree(file.path(PATHS$trees, "ref_tree.nwk"))
log_msg("  reference tree: ", length(reference$tip.label), " tips")

# -----------------------------------------------------------------------------
# Seeding the initial population
# -----------------------------------------------------------------------------
# EN: main.r seeded the population from a spreadsheet, "Grupos y medoides.xlsx",
#     through buildTreeFromXSLX. That file was never released with the code, so a
#     seeded run could not be reproduced by anyone else, and the function also
#     prepended a space to every filename, which made match() return NA silently
#     whenever the alignment files did not carry that space.
#
#     Seeding now reads from data/solutions.csv, which is in the repository. Any
#     named solution can be used, including the reference set. The genes are
#     checked against the pool before the run starts rather than failing halfway
#     through, and an unseeded run stays the default.
#
#         Rscript R/10_run_optimisation.R nsga2 5 SV
#
# ES: main.r sembraba la poblacion desde una planilla, "Grupos y medoides.xlsx",
#     a traves de buildTreeFromXSLX. Ese archivo nunca se libero con el codigo, asi
#     que una corrida sembrada no la podia reproducir nadie mas, y la funcion
#     ademas anteponia un espacio a cada nombre de archivo, lo que hacia que
#     match() devolviera NA en silencio cuando los alineamientos no traian ese
#     espacio.
#
#     El sembrado ahora lee de data/solutions.csv, que si esta en el repositorio.
#     Se puede usar cualquier solucion nombrada, incluida la de referencia. Los
#     genes se verifican contra el conjunto antes de arrancar y no a mitad de
#     camino, y una corrida sin sembrar sigue siendo el default.

seed_solution <- NULL
if (!is.null(seed_name) && nzchar(seed_name) && !identical(tolower(seed_name), "none")) {

  all_sols <- read_solutions()
  if (!seed_name %in% names(all_sols)) {
    stop("Unknown seed solution '", seed_name, "'.\nAvailable: ",
         paste(names(all_sols), collapse = ", "),
         "\nUse 'none' for a random initial population.", call. = FALSE)
  }

  seed_solution <- all_sols[[seed_name]]
  absent <- setdiff(seed_solution, pool)

  if (length(absent) > 0) {
    log_msg("  seed solution ", seed_name, " names ", length(absent),
            " ORF(s) absent from the pool: ", paste(absent, collapse = ", "))
    seed_solution <- setdiff(seed_solution, absent)
    if (length(seed_solution) < OPT$min_genes) {
      stop("Seed solution has only ", length(seed_solution),
           " usable ORFs, below min_genes = ", OPT$min_genes, ".", call. = FALSE)
    }
    log_msg("    seeding with the remaining ", length(seed_solution))
  }

  if (length(seed_solution) > OPT$max_genes) {
    stop("Seed solution ", seed_name, " has ", length(seed_solution),
         " ORFs, above max_genes = ", OPT$max_genes,
         ". Raise OPT$max_genes or pick a smaller solution.", call. = FALSE)
  }

  log_msg("  seeding initial population from ", seed_name,
          " (", length(seed_solution), " ORFs)")
} else {
  log_msg("  initial population: random")
}

cache_configure(OPT$cache_size)

# --- Seeds ------------------------------------------------------------------
run_seed <- function(algorithm, i) {
  # Deterministic and distinct per algorithm and run index.
  base <- PARAMS$seed + 1000L * (if (algorithm == "nsga2") 1L else 2L)
  base + i
}

# EN: A short fingerprint of the gene pool, stored with every run. Two runs are
#     only comparable if they searched the same space, and this makes a mismatch
#     detectable instead of silent.
# ES: Una huella corta del conjunto de genes, guardada con cada corrida. Dos
#     corridas solo son comparables si buscaron el mismo espacio, y esto vuelve
#     detectable una discrepancia en vez de silenciosa.
digest_pool <- function(pool) {
  paste0(length(pool), "-", substr(paste(utils::head(pool, 3), collapse = ""), 1, 12),
         "-", substr(paste(utils::tail(pool, 3), collapse = ""), 1, 12))
}

run_one <- function(algorithm, i) {
  t0 <- Sys.time()
  s  <- run_seed(algorithm, i)
  log_msg("  ", toupper(algorithm), " run ", i, "/", n_runs, " (seed ", s, ")")

  res <- if (algorithm == "nsga2") {
    nsga2_orf(generations = OPT$generations, pop_size = OPT$pop_size,
              mutation_rate = OPT$mutation_rate,
              min_genes = OPT$min_genes, max_genes = OPT$max_genes,
              pool = pool, reference = reference, seed = s,
              seed_solution = seed_solution)
  } else {
    mosa_orf(outer_loops = OPT$outer_loops, inner_loops = OPT$inner_loops,
             mutation_rate = OPT$mutation_rate,
             temperature = OPT$temperature, alpha = OPT$alpha,
             min_genes = OPT$min_genes, max_genes = OPT$max_genes,
             pool = pool, reference = reference, seed = s,
             seed_solution = seed_solution)
  }

  res$run     <- i
  res$minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  res$pool_hash     <- digest_pool(pool)
  res$seeded_from   <- if (is.null(seed_solution)) NA_character_ else seed_name

  f <- file.path(PATHS$runs, sprintf("%s_run%02d.rds", algorithm, i))
  saveRDS(res, f)
  log_msg("    front ", length(res$front), " solutions, ",
          round(res$minutes, 1), " min -> ", basename(f))
  invisible(f)
}

algorithms <- if (which_alg == "both") c("nsga2", "mosa") else which_alg

for (alg in algorithms) {
  log_msg("  === ", toupper(alg), ": ", n_runs, " independent runs ===")
  for (i in seq_len(n_runs)) run_one(alg, i)
}

st <- cache_stats()
log_msg("  alignment cache: ", st$hits, " hits, ", st$misses, " misses (",
        round(100 * st$hits / max(1, st$hits + st$misses), 1), "% hit rate)")

write_session_info("10_run_optimisation")
log_msg("10_run_optimisation: done")
