# =============================================================================
# 04_resultados.R
# Resume los resultados y genera las figuras del artículo:
#   - medias por signo y modelo (experimento principal, dataset completo, Ofiuco)
#   - prueba de Wilcoxon de una cola del ROC-AUC contra 0,5, por modelo
#   - análisis de sensibilidad al tamaño de muestra (árbol de decisión)
#   - conteo de variables del filtro chi-cuadrado, con y sin Bonferroni
#   - figuras en PDF
#
# Sirve tanto para la salida de 03_modelos.R como para la carpeta 4_results del
# repositorio original, que tiene la misma estructura:
#   Rscript 04_resultados.R                      (usa CFG$dir_resultados)
#   Rscript 04_resultados.R Tesis_ML_Zodiac/4_results
# =============================================================================

source("00_funciones.R")

arg <- commandArgs(trailingOnly = TRUE)
RES <- if (length(arg) > 0) arg[1] else CFG$dir_resultados
SAL <- dir_crear(RES, "resumen")

# Lee un archivo de detalle y deja el signo sin el prefijo "signo_zodiacal_".
leer_detalle <- function(...) {
  ruta <- file.path(RES, ...)
  if (!file.exists(ruta)) { message("No está: ", ruta); return(NULL) }
  d <- fread(ruta)
  d[, signo := sub("^signo_zodiacal_", "", signo)]
  d[, modelo := sub("_full$", "", modelo)]
  d[]
}

principal <- rbindlist(lapply(MODELOS, function(m)
  leer_detalle(paste0("modelo_", m), paste0(m, "_detalle.csv"))), fill = TRUE)
completo <- rbindlist(lapply(MODELOS, function(m)
  leer_detalle(paste0("modelo_", m, "_full_dataset"), paste0(m, "_full_detalle.csv"))), fill = TRUE)
ofiuco <- rbindlist(lapply(MODELOS, function(m)
  leer_detalle("Ofiuco", paste0("modelo_", m), paste0(m, "_detalle.csv"))), fill = TRUE)
TAMANOS <- c(10, 50, 100, 150, 200, 500, 1000)
sens <- rbindlist(lapply(TAMANOS, function(n) {
  d <- leer_detalle("modelo_dt_sensibilidad_n", sprintf("dt_detalle_n%d.csv", n))
  if (!is.null(d)) d[, n_sample := n]
  d
}), fill = TRUE)

# --- Medias por signo y modelo -------------------------------------------------
medias <- function(d) d[, .(accuracy = mean(cv_accuracy), precision = mean(cv_precision),
                            recall = mean(cv_recall), f1 = mean(cv_f1),
                            roc_auc = mean(cv_roc_auc, na.rm = TRUE)), keyby = .(modelo, signo)]
for (nm in c("principal", "completo", "ofiuco")) {
  d <- get(nm)
  if (nrow(d) > 0) fwrite(medias(d), file.path(SAL, sprintf("medias_%s.csv", nm)))
}

# --- Wilcoxon de una cola (ROC-AUC > 0,5) por modelo ---------------------------
# Aproximación normal sin corrección de continuidad, descartando diferencias
# nulas (como scipy.stats.wilcoxon con alternative = "greater"). El AUC de cada
# pliegue toma valores discretos, así que se redondea a 6 decimales antes de la
# prueba: sin eso, el ruido de punto flotante rompe empates y ceros reales y
# cambia el resultado. Se informa también el p corregido por Bonferroni.
wilcoxon <- principal[!is.na(cv_roc_auc), {
  auc <- round(cv_roc_auc, 6)
  w <- wilcox.test(auc, mu = 0.5, alternative = "greater", exact = FALSE, correct = FALSE)
  .(n = .N, n_sin_empates_en_05 = sum(auc != 0.5), media = mean(auc), mediana = median(auc),
    de = sd(auc), sobre_05 = mean(auc > 0.5), estadistico_V = unname(w$statistic),
    p_value = w$p.value)
}, keyby = modelo]
wilcoxon[, p_bonferroni := pmin(1, p_value * .N)]
fwrite(wilcoxon, file.path(SAL, "wilcoxon.csv"))
print(wilcoxon)

# --- Sensibilidad al tamaño de la muestra --------------------------------------
if (nrow(sens) > 0) {
  sens_res <- sens[, .(media_auc = mean(cv_roc_auc, na.rm = TRUE),
                       de_auc = sd(cv_roc_auc, na.rm = TRUE)), keyby = n_sample]
  fwrite(sens_res, file.path(SAL, "sensibilidad.csv"))
  print(sens_res)
}

# --- Filtro chi-cuadrado ---------------------------------------------------------
# Acepta la salida de 02_chi_cuadrado.R o el archivo del repositorio original.
ruta_chi <- c(file.path(RES, "chi2_12.csv"), file.path(RES, "v2_chi2_resultados.csv"))
ruta_chi <- ruta_chi[file.exists(ruta_chi)][1]
chi <- fread(ruta_chi)
chi[, bonf := p_value < CFG$alfa_chi2 / .N]
familias <- chi[, .(total = .N, p_001 = sum(p_value < CFG$alfa_chi2), bonferroni = sum(bonf)),
                keyby = familia]
fwrite(familias, file.path(SAL, "chi2_familias.csv"))
print(familias)

# =============================================================================
# Figuras
# =============================================================================
# Las figuras se guardan al tamaño final del artículo (una columna mide 3,1
# pulgadas y el ancho completo 6,5), para que el texto no se reduzca al insertarlas.
TEMA <- theme_minimal(base_size = 8, base_family = "sans") +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "grey90", linewidth = 0.3),
        strip.text = element_text(face = "bold", size = 8),
        axis.text = element_text(size = 7, colour = "grey25"),
        axis.title = element_text(size = 8), legend.position = "none",
        plot.margin = margin(4, 6, 4, 4))
