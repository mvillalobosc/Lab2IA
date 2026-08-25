# =============================================================================
# 09_topicos.R : topicos con STM sobre pasajes de config$chunk_palabras lemas
# de contenido, con el nivel como covariable de prevalencia (~ s(nivel)).
# Reemplaza a BERTopic: sin Python, deterministico via inicializacion Spectral.
# =============================================================================

if (!config$run_topicos) {
  log_msg("run_topicos = FALSE: modulo omitido")
} else {

set.seed(config$semilla)
uso <- P$cont_lemas %>%
  dplyr::group_by(doc_id) %>%
  dplyr::mutate(idx = dplyr::row_number(),
                chunk = ceiling(idx / config$chunk_palabras)) %>%
  dplyr::ungroup()

# fusionar chunks finales muy cortos con el anterior
tam <- uso %>% dplyr::count(doc_id, chunk)
cortos <- tam %>% dplyr::filter(n < 100, chunk > 1)
uso <- uso %>%
  dplyr::left_join(cortos %>% dplyr::mutate(fusionar = TRUE),
                   by = c("doc_id", "chunk")) %>%
  dplyr::mutate(chunk = ifelse(!is.na(fusionar), chunk - 1L, chunk)) %>%
  dplyr::select(-fusionar, -dplyr::any_of("n"))
uso$chunk_id <- paste0(uso$doc_id, "_c", uso$chunk)

# vocabulario
df_chunk <- uso %>% dplyr::distinct(chunk_id, lema) %>% dplyr::count(lema)
vocab_keep <- df_chunk$lema[df_chunk$n >= config$stm_min_docs]
uso <- uso %>% dplyr::filter(lema %in% vocab_keep)
vocab <- sort(unique(uso$lema))
uso$vid <- match(uso$lema, vocab)

conteos <- uso %>% dplyr::count(chunk_id, doc_id, vid)
chunks <- sort(unique(conteos$chunk_id))
documentos <- lapply(chunks, function(ch) {
  d <- conteos[conteos$chunk_id == ch, ]
  rbind(as.integer(d$vid), as.integer(d$n))
})
meta <- conteos %>% dplyr::distinct(chunk_id, doc_id) %>%
  dplyr::arrange(match(chunk_id, chunks)) %>%
  dplyr::inner_join(P$catalogo[, c("id_libro", "nivel", "etapa")],
                    by = c("doc_id" = "id_libro"))
meta <- as.data.frame(meta)
log_msg("STM: ", length(chunks), " pasajes, vocabulario = ", length(vocab),
        ", K = ", config$stm_K)

mod_stm <- stm::stm(documents = documentos, vocab = vocab, K = config$stm_K,
                    prevalence = ~ s(nivel), data = meta,
                    init.type = "Spectral", seed = config$semilla,
                    max.em.its = config$stm_max_iter, verbose = FALSE)

lab <- stm::labelTopics(mod_stm, n = 10)
etiquetas_topicos <- data.frame(
  topico = seq_len(config$stm_K),
  frex = apply(lab$frex, 1, paste, collapse = ", "),
  prob = apply(lab$prob, 1, paste, collapse = ", "))
guardar_tabla(etiquetas_topicos, "topicos_etiquetas")

# efecto del nivel sobre la prevalencia
ef <- stm::estimateEffect(seq_len(config$stm_K) ~ s(nivel), mod_stm,
                          metadata = meta, uncertainty = "Global")
saveRDS(ef, file.path(config$carpeta_salida, "cache", "stm_effect.rds"))

# tendencia descriptiva: theta medio por nivel y correlacion de Spearman
theta <- mod_stm$theta
tend <- lapply(seq_len(config$stm_K), function(k) {
  data.frame(topico = k, nivel = meta$nivel, theta = theta[, k])
}) %>% dplyr::bind_rows()
cor_top <- tend %>% dplyr::group_by(topico) %>%
  dplyr::summarise(rho_nivel = suppressWarnings(
    stats::cor(nivel, theta, method = "spearman")), .groups = "drop") %>%
  dplyr::arrange(dplyr::desc(abs(rho_nivel)))
guardar_tabla(dplyr::inner_join(cor_top, etiquetas_topicos, by = "topico"),
              "topicos_tendencia_nivel")

top8 <- head(cor_top$topico, 8)
p_t <- tend %>% dplyr::filter(topico %in% top8) %>%
  dplyr::group_by(topico, nivel) %>%
  dplyr::summarise(theta = mean(theta), .groups = "drop") %>%
  dplyr::inner_join(etiquetas_topicos, by = "topico") %>%
  dplyr::mutate(nombre = paste0("T", topico, ": ",
                                substr(frex, 1, 32))) %>%
  ggplot2::ggplot(ggplot2::aes(nivel, theta)) +
  ggplot2::geom_point(size = 1, alpha = 0.7) +
  ggplot2::geom_smooth(method = "loess", se = TRUE, linewidth = 0.8,
                       colour = "#B2182B", formula = y ~ x) +
  ggplot2::facet_wrap(~nombre, scales = "free_y", ncol = 4) +
  ggplot2::scale_x_continuous(breaks = c(1, 4, 8, 12)) +
  ggplot2::labs(title = "Prevalencia media de topicos con mayor tendencia por nivel",
                x = "Nivel", y = "Theta medio") +
  tema_pipeline() +
  ggplot2::theme(strip.text = ggplot2::element_text(size = 7))
guardar_fig(p_t, "09_topicos_tendencia", 12, 6)

# topico dominante por pasaje y contraste chi2 con el nivel
dom <- apply(theta, 1, which.max)
tab_dom <- table(meta$nivel, dom)
chi_dom <- suppressWarnings(stats::chisq.test(tab_dom))
guardar_tabla(data.frame(chi2 = unname(chi_dom$statistic),
                         gl = unname(chi_dom$parameter), p = chi_dom$p.value,
                         v_cramer = cramer_v(tab_dom)),
              "topicos_chi2_dominante_nivel")

P$stm <- mod_stm
P$stm_meta <- meta
}
