# =====================================================================
# 01_table_tests.R  ·  Publication table (metaheuristics style)
# mean +/- sd, best in bold, Wilcoxon vs best (Holm), avg rank, Friedman
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

D <- hv_table_long()
A12 <- function(x, y) { r <- rank(c(x, y)); n1 <- length(x); n2 <- length(y); (sum(r[seq_len(n1)])/n1 - (n1+1)/2)/n2 }

nd <- length(datasets)
MU <- matrix(NA_real_, nd, 3, dimnames = list(datasets, ORD))   # medias
SD <- matrix(NA_real_, nd, 3, dimnames = list(datasets, ORD))   # desviaciones
PB <- matrix(NA_real_, nd, 3, dimnames = list(datasets, ORD))   # p vs el best
RK <- matrix(NA_real_, nd, 3, dimnames = list(datasets, ORD))   # rank
BEST <- character(nd); names(BEST) <- datasets
PKW <- numeric(nd);    names(PKW)  <- datasets
pairs_list <- list()

for (ds in datasets) {
  sub <- D[D$dataset == ds, ]; hv <- split(sub$hv, sub$method)
  for (m in ORD) { MU[ds, m] <- mean(hv[[m]]); SD[ds, m] <- sd(hv[[m]]) }
  BEST[ds] <- ORD[which.max(MU[ds, ])]
  RK[ds, ] <- rank(-MU[ds, ])
  PKW[ds]  <- suppressWarnings(kruskal.test(sub$hv, sub$method)$p.value)
  for (m in ORD)
    if (m != BEST[ds]) PB[ds, m] <- suppressWarnings(wilcox.test(hv[[m]], hv[[BEST[ds]]])$p.value)
  for (cmp in list(c("NSGA-II","MOSA"), c("NSGA-II","RS"), c("MOSA","RS"))) {
    x <- hv[[cmp[1]]]; y <- hv[[cmp[2]]]
    pairs_list[[length(pairs_list)+1]] <- data.frame(dataset = ds, comparacion = paste(cmp, collapse=" vs "),
      p = suppressWarnings(wilcox.test(x, y)$p.value), A12 = round(A12(x, y), 3),
      dif_medias = round(mean(x) - mean(y), 3), stringsAsFactors = FALSE)
  }
}
# Holm per column (comparisons against the best method)
PBH <- PB
for (m in ORD) { ok <- !is.na(PB[, m]); PBH[ok, m] <- p.adjust(PB[ok, m], "holm") }
avg_rank <- colMeans(RK)
fr <- suppressWarnings(friedman.test(MU))

tab <- data.frame(dataset = datasets,
                  NSGA_mean = MU[, "NSGA-II"], NSGA_sd = SD[, "NSGA-II"],
                  MOSA_mean = MU[, "MOSA"],    MOSA_sd = SD[, "MOSA"],
                  RS_mean   = MU[, "RS"],      RS_sd   = SD[, "RS"],
                  best = BEST, p_kruskal = PKW,
                  p_holm_kruskal = p.adjust(PKW, "holm"),
                  row.names = NULL, stringsAsFactors = FALSE)
write.csv(tab, file.path(OUT_DIR, "tabla_hv.csv"), row.names = FALSE)
pairs_df <- do.call(rbind, pairs_list)
pairs_df$p_holm <- ave(pairs_df$p, pairs_df$comparacion, FUN = function(p) p.adjust(p, "holm"))
write.csv(pairs_df, file.path(OUT_DIR, "tests_pareados.csv"), row.names = FALSE)

cat("\n===== TABLE (MOSA:", MOSA_METRIC, ") =====\n")
print(data.frame(dataset = datasets, NSGA = round(MU[,"NSGA-II"],3), MOSA = round(MU[,"MOSA"],3),
                 RS = round(MU[,"RS"],3), best = BEST, row.names = NULL), row.names = FALSE)
cat(sprintf("\nAvg rank (1=best) -> NSGA-II %.2f | MOSA %.2f | RS %.2f\n",
            avg_rank["NSGA-II"], avg_rank["MOSA"], avg_rank["RS"]))
cat(sprintf("Friedman chi2=%.2f p=%.4g\n", as.numeric(fr$statistic), fr$p.value))
cat("Outputs: tabla_hv.csv, tests_pareados.csv\n")
