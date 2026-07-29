# =====================================================================
# 04_fronts.R  ·  Final Pareto fronts (three methods overlaid)
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

read_front <- function(ds, m) {
  f <- file.path(RESULTS_DIR, sprintf("front_%s_%s.csv", KEY[[m]], ds))
  if (!file.exists(f)) return(NULL)
  d <- read.csv(f); d$method <- m; d$dataset <- ds; d
}
todo <- list()
for (ds in datasets) for (m in ORD) { d <- read_front(ds, m); if (!is.null(d)) todo[[length(todo)+1]] <- d }
FR <- do.call(rbind, todo)
FR$method  <- factor(FR$method, levels = ORD)
FR$dataset <- factor(FR$dataset, levels = datasets)
FR <- FR[order(FR$dataset, FR$method, FR$ls), ]

# min-max normalisation per data set (union of the 3 methods) -> axes in [0,1]
scale01 <- function(v) { r <- range(v, na.rm = TRUE); d <- diff(r); if (d == 0) rep(0, length(v)) else (v - r[1]) / d }
FR$ls_n <- ave(FR$ls, FR$dataset, FUN = scale01)
FR$me_n <- ave(FR$me, FR$dataset, FUN = scale01)

p <- ggplot(FR, aes(ls_n, me_n, colour = method)) +
  geom_line(aes(group = method), linewidth = 0.4, alpha = 0.6) +
  geom_point(size = 0.9, alpha = 0.85) +
  facet_wrap(~dataset, ncol = 4) +
  scale_colour_manual(values = PAL) +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
  coord_fixed(ratio = 1) +          # same scale on both objectives (square panels)
  labs(x = "Normalised least-squares error (LS)", y = "Normalised minimum evolution (ME)",
       title = "Final Pareto fronts (best run)") +
  theme_pub(11)
save_plot(p, "fronts", w = 10, h = 10)

cat("Fronteras listas en ", OUT_DIR, "\n")
