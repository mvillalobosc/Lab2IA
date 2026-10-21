## ============================================================================
## figuras.R
## ----------------------------------------------------------------------------
## Figuras del artículo a tamaño de revista (Springer Nature, 84 o 174 mm),
## en PDF vectorial con fuente tipo Helvetica incrustada (TeX Gyre Heros),
## colores pastel con bordes más oscuros y formas distintas por arquitectura.
##
## Figures of the paper at journal size (Springer Nature, 84 or 174 mm), as
## vector PDF with an embedded Helvetica-like font (TeX Gyre Heros), pastel
## colours with darker borders and one shape per architecture. Fig. 1 is a
## TikZ diagram (Fig1.tex) that is compiled with pdflatex.
##
## Uso / usage (desde post_hoc/): Rscript figuras.R [../salida] [.] [figuras] [Fig2 Fig3 ...]
## Salidas / outputs: figuras/Fig2.pdf a Fig16.pdf (Fig11 a Fig16 son las del
##   apéndice, que siguen la numeración del texto como pide Springer)
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
D <- if (length(args) > 0) args[1] else "../salida"      # salidas del servidor
R <- if (length(args) > 1) args[2] else "."              # carpeta post_hoc (resultados/ y estadistica/)
F <- if (length(args) > 2) args[3] else "figuras"        # carpeta de las figuras
pedidas <- if (length(args) > 3) args[-(1:3)] else "todas"
dir.create(F, showWarnings = FALSE)
suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })

FAM <- "TeX Gyre Heros"
ARQ_ES <- c("continua", "eventos", "continua_modulada", "periodica")
ARQ_LEV <- c("continuous", "event", "modulated continuous", "periodic")   # orden alfabético
names(ARQ_LEV) <- ARQ_ES
FILL <- c(continuous = "#F4A6A6", "event" = "#C9A7E7", "modulated continuous" = "#B5D99C", periodic = "#A7C7E7")
LINE <- c(continuous = "#C0605F", "event" = "#8E68BD", "modulated continuous" = "#6F9F55", periodic = "#5F8DBF")
SHAPE <- c(continuous = 21, "event" = 23, "modulated continuous" = 22, periodic = 24)
arq <- function(x) factor(unname(ARQ_LEV[as.character(x)]), levels = ARQ_LEV)
tema <- function() theme_bw(base_size = 8, base_family = FAM) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#EBEBEB", linewidth = 0.25),
  panel.border = element_rect(colour = "#A0A0A0", linewidth = 0.3, fill = NA), axis.ticks = element_line(colour = "#A0A0A0", linewidth = 0.3),
  axis.text = element_text(size = 7, colour = "#303030"), axis.title = element_text(size = 8, colour = "#202020"),
  legend.text = element_text(size = 7.5), legend.title = element_text(size = 8), legend.position = "bottom",
  legend.key.size = unit(3.2, "mm"), legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(1.5, "mm"),
  strip.background = element_rect(fill = "#F1F1F1", colour = NA), strip.text = element_text(size = 8, face = "bold", colour = "#202020"),
  plot.margin = margin(1.5, 2.5, 1, 1.5, "mm"), plot.tag = element_text(size = 9, face = "bold", family = FAM),
  plot.background = element_rect(fill = "white", colour = NA))
esc_fill <- scale_fill_manual(values = FILL, name = NULL, drop = FALSE)
esc_col <- scale_colour_manual(values = LINE, name = NULL, drop = FALSE)
esc_shape <- scale_shape_manual(values = SHAPE, name = NULL, drop = FALSE)
guardar <- function(p, nombre, ancho_mm, alto_mm) {
  ggsave(file.path(F, nombre), p, device = cairo_pdf, width = ancho_mm / 25.4, height = alto_mm / 25.4, bg = "white")
  cat("ok", nombre, "\n")
}
leer <- function(f, carpeta = D) {   # admite el .csv.gz del repositorio
  ruta <- file.path(carpeta, f); if (!file.exists(ruta) && file.exists(paste0(ruta, ".gz"))) ruta <- paste0(ruta, ".gz")
  read.csv(ruta, stringsAsFactors = FALSE)
}
quiere <- function(n) "todas" %in% pedidas || n %in% pedidas
con_etiquetas <- function(p) p + plot_annotation(tag_levels = "a") & theme(plot.tag = element_text(size = 9, face = "bold", family = FAM))

## Frontera de Pareto en dos dimensiones (minimizar x e y): ordena por x y
## guarda los puntos que mejoran el mínimo de y acumulado. La escalera se
## dibuja con geom_step (horizontal y luego vertical) y se prolonga hasta x_max.
frontera_2d <- function(x, y) {
  o <- order(x, y); x <- x[o]; y <- y[o]
  keep <- y < cummin(c(Inf, head(y, -1)))
  data.frame(x = x[keep], y = y[keep])
}
escaleras <- function(d, grupos, x_max) {
  do.call(rbind, lapply(split(d, d[, grupos], drop = TRUE), function(g) {
    f <- frontera_2d(g$x, g$y)
    f <- rbind(f, data.frame(x = x_max, y = tail(f$y, 1)))
    cbind(g[rep(1, nrow(f)), grupos, drop = FALSE], f)
  }))
}

