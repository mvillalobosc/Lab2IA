# =====================================================================
# 09_figure_S1_workflow.R
# Supplementary Figure S1: analytical workflow of the main analysis. The sample sizes printed in the boxes are taken
# from the database (countries, country-years, range of the annual frontiers); the balanced panel of
# the Malmquist analysis (34 countries) was defined in the source study and is set below.
# Output: results/Figure_S1.png (1850 x 1830 px; the supplementary file includes it at the full text width)
# =====================================================================
source(file.path("R", "00_setup.R"))
library(grid)
# the labels use en dashes and the multiplication sign: draw them in a UTF-8 locale
if (!isTRUE(l10n_info()$`UTF-8`)) invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

db <- read.csv(DATABASE)
scores <- db[db$in_main_sample, ]
n_countries <- length(unique(scores$code))
n_country_years <- nrow(scores)
per_year <- range(table(scores$year))
N_PANEL <- 34

W <- 1850; H <- 1830
FAMILY <- "Helvetica"        # resolves to Helvetica, Arial or a metric clone (TeX Gyre Heros, Liberation Sans)
INK <- "#1A1A1A"; SUB <- "#444444"; ARROW <- "#4A4A4A"; TEAL <- "#00A499"
PAL <- list(beige = c("#EFECE4", "#B8B0A0"), blue = c("#DBEAFC", "#8FB4E3"), green = c("#D6F0E0", "#74C79B"),
            purple = c("#E4DDF7", "#A690DE"), yellow = c("#FDEDCF", "#E6C878"), red = c("#FBE0DA", "#E09080"))
LWD <- 2.6 / 0.75            # 2.6 px lines (lwd 1 = 1/96 inch = 0.75 px at 72 dpi)

# column centres and box sizes (pixels; y grows downwards)
C1 <- 500; C2 <- 1030; C3 <- 1560; BW <- 470; BH <- 100

Y <- function(y) H - y          # layout coordinates run from the top of the canvas; grid's run from the bottom
box <- function(cx, top, title, subtitle, col, w = BW) {
  grid.roundrect(x = cx, y = Y(top + BH / 2), width = w, height = BH, default.units = "native",
                 r = unit(12, "points"), gp = gpar(fill = PAL[[col]][1], col = PAL[[col]][2], lwd = 2 / 0.75))
  grid.text(title, x = cx, y = Y(top + 37), default.units = "native",
            gp = gpar(fontfamily = FAMILY, fontface = "bold", fontsize = 27, col = INK))
  grid.text(subtitle, x = cx, y = Y(top + 72), default.units = "native", gp = gpar(fontfamily = FAMILY, fontsize = 22, col = SUB))
  invisible(list(cx = cx, top = top, bottom = top + BH, left = cx - w / 2, right = cx + w / 2, mid = top + BH / 2))
}
head_arrow <- arrow(angle = 22, length = unit(15, "points"), type = "closed")
path <- function(x, y, arrowhead = TRUE) {
  grid.lines(x = x, y = Y(y), default.units = "native", arrow = if (arrowhead) head_arrow,
             gp = gpar(col = ARROW, fill = ARROW, lwd = LWD, linejoin = "mitre", lineend = "butt"))
}
dot <- function(x, y) grid.circle(x = x, y = Y(y), r = unit(5, "points"), default.units = "native", gp = gpar(fill = ARROW, col = NA))
phase <- function(top, bottom, number, name_lines) {
  grid.rect(x = 40, y = Y(top), width = 9, height = bottom - top, just = c("left", "top"), default.units = "native",
            gp = gpar(fill = TEAL, col = NA))
  grid.text(paste("Phase", number), x = 66, y = Y(top + 18), just = c("left", "centre"), default.units = "native",
            gp = gpar(fontfamily = FAMILY, fontface = "bold", fontsize = 31, col = TEAL))
  for (i in seq_along(name_lines)) {
    grid.text(name_lines[i], x = 66, y = Y(top + 18 + 38 * i), just = c("left", "centre"), default.units = "native",
              gp = gpar(fontfamily = FAMILY, fontface = "bold", fontsize = 27, col = INK))
  }
}

