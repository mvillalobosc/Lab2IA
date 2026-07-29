# =====================================================================
# run_all_analysis.R  ·  Runs the whole analysis in one go
#   Rscript analisis/_correr_todo.R
# Paths and the MOSA_METRIC switch are set in _common.R
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
H <- .here()
source(file.path(H, "_common.R"))
for (s in c("01_table_tests.R","02_violins.R","03_convergence.R","04_fronts.R","05_epsilon.R","06_ranking.R")) {
  message("\n######## ", s, " ########")
  ok <- try(source(file.path(H, s)), silent = TRUE)
  if (inherits(ok, "try-error")) message("  ERROR in ", s, ": ", conditionMessage(attr(ok, "condition")))
}
message("\nDone. Everything in: ", OUT_DIR)