## ---------------------------------------------------------------------------
## Fig. 2: un ensayo de dos pulsos (ISI 45 ms) leído por la rodilla de cada
## arquitectura (régimen limpio)
## ---------------------------------------------------------------------------
if (quiere("Fig2")) {
  suppressMessages(source(file.path(R, "cargar_funciones.R"), encoding = "UTF-8", chdir = TRUE))
  rd <- read.csv(file.path(R, "resultados", "rodillas_corregidas.csv")); rd <- rd[rd$regimen == "limpio", ]
  set.seed(1)        # ruido en que cada rodilla da su respuesta modal a ISI 45 ms ("dos" en las cuatro)
  Tt <- 600; t1 <- 150; isi <- 45
  estim <- matrix(0, 1, Tt); estim[1, t1:(t1 + 9)] <- 1; estim[1, (t1 + isi):(t1 + isi + 9)] <- 1
  banco <- list(estim = estim, ruido = matrix(rnorm(Tt), 1, Tt), cond = data.frame(n_pulsos = 2, isi = isi, t1 = t1, t2 = t1 + isi, t_ultimo = t1 + isi))
  trazas <- list(); lecturas <- list(); umbrales <- list(); rotulos <- c()
  for (a in ARQ_ES) {
    r <- rd[rd$arquitectura == a, ][1, ]
    th <- setNames(as.numeric(r[nombres_theta(a)]), nombres_theta(a))
    X <- integrar(th[["tau"]], banco, CFG)
    tl <- tiempos_lectura(th, a, X)[[1]]
    V <- max_movil(X, th[["w"]])[1, ]
    u <- if (a == "continua_modulada") th[["theta_p"]] * (1 + th[["A_mod"]] * sin(2 * pi * seq_len(Tt) / th[["T_mod"]])) else rep(th[["theta_p"]], Tt)
    reg <- tl[V[tl] >= u[tl]]
    n_ev <- if (length(reg)) 1 + sum(diff(reg) > th[["m"]]) else 0
    trazas[[a]] <- data.frame(arquitectura = a, t = seq_len(Tt), x = X[1, ])
    lecturas[[a]] <- data.frame(arquitectura = a, t = tl, v = V[tl], registrada = V[tl] >= u[tl])
    umbrales[[a]] <- rbind(data.frame(arquitectura = a, t = seq_len(Tt), y = u, tipo = "registration threshold"),
                           if (a == "eventos") data.frame(arquitectura = a, t = seq_len(Tt), y = th[["theta_g"]], tipo = "gate threshold"))
    rotulos[ARQ_LEV[a]] <- sprintf("%s: %s reads, %d event%s, \"%s\"", ARQ_LEV[a],
                                   if (a %in% c("continua", "continua_modulada")) "600" else as.character(length(tl)),
                                   n_ev, if (n_ev == 1) "" else "s", if (n_ev >= 2) "two" else "one")
  }
  tz <- do.call(rbind, trazas); lc <- do.call(rbind, lecturas); um <- do.call(rbind, umbrales)
  for (d in c("tz", "lc", "um")) { z <- get(d); z$architecture <- arq(z$arquitectura); assign(d, z) }
  lim <- c(100, 500)
  tz <- tz[tz$t >= lim[1] & tz$t <= lim[2], ]; um <- um[um$t >= lim[1] & um$t <= lim[2], ]
  lc <- lc[lc$t >= lim[1] & lc$t <= lim[2], ]
  densas <- data.frame(architecture = arq(c("continua", "continua_modulada")), xmin = lim[1], xmax = lim[2])
  ralas <- lc[!lc$arquitectura %in% c("continua", "continua_modulada"), ]
  pul <- data.frame(xmin = c(t1, t1 + isi) - 0.5, xmax = c(t1 + 9, t1 + isi + 9) + 0.5)
  p <- ggplot() +
    geom_rect(data = pul, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "#F3E6C8", alpha = 0.9) +
    geom_rect(data = densas, aes(xmin = xmin, xmax = xmax, ymin = -0.47, ymax = -0.38), fill = "#9A9A9A") +
    geom_segment(data = ralas, aes(x = t, xend = t, y = -0.49, yend = -0.36), colour = "#505050", linewidth = 0.45) +
    geom_line(data = tz, aes(t, x), colour = "#5A5A5A", linewidth = 0.35) +
    geom_line(data = um, aes(t, y, linetype = tipo), colour = "#303030", linewidth = 0.35) +
    geom_point(data = lc[lc$registrada, ], aes(t, v, fill = architecture, shape = architecture), colour = "#404040", size = 1.6, stroke = 0.3) +
    facet_wrap(~ architecture, ncol = 2, labeller = as_labeller(rotulos)) + esc_fill + esc_shape +
    scale_linetype_manual(values = c("registration threshold" = "22", "gate threshold" = "13"), name = NULL) +
    scale_x_continuous(breaks = seq(100, 500, 100), expand = c(0.015, 0)) +
    scale_y_continuous(breaks = c(0, 0.5, 1)) + coord_cartesian(xlim = lim, ylim = c(-0.5, 1.2)) +
    labs(x = "time in the trial (ms)", y = "integrator state x(t)") +
    guides(fill = "none", shape = "none") + tema() +
    theme(panel.spacing.x = unit(4, "mm"), strip.text = element_text(size = 7.5, face = "plain"))
  guardar(p, "Fig2.pdf", 174, 84)
}

