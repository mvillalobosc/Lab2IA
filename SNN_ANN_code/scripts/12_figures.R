# =====================================================================
# 12_figures.R
# Mapping figures for the manuscript (vector PDF, 131 mm wide, which is
# the text width of the sn-jnl class, 8 pt type). Reads the final map
# (data/results/mapping.csv) and writes to <output_dir>:
#   Fig2_year_category.pdf   included studies by year and category
#   Fig3_evidence_year.pdf   basis of the efficiency evidence in the
#                            ANN-SNN comparisons, by year
#   Fig4_platforms.pdf       platforms of the SNN and of the ANN in the
#                            ANN-SNN comparisons
#   Fig5_sparsity.pdf        sparsity methods and presence of a cost term
#                            in the objective, by method family
# Categorical palette validated for colour-vision deficiency (adjacent
# pairs) and single-hue ordinal ramp for the strength of the evidence.
# Usage: Rscript scripts/12_figures.R <output_dir>     (review value: figures)
# =====================================================================
suppressPackageStartupMessages({ library(data.table); library(ggplot2); library(patchwork); library(scales) })
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
output_dir <- commandArgs(trailingOnly = TRUE)[1]
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

m   <- fread("data/results/mapping.csv", colClasses = "character", na.strings = "")
inc <- m[eligible == "Y"]
inc[, year := as.integer(year)]
has <- function(x, c) grepl(c, x)

PAL <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300")
GREY <- "#9a9893"
theme_map <- theme_minimal(base_size = 8, base_family = "sans") +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = "#e6e5e1", linewidth = 0.3),
        axis.ticks = element_blank(), legend.position = "bottom",
        legend.key.size = unit(3.5, "mm"), legend.text = element_text(size = 7.5),
        legend.title = element_blank(), plot.title = element_text(size = 8.5, face = "bold"),
        plot.title.position = "plot", strip.text = element_text(face = "bold", size = 9),
        axis.title = element_text(size = 8.5, colour = "#52514e"), axis.text = element_text(colour = "#0b0b0b"))

# ---------------- Fig 2: year x category (multi-label) ----------------
cat_lab <- c(C1 = "ANN-SNN efficiency comparison", C2 = "Pruning or sparsity in SNN",
             C3 = "Lottery tickets in ANN", C4 = "Lottery tickets in SNN",
             C5 = "Review or survey", C6 = "Benchmarking methodology")
f2 <- rbindlist(lapply(names(cat_lab), function(c) inc[has(categories, c), .(n = .N), by = year][, cat := cat_lab[c]]))
f2[, cat := factor(cat, levels = cat_lab)]
p2 <- ggplot(f2, aes(x = factor(year), y = n, fill = cat)) +
  geom_col(width = 0.72, colour = "#fcfcfb", linewidth = 0.4) +
  scale_fill_manual(values = PAL, drop = FALSE) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.04))) +
  labs(x = "Publication year (2026 includes early-access records)", y = "Included studies (one count per category)") +
  theme_map + theme(panel.grid.major.y = element_line(colour = "#e6e5e1", linewidth = 0.3)) + guides(fill = guide_legend(nrow = 2, byrow = TRUE))
ggsave(file.path(output_dir, "Fig2_year_category.pdf"), p2, width = 131, height = 80, units = "mm", device = cairo_pdf)

# ---------------- Fig 3: evidence basis by year in C1 ----------------
c1 <- inc[has(categories, "C1")]
ev_lab <- c(MEASURED = "Measured on hardware", BOTH = "Measured and estimated",
            ESTIMATED = "Analytical estimate", CLAIM = "Claim without figures",
            NS = "Basis not stated", NONE = "No efficiency figure")
f3 <- c1[, .(n = .N), by = .(year, evidence)]
f3[, evidence := factor(ev_lab[evidence], levels = ev_lab)]
EVPAL <- c("#0d366b", "#1c5cab", "#3987e5", "#86b6ef", "#c3c2b7", "#e6e5e1")
tot3 <- c1[, .(total = .N, measured = sum(evidence %in% c("MEASURED", "BOTH"))), by = year][, pct := measured / total]
p3a <- ggplot(f3, aes(x = factor(year), y = n, fill = evidence)) +
  geom_col(width = 0.72, colour = "#fcfcfb", linewidth = 0.4) +
  scale_fill_manual(values = EVPAL, drop = FALSE) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.04))) +
  labs(x = "Publication year", y = "ANN-SNN comparison studies", title = "(a) Basis of the reported efficiency figures") +
  theme_map + guides(fill = guide_legend(nrow = 2, byrow = TRUE))
p3b <- ggplot(tot3, aes(x = factor(year), y = pct, group = 1)) +
  geom_line(colour = "#2a78d6", linewidth = 0.8) +
  geom_point(colour = "#2a78d6", size = 2.2) +
  geom_text(aes(label = percent(pct, accuracy = 1), vjust = ifelse(year %in% c(2021, 2023), 2.1, -1.2)), size = 2.7, colour = "#0b0b0b") +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 0.45), expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Publication year", y = "Share with measured energy", title = "(b) Share with hardware measurement") + theme_map
p3 <- p3a + p3b + plot_layout(widths = c(1.35, 1))
ggsave(file.path(output_dir, "Fig3_evidence_year.pdf"), p3, width = 131, height = 78, units = "mm", device = cairo_pdf)

