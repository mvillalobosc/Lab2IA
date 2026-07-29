# =====================================================================
# run_mosa.R  ·  Multi-Objective Simulated Annealing (MOSA) for
#              alignment-free phylogenetic inference
# ---------------------------------------------------------------------
# Optimises the hypervolume (aggregating LS and ME) of a single tree that is
# perturbs and accepts using the Metropolis criterion with cooling.
#
# Mejoras respecto al original:
#   - relative paths, configurable data set and parameters,
#   - fixed $score -> $scores (it relied on R partial matching),
#   - preallocated results matrix (no incremental rbind),
#   - exports the per-iteration convergence trace (iteration, current score,
#     best-so-far) to results/ as CSV,
#   - commented, no debugging leftovers.
#
# Uso:  Rscript algorithms/mosa/run_mosa.R
# =====================================================================

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
def("DATASET",     "primates_14.phylip")
def("SEQ_TYPE",        "DNA")
def("K",           5)
def("N_INNER",  100)    # iteraciones por nivel de temperatura (equilibrio)
def("N_OUTER",      75)     # temperature levels (stopping criterion)
def("T0",          5000)   # temperatura inicial
def("ALPHA",       0.69)   # factor de enfriamiento geometrico
def("EVERY_N",      5)      # registrar metricas de convergencia cada N ciclos externos
def("N_RUNS",  11)
def("SEED",     123)
def("VERBOSE",     TRUE)   # TRUE = imprime el paso en que va
def("PARALLEL",    FALSE)  # TRUE = run the N runs in parallel (multicore)
def("N_CORES",     max(1, parallel::detectCores() - 1))
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

# =====================================================================
# ONE RUN (encapsulated so it can be parallelised)
# =====================================================================
progress_bar <- function(i, n, width_chars = 30) {
  done <- floor(width_chars * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", done), strrep(" ", width_chars - done),
          round(100 * i / n))
}

medoid <- function(P) {
  if (nrow(P) <= 1) return(1L)
  which.min(rowSums(as.matrix(dist(P))))
}
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

