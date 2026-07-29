# =====================================================================
# 02_violins.R  ·  Violin plots (distribution) + box + mean, horizontal
# =====================================================================
.here <- function() {
  for (i in rev(seq_len(sys.nframe()))) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a); if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
if (!exists("theme_pub")) source(file.path(.here(), "_common.R"))

DW <- 0.8  # dodge width comun (violin/box/mean alineados)

violin_h <- function(d, xlab, nombre, titulo, subt = NULL, baseline = NA, h = 8.6) {
  d$dataset <- factor(d$dataset, levels = rev(datasets))   # A at the top, Z at the bottom
  nlev  <- nlevels(d$dataset)
  bands <- data.frame(y = seq(1, nlev, by = 2))            # zebra bands
  p <- ggplot(d, aes(value, dataset, fill = method)) +
    geom_rect(data = bands, inherit.aes = FALSE,
              aes(ymin = y - 0.5, ymax = y + 0.5, xmin = -Inf, xmax = Inf), fill = "grey96")
  if (!is.na(baseline))
    p <- p + geom_vline(xintercept = baseline, linetype = "22", colour = "grey70", linewidth = 0.5)
  p <- p +
    geom_violin(aes(colour = method, group = interaction(dataset, method)),
                position = position_dodge(width = DW), orientation = "y",
                width = 0.9, alpha = 0.75, linewidth = 0.4, scale = "width", trim = TRUE) +
    geom_boxplot(aes(group = interaction(dataset, method)),
                 position = position_dodge(width = DW), width = 0.16, orientation = "y",
                 fill = "white", colour = "grey25", linewidth = 0.35, outlier.shape = NA,
                 show.legend = FALSE) +
    stat_summary(aes(group = interaction(dataset, method)), fun = mean, geom = "point",
                 position = position_dodge(width = DW), orientation = "y",
                 shape = 23, fill = "white", colour = "grey20", size = 1.6, stroke = 0.5) +
    scale_fill_manual(values = PAL, breaks = ORD) +
    scale_colour_manual(values = PAL, guide = "none") +
    labs(x = xlab, y = NULL, title = titulo, subtitle = subt) + theme_pub(12) +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.45),
          axis.ticks.y = element_blank(), panel.border = element_blank(),
          axis.line.x  = element_line(colour = "grey60", linewidth = 0.4),
          plot.subtitle = element_text(colour = "grey45", size = 9.5),
          plot.title    = element_text(face = "bold", size = 14))
  if (!is.na(baseline))
    p <- p + annotate("text", x = baseline, y = nlev + 0.55, label = "NJ baseline",
                      hjust = -0.03, colour = "grey55", size = 3, fontface = "italic") +
      coord_cartesian(clip = "off")
  save_plot(p, nombre, w = 9.6, h = h); p
}

# Hypervolume
D <- hv_table_long(); names(D)[names(D) == "hv"] <- "value"
violin_h(D, "Hypervolume", "violin_hv", "Hypervolume across datasets", baseline = 3.61)

# Spread final
S <- final_metric_long("spread")
violin_h(S[!is.na(S$value), ], "Spread (Deb's Delta)", "violin_spread",
       "Front spread across datasets")

# Final front size
F <- final_metric_long("front_size")
violin_h(F, "Number of non-dominated solutions", "violin_front_size",
       "Final front size across datasets")

cat("Violin plots done in ", OUT_DIR, "\n")