## ---------------------------------------------------------------------------
## Fig. 3: validación del optimizador. (a) convergencia, (b) NSGA-III frente a
## búsqueda aleatoria con el mismo presupuesto
## ---------------------------------------------------------------------------
if (quiere("Fig3")) {
  cv <- leer("validation_convergence_curve.csv"); cc <- leer("validation_convergence_cutoff.csv")
  G <- leer("validation_convergence_chosen_cutoff.csv")$generations_main_runs[1]   # corte de las corridas principales
  cv <- merge(cv, cc[, c("arquitectura", "semilla", "hv_final")])
  cv$frac <- cv$hv_running_max / cv$hv_final
  cv$architecture <- arq(cv$arquitectura)
  cv <- cv[cv$generation %in% unique(round(10^seq(0, log10(1500), length.out = 220))), ]
  pa <- ggplot(cv, aes(generation, frac, colour = architecture, group = interaction(architecture, semilla))) +
    geom_hline(yintercept = c(0.95, 0.99), colour = "#BDBDBD", linewidth = 0.3, linetype = "22") +
    geom_vline(xintercept = G, colour = "#606060", linewidth = 0.35, linetype = "42") +
    geom_line(linewidth = 0.4, alpha = 0.9) + esc_col +
    annotate("text", x = G * 0.9, y = 0.83, label = sprintf("cutoff of the main runs (%d generations)", G), hjust = 1, size = 2.5, family = FAM, colour = "#404040") +
    scale_x_log10(breaks = c(1, 10, 100, 1000), labels = c("1", "10", "100", "1000")) +
    scale_y_continuous(breaks = seq(0.8, 1, 0.05)) + coord_cartesian(ylim = c(0.8, 1.0)) +
    labs(x = "generation (log scale)", y = "fraction of the final hypervolume") +
    guides(colour = guide_legend(nrow = 1, override.aes = list(linewidth = 0.8))) + tema()
  sr <- leer("validation_seed_runs.csv")
  sr$architecture <- arq(sr$arquitectura)
  sr$method <- factor(ifelse(sr$method == "random", "random search", "NSGA-III"), levels = c("NSGA-III", "random search"))
  pb <- ggplot(sr, aes(method, hv_validation)) +
    geom_boxplot(aes(fill = architecture, alpha = method), colour = "#606060", linewidth = 0.3, width = 0.62, outlier.shape = NA) +
    geom_point(aes(shape = architecture), position = position_jitter(width = 0.12, height = 0, seed = 3), size = 1.1,
               fill = "white", colour = "#404040", stroke = 0.3) +
    facet_wrap(~ architecture, scales = "free_y", nrow = 1) + esc_fill + esc_shape +
    scale_alpha_manual(values = c("NSGA-III" = 1, "random search" = 0.35), guide = "none") +
    scale_y_continuous(labels = function(v) sprintf("%.3f", v)) +
    labs(x = NULL, y = "validation hypervolume") + guides(fill = "none", shape = "none") +
    tema()
  p <- con_etiquetas((pa / pb) + plot_layout(heights = c(1, 1)))
  guardar(p, "Fig3.pdf", 174, 118)
}

## ---------------------------------------------------------------------------
## Fig. 4: frentes validados (agentes funcionales), proyecciones contra el costo
## ---------------------------------------------------------------------------
if (quiere("Fig4")) {
  fv <- leer("frentes_validados.csv"); fv <- fv[fv$funcional, ]
  REG <- c(limpio = "clean input", rafagas = "bursty input")
  OBJ <- c(error = "error rate", umbral = "fusion threshold (ms)", latencia = "access latency (ms)")
  desplaz <- ifelse(fv$arquitectura == "continua", 0.86, ifelse(fv$arquitectura == "continua_modulada", 1.16, 1))
  largo <- do.call(rbind, lapply(names(OBJ), function(o) data.frame(
    regime = factor(REG[fv$regimen], levels = REG), objective = factor(OBJ[o], levels = OBJ),
    architecture = arq(fv$arquitectura), x = fv$costo * desplaz, y = fv[[o]])))
  front <- escaleras(largo, c("regime", "objective", "architecture"), x_max = 1300)
  ptsf <- do.call(rbind, lapply(split(largo, largo[, c("regime", "objective", "architecture")], drop = TRUE), function(g)
    cbind(g[rep(1, nrow(frontera_2d(g$x, g$y))), c("regime", "objective", "architecture")], frontera_2d(g$x, g$y))))
  largo <- largo[order(largo$architecture == "event"), ]
  p <- ggplot(largo, aes(x, y)) +
    geom_point(aes(fill = architecture, shape = architecture), size = 1.0, colour = "#8A8A8A", stroke = 0.15, alpha = 0.45) +
    geom_step(data = front, aes(colour = architecture, group = architecture), direction = "hv", linewidth = 0.6) +
    geom_point(data = ptsf, aes(fill = architecture, shape = architecture), size = 1.5, colour = "#303030", stroke = 0.3) +
    facet_grid(objective ~ regime, scales = "free_y", switch = "y") + esc_fill + esc_shape + esc_col +
    scale_x_log10(breaks = c(0.1, 1, 10, 100, 1000), labels = c("0.1", "1", "10", "100", "1000")) +
    coord_cartesian(xlim = c(0.025, 1300)) +
    labs(x = "cost (reads per second, log scale)", y = NULL) +
    guides(fill = guide_legend(nrow = 1, override.aes = list(size = 2, alpha = 1)), shape = guide_legend(nrow = 1), colour = guide_legend(nrow = 1)) +
    tema() + theme(strip.placement = "outside", strip.text.y.left = element_text(angle = 90))
  guardar(p, "Fig4.pdf", 174, 125)
}

