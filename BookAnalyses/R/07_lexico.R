# =============================================================================
# 07_lexico.R : frecuencias, chi2 termino x nivel con residuos, keyness por
# etapa (log-likelihood de Dunning) y matriz TF-IDF para el modulo semantico.
# Preprocesamiento propio: lemas de palabras de contenido, sin stopwords.
# PROPN excluido por defecto (config$incluir_propn) porque los nombres de
# personajes dominan el espacio lexico; se guarda ademas la version con PROPN.
# =============================================================================

sw_es <- stopwords::stopwords("es", source = "snowball")
upos_contenido <- c("NOUN", "VERB", "ADJ", "ADV")
if (config$incluir_propn) upos_contenido <- c(upos_contenido, "PROPN")

cont <- P$anot %>%
  dplyr::filter(es_palabra, upos %in% c(upos_contenido, "PROPN")) %>%
  dplyr::transmute(doc_id, upos, lema = lemma_lower) %>%
  dplyr::filter(!lema %in% sw_es, nchar(lema) >= 2,
                stringi::stri_detect_regex(lema, paste0("^[", .LMIN, "]+$")))

niv <- P$catalogo[, c("id_libro", "nivel", "etapa")]
cont <- dplyr::inner_join(cont, niv, by = c("doc_id" = "id_libro"))
cont_sin_propn <- cont %>% dplyr::filter(upos != "PROPN")
uso <- if (config$incluir_propn) cont else cont_sin_propn

# --- frecuencias -------------------------------------------------------------
top_etapa <- uso %>%
  dplyr::count(etapa, lema, sort = TRUE) %>%
  dplyr::group_by(etapa) %>% dplyr::slice_head(n = 20) %>% dplyr::ungroup()
guardar_tabla(top_etapa, "lexico_top20_por_etapa")

# --- chi2 termino x nivel ----------------------------------------------------
chi2_terminos <- function(datos, sufijo) {
  top_lemas <- datos %>% dplyr::count(lema, sort = TRUE) %>%
    dplyr::slice_head(n = config$n_terminos_chi2) %>% dplyr::pull(lema)
  tabla <- datos %>% dplyr::filter(lema %in% top_lemas) %>%
    dplyr::count(lema, nivel) %>%
    tidyr::pivot_wider(names_from = nivel, values_from = n, values_fill = 0)
  M <- as.matrix(tabla[, -1]); rownames(M) <- tabla$lema
  chi <- suppressWarnings(stats::chisq.test(M))
  res <- as.data.frame(as.table(chi$stdres))
  colnames(res) <- c("lema", "nivel", "residuo")
  top_res <- res %>% dplyr::group_by(nivel) %>%
    dplyr::slice_max(residuo, n = 15) %>% dplyr::ungroup()
  guardar_tabla(top_res, paste0("lexico_residuos_top_", sufijo))
  guardar_tabla(data.frame(chi2 = unname(chi$statistic),
                           gl = unname(chi$parameter), p = chi$p.value,
                           v_cramer = cramer_v(M), terminos = nrow(M)),
                paste0("lexico_chi2_global_", sufijo))
}
chi2_terminos(cont_sin_propn, "sin_propn")
chi2_terminos(cont, "con_propn")

# --- keyness por etapa (LL) --------------------------------------------------
frec_etapa <- uso %>% dplyr::count(etapa, lema)
tot_etapa <- frec_etapa %>% dplyr::group_by(etapa) %>%
  dplyr::summarise(total = sum(n), .groups = "drop")
key_list <- lapply(levels(uso$etapa), function(et) {
  foco <- frec_etapa %>% dplyr::filter(etapa == et)
  resto <- frec_etapa %>% dplyr::filter(etapa != et) %>%
    dplyr::group_by(lema) %>% dplyr::summarise(n_resto = sum(n), .groups = "drop")
  c_tot <- tot_etapa$total[tot_etapa$etapa == et]
  d_tot <- sum(tot_etapa$total) - c_tot
  dplyr::full_join(foco, resto, by = "lema") %>%
    dplyr::mutate(etapa = et,
                  n = dplyr::coalesce(n, 0L),
                  n_resto = dplyr::coalesce(n_resto, 0L)) %>%
    dplyr::filter(n + n_resto >= config$keyness_min_frec) %>%
    dplyr::mutate(ll = ll_keyness(n, n_resto, c_tot, d_tot)) %>%
    dplyr::arrange(dplyr::desc(ll)) %>% dplyr::slice_head(n = 30)
})
keyness <- dplyr::bind_rows(key_list)
guardar_tabla(keyness, "lexico_keyness_por_etapa")

p_key <- keyness %>% dplyr::group_by(etapa) %>%
  dplyr::slice_head(n = 12) %>% dplyr::ungroup() %>%
  ggplot2::ggplot(ggplot2::aes(ll, stats::reorder(lema, ll))) +
  ggplot2::geom_col(fill = "#4477AA") +
  ggplot2::facet_wrap(~etapa, scales = "free_y") +
  ggplot2::labs(title = "Lemas caracteristicos por etapa (log-likelihood)",
                x = "LL con signo", y = NULL) +
  tema_pipeline()
guardar_fig(p_key, "07_keyness_etapas", 11, 5)

# --- TF-IDF para el modulo semantico ----------------------------------------
frec_dl <- uso %>% dplyr::count(doc_id, lema)
df_lema <- frec_dl %>% dplyr::count(lema, name = "df") %>%
  dplyr::filter(df >= config$min_df)
frec_dl <- frec_dl %>% dplyr::semi_join(df_lema, by = "lema")
docs <- sort(unique(frec_dl$doc_id))
lemas <- sort(unique(frec_dl$lema))
X <- Matrix::sparseMatrix(i = match(frec_dl$doc_id, docs),
                          j = match(frec_dl$lema, lemas),
                          x = frec_dl$n,
                          dims = c(length(docs), length(lemas)),
                          dimnames = list(docs, lemas))
idf <- log(nrow(X) / (Matrix::colSums(X > 0)))
tfidf <- X
tfidf@x <- log1p(tfidf@x)
tfidf <- tfidf %*% Matrix::Diagonal(x = idf)
norma <- sqrt(Matrix::rowSums(tfidf^2)); norma[norma == 0] <- 1
tfidf <- Matrix::Diagonal(x = 1 / norma) %*% tfidf
rownames(tfidf) <- docs; colnames(tfidf) <- lemas
log_msg("TF-IDF: ", nrow(tfidf), " libros x ", ncol(tfidf), " lemas")

P$tfidf <- tfidf
P$cont_lemas <- uso
