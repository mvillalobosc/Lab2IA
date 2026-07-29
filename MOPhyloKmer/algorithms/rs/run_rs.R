# =====================================================================
# run_rs.R  ·  Random Search baseline for phylogenetic inference
# ---------------------------------------------------------------------
# Minimal baseline: each generation draws POP_RS candidates by MUTATION
# from MOSA (perturb_tree) starting from the base tree, no selection, no crossover.
# It keeps an archive of non-dominated solutions and reports the hypervolume of
# the cumulative front per generation (comparable with NSGA-II and MOSA).
# It reuses the MOSA modules and writes to results/ in the same format.
#
# Parameters (in config.R):  POP_RS, GEN_RS   (evaluations = POP_RS * GEN_RS)
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
MOSA_R <- file.path(PROJ, "algorithms", "mosa", "R")   # reutiliza los modulos de MOSA
source(file.path(MOSA_R, "packages.R"))
for (.f in list.files(MOSA_R, pattern = "\\.R$", full.names = TRUE))
  if (!grepl("packages\\.R$", .f)) source(.f)

# --- defaults (values already set by config.R or main.R are kept) ------------------
def <- function(nombre, value) if (!exists(nombre, inherits = TRUE)) assign(nombre, value, envir = .GlobalEnv)
def("DATA_DIR",    file.path(PROJ, "data"))
def("RESULTS_DIR", file.path(PROJ, "results"))
def("DATASET",     "primates_14.phylip")
def("SEQ_TYPE",        "DNA")
def("K",           5)
def("POP_RS",      93)     # population size (candidates per generation)
def("GEN_RS",      108)    # number of generations
def("N_RUNS",  11)
def("SEED",     123)
def("VERBOSE",     TRUE)
def("PARALLEL",    FALSE)
def("N_CORES",     max(1, parallel::detectCores() - 1))
def("EVERY_N",      5)     # record convergence metrics every N generations
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