## ---------------------------------------------------------------------------
## Fig. 5: intervalos entre lecturas en el frente funcional
## ---------------------------------------------------------------------------
if (quiere("Fig5")) {
  fv <- leer("frentes_validados.csv"); fv <- fv[fv$funcional & fv$arquitectura != "continua", ]
  REG <- c(limpio = "clean input", rafagas = "bursty input")
  fv$intervalo <- ifelse(fv$arquitectura == "periodica", fv$T, ifelse(fv$arquitectura == "eventos", fv$r, fv$T_mod))
  fv$architecture <- arq(fv$arquitectura)
  fv$regime <- factor(REG[fv$regimen], levels = REG)
  etq <- c("event" = "event\nrefractory period r", "modulated continuous" = "modulated continuous\nmodulation period",
           periodic = "periodic\nreading period T")
  fv$panel <- factor(etq[as.character(fv$architecture)], levels = etq)
  cortes <- 10^seq(0, log10(250), length.out = 28)
  hist <- do.call(rbind, lapply(split(fv, list(fv$panel, fv$regime), drop = TRUE), function(d) {
    h <- hist(pmin(pmax(d$intervalo, 1), 250), breaks = cortes, plot = FALSE)
    data.frame(panel = d$panel[1], regime = d$regime[1], architecture = d$architecture[1],
               xmin = head(cortes, -1), xmax = cortes[-1], n = h$counts)
  }))
  hist <- hist[hist$n > 0, ]
  p <- ggplot(hist) +
    annotate("rect", xmin = 80, xmax = 125, ymin = -Inf, ymax = Inf, fill = "#EDEDED") +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = n, fill = architecture), colour = "#4A4A4A", linewidth = 0.2) +
    facet_grid(regime ~ panel) + esc_fill +
    scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 250)) + scale_y_continuous(expand = c(0, 0), limits = c(0, 108)) +
    labs(x = "interval (ms, log scale); grey band: alpha period, 80 to 125 ms", y = "number of front solutions") +
    guides(fill = "none") + tema()
  guardar(p, "Fig5.pdf", 174, 72)
}

## ---------------------------------------------------------------------------
## Fig. 6: sensibilidad. Fracción del frente combinado (agentes funcionales)
## ---------------------------------------------------------------------------
if (quiere("Fig6")) {
  COND <- c(base = "baseline", pulso_5 = "pulse 5 ms", pulso_20 = "pulse 20 ms", ruido_0.4 = "noise 0.4", ruido_0.9 = "noise 0.9", isi_corto = "ISI 5 to 70 ms")
  sf <- leer("sensibilidad_frentes.csv"); sf <- sf[sf$funcional, ]
  desplaz <- ifelse(sf$arquitectura == "continua", 0.86, ifelse(sf$arquitectura == "continua_modulada", 1.16, 1))
  d <- data.frame(condition = factor(COND[sf$condicion], levels = COND), architecture = arq(sf$arquitectura),
                  x = sf$costo * desplaz, y = sf$error)
  front <- escaleras(d, c("condition", "architecture"), x_max = 1300)
  ptsf <- do.call(rbind, lapply(split(d, d[, c("condition", "architecture")], drop = TRUE), function(g)
    cbind(g[rep(1, nrow(frontera_2d(g$x, g$y))), c("condition", "architecture")], frontera_2d(g$x, g$y))))
  pa <- ggplot(d, aes(x, y)) +
    geom_point(aes(fill = architecture, shape = architecture), size = 0.8, colour = "#8A8A8A", stroke = 0.15, alpha = 0.4) +
    geom_step(data = front, aes(colour = architecture, group = architecture), direction = "hv", linewidth = 0.55) +
    geom_point(data = ptsf, aes(fill = architecture, shape = architecture), size = 1.2, colour = "#303030", stroke = 0.25) +
    facet_wrap(~ condition, nrow = 2) + esc_fill + esc_shape + esc_col +
    scale_x_log10(breaks = c(0.1, 1, 10, 100, 1000), labels = c("0.1", "1", "10", "100", "1000")) +
    coord_cartesian(xlim = c(0.025, 1300)) +
    labs(x = "cost (reads per second, log scale)", y = "error rate") +
    guides(fill = guide_legend(nrow = 1, override.aes = list(size = 2, alpha = 1)), shape = guide_legend(nrow = 1), colour = guide_legend(nrow = 1)) + tema()
  sm <- leer("sensibilidad_metricas.csv"); sm <- sm[sm$subconjunto == "funcional", ]
  sm$condition <- factor(COND[sm$condicion], levels = COND)
  sm$architecture <- arq(sm$arquitectura)
  pb <- ggplot(sm, aes(condition, fraccion_frente_combinado, fill = architecture)) +
    geom_col(position = position_dodge(width = 0.82), width = 0.76, colour = "#4A4A4A", linewidth = 0.2) +
    esc_fill + scale_y_continuous(limits = c(0, 0.72), breaks = seq(0, 0.7, 0.1), expand = c(0, 0)) +
    labs(x = NULL, y = "share of the combined front") + guides(fill = "none") + tema()
  p <- con_etiquetas((pa / pb) + plot_layout(heights = c(1.55, 1), guides = "collect") & theme(legend.position = "bottom"))
  guardar(p, "Fig6.pdf", 174, 150)
}

## ---------------------------------------------------------------------------
## Fig. 10: ausencias
## ---------------------------------------------------------------------------
if (quiere("Fig10")) {
  au <- read.csv(file.path(R, "resultados", "ausencias_corregidas", "ausencias.csv"))
  au$architecture <- arq(au$arquitectura)
  au$condition <- factor(ifelse(au$cambio_sensorial, "sensory change during the gap", "no sensory change"),
                         levels = c("no sensory change", "sensory change during the gap"))
  p <- ggplot(au, aes(architecture, fraccion_huecos_detectados, fill = architecture, alpha = condition)) +
    geom_col(position = position_dodge(width = 0.78), width = 0.72, colour = "#4A4A4A", linewidth = 0.2) +
    geom_text(aes(label = sprintf("%.3f", fraccion_huecos_detectados), group = condition), position = position_dodge(width = 0.78),
              vjust = -0.5, size = 2.4, family = FAM, colour = "#303030", alpha = 1) +
    esc_fill + scale_alpha_manual(values = c("no sensory change" = 0.35, "sensory change during the gap" = 1), name = NULL) +
    scale_y_continuous(limits = c(0, 0.5), expand = c(0, 0)) +
    labs(x = NULL, y = "fraction of gaps detected") +
    guides(fill = "none", alpha = guide_legend(nrow = 2, override.aes = list(fill = "#A0A0A0"))) +
    tema() + theme(axis.text.x = element_text(angle = 20, hjust = 1))
  guardar(p, "Fig10.pdf", 84, 70)
}

