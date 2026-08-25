# =============================================================================
# 10_estadistica_nivel.R : contrastes por nivel sobre la tabla maestra.
#   Kruskal-Wallis + Dunn (Holm) + epsilon2, delta de Cliff en extremos,
#   Jonckheere-Terpstra por permutacion, GAM por metrica, GAM mixto a nivel
#   de oracion para la polaridad, y sensibilidad sin libros duplicados.
# =============================================================================

set.seed(config$semilla)

# --- tabla maestra -----------------------------------------------------------
maestra <- P$catalogo %>%
  dplyr::select(id_libro, titulo, titulo_norm, nivel, etapa, n_palabras,
                titulo_duplicado, contenido_duplicado) %>%
  dplyr::left_join(P$comp_libro, by = c("id_libro" = "doc_id")) %>%
  dplyr::left_join(P$gram_libro, by = c("id_libro" = "doc_id")) %>%
  dplyr::left_join(P$afect_libro, by = c("id_libro" = "doc_id"))
guardar_tabla(maestra, "metricas_maestras_por_libro")
P$maestra <- maestra

metricas <- intersect(config$metricas_kw, colnames(maestra))
omitidas <- setdiff(config$metricas_kw, metricas)
if (length(omitidas) > 0)
  log_msg("Metricas no presentes en la maestra (omitidas): ",
          paste(omitidas, collapse = ", "))

correr_bateria <- function(datos, sufijo) {
  kw_out <- list(); dunn_out <- list()
  for (m in metricas) {
    x <- datos[[m]]; g <- factor(datos$nivel)
    ok <- !is.na(x)
    if (sum(ok) < 10 || length(unique(g[ok])) < 3) next
    kw <- stats::kruskal.test(x[ok], g[ok])
    H <- unname(kw$statistic)
    jt <- jt_test(x[ok], datos$nivel[ok], B = config$jt_perm,
                  semilla = config$semilla)
    n1 <- datos$nivel == 1; n12 <- datos$nivel == 12
    pri <- datos$nivel <= 4; med <- datos$nivel >= 9
    kw_out[[m]] <- data.frame(
      metrica = m, H = H, gl = unname(kw$parameter), p_kw = kw$p.value,
      epsilon2 = epsilon_cuadrado(H, sum(ok)),
      jt_J = jt$J, jt_p = jt$p, jt_direccion = jt$direccion,
      cliff_1_vs_12 = cliff_delta(x[n1], x[n12]),
      cliff_basica_ini_vs_media = cliff_delta(x[pri], x[med]))
    if (kw$p.value < 0.05)
      dunn_out[[m]] <- dunn_manual(x[ok], g[ok]) %>%
        dplyr::mutate(metrica = m, .before = 1) %>%
        dplyr::filter(p_ajustada < 0.05)
  }
  kw_tab <- dplyr::bind_rows(kw_out) %>%
    dplyr::mutate(p_kw_holm = stats::p.adjust(p_kw, "holm"), .after = p_kw) %>%
    dplyr::arrange(p_kw)
  guardar_tabla(kw_tab, paste0("estadistica_kw_jt_", sufijo))
  guardar_tabla(dplyr::bind_rows(dunn_out),
                paste0("estadistica_dunn_significativos_", sufijo))
  kw_tab
}

kw_tab <- correr_bateria(maestra, "completo")

# --- sensibilidad sin duplicados --------------------------------------------
dups <- maestra$titulo_duplicado | maestra$contenido_duplicado
if (any(dups)) {
  log_msg("Sensibilidad: repitiendo KW y JT sin ", sum(dups),
          " libros duplicados")
  invisible(correr_bateria(maestra[!dups, ], "sin_duplicados"))
}

# --- GAM por metrica ---------------------------------------------------------
hay_dup_titulo <- any(maestra$titulo_duplicado)
gam_out <- list(); pred_out <- list()
for (m in metricas) {
  d <- maestra[!is.na(maestra[[m]]), c(m, "nivel", "titulo_norm")]
  if (nrow(d) < 15) next
  colnames(d)[1] <- "y"
  d$titulo_norm <- factor(d$titulo_norm)
  k_gam <- min(config$gam_k, length(unique(d$nivel)) - 1)
  form <- if (hay_dup_titulo)
    y ~ s(nivel, k = k_gam) + s(titulo_norm, bs = "re")
  else y ~ s(nivel, k = k_gam)
  fit <- tryCatch(mgcv::bam(form, data = d, method = "fREML",
                            discrete = TRUE),
                  error = function(e) NULL)
  if (is.null(fit)) next
  s_tab <- summary(fit)$s.table
  gam_out[[m]] <- data.frame(metrica = m,
    edf = s_tab[1, "edf"], F = s_tab[1, "F"], p_suavizado = s_tab[1, "p-value"],
    dev_explicada = summary(fit)$dev.expl)
  nuevo <- data.frame(nivel = seq(1, 12, by = 0.25),
                      titulo_norm = d$titulo_norm[1])
  pr <- mgcv::predict.bam(fit, nuevo, se.fit = TRUE,
    exclude = if (hay_dup_titulo) "s(titulo_norm)" else NULL,
    newdata.guaranteed = TRUE, discrete = FALSE)
  pred_out[[m]] <- data.frame(metrica = m, nivel = nuevo$nivel,
                              ajuste = pr$fit, se = pr$se.fit)
}
gam_tab <- dplyr::bind_rows(gam_out) %>% dplyr::arrange(p_suavizado)
guardar_tabla(gam_tab, "estadistica_gam_por_metrica")

pred <- dplyr::bind_rows(pred_out)
sel_fig <- head(gam_tab$metrica, 8)
p_gam <- pred %>% dplyr::filter(metrica %in% sel_fig) %>%
  ggplot2::ggplot(ggplot2::aes(nivel, ajuste)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = ajuste - 2 * se,
                                    ymax = ajuste + 2 * se),
                       fill = "#4477AA", alpha = 0.25) +
  ggplot2::geom_line(colour = "#4477AA", linewidth = 0.9) +
  ggplot2::facet_wrap(~metrica, scales = "free_y", ncol = 4) +
  ggplot2::scale_x_continuous(breaks = c(1, 4, 8, 12)) +
  ggplot2::labs(title = "Trayectorias GAM de las metricas con menor p",
                x = "Nivel", y = "Valor ajustado") +
  tema_pipeline()
guardar_fig(p_gam, "10_gam_trayectorias", 12, 6)

# --- GAM mixto a nivel de oracion: polaridad --------------------------------
ora <- P$oraciones_afect %>%
  dplyr::inner_join(P$catalogo[, c("id_libro", "nivel")],
                    by = c("doc_id" = "id_libro")) %>%
  dplyr::mutate(id_libro = factor(doc_id))
k_gam <- min(config$gam_k, length(unique(ora$nivel)) - 1)
fit_ora <- mgcv::bam(polaridad_norm ~ s(nivel, k = k_gam) +
                       s(id_libro, bs = "re"),
                     data = ora, discrete = TRUE)
s_ora <- summary(fit_ora)
guardar_tabla(data.frame(
  termino = rownames(s_ora$s.table), edf = s_ora$s.table[, "edf"],
  F = s_ora$s.table[, "F"], p = s_ora$s.table[, "p-value"],
  n_oraciones = nrow(ora), dev_explicada = s_ora$dev.expl),
  "estadistica_gam_polaridad_oraciones")
log_msg("GAM mixto oraciones: n = ", nrow(ora), ", p suavizado nivel = ",
        signif(s_ora$s.table[1, "p-value"], 3))

P$kw_tab <- kw_tab
P$gam_tab <- gam_tab