# ---------------- Fig 4: platforms in C1 ----------------
plat_lab <- c(SIM = "Software simulation only", NS = "Not stated", ASIC = "Custom ASIC", FPGA = "FPGA",
              OTHER_NEURO = "Other neuromorphic chip", LOIHI = "Loihi", LOIHI2 = "Loihi 2", GPU = "GPU",
              EDGE_GPU = "Embedded GPU (Jetson)", CPU = "CPU", MEMRISTOR = "Memristive / in-memory",
              SPINNAKER2 = "SpiNNaker2", SPINNAKER = "SpiNNaker", AKIDA = "Akida", MCU = "Microcontroller",
              TIANJIC = "Tianjic", XYLO = "Xylo", BRAINSCALES = "BrainScaleS", TRUENORTH = "TrueNorth",
              NPU = "NPU / accelerator stick", TPU = "TPU", DYNAP = "DYNAP", SPECK = "Speck", DARWIN = "Darwin", NA_ = "NA")
count_platforms <- function(col) { v <- unlist(strsplit(c1[[col]], "\\+")); v <- v[!(v %in% c("NA", "-"))]
  d <- as.data.table(table(v)); setnames(d, c("plat", "n")); d[, lab := plat_lab[plat]]; d[order(-n)] }
f4s <- count_platforms("platform_snn"); f4a <- count_platforms("platform_ann")
f4s[, physical := !(plat %in% c("SIM", "NS"))]; f4a[, physical := !(plat %in% c("SIM", "NS"))]
bars <- function(d, title) {
  d <- d[n >= 2]; d[, lab := factor(lab, levels = rev(lab))]
  ggplot(d, aes(x = n, y = lab, fill = physical)) +
    geom_col(width = 0.7) +
    geom_text(aes(label = n), hjust = -0.25, size = 2.6, colour = "#0b0b0b") +
    scale_fill_manual(values = c(`FALSE` = GREY, `TRUE` = "#2a78d6"), labels = c("No physical platform", "Physical platform")) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.26))) +
    labs(x = "Studies", y = NULL, title = title) +
    theme_map + theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#e6e5e1", linewidth = 0.3))
}
p4 <- bars(f4s, "(a) Platform on which the SNN was run") + bars(f4a, "(b) Platform on which the ANN was run") +
  plot_layout(guides = "collect") & theme(legend.position = "bottom")
ggsave(file.path(output_dir, "Fig4_platforms.pdf"), p4, width = 131, height = 92, units = "mm", device = cairo_pdf)

# ---------------- Fig 5: sparsity methods and cost in the objective ----------------
met_lab <- c(MAG = "Magnitude pruning", ACT = "Activity or spike based", SCORE = "Learned scores / masks",
             REG = "Regularisation", EVO = "Evolutionary / search", DST = "Dynamic sparse training",
             RANDOM = "Random pruning or subnetworks", THEORY = "Theoretical analysis", OTHER = "Other", NS = "Not stated")
grp_lab <- c(C2 = "Pruning or sparsity in SNN (n = 383)", C3 = "Lottery tickets in ANN (n = 331)")
f5 <- rbindlist(lapply(names(grp_lab), function(g) { s <- inc[has(categories, g)]
  v <- unlist(strsplit(s$sparsity_method, "\\+")); v <- v[!(v %in% c("NA", "-"))]
  d <- as.data.table(table(v)); setnames(d, c("met", "n")); d[, pct := n / nrow(s)]; d[, group := grp_lab[g]]; d }))
f5[, lab := factor(met_lab[met], levels = rev(met_lab))]
f5[, group := factor(group, levels = grp_lab)]
p5a <- ggplot(f5, aes(x = pct, y = lab, fill = group)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c("#eb6834", "#1baf7a")) +
  scale_x_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.08))) +
  labs(x = "Share of studies in the family", y = NULL, title = "(a) Method used to obtain the sparse network") +
  theme_map + theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#e6e5e1", linewidth = 0.3))
co_lab <- c(Y = "Cost or activity in the objective", N = "Accuracy and density only", NS = "Not stated")
f5b <- rbindlist(lapply(names(grp_lab), function(g) { s <- inc[has(categories, g)]
  d <- s[, .(n = .N), by = cost_in_objective]; d[, pct := n / nrow(s)]; d[, group := grp_lab[g]]; d }))
f5b[, cost_in_objective := factor(co_lab[cost_in_objective], levels = co_lab)]
f5b[, group := factor(group, levels = rev(grp_lab))]
p5b <- ggplot(f5b, aes(x = pct, y = group, fill = cost_in_objective)) +
  geom_col(width = 0.6, colour = "#fcfcfb", linewidth = 0.4) +
  geom_text(aes(label = ifelse(pct > 0.06, percent(pct, accuracy = 1), "")), position = position_stack(vjust = 0.5), size = 2.7, colour = "#fcfcfb") +
  scale_fill_manual(values = c("#2a78d6", "#eda100", GREY)) +
  scale_x_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.02))) +
  scale_y_discrete(labels = function(x) sub(" \\(n.*", "", x)) +
  labs(x = "Share of studies", y = NULL, title = "(b) Does energy, firing activity or hardware cost enter the objective?") +
  theme_map + theme(panel.grid.major.y = element_blank())
p5 <- p5a / p5b + plot_layout(heights = c(2.4, 1))
ggsave(file.path(output_dir, "Fig5_sparsity.pdf"), p5, width = 131, height = 118, units = "mm", device = cairo_pdf)
cat("figures written to", output_dir, "\n")