## ---------------------------------------------------------------------------
## Fig. 12: fracción del frente combinado por semilla
## ---------------------------------------------------------------------------
if (quiere("Fig12")) {
  cf <- leer("validation_seed_combined_front.csv")
  cf$architecture <- arq(cf$arquitectura)
  p <- ggplot(cf, aes(factor(semilla), share_combined_front, fill = architecture)) +
    geom_col(width = 0.78, colour = "#4A4A4A", linewidth = 0.2) + esc_fill +
    scale_y_continuous(expand = c(0, 0), limits = c(0, 1.0001)) +
    labs(x = "seed", y = "share of the combined front") + guides(fill = guide_legend(nrow = 1)) + tema()
  guardar(p, "Fig12.pdf", 174, 62)   # fracción del frente por semilla
}

## ---------------------------------------------------------------------------
## Fig. 11: parametrización. Rango medio de Friedman por configuración
## ---------------------------------------------------------------------------
if (quiere("Fig11")) {
  ta <- read.csv(file.path(R, "estadistica", "A_parametrizacion_rangos.csv"))
  ta$pc <- sub(".*pc=([0-9.]+) .*", "\\1", ta$config); ta$pm <- sub(".*pm=([0-9.]+)", "\\1", ta$config)
  ta$pop <- factor(sprintf("population %d", ta$popSize), levels = sprintf("population %d", c(52, 88, 132)))
  ta$elegida <- ta$config == "N=132 pc=0.8 pm=0.20"
  p <- ggplot(ta, aes(pc, pm, fill = rango_medio)) +
    geom_tile(colour = "white", linewidth = 0.6) +
    geom_text(aes(label = sprintf("%.1f", rango_medio), fontface = ifelse(elegida, "bold", "plain")), size = 2.6, family = FAM, colour = "#202020") +
    facet_wrap(~ pop, nrow = 1) +
    scale_fill_gradient(low = "#A7C7E7", high = "#F7F2EA", name = "mean Friedman rank (lower is better)") +
    labs(x = "crossover probability", y = "mutation probability") +
    guides(fill = guide_colourbar(barwidth = unit(40, "mm"), barheight = unit(2.5, "mm"), title.position = "top")) + tema()
  guardar(p, "Fig11.pdf", 174, 62)   # parametrización
}

## ---------------------------------------------------------------------------
## Fig. 16: Haarlem, IAF prestímulo en ensayos correctos e incorrectos
## ---------------------------------------------------------------------------
if (quiere("Fig16")) {
  suppressPackageStartupMessages(library(readxl))
  b <- as.data.frame(read_excel(file.path(R, "..", "datos_reales", "haarlem_2024", "iaf_longformat.xlsx")))
  l <- rbind(data.frame(sensor = "sensor C16", cond = b$Condition, t = b$Time, iaf = b$C16, se = b$C16_SE),
             data.frame(sensor = "sensor B7", cond = b$Condition, t = b$Time, iaf = b$B7, se = b$B7_SE))
  l$condition <- factor(ifelse(l$cond == "Correct", "correct trials", "incorrect trials"), levels = c("correct trials", "incorrect trials"))
  pal <- c("correct trials" = "#A7C7E7", "incorrect trials" = "#F4A6A6"); pal2 <- c("correct trials" = "#5F8DBF", "incorrect trials" = "#C0605F")
  p <- ggplot(l, aes(t, iaf, colour = condition, fill = condition)) +
    geom_ribbon(aes(ymin = iaf - se, ymax = iaf + se), alpha = 0.35, colour = NA) +
    geom_line(linewidth = 0.45) + facet_wrap(~ sensor) +
    scale_colour_manual(values = pal2, name = NULL) + scale_fill_manual(values = pal, name = NULL) +
    labs(x = "time relative to stimulus onset (ms)", y = "instantaneous alpha frequency (Hz)") + tema()
  guardar(p, "Fig16.pdf", 174, 62)   # IAF prestímulo de Haarlem
}

## ---------------------------------------------------------------------------
## Fig. 14: periodo ajustado contra 1000/IAF en los datos sintéticos
## ---------------------------------------------------------------------------
if (quiere("Fig14")) {
  ap <- leer("ajuste_participantes.csv")
  per <- ap[ap$arquitectura %in% c("periodica", "continua_modulada") & grepl("^sintetico", ap$dataset), ]
  per$periodo <- ifelse(per$arquitectura == "periodica", per$T_ajustado, per$T_mod_ajustado)
  GEN <- c(sintetico_continua = "continuous", sintetico_eventos = "event", sintetico_continua_modulada = "modulated continuous", sintetico_periodica = "periodic")
  per$generator <- factor(GEN[per$dataset], levels = ARQ_LEV)
  per$fitted <- factor(ifelse(per$arquitectura == "periodica", "fitted periodic reader: period T", "fitted modulated reader: modulation period"),
                       levels = c("fitted periodic reader: period T", "fitted modulated reader: modulation period"))
  p <- ggplot(per, aes(1000 / iaf, periodo, fill = generator, shape = generator)) +
    geom_abline(slope = 1, intercept = 0, linetype = "22", colour = "#808080", linewidth = 0.3) +
    geom_point(size = 1.7, colour = "#404040", stroke = 0.3) + facet_wrap(~ fitted) +
    scale_fill_manual(values = FILL, name = "generator") + scale_shape_manual(values = SHAPE, name = "generator") +
    scale_y_log10() + labs(x = "1000 / IAF of the synthetic participant (ms)", y = "fitted period (ms, log scale)") +
    guides(fill = guide_legend(nrow = 1), shape = guide_legend(nrow = 1)) + tema()
  guardar(p, "Fig14.pdf", 174, 66)   # periodo ajustado en datos sintéticos
}

