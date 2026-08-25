# =============================================================================
# 06_complejidad.R : legibilidad y diversidad lexica por libro.
# Legibilidad sobre superficie limpia con segmentacion de udpipe.
# Diversidad sobre formas superficiales en minuscula, sin filtrar stopwords.
# ARI, RIX y FK se reportan por comparabilidad con los trabajos previos del
# grupo; la interpretacion para espanol descansa en FH, SP (INFLESZ) y mu.
# =============================================================================

pal <- P$anot[P$anot$es_palabra, c("doc_id", "oracion_uid", "token_lower")]

comp <- lapply(split(pal, pal$doc_id), function(d) {
  leg <- calcular_legibilidad(d$token_lower, d$oracion_uid)
  div <- metricas_diversidad(d$token_lower, ventanas = config$ventanas_mattr,
                             hdd_m = config$hdd_muestra)
  if (is.null(leg) || is.null(div)) return(NULL)
  c(leg, div, list(zipf_pendiente = pendiente_zipf(d$token_lower)))
})
vacios <- names(comp)[vapply(comp, is.null, logical(1))]
for (id in vacios)
  registrar_exclusion("06_complejidad", id,
                      P$catalogo$titulo[P$catalogo$id_libro == id],
                      "texto insuficiente para legibilidad o diversidad", NA)
comp <- comp[!vapply(comp, is.null, logical(1))]
comp_libro <- dplyr::bind_rows(lapply(comp, tibble::as_tibble), .id = "doc_id")
comp_libro$inflesz <- banda_inflesz(comp_libro$szigriszt_pazos)

# advertencia si MATTR no calculable por texto corto
for (w in config$ventanas_mattr) {
  col <- paste0("mattr_", w)
  na_ids <- comp_libro$doc_id[is.na(comp_libro[[col]])]
  for (id in na_ids)
    registrar_advertencia("06_complejidad", id,
      P$catalogo$titulo[P$catalogo$id_libro == id],
      paste0(col, " NA: texto mas corto que la ventana"), w)
}

guardar_tabla(comp_libro, "complejidad_por_libro")

# --- figura de sintesis: indices estandarizados por nivel -------------------
niv <- P$catalogo[, c("id_libro", "nivel", "etapa")]
sel <- c("ari", "rix", "szigriszt_pazos", "mattr_100", "mtld",
         "long_oracion_media")
comp_niv <- comp_libro %>%
  dplyr::inner_join(niv, by = c("doc_id" = "id_libro")) %>%
  dplyr::select(nivel, dplyr::all_of(sel)) %>%
  tidyr::pivot_longer(-nivel, names_to = "metrica", values_to = "valor") %>%
  dplyr::group_by(metrica) %>%
  dplyr::mutate(z = as.numeric(scale(valor))) %>%
  dplyr::group_by(nivel, metrica) %>%
  dplyr::summarise(z = mean(z, na.rm = TRUE), .groups = "drop")

p_z <- ggplot2::ggplot(comp_niv, ggplot2::aes(nivel, z, colour = metrica)) +
  capas_etapas() +
  ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.5) +
  ggplot2::geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::scale_fill_manual(values = c("#88CCEE", "#DDCC77", "#CC6677"),
                             guide = "none") +
  ggplot2::labs(title = "Complejidad y diversidad estandarizadas por nivel",
    subtitle = "Media de puntajes z por nivel. SP alto = mas facil",
    x = "Nivel", y = "Puntaje z medio", colour = "Metrica") +
  tema_pipeline()
guardar_fig(p_z, "06_complejidad_estandarizada", 10, 6)

# boxplot de los tres indices calibrados para espanol
es_larga <- comp_libro %>%
  dplyr::inner_join(niv, by = c("doc_id" = "id_libro")) %>%
  dplyr::select(nivel, fernandez_huerta, szigriszt_pazos, perfil_mu) %>%
  tidyr::pivot_longer(-nivel, names_to = "indice", values_to = "valor")
p_es <- ggplot2::ggplot(es_larga,
    ggplot2::aes(factor(nivel), valor)) +
  ggplot2::geom_boxplot(outlier.size = 0.8, fill = "#88CCEE", alpha = 0.6) +
  ggplot2::facet_wrap(~indice, scales = "free_y") +
  ggplot2::labs(title = "Indices de legibilidad calibrados para espanol",
                x = "Nivel", y = "Valor (mayor = mas facil)") +
  tema_pipeline()
guardar_fig(p_es, "06_legibilidad_espanol", 11, 4.5)

P$comp_libro <- comp_libro
