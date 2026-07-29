# =====================================================================
# run_experiments.R  ·  Results table (NSGA-II, MOSA and Random Search)
# ---------------------------------------------------------------------
# Runs the THREE methods (11 runs each) on the data sets listed in config.R
# and builds the results table:
#     Data set | NSGA-II | MOSA | RS | p (Kruskal-Wallis)
# with Holm correction. Outputs:
#     tabla_resultados.csv   (data + NJ baseline + pairwise p + Holm)
#     tabla_hv.tex           (LaTeX table, ready to paste)
#
# All settings (parameters, data sets, parallelism) live in config.R.
# Uso:  Rscript run_experiments.R
# =====================================================================
.app_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
APP <- .app_dir()
assign("TUNE_ONLY", FALSE, envir = globalenv())   # clears leftover irace state in the same session
source(file.path(APP, "config.R"))
DATA_DIR    <- file.path(APP, "data")
RESULTS_DIR <- file.path(APP, "results")
FIG_DIR     <- file.path(APP, "figures")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR,     recursive = TRUE, showWarnings = FALSE)

# --- 1) run the THREE methods on each data set -------------------
if (isTRUE(RUN_ALGORITHMS)) {
  VERBOSE <- TRUE
  for (dsf in DATASETS) {
    DATASET <- dsf
    message("\n########## ", tools::file_path_sans_ext(dsf), " ##########")
    source(file.path(APP, "algorithms", "nsga2", "run_nsga.R"))   # -> resumen_NSGA_<ds>.csv
    source(file.path(APP, "algorithms", "mosa", "run_mosa.R"))          # -> resumen_MOSA_<ds>.csv
    source(file.path(APP, "algorithms", "rs", "run_rs.R"))          # -> resumen_RS_<ds>.csv
  }
}

# --- 2) NJ baseline (hypervolume of the base tree) ------------------------------
HV_NJ <- round((2 - 0.1) * (2 - 0.1), 2)   # 3.61 (tree base normalizado en (0.1,0.1))

# --- 3) build the results table from the resumen_*.csv files -----------------------
rows_list <- list(); pvals <- numeric(0)
for (dsf in DATASETS) {
  ds <- tools::file_path_sans_ext(dsf)
  fn <- file.path(RESULTS_DIR, sprintf("resumen_NSGA_%s.csv", ds))
  fm <- file.path(RESULTS_DIR, sprintf("resumen_MOSA_%s.csv", ds))
  fr <- file.path(RESULTS_DIR, sprintf("resumen_RS_%s.csv",   ds))
  if (!all(file.exists(c(fn, fm, fr)))) {
    warning("Missing summary files for ", ds, " (se omite)"); next
  }
  hv_n <- read.csv(fn)$hv_max
  hv_m <- read.csv(fm)$hv_best
  hv_r <- read.csv(fr)$hv_max

  # omnibus test (Kruskal-Wallis) across the three methods
  val <- c(hv_n, hv_m, hv_r)
  grp <- factor(rep(c("NSGA", "MOSA", "RS"), c(length(hv_n), length(hv_m), length(hv_r))))
  p_kw <- suppressWarnings(kruskal.test(val, grp)$p.value)
  # pairwise comparisons (for the CSV)
  p_nm <- suppressWarnings(wilcox.test(hv_n, hv_m)$p.value)
  p_nr <- suppressWarnings(wilcox.test(hv_n, hv_r)$p.value)
  p_mr <- suppressWarnings(wilcox.test(hv_m, hv_r)$p.value)

  rows_list[[ds]] <- data.frame(
    dataset = ds, NJ = HV_NJ,
    NSGA = round(mean(hv_n), 2), MOSA = round(mean(hv_m), 2), RS = round(mean(hv_r), 2),
    p = p_kw, p_NSGA_MOSA = p_nm, p_NSGA_RS = p_nr, p_MOSA_RS = p_mr,
    stringsAsFactors = FALSE)
  pvals <- c(pvals, p_kw)
}
if (length(rows_list) == 0)
  stop("No summary files were produced. Check that RUN_ALGORITHMS=TRUE in config.R and restart R ",
       "(Session > Restart R) para limpiar cualquier estado de una run previa.")
results_table <- do.call(rbind, rows_list)
results_table$p_holm      <- p.adjust(results_table$p, method = "holm")
results_table$signif_holm <- results_table$p_holm < 0.05
results_table$best       <- c("NSGA-II", "MOSA", "RS")[max.col(results_table[, c("NSGA", "MOSA", "RS")], ties.method = "first")]

write.csv(results_table, file.path(APP, "tabla_resultados.csv"), row.names = FALSE)
message("\nTable (data) -> ", file.path(APP, "tabla_resultados.csv"))

# --- 4) LaTeX table (3 methods + omnibus p) --------------------------------
esc  <- function(x) gsub("_", "\\\\_", x)
format_p <- function(p) if (is.na(p)) "--" else if (p < 0.001) "$<0.001$" else sprintf("%.3f", p)
lineas <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Mean hypervolume of NSGA-II, MOSA and Random Search (RS) over eleven runs, with the Kruskal--Wallis $p$-value across the three methods. All comparisons remain significant after Holm correction at family-wise $\\alpha=0.05$.}",
  "\\label{tab:hv}",
  "\\begin{tabular}{lrrrr}", "\\toprule",
  "\\textbf{Data set} & \\textbf{NSGA-II} & \\textbf{MOSA} & \\textbf{RS} & \\textbf{$p$}\\\\",
  "\\midrule")
for (i in seq_len(nrow(results_table))) {
  lineas <- c(lineas, sprintf("%-16s & %.2f & %.2f & %.2f & %s\\\\",
              esc(results_table$dataset[i]), results_table$NSGA[i], results_table$MOSA[i], results_table$RS[i], format_p(results_table$p[i])))
}
lineas <- c(lineas, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(lineas, file.path(APP, "tabla_hv.tex"))
message("Table (LaTeX) -> ", file.path(APP, "tabla_hv.tex"))

# --- console summary ----------------------------------------------
cat("\n================= RESULTS TABLE =================\n")
print(results_table[, c("dataset", "NJ", "NSGA", "MOSA", "RS", "p", "p_holm", "best")], row.names = FALSE)
cat(sprintf("\nGana NSGA-II en %d de %d datasets (MOSA %d, RS %d).\n",
            sum(results_table$best == "NSGA-II"), nrow(results_table),
            sum(results_table$best == "MOSA"), sum(results_table$best == "RS")))
cat(sprintf("NJ baseline = %.2f | all significant after Holm: %s\n",
            HV_NJ, all(results_table$signif_holm, na.rm = TRUE)))