## ---------------------------------------------------------------------------
## Fig. 7: identificabilidad. (a) matriz de recuperación, (b) mimetismo,
## (c) arquitectura con menor AIC en Deodato y Melcher con las dos lecturas
## ---------------------------------------------------------------------------
if (quiere("Fig7")) {
  ABR <- c(continuous = "C", "event" = "E", "modulated continuous" = "M", periodic = "P")
  rc <- leer("recuperacion_modelos.csv"); rc4 <- leer("recuperacion_modelos_margen4.csv")
  GEN <- c(sintetico_continua = "continua", sintetico_eventos = "eventos", sintetico_continua_modulada = "continua_modulada", sintetico_periodica = "periodica")
  m <- do.call(rbind, lapply(names(GEN), function(d) do.call(rbind, lapply(ARQ_ES, function(a)
    data.frame(generator = ARQ_LEV[GEN[d]], fitted = ARQ_LEV[a], n = rc[rc$dataset == d, a], n4 = rc4[rc4$dataset == d, a])))))
  m$generator <- factor(m$generator, levels = rev(ARQ_LEV)); m$fitted <- factor(m$fitted, levels = ARQ_LEV)
  m$lab <- sprintf("%d (%d)", m$n, m$n4)
  m$diag <- as.character(m$generator) == as.character(m$fitted)
  pa <- ggplot(m, aes(fitted, generator, fill = n)) +
    geom_tile(colour = "white", linewidth = 0.8) +
    geom_tile(data = m[m$diag, ], fill = NA, colour = "#505050", linewidth = 0.5) +
    geom_text(aes(label = lab), size = 2.6, family = FAM, colour = "#202020") +
    scale_fill_gradient(low = "#F7F4EF", high = "#A7C7E7", limits = c(0, 12)) +
    scale_x_discrete(labels = ABR) + scale_y_discrete(labels = ABR) +
    labs(x = "lowest AIC", y = "generator") + guides(fill = "none") + tema()
  mi <- read.csv(file.path(R, "resultados", "mimetismo.csv"))
  mi$generator <- factor(ABR[as.character(arq(mi$generador))], levels = rev(ABR))
  mi$delta <- mi$aic_verdadero - mi$aic_mejor_alternativa
  mi$recortado <- mi$delta < -20
  mi$delta_v <- pmax(mi$delta, -20)
  mi$alternative <- arq(mi$arq_mejor_alternativa)
  pb <- ggplot(mi, aes(delta_v, generator)) +
    annotate("rect", xmin = 0, xmax = Inf, ymin = -Inf, ymax = Inf, fill = "#F3EEF8") +
    geom_vline(xintercept = 0, linetype = "22", colour = "#606060", linewidth = 0.35) +
    geom_point(aes(fill = alternative, shape = alternative), size = 1.7, colour = "#404040", stroke = 0.3,
               position = position_jitter(height = 0.17, width = 0, seed = 2)) +
    esc_fill + esc_shape + scale_x_continuous(limits = c(-21, 16), breaks = c(-20, -10, 0, 10)) +
    annotate("text", x = 15.5, y = 4.45, label = "mimicry", hjust = 1, size = 2.4, family = FAM, colour = "#5E4A7A") +
    labs(x = "AIC of the true generator minus\nAIC of the best competitor", y = NULL) +
    guides(fill = guide_legend(title = "best competitor", ncol = 2, title.position = "top"), shape = guide_legend(title = "best competitor", ncol = 2, title.position = "top")) +
    tema() + theme(legend.text = element_text(size = 6.5))
  dm1 <- leer("ajuste_participantes.csv"); dm1 <- dm1[dm1$dataset == "deodato_melcher_2024", ]
  dm2 <- read.csv(file.path(R, "resultados", "ajuste_deodato_pausa.csv"))
  cuenta <- function(d, lectura) do.call(rbind, lapply(ARQ_ES, function(a) data.frame(reading = lectura, architecture = ARQ_LEV[a],
    tipo = c("decisive", "not decisive"),
    n = c(sum(d$mejor & d$distinguible & d$arquitectura == a), sum(d$mejor & !d$distinguible & d$arquitectura == a)))))
  cc <- rbind(cuenta(dm2, "ISI as\nblank gap"), cuenta(dm1, "ISI as onset\nasynchrony"))
  cc$architecture <- factor(cc$architecture, levels = ARQ_LEV)
  cc$reading <- factor(cc$reading, levels = c("ISI as\nblank gap", "ISI as onset\nasynchrony"))
  cc$tipo <- factor(cc$tipo, levels = c("not decisive", "decisive"))
  pc <- ggplot(cc, aes(architecture, n, fill = architecture, alpha = tipo)) +
    geom_col(width = 0.72, colour = "#4A4A4A", linewidth = 0.2) + facet_wrap(~ reading) +
    esc_fill + scale_alpha_manual(values = c("not decisive" = 0.35, "decisive" = 1), name = "AIC margin of 4 or more") +
    scale_x_discrete(labels = ABR) + scale_y_continuous(expand = c(0, 0), limits = c(0, 25)) +
    labs(x = "lowest AIC", y = "participants") +
    guides(fill = "none", alpha = guide_legend(ncol = 1, title.position = "top", override.aes = list(fill = "#A0A0A0"))) + tema()
  p <- con_etiquetas((pa | pb | pc) + plot_layout(widths = c(0.95, 1.05, 1.0)))
  guardar(p, "Fig7.pdf", 174, 78)
}

