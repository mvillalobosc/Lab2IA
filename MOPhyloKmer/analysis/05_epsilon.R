# =====================================================================
# 05_epsilon.R  ·  Additive epsilon to the combined best front
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

non_dominated <- function(P) which(!vapply(seq_len(nrow(P)), function(i)
  any(P[,1] <= P[i,1] & P[,2] <= P[i,2] & (P[,1] < P[i,1] | P[,2] < P[i,2])), logical(1)))
additive_epsilon <- function(A, R)
  max(apply(R, 1, function(r) min(apply(A, 1, function(a) max(a - r)))))

read_front <- function(ds, m) {
  f <- file.path(RESULTS_DIR, sprintf("front_%s_%s.csv", KEY[[m]], ds))
  if (file.exists(f)) as.matrix(read.csv(f)[, c("ls","me")]) else NULL
}

EPS  <- matrix(NA_real_, length(datasets), 3, dimnames = list(datasets, ORD))
SIZE <- matrix(NA_real_, length(datasets), 3, dimnames = list(datasets, ORD))
for (ds in datasets) {
  fr <- lapply(ORD, function(m) read_front(ds, m)); names(fr) <- ORD
  fr <- fr[!vapply(fr, is.null, logical(1))]
  if (length(fr) < 2) next
  U <- do.call(rbind, fr); comb <- U[non_dominated(U), , drop = FALSE]
  rng <- apply(U, 2, range); den <- pmax(rng[2,] - rng[1,], 1e-9)
  normalize <- function(P) sweep(sweep(P, 2, rng[1,], "-"), 2, den, "/")
  cN <- normalize(comb)
  for (m in names(fr)) {
    EPS[ds, m]  <- round(additive_epsilon(normalize(fr[[m]]), cN), 4)
    SIZE[ds, m] <- nrow(fr[[m]])
  }
}
if (all(is.na(EPS))) stop("No fronts (front_*.csv) found in ", RESULTS_DIR)

# --- tabular outputs (no reshape) ---------------------------------
W <- data.frame(dataset = datasets,
                eps_NSGA = EPS[, "NSGA-II"], eps_MOSA = EPS[, "MOSA"], eps_RS = EPS[, "RS"],
                size_NSGA = SIZE[, "NSGA-II"], size_MOSA = SIZE[, "MOSA"], size_RS = SIZE[, "RS"],
                row.names = NULL, stringsAsFactors = FALSE)
W$best <- ORD[apply(EPS, 1, function(r) if (all(is.na(r))) NA_integer_ else which.min(r))]
write.csv(W, file.path(OUT_DIR, "indicadores_epsilon.csv"), row.names = FALSE)

# --- plot ----------------------------------------------------------
IND <- data.frame(
  dataset = factor(rep(datasets, times = 3), levels = rev(datasets)),
  method  = factor(rep(ORD, each = length(datasets)), levels = ORD),
  epsilon = as.numeric(EPS))
IND <- IND[!is.na(IND$epsilon), ]
nlevE  <- nlevels(IND$dataset)
bandsE <- data.frame(y = seq(1, nlevE, by = 2))
p <- ggplot(IND, aes(epsilon, dataset, colour = method)) +
  geom_rect(data = bandsE, inherit.aes = FALSE,
            aes(ymin = y - 0.5, ymax = y + 0.5, xmin = -Inf, xmax = Inf), fill = "grey96") +
  geom_point(aes(group = method), size = 2.6, alpha = 0.95,
             position = position_dodge(width = 0.6)) +
  scale_colour_manual(values = PAL, breaks = ORD) +
  labs(x = "Additive epsilon to combined front (lower is better)", y = NULL,
       title = "Additive epsilon indicator") +
  theme_pub(12) +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.45),
        axis.ticks.y = element_blank(), panel.border = element_blank(),
        axis.line.x = element_line(colour = "grey60", linewidth = 0.4))
save_plot(p, "epsilon_by_dataset", w = 8.5, h = 7.5)

cat("\n===== ADDITIVE EPSILON (lower = better) =====\n")
print(W[, c("dataset","eps_NSGA","eps_MOSA","eps_RS","best")], row.names = FALSE)
cat("Outputs: epsilon_by_dataset.png, indicadores_epsilon.csv\n")
