# =============================================================================
# 04_perfil_gramatical.R : proporciones POS, sintaxis de dependencias y
# contraste por nivel. Todo sobre la anotacion del texto crudo.
# =============================================================================

anot <- P$anot
pal <- anot[anot$es_palabra, ]

# --- proporciones POS por libro ---------------------------------------------
upos_set <- c("NOUN", "VERB", "ADJ", "ADV", "PRON", "AUX", "ADP", "DET",
              "SCONJ", "CCONJ", "PROPN", "NUM")
pos_libro <- pal %>%
  dplyr::filter(upos %in% upos_set) %>%
  dplyr::count(doc_id, upos) %>%
  dplyr::group_by(doc_id) %>%
  dplyr::mutate(prop = n / sum(n)) %>%
  dplyr::ungroup()

pos_ancho <- pos_libro %>%
  dplyr::select(doc_id, upos, prop) %>%
  tidyr::pivot_wider(names_from = upos, values_from = prop, values_fill = 0,
                     names_prefix = "prop_")

# razon sustantivo/verbo y nominalizaciones
sufijos_nom <- paste0("(ci\u00f3n|cion|si\u00f3n|sion|ciones|siones|miento|",
                      "mientos|idad|idades|anza|anzas|dumbre)$")
gram_extra <- pal %>%
  dplyr::group_by(doc_id) %>%
  dplyr::summarise(
    n_palabras_anot = dplyr::n(),
    razon_sust_verbo = sum(upos == "NOUN") / max(1, sum(upos == "VERB")),
    nominalizaciones_x1000 = 1000 *
      sum(upos == "NOUN" &
          stringi::stri_detect_regex(lemma_lower, sufijos_nom)) / dplyr::n(),
    .groups = "drop")

# --- sintaxis de dependencias -----------------------------------------------
dep <- anot[!is.na(anot$head_token_id) & anot$head_token_id > 0 & anot$es_palabra, ]
dist_dep <- dep %>%
  dplyr::group_by(doc_id) %>%
  dplyr::summarise(dist_dependencia_media = mean(abs(token_id - head_token_id)),
                   .groups = "drop")

# profundidad de arbol: propagacion iterativa sobre todo el corpus
tok <- anot[!is.na(anot$head_token_id), ]
clave <- paste(tok$oracion_uid, tok$token_id)
clave_padre <- paste(tok$oracion_uid, tok$head_token_id)
idx_padre <- match(clave_padre, clave)
prof <- ifelse(tok$head_token_id == 0, 1L, NA_integer_)
for (it in 1:60) {
  pend <- which(is.na(prof))
  if (length(pend) == 0) break
  listo <- pend[!is.na(idx_padre[pend]) & !is.na(prof[idx_padre[pend]])]
  if (length(listo) == 0) { prof[pend] <- 1L; break }   # arboles rotos
  prof[listo] <- prof[idx_padre[listo]] + 1L
}
tok$prof <- prof
prof_libro <- tok %>%
  dplyr::group_by(doc_id, oracion_uid) %>%
  dplyr::summarise(prof_max = max(prof, na.rm = TRUE), .groups = "drop") %>%
  dplyr::group_by(doc_id) %>%
  dplyr::summarise(profundidad_arbol_media = mean(prof_max), .groups = "drop")

# subordinadas por oracion (deprel csubj, ccomp, xcomp, advcl, acl y subtipos)
re_sub <- "^(csubj|ccomp|xcomp|advcl|acl)"
sub_libro <- anot %>%
  dplyr::group_by(doc_id) %>%
  dplyr::summarise(
    subordinadas_por_oracion =
      sum(stringi::stri_detect_regex(dep_rel, re_sub), na.rm = TRUE) /
      dplyr::n_distinct(oracion_uid),
    .groups = "drop")

gram_libro <- pos_ancho %>%
  dplyr::left_join(gram_extra, by = "doc_id") %>%
  dplyr::left_join(dist_dep, by = "doc_id") %>%
  dplyr::left_join(prof_libro, by = "doc_id") %>%
  dplyr::left_join(sub_libro, by = "doc_id")
guardar_tabla(gram_libro, "perfil_gramatical_por_libro")

# --- contraste POS x nivel ---------------------------------------------------
niv <- P$catalogo[, c("id_libro", "nivel", "etapa")]
pos_nivel <- pal %>%
  dplyr::filter(upos %in% upos_set) %>%
  dplyr::inner_join(niv, by = c("doc_id" = "id_libro")) %>%
  dplyr::count(nivel, upos) %>%
  tidyr::pivot_wider(names_from = upos, values_from = n, values_fill = 0)
tab_pos <- as.matrix(pos_nivel[, -1])
rownames(tab_pos) <- pos_nivel$nivel

chi_pos <- suppressWarnings(stats::chisq.test(tab_pos))
res_pos <- as.data.frame(as.table(chi_pos$stdres))
colnames(res_pos) <- c("nivel", "upos", "residuo_estandarizado")
guardar_tabla(res_pos, "pos_residuos_chi2")
guardar_tabla(data.frame(chi2 = unname(chi_pos$statistic),
                         gl = unname(chi_pos$parameter),
                         p = chi_pos$p.value,
                         v_cramer = cramer_v(tab_pos)),
              "pos_chi2_global")

p_res <- ggplot2::ggplot(res_pos,
    ggplot2::aes(x = as.integer(as.character(nivel)), y = upos,
                 fill = residuo_estandarizado)) +
  ggplot2::geom_tile() +
  ggplot2::scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B") +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::labs(title = "Residuos estandarizados: categoria gramatical x nivel",
                x = "Nivel", y = NULL, fill = "Residuo") +
  tema_pipeline()
guardar_fig(p_res, "04_pos_residuos", 9, 5.5)

pos_prop_nivel <- pal %>%
  dplyr::filter(upos %in% c("NOUN", "VERB", "ADJ", "ADV", "SCONJ")) %>%
  dplyr::inner_join(niv, by = c("doc_id" = "id_libro")) %>%
  dplyr::count(nivel, upos) %>%
  dplyr::group_by(nivel) %>%
  dplyr::mutate(prop = n / sum(n)) %>%
  dplyr::ungroup()
p_pos <- ggplot2::ggplot(pos_prop_nivel,
    ggplot2::aes(nivel, prop, colour = upos)) +
  capas_etapas() +
  ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.6) +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::scale_fill_manual(values = c("#88CCEE", "#DDCC77", "#CC6677"),
                             guide = "none") +
  ggplot2::labs(title = "Proporcion de categorias abiertas por nivel",
                x = "Nivel", y = "Proporcion", colour = "UPOS") +
  tema_pipeline()
guardar_fig(p_pos, "04_pos_por_nivel", 9, 5.5)

P$gram_libro <- gram_libro