## ---------------------------------------------------------------------------
## Fig. 8: curvas psicométricas de Deodato y Melcher (ISI como pausa) y las
## de cada arquitectura con sus parámetros ajustados
## ---------------------------------------------------------------------------
if (quiere("Fig8")) {
  suppressMessages(source(file.path(R, "cargar_funciones.R"), encoding = "UTF-8", chdir = TRUE))
  dm <- normalizar_datos(read.csv(file.path(R, "..", "datos_reales", "deodato_melcher_2024", "deodato_melcher_2024_ensayos.csv")))
  dm <- dm[dm$incluido == 1, ]
  aj <- read.csv(file.path(R, "resultados", "ajuste_deodato_pausa.csv"))
  obs <- aggregate(respuesta == 2 ~ participante + isi, data = dm[dm$n_pulsos == 2, ], FUN = mean); names(obs)[3] <- "p_dos"
  isis_rep <- sort(unique(obs$isi)); cfg2 <- CFG; cfg2$isis <- isis_rep + CFG$pulso_dur
  banco <- crear_banco(60, 60, cfg2, "limpio", semilla = 4242)
  sim <- do.call(rbind, lapply(seq_len(nrow(aj)), function(i) {
    r <- aj[i, ]; a <- r$arquitectura
    th <- c(tau = r$tau, theta_p = r$theta_p, m = r$m, w = r$w, T = r$T_ajustado, theta_g = r$theta_g_ajustado, r = r$r_ajustado,
            A_mod = r$A_mod_ajustado, T_mod = r$T_mod_ajustado)[nombres_theta(a)]
    s <- simular_agente(th, a, banco, cfg2); s <- s[s$n_pulsos == 2, ]
    p <- tapply(s$respuesta == 2, s$isi, mean)
    data.frame(participante = r$participante, arquitectura = a, isi = as.numeric(names(p)) - CFG$pulso_dur, p_dos = as.numeric(p))
  }))
  ee <- function(v) sd(v) / sqrt(length(v))
  om <- aggregate(p_dos ~ isi, data = obs, FUN = mean); om$ee <- aggregate(p_dos ~ isi, data = obs, FUN = ee)$p_dos
  sm <- aggregate(p_dos ~ isi + arquitectura, data = sim, FUN = mean); sm$architecture <- arq(sm$arquitectura)
  comp <- merge(obs, sim, by = c("participante", "isi"), suffixes = c("_obs", "_sim"))
  ecm <- aggregate((p_dos_obs - p_dos_sim)^2 ~ arquitectura, data = comp, FUN = mean); names(ecm)[2] <- "ecm"
  write.csv(ecm, file.path(R, "resultados", "ecm_curva_deodato_pausa.csv"), row.names = FALSE); print(ecm)
  p <- ggplot() +
    geom_ribbon(data = om, aes(isi, ymin = p_dos - ee, ymax = p_dos + ee), fill = "#D9D9D9") +
    geom_line(data = om, aes(isi, p_dos), colour = "#202020", linewidth = 0.6) +
    geom_point(data = om, aes(isi, p_dos), colour = "#202020", size = 1.4) +
    geom_line(data = sm, aes(isi, p_dos, colour = architecture), linewidth = 0.55) +
    geom_point(data = sm, aes(isi, p_dos, fill = architecture, shape = architecture), size = 1.5, colour = "#404040", stroke = 0.25) +
    esc_col + esc_fill + esc_shape + scale_y_continuous(limits = c(0, 1)) + scale_x_continuous(breaks = isis_rep) +
    labs(x = "ISI, blank gap between flashes (ms)", y = "P(\"two\" response)") +
    guides(colour = guide_legend(nrow = 2), fill = guide_legend(nrow = 2), shape = guide_legend(nrow = 2)) + tema()
  guardar(p, "Fig8.pdf", 84, 80)
}

## ---------------------------------------------------------------------------
## Fig. 9: Haarlem. Cota inferior del umbral de un lector periódico en el
## paradigma de los autores y umbrales observados en su periodo alfa
## ---------------------------------------------------------------------------
if (quiere("Fig9")) {
  cota <- read.csv(file.path(R, "resultados", "cota_haarlem_final.csv")); cota <- cota[!cota$censurado, ]
  hp <- leer("haarlem_participantes.csv")
  hp$T_max <- approx(cota$umbral_cota, cota$T, xout = hp$umbral_ms, ties = max, rule = 2)$y
  write.csv(hp[, c("participante", "umbral_ms", "periodo_reposo_ms", "periodo_prestim_ms", "T_max")], file.path(R, "resultados", "haarlem_T_max.csv"), row.names = FALSE)
  pa <- ggplot() +
    geom_ribbon(data = cota, aes(T, ymin = umbral_cota, ymax = 150), fill = "#DCE8F4") +
    geom_line(data = cota, aes(T, umbral_cota), colour = "#5F8DBF", linewidth = 0.6) +
    geom_point(data = cota, aes(T, umbral_validado), shape = 4, colour = "#5F8DBF", size = 1.3, stroke = 0.4) +
    geom_point(data = hp, aes(periodo_reposo_ms, umbral_ms), shape = 21, fill = "#F4A6A6", colour = "#404040", size = 1.6, stroke = 0.3) +
    annotate("text", x = 14, y = 128, label = "thresholds reachable by a\nperiodic reader with period T", hjust = 0, size = 2.4, family = FAM, colour = "#3A5F86") +
    annotate("text", x = 118, y = 146, label = "T = 120 ms: 75% never reached", hjust = 1, vjust = 1, size = 2.2, family = FAM, colour = "#3A5F86") +
    annotate("text", x = 75, y = 22, label = "participants at their\nresting alpha period", hjust = 1, size = 2.4, family = FAM, colour = "#8A3E3E") +
    scale_x_continuous(limits = c(10, 125), breaks = seq(20, 120, 20)) + scale_y_continuous(limits = c(0, 150), expand = c(0, 0)) +
    labs(x = "period T or alpha period, 1000 / IAF (ms)", y = "two-flash threshold, blank ISI (ms)") + tema()
  l <- rbind(data.frame(participante = hp$participante, tipo = "resting alpha period", v = hp$periodo_reposo_ms),
             data.frame(participante = hp$participante, tipo = "longest compatible period", v = hp$T_max))
  l$tipo <- factor(l$tipo, levels = c("longest compatible period", "resting alpha period"))
  orden <- hp$participante[order(hp$T_max)]
  l$participante <- factor(l$participante, levels = orden)
  pb <- ggplot(l, aes(v, participante)) +
    geom_line(aes(group = participante), colour = "#BDBDBD", linewidth = 0.3) +
    geom_point(aes(fill = tipo, shape = tipo), size = 1.5, colour = "#404040", stroke = 0.3) +
    scale_fill_manual(values = c("longest compatible period" = "#A7C7E7", "resting alpha period" = "#F4A6A6"), name = NULL) +
    scale_shape_manual(values = c("longest compatible period" = 24, "resting alpha period" = 21), name = NULL) +
    scale_x_continuous(limits = c(20, 125)) +
    labs(x = "period (ms)", y = "participant") +
    guides(fill = guide_legend(nrow = 2), shape = guide_legend(nrow = 2)) + tema() + theme(axis.text.y = element_text(size = 5.5))
  p <- con_etiquetas((pa | pb) + plot_layout(widths = c(1.25, 1)))
  guardar(p, "Fig9.pdf", 174, 82)
}

