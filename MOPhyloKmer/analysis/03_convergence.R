# =====================================================================
# 03_convergence.R  ·  Convergence: mean and 95% CI (three methods)
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

C <- convergence_long()
# aggregate by (data set, method, eval): mean and 95% CI (Student t) over runs
ci95 <- function(v) {
  n <- length(v); m <- mean(v)
  if (n < 2) return(c(m = m, lo = m, hi = m))
  e <- qt(0.975, n - 1) * sd(v) / sqrt(n)
  c(m = m, lo = m - e, hi = m + e)
}
ag <- aggregate(hv ~ dataset + method + eval, C, FUN = ci95)
ag <- do.call(data.frame, ag)
names(ag)[grepl("^hv", names(ag))] <- c("media", "lo", "hi")
ag$method  <- factor(ag$method, levels = ORD)
ag$dataset <- factor(ag$dataset, levels = datasets)

p <- ggplot(ag, aes(eval, media, colour = method, fill = method)) +
  geom_hline(yintercept = 3.61, linetype = "22", colour = "grey75", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi, group = method), alpha = 0.45, colour = NA) +
  geom_line(aes(y = lo, group = method), linewidth = 0.25, alpha = 0.9) +
  geom_line(aes(y = hi, group = method), linewidth = 0.25, alpha = 0.9) +
  geom_line(aes(group = method), linewidth = 0.7) +
  facet_wrap(~dataset, ncol = 4) +   # same scale everywhere: comparable across data sets
  scale_colour_manual(values = PAL) + scale_fill_manual(values = PAL) +
  labs(x = "Objective-function evaluations", y = "Hypervolume (best so far)",
       title = "Convergence: mean and 95% confidence interval") +
  theme_pub(11)
save_plot(p, "convergence", w = 11, h = 8)

cat("Convergencia lista en ", OUT_DIR, "\n")
