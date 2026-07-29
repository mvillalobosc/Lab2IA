# =====================================================================
# 06_ranking.R  ·  Win counts and average rank per method (metaheuristics)
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

D <- hv_table_long()
wins <- setNames(numeric(3), ORD); ranks <- matrix(NA, length(datasets), 3, dimnames = list(datasets, ORD))
for (ds in datasets) {
  mu <- sapply(ORD, function(m) mean(D$hv[D$dataset == ds & D$method == m]))
  wins[names(which.max(mu))] <- wins[names(which.max(mu))] + 1
  ranks[ds, ] <- rank(-mu)
}
avg_rank <- colMeans(ranks)

# --- (a) wins ---
dw <- data.frame(method = factor(ORD, levels = ORD), wins = as.integer(wins[ORD]))
pw <- ggplot(dw, aes(method, wins, fill = method)) +
  geom_col(width = 0.62, alpha = 0.95) +
  geom_text(aes(label = wins), vjust = -0.4, size = 4.2, colour = "grey25") +
  scale_fill_manual(values = PAL, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = "Datasets won (best mean HV)",
       title = sprintf("Wins per method (of %d datasets)", length(datasets))) +
  theme_pub(12)
save_plot(pw, "ranking_wins", w = 5.2, h = 4.2)

# --- (b) average rank ---
dr <- data.frame(method = factor(ORD, levels = ORD), r = avg_rank[ORD])
pr <- ggplot(dr, aes(r, reorder(method, -r), fill = method)) +
  geom_col(width = 0.6, alpha = 0.95) +
  geom_text(aes(label = sprintf("%.2f", r)), hjust = -0.15, size = 4, colour = "grey25") +
  scale_fill_manual(values = PAL, guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15)), limits = c(0, 3)) +
  labs(x = "Average rank (1 = best)", y = NULL, title = "Average rank across datasets") +
  theme_pub(12)
save_plot(pr, "ranking_avg", w = 5.6, h = 3.4)
cat("Ranking done in ", OUT_DIR, "\n")