## ---------------------------------------------------------------------------
## Fig. 15: Deodato y Melcher (ISI como pausa), AIC relativo por participante
## ---------------------------------------------------------------------------
if (quiere("Fig15")) {
  aj <- read.csv(file.path(R, "resultados", "ajuste_deodato_pausa.csv"))
  aj$architecture <- arq(aj$arquitectura)
  p <- ggplot(aj, aes(participante, pmin(delta_aic, 60), fill = architecture)) +
    geom_col(position = position_dodge(width = 0.85), width = 0.8, colour = "#4A4A4A", linewidth = 0.1) +
    esc_fill + scale_y_continuous(expand = c(0, 0), limits = c(0, 61)) +
    labs(x = "participant", y = "AIC minus the lowest AIC of the participant\n(truncated at 60)") +
    guides(fill = guide_legend(nrow = 1)) + tema() + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 5.5))
  guardar(p, "Fig15.pdf", 174, 66)   # AIC por participante
}

## ---------------------------------------------------------------------------
## Fig. 13: fronteras de error contra costo de NSGA-III y de la búsqueda
## aleatoria (11 semillas juntas, agentes funcionales)
## ---------------------------------------------------------------------------
if (quiere("Fig13")) {
  sf <- leer("validation_seed_fronts.csv")
  sf <- sf[sf$umbral < 300, ]
  base <- data.frame(architecture = arq(sf$arquitectura), method = factor(ifelse(sf$metodo == "random", "random search", "NSGA-III"), levels = c("NSGA-III", "random search")))
  pares <- list(c("costo", "cost (reads per second, log scale)"), c("latencia", "access latency (ms, log scale)"))
  hacer <- function(var, etiqueta, arqs) {
    d <- cbind(base, x = if (var == "latencia") pmax(sf[[var]], 0.5) else sf[[var]], y = sf$error)[base$architecture %in% arqs, ]
    d$architecture <- droplevels(d$architecture)
    front <- do.call(rbind, lapply(split(d, d$architecture, drop = TRUE), function(g)   # cada panel termina en su propio costo máximo
      escaleras(g, c("architecture", "method"), x_max = max(g$x) * 1.2)))
    ptsf <- do.call(rbind, lapply(split(d, d[, c("architecture", "method")], drop = TRUE), function(g)
      cbind(g[rep(1, nrow(frontera_2d(g$x, g$y))), c("architecture", "method")], frontera_2d(g$x, g$y))))
    ggplot(front, aes(x, y)) +
      geom_step(aes(linetype = method, colour = method, group = method), direction = "hv", linewidth = 0.55) +
      geom_point(data = ptsf, aes(shape = method, fill = method), size = 1.2, colour = "#303030", stroke = 0.25) +
      facet_wrap(~ architecture, nrow = 1, scales = "free_x") +
      scale_colour_manual(values = c("NSGA-III" = "#5F8DBF", "random search" = "#8A8A8A"), name = NULL) +
      scale_fill_manual(values = c("NSGA-III" = "#A7C7E7", "random search" = "#D9D9D9"), name = NULL) +
      scale_shape_manual(values = c("NSGA-III" = 21, "random search" = 24), name = NULL) +
      scale_linetype_manual(values = c("NSGA-III" = "solid", "random search" = "22"), name = NULL) +
      scale_x_log10(labels = function(v) format(v, drop0trailing = TRUE, scientific = FALSE, trim = TRUE)) +
      labs(x = etiqueta, y = "error rate") + tema() + theme(panel.spacing.x = unit(5, "mm"))
  }
  pa <- hacer("costo", "cost (reads per second, log scale)", c("event", "periodic"))
  pb <- hacer("latencia", "access latency (ms, log scale)", ARQ_LEV)
  p <- con_etiquetas((pa / pb) + plot_layout(heights = c(1, 1), guides = "collect") & theme(legend.position = "bottom"))
  guardar(p, "Fig13.pdf", 174, 118)   # fronteras NSGA-III frente a búsqueda aleatoria
}
