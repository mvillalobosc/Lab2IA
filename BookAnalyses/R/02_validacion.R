# =============================================================================
# 02_validacion.R : sanidad del corpus antes de calcular nada.
# Nada se excluye en silencio: todo queda en log_exclusiones o log_advertencias.
# =============================================================================

cat_v <- P$catalogo
sw_es <- stopwords::stopwords("es", source = "snowball")

cat_v$n_palabras <- vapply(cat_v$id_libro, function(id)
  stringi::stri_count_regex(P$textos[[id]], paste0("[", .LMIN, .LMAY, "]+")),
  integer(1))
cat_v$prop_stopwords <- vapply(cat_v$id_libro, function(id)
  proporcion_stopwords_es(P$textos[[id]], sw_es), numeric(1))
cat_v$md5 <- vapply(cat_v$id_libro, function(id)
  digest_texto(P$textos[[id]]), character(1))

# libros muy cortos: advertencia (siguen en el analisis, marcados)
cortos <- cat_v$n_palabras < config$min_palabras
for (i in which(cortos))
  registrar_advertencia("02_validacion", cat_v$id_libro[i], cat_v$titulo[i],
                        paste0("menos de ", config$min_palabras, " palabras"),
                        cat_v$n_palabras[i])

# texto no reconocible como espanol: bajo el umbral de stopwords todas las
# metricas basadas en lexico y silabeo son invalidas
no_es <- !is.na(cat_v$prop_stopwords) & cat_v$prop_stopwords < config$umbral_espanol
if (isTRUE(config$excluir_no_espanol)) {
  for (i in which(no_es))
    registrar_exclusion("02_validacion", cat_v$id_libro[i], cat_v$titulo[i],
      "texto no reconocible como espanol (capa de texto corrupta o idioma)",
      round(cat_v$prop_stopwords[i], 3))
  cat_v <- cat_v[!no_es, ]
  P$textos <- P$textos[cat_v$id_libro]
} else {
  for (i in which(no_es))
    registrar_advertencia("02_validacion", cat_v$id_libro[i], cat_v$titulo[i],
                          "proporcion de stopwords ES bajo umbral: revisar idioma",
                          round(cat_v$prop_stopwords[i], 3))
}

# duplicados por titulo (mismo titulo asignado a mas de un nivel)
dup_tit <- cat_v %>% dplyr::count(titulo_norm) %>% dplyr::filter(n > 1)
cat_v$titulo_duplicado <- cat_v$titulo_norm %in% dup_tit$titulo_norm

# duplicados por contenido identico (hash)
dup_md5 <- cat_v %>% dplyr::count(md5) %>% dplyr::filter(n > 1)
cat_v$contenido_duplicado <- cat_v$md5 %in% dup_md5$md5

dups <- cat_v %>%
  dplyr::filter(titulo_duplicado | contenido_duplicado) %>%
  dplyr::select(id_libro, titulo, nivel, n_palabras, titulo_duplicado,
                contenido_duplicado, md5)
guardar_tabla(dups, "duplicados")
if (nrow(dups) > 0)
  log_msg("Duplicados detectados: ", nrow(dups), " filas (ver tablas/duplicados.csv). ",
          "Se mantienen en su nivel asignado; modulo 10 corre sensibilidad sin ellos.")

resumen <- cat_v %>%
  dplyr::group_by(nivel, etapa) %>%
  dplyr::summarise(libros = dplyr::n(),
                   palabras_total = sum(n_palabras),
                   palabras_mediana = stats::median(n_palabras), .groups = "drop")
guardar_tabla(resumen, "resumen_validacion_por_nivel")
print(as.data.frame(resumen))

if (nrow(cat_v) < 6 || length(unique(cat_v$nivel)) < 3)
  stop("Corpus insuficiente tras validacion: ", nrow(cat_v), " libros en ",
       length(unique(cat_v$nivel)), " niveles")

P$catalogo <- cat_v