run_once_mosa <- function(run) {
  set.seed(SEED + run)
  show_progress <- isTRUE(VERBOSE) && !isTRUE(PARALLEL)
  t0 <- Sys.time()
  ds <- tools::file_path_sans_ext(DATASET)
  if (show_progress) cat(sprintf("\n-- Run %d/%d --\n", run, N_RUNS))

  # --- initial solution --------------------------------------------
  sequences <- read_sequences(file.path(DATA_DIR, DATASET), SEQ_TYPE)
  base_tree <- build_base_tree(sequences, k = K)
  base_tree <- compute_objectives(base_tree)
  max_ls <- base_tree$scores$ls * 10
  max_me <- base_tree$scores$me * 10
  base_tree <- compute_normalized_objectives(base_tree, max_ls, max_me)
  base_tree <- compute_hypervolume(base_tree)

  best_tree    <- base_tree
  current_tree <- base_tree

  total <- N_OUTER * N_INNER
  Temp  <- T0
  # recorded per outer cycle (every EVERY_N): current, best and archive metrics
  rec_it <- integer(0); rec_cur <- numeric(0); rec_best <- numeric(0)
  rec_hv <- numeric(0); rec_sp <- numeric(0); rec_sz <- numeric(0)

  # non-dominated archive (used for the front and the medoid tree)
  arch_ls <- base_tree$scores$ls
  arch_me <- base_tree$scores$me
  arch_tr <- list(base_tree)

  for (a in seq_len(N_OUTER)) {
    for (b in seq_len(N_INNER)) {
      candidate_tree <- perturb_tree(current_tree)
      candidate_tree <- compute_objectives(candidate_tree)
      candidate_tree <- compute_normalized_objectives(candidate_tree, max_ls, max_me)
      candidate_tree <- compute_hypervolume(candidate_tree)

      # update the non-dominated archive (minimiza LS y ME)
      nl <- candidate_tree$scores$ls; nm <- candidate_tree$scores$me
      if (!any(arch_ls <= nl & arch_me <= nm & (arch_ls < nl | arch_me < nm))) {
        keep <- !(nl <= arch_ls & nm <= arch_me & (nl < arch_ls | nm < arch_me))
        arch_ls <- c(arch_ls[keep], nl)
        arch_me <- c(arch_me[keep], nm)
        arch_tr <- c(arch_tr[keep], list(candidate_tree))
      }

      deltaE <- current_tree$scores$hyp - candidate_tree$scores$hyp
      if (candidate_tree$scores$hyp > best_tree$scores$hyp) best_tree <- candidate_tree

      if (deltaE <= 0) {
        current_tree <- candidate_tree
      } else if (runif(1) < exp(-deltaE / Temp)) {
        current_tree <- candidate_tree
      }
    }
    Temp <- Temp * ALPHA
    # record at the end of the outer cycle, every EVERY_N (plus first and last)
    if (a == 1L || a == N_OUTER || a %% EVERY_N == 0L) {
      m <- front_metrics(cbind(arch_ls / max_ls, arch_me / max_me))
      rec_it   <- c(rec_it, a * N_INNER)
      rec_cur  <- c(rec_cur, current_tree$scores$hyp)
      rec_best <- c(rec_best, best_tree$scores$hyp)
      rec_hv   <- c(rec_hv, m["hv"]); rec_sp <- c(rec_sp, m["spread"]); rec_sz <- c(rec_sz, m["size"])
    }
    if (show_progress)
      cat(sprintf("\r   nivel %3d/%d %s  T=%7.1f  BEST=%.4f",
                  a, N_OUTER, progress_bar(a, N_OUTER), Temp, best_tree$scores$hyp))
  }
  if (show_progress) cat("\n")

  # --- front + MEDOID tree of that front -----------------------
  Pn  <- cbind(arch_ls / max_ls, arch_me / max_me)   # normalised objectives
  med <- medoid(Pn)
  write.csv(data.frame(ls = arch_ls, me = arch_me),
            file.path(RESULTS_DIR, sprintf("front_MOSA_%s_run%02d.csv", ds, run)),
            row.names = FALSE)
  medoid_tree <- arch_tr[[med]]
  if (is.null(medoid_tree$tip.label))
    medoid_tree$tip.label <- rownames(base_tree$dist_kmer)
  write.tree(medoid_tree,
             file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s_run%02d.nwk", ds, run)))
  write.csv(
    data.frame(iteration = rec_it, current = rec_cur, best_so_far = cummax(rec_best),
               hypervolume = rec_hv, spread = rec_sp, front_size = rec_sz),
    file.path(RESULTS_DIR, sprintf("conv_MOSA_%s_run%02d.csv", ds, run)),
    row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(run = run, hv_best = best_tree$scores$hyp, seconds = seg)
}

# =====================================================================
# DISPATCH: serial or parallel (at the run level)
# =====================================================================
# TUNE_ONLY=TRUE => only define the functions (irace uses them without running the batch)
if (!isTRUE(get0("TUNE_ONLY", envir = globalenv(), ifnotfound = FALSE))) {
if (isTRUE(VERBOSE))
  cat(sprintf("\n==== MOSA | %s | %d runs | %d levels x %d iter | %s ====\n",
              DATASET, N_RUNS, N_OUTER, N_INNER,
              if (isTRUE(PARALLEL)) sprintf("PARALLEL x%d cores", min(N_CORES, N_RUNS)) else "serial"))

if (isTRUE(PARALLEL)) {
  library(parallel)
  ncores <- min(N_CORES, N_RUNS)
  cl <- makeCluster(ncores)
  on.exit(try(stopCluster(cl), silent = TRUE), add = TRUE)
  clusterExport(cl, c("ROOT", "DATA_DIR", "RESULTS_DIR", "DATASET", "SEQ_TYPE", "K", "EVERY_N",
                      "N_INNER", "N_OUTER", "T0", "ALPHA", "SEED",
                      "N_RUNS", "VERBOSE", "PARALLEL", "progress_bar", "medoid", "front_metrics", "run_once_mosa"),
                envir = environment())
  clusterEvalQ(cl, {
    source(file.path(ROOT, "R", "packages.R"))
    for (.f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
      if (!grepl("packages\\.R$", .f)) source(.f)
    TRUE
  })
  res <- parLapply(cl, seq_len(N_RUNS), run_once_mosa)
  stopCluster(cl)
} else {
  res <- lapply(seq_len(N_RUNS), run_once_mosa)
}

summary_df <- do.call(rbind, res)

# --- keep ONLY the medoid and the front of the BEST run ---
ds <- tools::file_path_sans_ext(DATASET)
best <- summary_df$run[which.max(summary_df$hv_best)]
file.copy(file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s_run%02d.nwk", ds, best)),
          file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s.nwk", ds)), overwrite = TRUE)
file.copy(file.path(RESULTS_DIR, sprintf("front_MOSA_%s_run%02d.csv", ds, best)),
          file.path(RESULTS_DIR, sprintf("front_MOSA_%s.csv", ds)), overwrite = TRUE)
unlink(list.files(RESULTS_DIR, pattern = sprintf("^medoid_MOSA_%s_run.*\\.nwk$", ds), full.names = TRUE))
unlink(list.files(RESULTS_DIR, pattern = sprintf("^front_MOSA_%s_run.*\\.csv$", ds), full.names = TRUE))
for (i in seq_len(nrow(summary_df)))
  message(sprintf("Run %2d/%d  HVbest=%.4f  %.1fs",
                  summary_df$run[i], N_RUNS, summary_df$hv_best[i], summary_df$seconds[i]))

write.csv(summary_df,
          file.path(RESULTS_DIR,
                    sprintf("resumen_MOSA_%s.csv", tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Done. Traces and summary in: ", RESULTS_DIR)
}  # end of the TUNE_ONLY guard