png(file.path(RESULTS, "Figure_S1.png"), width = W, height = H, res = 72, type = "cairo", bg = "white")
grid.newpage()
pushViewport(viewport(xscale = c(0, W), yscale = c(0, H)))

# Phase 1: data preparation
phase(70, 510, 1, c("Data", "preparation"))
bA <- box(C2, 70, "WHO and World Bank indicators", sprintf("%d–%d, country-level", min(YEARS), max(YEARS)), "beige", w = 560)
bB <- box(C2, 230, "Complete-case filtering", "No imputation; classify by region, financing", "beige", w = 560)
bC <- box(C2, 410, sprintf("Annual samples: %d countries", n_countries),
         sprintf("%d country-years; %d–%d per year", n_country_years, per_year[1], per_year[2]), "blue")
bD <- box(C1, 410, sprintf("Balanced panel: %d countries", N_PANEL), "Complete across all years", "green")
path(c(C2, C2), c(bA$bottom, bB$top))
path(c(C2, C2), c(bB$bottom, bC$top))
path(c(C2 - 140, C2 - 140, C1, C1), c(bB$bottom, bB$bottom + 40, bB$bottom + 40, bD$top))

# Phase 2: DEA estimation and model selection
phase(600, 1150, 2, c("DEA estimation", "and model", "selection"))
bE <- box(C2, 600, "Inputs and outputs defined", "3 inputs, 2 outputs per country", "blue")
bF <- box(C2, 750, "Four DEA specifications", "IO/OO × CRS/VRS, per year", "blue")
bG <- box(C2, 900, "Iterative sensitivity analysis", "Remove frontier units, re-estimate", "blue")
bH <- box(C2, 1050, "Selected model: IO–CRS", "Most stable and discriminating", "purple")
path(c(C2, C2), c(bC$bottom, bE$top)); path(c(C2, C2), c(bE$bottom, bF$top))
path(c(C2, C2), c(bF$bottom, bG$top)); path(c(C2, C2), c(bG$bottom, bH$top))

# Phase 3: statistical evaluation
phase(1240, 1540, 3, c("Statistical", "evaluation"))
bI <- box(C2, 1240, "Annual IO–CRS efficiency scores", "Country-level, per year", "purple")
bJ <- box(C3, 1240, "Distributional assessment", "Scores bounded 0–1, non-normal", "yellow")
bK <- box(C1, 1440, "Malmquist decomposition", "Efficiency vs technological change", "green")
bL <- box(C2, 1440, "Kruskal–Wallis tests", "Group differences", "red")
bM <- box(C3, 1440, "Bootstrapped Tobit", "Pooled and yearly associations", "red")
path(c(C2, C2), c(bH$bottom, bI$top))
path(c(bI$right, bJ$left), c(bI$mid, bJ$mid))
# balanced panel and IO-CRS model feed the Malmquist index
path(c(C1, C1), c(bD$bottom, bK$top))
path(c(bI$left, C1), c(bI$mid, bI$mid), arrowhead = FALSE); dot(C1, bI$mid)
# scores and their distribution feed both the group tests and the Tobit model
bus <- 1390
path(c(C2, C2), c(bI$bottom, bus), arrowhead = FALSE); path(c(C3, C3), c(bJ$bottom, bus), arrowhead = FALSE)
path(c(C2, C3), c(bus, bus), arrowhead = FALSE); dot(C2, bus); dot(C3, bus)
path(c(C2, C2), c(bus, bL$top)); path(c(C3, C3), c(bus, bM$top))

# Phase 4: synthesis
phase(1660, 1760, 4, "Synthesis")
bN <- box(C2, 1660, "Integrated interpretation", "Efficiency, productivity, associations; regional benchmark", "purple", w = 700)
bus2 <- 1600
path(c(C1, C1), c(bK$bottom, bus2), arrowhead = FALSE); path(c(C3, C3), c(bM$bottom, bus2), arrowhead = FALSE)
path(c(C1, C3), c(bus2, bus2), arrowhead = FALSE); dot(C1, bus2); dot(C3, bus2)
path(c(C2, C2), c(bL$bottom, bN$top)); dot(C2, bus2)

popViewport()
invisible(dev.off())
message("saved results/Figure_S1.png (", n_countries, " countries, ", n_country_years, " country-years)")
