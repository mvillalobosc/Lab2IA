# =====================================================================
# run_nsga.R  ·  NSGA-II for alignment-free phylogenetic inference
# ---------------------------------------------------------------------
# Optimiza simultaneamente Least Squares (LS) y Minimum Evolution (ME)
# based on k-mer distance representations and Neighbour Joining.
#
# Mejoras respecto al original:
#   - relative paths (no hard-coded C:/Users/... paths),
#   - data set and parameters configurable in a single block,
#   - vectorised crossover and mutation,
#   - preallocated objective vectors (no growing with c()),
#   - hypervolume reset on every run,
#   - exports the per-generation convergence trace to results/ (CSV),
#   - commented code, no debugging leftovers.
#
# Usage:  Rscript algorithms/nsga2/run_nsga.R
# =====================================================================

# --- locate the script folder for robust relative paths ---
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

source(file.path(ROOT, "R", "packages.R"))
for (f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
  if (!grepl("packages\\.R$", f)) source(f)

# =====================================================================
# CONFIGURATION (edit here)
# =====================================================================
# default values; if main.R already defined them, they are kept.
def <- function(nombre, value) if (!exists(nombre, inherits = TRUE)) assign(nombre, value, envir = .GlobalEnv)
def("DATA_DIR",    file.path(PROJ, "data"))
def("RESULTS_DIR", file.path(PROJ, "results"))
def("DATASET",      "conrado_126.phylip")  # dataset a ejecutar
def("SEQ_TYPE",         "DNA")                  # "DNA" o "AA"
def("K",            5)                       # longitud de palabra k-mer
def("POP_SIZE",    68)                      # population size
def("N_GEN", 50)                      # number of generations
def("N_RUNS",   11)                      # repeticiones independientes
def("P_CROSS",      0.39)                    # ponderacion de crossover
def("P_MUT",       0.40)                    # probabilidad de mutation
def("SEED",      123)
def("VERBOSE",      TRUE)   # TRUE = imprime el paso en que va
def("PARALLEL",     FALSE)  # TRUE = run the N runs in parallel (multicore)
def("N_CORES",      max(1, parallel::detectCores() - 1))  # cores to use
def("EVERY_N",       5)     # record convergence metrics every N generations
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

# --- helper: build a phylo tree from a distance matrix -----
#     (replaces the NJ + cleanup block repeated four times in the original)
# index of the MEDOID of a set of points (smallest sum of distances)
# hypervolume + spread (Delta) + size of a normalised Nx2 front
front_metrics <- function(Pn) {
  Pn <- Pn[!duplicated(Pn), , drop = FALSE]
  hv <- round(computeHV(t(Pn), ref.point = c(2, 2)), 4)
  n  <- nrow(Pn)
  sp <- if (n < 3) NA_real_ else {
    o <- order(Pn[, 1]); Q <- Pn[o, , drop = FALSE]
    d <- sqrt(rowSums((Q[-1, , drop = FALSE] - Q[-n, , drop = FALSE])^2))
    dm <- mean(d); if (dm == 0) 0 else sum(abs(d - dm)) / (length(d) * dm)
  }
  c(hv = hv, spread = round(sp, 4), size = n)
}

medoid <- function(P) {
  if (nrow(P) <= 1) return(1L)
  which.min(rowSums(as.matrix(dist(P))))
}

tree_from_matrix <- function(dist_mat, dist_original) {
  a <- NJ(dist_mat)
  a$dist_kmer     <- dist_mat
  a$dist_original <- dist_original
  a$edge.length[a$edge.length < 0] <- 0
  a <- multi2di(a)
  midpoint(a)
}

# =====================================================================
# ONE RUN (encapsulated so it can be parallelised)
# ---------------------------------------------------------------------
# Executes one full run, writes its trace and tree to results/ and
# returns a one-row data frame with the summary. The seed depends
# on the run (SEED + run) => reproducible results, identical
# in serial or parallel mode.
# =====================================================================
progress_bar <- function(i, n, width_chars = 30) {
  done <- floor(width_chars * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", done), strrep(" ", width_chars - done),
          round(100 * i / n))
}

run_once_nsga <- function(run) {
  set.seed(SEED + run)
  show_progress <- isTRUE(VERBOSE) && !isTRUE(PARALLEL)
  t0 <- Sys.time()
  ds <- tools::file_path_sans_ext(DATASET)
  if (show_progress) cat(sprintf("\n-- Run %d/%d --\n", run, N_RUNS))

  # --- initial population -------------------------------------------
  sequences  <- read_sequences(file.path(DATA_DIR, DATASET), SEQ_TYPE)
  base_tree  <- build_base_tree(sequences, k = K)
  population   <- build_population(base_tree, POP_SIZE)
  puntajes    <- compute_scores(population)

  max_ls <- puntajes[[1]]$scores$ls * 10
  max_me <- puntajes[[1]]$scores$me * 10
  puntajesNorm <- compute_normalized_scores(puntajes, max_ls, max_me)

  me_ls  <- non_dominated_sort_cw(puntajesNorm)
  orden  <- order(me_ls$ranking, -me_ls$crowding2)
  matriz_original <- puntajesNorm[[1]]$dist_original

  # --- hypervolume of the initial front = GENERATION 0 -------------------------
  idx0 <- as.numeric(rownames(me_ls[me_ls$ranking == 1, ]))
  vec0 <- t(vapply(idx0, function(b)
    c(puntajesNorm[[b]]$scores$ls_norm, puntajesNorm[[b]]$scores$me_norm), numeric(2)))
  hv0  <- compute_hypervolume(vec0)

  hv_gen    <- numeric(N_GEN + 1)
  spread_g  <- numeric(N_GEN + 1)
  size_g    <- numeric(N_GEN + 1)
  m0 <- front_metrics(vec0)
  hv_gen[1] <- m0["hv"]; spread_g[1] <- m0["spread"]; size_g[1] <- m0["size"]

  for (generacion in seq_len(N_GEN)) {
    n <- length(puntajesNorm)
    Q <- vector("list", n)
    n_cross <- round(n * 0.4)
    n_muta  <- round(n * 0.4)

    for (i in seq_len(n_cross - 1)) {
      p1 <- tournament_selection(puntajesNorm, me_ls, orden)
      p2 <- tournament_selection(puntajesNorm, me_ls, orden)
      Q[[i]] <- tree_from_matrix(crossover(p1, p2, P_CROSS), matriz_original)
    }
    for (i in n_cross:(n_cross + n_muta - 1)) {
      Q[[i]] <- tree_from_matrix(mutation(P_MUT, puntajesNorm[[i]]), matriz_original)
    }
    for (i in (n_cross + n_muta):n) {
      Q[[i]] <- tree_from_matrix(generate_random_tree(puntajesNorm[[i]]), matriz_original)
    }
    Q <- Q[!vapply(Q, is.null, logical(1))]
    class(Q) <- "multiPhylo"

    puntajesQ     <- compute_scores(Q)
    puntajesNormQ <- compute_normalized_scores(puntajesQ, max_ls, max_me)
    unionPQ  <- rbind(puntajesNorm, puntajesNormQ)
    me_lsPQ  <- non_dominated_sort_cw(unionPQ)
    ordenPQ  <- order(me_lsPQ$ranking, -me_lsPQ$crowding2)

    mitad <- floor(length(ordenPQ) / 2)
    new_population <- vector("list", mitad)
    for (i in seq_len(mitad)) {
      new_population[[i]] <- tree_from_matrix(
        unionPQ[[ordenPQ[i]]]$dist_kmer, matriz_original)
    }
    class(new_population) <- "multiPhylo"

    frente <- me_lsPQ[me_lsPQ$ranking == 1, ]
    idx    <- as.numeric(rownames(frente))
    obj_values <- t(vapply(idx, function(b)
      c(unionPQ[[b]]$scores$ls_norm, unionPQ[[b]]$scores$me_norm), numeric(2)))
    mg <- front_metrics(obj_values)
    hv_gen[generacion + 1]   <- mg["hv"]
    spread_g[generacion + 1] <- mg["spread"]
    size_g[generacion + 1]   <- mg["size"]

    puntajes     <- compute_scores(new_population)
    puntajesNorm <- compute_normalized_scores(puntajes, max_ls, max_me)
    me_ls        <- non_dominated_sort_cw(puntajesNorm)
    orden        <- order(me_ls$ranking, -me_ls$crowding2)

    if (show_progress)
      cat(sprintf("\r   gen %3d/%d %s  HV=%.4f",
                  generacion, N_GEN, progress_bar(generacion, N_GEN),
                  max(hv_gen[seq_len(generacion + 1)])))
  }
  if (show_progress) cat("\n")

  best_so_far <- cummax(hv_gen)

  # --- final front + MEDOID tree (centre of the front) --------
  idxF <- which(me_ls$ranking == 1)
  Pn   <- as.matrix(me_ls[idxF, c("LSnorm", "MEnorm")])   # normalised objectives
  med  <- idxF[medoid(Pn)]
  write.csv(data.frame(ls = me_ls$LS[idxF], me = me_ls$ME[idxF]),
            file.path(RESULTS_DIR, sprintf("front_NSGA_%s_run%02d.csv", ds, run)),
            row.names = FALSE)
  medoid_tree <- new_population[[med]]
  if (is.null(medoid_tree$tip.label))
    medoid_tree$tip.label <- rownames(matriz_original)
  write.tree(medoid_tree,
             file.path(RESULTS_DIR, sprintf("medoid_NSGA_%s_run%02d.nwk", ds, run)))
  gens <- 0:N_GEN
  keep <- gens == 0L | gens == N_GEN | (gens %% EVERY_N == 0L)
  write.csv(
    data.frame(generation = gens[keep], hypervolume = hv_gen[keep],
               best_so_far = best_so_far[keep], spread = spread_g[keep],
               front_size = size_g[keep]),
    file.path(RESULTS_DIR, sprintf("conv_NSGA_%s_run%02d.csv", ds, run)),
    row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(run = run, hv_max = max(hv_gen), seconds = seg)
}

# =====================================================================
# DISPATCH: serial or parallel (at the run level)
# =====================================================================
# TUNE_ONLY=TRUE => only define the functions (irace uses them without running the batch)
if (!isTRUE(get0("TUNE_ONLY", envir = globalenv(), ifnotfound = FALSE))) {
if (isTRUE(VERBOSE))
  cat(sprintf("\n==== NSGA-II | %s | %d runs | %d generations | %s ====\n",
              DATASET, N_RUNS, N_GEN,
              if (isTRUE(PARALLEL)) sprintf("PARALLEL x%d cores", min(N_CORES, N_RUNS)) else "serial"))

if (isTRUE(PARALLEL)) {
  library(parallel)
  ncores <- min(N_CORES, N_RUNS)
  cl <- makeCluster(ncores)
  on.exit(try(stopCluster(cl), silent = TRUE), add = TRUE)
  # export config and helpers to each worker, then load the modules
  clusterExport(cl, c("ROOT", "DATA_DIR", "RESULTS_DIR", "DATASET", "SEQ_TYPE", "K", "EVERY_N",
                      "POP_SIZE", "N_GEN", "P_CROSS", "P_MUT", "SEED",
                      "N_RUNS", "VERBOSE", "PARALLEL",
                      "tree_from_matrix", "medoid", "front_metrics", "progress_bar", "run_once_nsga"),
                envir = environment())
  clusterEvalQ(cl, {
    source(file.path(ROOT, "R", "packages.R"))
    for (.f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
      if (!grepl("packages\\.R$", .f)) source(.f)
    TRUE
  })
  res <- parLapply(cl, seq_len(N_RUNS), run_once_nsga)
  stopCluster(cl)
} else {
  res <- lapply(seq_len(N_RUNS), run_once_nsga)
}

summary_df <- do.call(rbind, res)

# --- keep ONLY the medoid and the front of the BEST run ---
ds <- tools::file_path_sans_ext(DATASET)
best <- summary_df$run[which.max(summary_df$hv_max)]
file.copy(file.path(RESULTS_DIR, sprintf("medoid_NSGA_%s_run%02d.nwk", ds, best)),
          file.path(RESULTS_DIR, sprintf("medoid_NSGA_%s.nwk", ds)), overwrite = TRUE)
file.copy(file.path(RESULTS_DIR, sprintf("front_NSGA_%s_run%02d.csv", ds, best)),
          file.path(RESULTS_DIR, sprintf("front_NSGA_%s.csv", ds)), overwrite = TRUE)
unlink(list.files(RESULTS_DIR, pattern = sprintf("^medoid_NSGA_%s_run.*\\.nwk$", ds), full.names = TRUE))
unlink(list.files(RESULTS_DIR, pattern = sprintf("^front_NSGA_%s_run.*\\.csv$", ds), full.names = TRUE))
for (i in seq_len(nrow(summary_df)))
  message(sprintf("Run %2d/%d  HVmax=%.4f  %.1fs",
                  summary_df$run[i], N_RUNS, summary_df$hv_max[i], summary_df$seconds[i]))

write.csv(summary_df,
          file.path(RESULTS_DIR,
                    sprintf("resumen_NSGA_%s.csv", tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Done. Traces and summary in: ", RESULTS_DIR)
}  # end of the TUNE_ONLY guard