AZUL <- "#2a78d6"; NARANJA <- "#eb6834"; VERDE <- "#1baf7a"

# Figura 1: p-values del filtro chi-cuadrado por familia de variables. Entre
# paréntesis, cuántas variables de cada familia pasan p < 0,01.
etiqueta_fam <- c(ESPECIALIDAD_MEDICA = "Specialty", DIAGNOSTICO = "Diagnoses",
                  PROCEDIMIENTO = "Procedures")
cuentas <- chi[, .(n = .N, sig = sum(p_value < CFG$alfa_chi2)), keyby = familia]
eje <- setNames(sprintf("%s\n(%d of %s)", etiqueta_fam[cuentas$familia], cuentas$sig,
                        prettyNum(cuentas$n, big.mark = ",")), cuentas$familia)
chi[, fam := factor(eje[familia], levels = eje[names(etiqueta_fam)])]
chi[, mlog := pmin(-log10(pmax(p_value, 1e-300)), 300)]
umbrales <- data.table(y = -log10(c(CFG$alfa_chi2, CFG$alfa_chi2 / nrow(chi))),
                       txt = c("p = 0.01", "Bonferroni"), tipo = c("dashed", "dotted"))
set.seed(1)
g1 <- ggplot(chi, aes(fam, mlog, colour = fam)) +
  geom_hline(data = umbrales, aes(yintercept = y, linetype = tipo), linewidth = 0.4, colour = "grey30") +
  geom_jitter(width = 0.32, height = 0, size = 0.6, alpha = 0.55, shape = 16) +
  geom_text(data = umbrales, aes(x = 3.55, y = y, label = txt), inherit.aes = FALSE,
            hjust = 0, size = 2.4, colour = "grey30") +
  scale_colour_manual(values = c(AZUL, NARANJA, VERDE)) +
  scale_linetype_identity() +
  scale_y_continuous(trans = scales::pseudo_log_trans(base = 10),
                     breaks = c(0, 1, 2, 5, 10, 30, 100, 300)) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = expression(-log[10](p))) + TEMA +
  theme(plot.margin = margin(4, 40, 4, 4))
ggsave(file.path(SAL, "fig_chi2.pdf"), g1, width = 3.1, height = 2.6, device = cairo_pdf)

# Figura 2: distribución del ROC-AUC por iteración, por signo y modelo. El
# recorte del eje se hace con coord_cartesian para no descartar datos al
# calcular las cajas.
if (nrow(principal) > 0) {
  d2 <- copy(principal)
  # Nombres en dos líneas para que quepan en el encabezado de cada panel.
  nombre_panel <- sub("k-nearest ", "k-nearest\n", sub("vector ", "vector\n", NOMBRE_MODELO))
  d2[, Modelo := factor(nombre_panel[modelo], levels = nombre_panel)]
  d2[, Signo := factor(NOMBRE_SIGNO[signo], levels = rev(sort(unique(NOMBRE_SIGNO[signo]))))]
  g2 <- ggplot(d2, aes(cv_roc_auc, Signo)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", linewidth = 0.4, colour = "grey30") +
    geom_boxplot(width = 0.6, outlier.shape = NA, linewidth = 0.3, colour = AZUL,
                 fill = "#2a78d61f", coef = 1.5) +
    stat_summary(fun = mean, geom = "point", size = 0.9, colour = NARANJA) +
    facet_wrap(~ Modelo, nrow = 1) +
    scale_x_continuous(breaks = c(0.3, 0.5, 0.7)) +
    coord_cartesian(xlim = c(0.25, 0.75)) +
    labs(x = sprintf("ROC-AUC per bootstrap iteration (%d per sign)", uniqueN(d2$iter)),
         y = NULL) + TEMA
  ggsave(file.path(SAL, "fig_auc.pdf"), g2, width = 6.5, height = 2.6, device = cairo_pdf)
}

# Figura 3: sensibilidad del árbol de decisión al tamaño de la muestra. El
# panel (a) usa una escala de 0,45 a 0,55 para no exagerar variaciones mínimas.
if (nrow(sens) > 0) {
  d3 <- rbind(sens_res[, .(n_sample, valor = media_auc, panel = "(a) Mean ROC-AUC")],
              sens_res[, .(n_sample, valor = de_auc, panel = "(b) SD of ROC-AUC")])
  limites <- data.table(n_sample = 100, valor = c(0.45, 0.55, 0, 0.19),
                        panel = rep(c("(a) Mean ROC-AUC", "(b) SD of ROC-AUC"), each = 2))
  ref <- data.table(panel = "(a) Mean ROC-AUC", valor = 0.5)
  g3 <- ggplot(d3, aes(n_sample, valor)) +
    geom_blank(data = limites) +
    geom_hline(data = ref, aes(yintercept = valor), linetype = "dashed", linewidth = 0.4, colour = "grey30") +
    geom_line(colour = AZUL, linewidth = 0.6) +
    geom_point(colour = AZUL, size = 1.4) +
    geom_point(data = d3[n_sample == CFG$n_muestra], colour = NARANJA, size = 2.4, shape = 18) +
    geom_text(data = d3[n_sample == CFG$n_muestra], aes(label = "n = 100"), colour = "grey15",
              size = 2.4, vjust = -1.2) +
    facet_wrap(~ panel, scales = "free_y") +
    scale_x_log10(breaks = c(10, 50, 100, 200, 500, 1000)) +
    labs(x = "Bootstrap sample size (log scale)", y = NULL) + TEMA
  ggsave(file.path(SAL, "fig_sensibilidad.pdf"), g3, width = 6.5, height = 1.85, device = cairo_pdf)
}
message("Resúmenes y figuras en ", SAL)