# =====================================================================
# ONE RUN
# =====================================================================
progress_bar <- function(i, n, width_chars = 30) {
  done <- floor(width_chars * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", done), strrep(" ", width_chars - done), round(100 * i / n))
}
medoid <- function(P) { if (nrow(P) <= 1) return(1L); which.min(rowSums(as.matrix(dist(P)))) }
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
# non-dominated front (both objectives minimised) of an Nx2 matrix
non_dominated <- function(P) {
  which(!vapply(seq_len(nrow(P)), function(i)
    any(P[, 1] <= P[i, 1] & P[, 2] <= P[i, 2] & (P[, 1] < P[i, 1] | P[, 2] < P[i, 2])),
    logical(1)))
}

run_once_rs <- function(run) {
  set.seed(SEED + run)
  show_progress <- isTRUE(VERBOSE) && !isTRUE(PARALLEL)
  t0 <- Sys.time()
  ds <- tools::file_path_sans_ext(DATASET)
  if (show_progress) cat(sprintf("\n-- Run %d/%d --\n", run, N_RUNS))

  sequences <- read_sequences(file.path(DATA_DIR, DATASET), SEQ_TYPE)
  base_tree <- build_base_tree(sequences, k = K)
  base_tree <- compute_objectives(base_tree)
  max_ls <- base_tree$scores$ls * 10
  max_me <- base_tree$scores$me * 10

  # non-dominated archive (cumulative front) with its trees
  arch_ls <- base_tree$scores$ls
  arch_me <- base_tree$scores$me
  arch_tr <- list(base_tree)

  hv_gen <- numeric(GEN_RS)
  spread_g <- numeric(GEN_RS)
  size_g <- numeric(GEN_RS)
  for (g in seq_len(GEN_RS)) {
    for (i in seq_len(POP_RS)) {
      cand <- perturb_tree(base_tree)                 # <- mutation del SA
      cand <- compute_objectives(cand)
      nl <- cand$scores$ls; nm <- cand$scores$me
      # update the non-dominated archive
      if (!any(arch_ls <= nl & arch_me <= nm & (arch_ls < nl | arch_me < nm))) {
        keep <- !(nl <= arch_ls & nm <= arch_me & (nl < arch_ls | nm < arch_me))
        arch_ls <- c(arch_ls[keep], nl)
        arch_me <- c(arch_me[keep], nm)
        arch_tr <- c(arch_tr[keep], list(cand))
      }
    }
    # metrics of the cumulative front (normalised) -> monotone hypervolume
    Pn <- cbind(arch_ls / max_ls, arch_me / max_me)
    mg <- front_metrics(Pn)
    hv_gen[g] <- mg["hv"]; spread_g[g] <- mg["spread"]; size_g[g] <- mg["size"]
    if (show_progress) cat(sprintf("\r   gen %3d/%d %s  HV=%.4f", g, GEN_RS, progress_bar(g, GEN_RS), hv_gen[g]))
  }
  if (show_progress) cat("\n")
  best_so_far <- cummax(hv_gen)

  # front + medoid + trace (same names and format as NSGA-II and MOSA)
  Pn  <- cbind(arch_ls / max_ls, arch_me / max_me)
  med <- medoid(Pn)
  write.csv(data.frame(ls = arch_ls, me = arch_me),
            file.path(RESULTS_DIR, sprintf("front_RS_%s_run%02d.csv", ds, run)), row.names = FALSE)
  arbol_med <- arch_tr[[med]]
  if (is.null(arbol_med$tip.label)) arbol_med$tip.label <- rownames(base_tree$dist_kmer)
  write.tree(arbol_med, file.path(RESULTS_DIR, sprintf("medoid_RS_%s_run%02d.nwk", ds, run)))
  g_all <- seq_len(GEN_RS)
  keep  <- g_all == 1L | g_all == GEN_RS | (g_all %% EVERY_N == 0L)
  write.csv(data.frame(generation = g_all[keep], hypervolume = hv_gen[keep],
                       best_so_far = best_so_far[keep], spread = spread_g[keep],
                       front_size = size_g[keep]),
            file.path(RESULTS_DIR, sprintf("conv_RS_%s_run%02d.csv", ds, run)), row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(run = run, hv_max = max(hv_gen), seconds = seg)
}

# =====================================================================
# DISPATCH: serial or parallel (at the run level)
# =====================================================================
if (!isTRUE(get0("TUNE_ONLY", envir = globalenv(), ifnotfound = FALSE))) {

if (isTRUE(VERBOSE))
  cat(sprintf("\n==== Random Search | %s | %d runs | POP=%d x GEN=%d | %s ====\n",
              DATASET, N_RUNS, POP_RS, GEN_RS,
              if (isTRUE(PARALLEL)) sprintf("PARALLEL x%d cores", min(N_CORES, N_RUNS)) else "serial"))

if (isTRUE(PARALLEL)) {
  library(parallel)
  ncores <- min(N_CORES, N_RUNS)
  cl <- makeCluster(ncores)
  clusterExport(cl, c("ROOT", "MOSA_R", "DATA_DIR", "RESULTS_DIR", "DATASET", "SEQ_TYPE", "K", "EVERY_N",
                      "POP_RS", "GEN_RS", "SEED", "N_RUNS", "VERBOSE", "PARALLEL",
                      "progress_bar", "medoid", "non_dominated", "front_metrics", "run_once_rs"), envir = environment())
  clusterEvalQ(cl, {
    source(file.path(MOSA_R, "packages.R"))
    for (.f in list.files(MOSA_R, pattern = "\\.R$", full.names = TRUE))
      if (!grepl("packages\\.R$", .f)) source(.f)
    TRUE
  })
  res <- parLapply(cl, seq_len(N_RUNS), run_once_rs)
  stopCluster(cl)
} else {
  res <- lapply(seq_len(N_RUNS), run_once_rs)
}

summary_df <- do.call(rbind, res)

# consolidate: medoid and front of the BEST run
ds <- tools::file_path_sans_ext(DATASET)
best <- summary_df$run[which.max(summary_df$hv_max)]
file.copy(file.path(RESULTS_DIR, sprintf("medoid_RS_%s_run%02d.nwk", ds, best)),
          file.path(RESULTS_DIR, sprintf("medoid_RS_%s.nwk", ds)), overwrite = TRUE)
file.copy(file.path(RESULTS_DIR, sprintf("front_RS_%s_run%02d.csv", ds, best)),
          file.path(RESULTS_DIR, sprintf("front_RS_%s.csv", ds)), overwrite = TRUE)
unlink(list.files(RESULTS_DIR, pattern = sprintf("^medoid_RS_%s_run.*\\.nwk$", ds), full.names = TRUE))
unlink(list.files(RESULTS_DIR, pattern = sprintf("^front_RS_%s_run.*\\.csv$", ds), full.names = TRUE))

for (i in seq_len(nrow(summary_df)))
  message(sprintf("Run %2d/%d  HVmax=%.4f  %.1fs",
                  summary_df$run[i], N_RUNS, summary_df$hv_max[i], summary_df$seconds[i]))

write.csv(summary_df,
          file.path(RESULTS_DIR, sprintf("resumen_RS_%s.csv", tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Done (RS). Traces and summary in: ", RESULTS_DIR)

}  # end of the TUNE_ONLY guard
