# =============================================================================
# 02_clean.R  Limpieza, tokenizacion y particion lexica
# =============================================================================
# Cambios respecto al original:
#  - La reclasificacion de "chile" como palabra cultural ocurria a mitad del
#    modulo de frecuencias, despues de haber calculado el porcentaje de
#    modismos que alimenta los modelos de popularidad. El resultado era que las
#    nubes por temporada y el modelo Random Forest usaban particiones lexicas
#    distintas. Aqui se aplica una sola vez, antes de cualquier calculo.
#  - Se reporta explicitamente que palabras del corpus quedan fuera del lexico
#    tematico, en vez de fallar o descartarlas en silencio.
# =============================================================================

log_step("02  Limpieza y particion lexica")

ing   <- load_step("01_ingest")
serie <- ing$serie

diccionario <- hunspell::dictionary(CFG$f_dic)

# El texto original conserva puntuacion y mayusculas: lo requieren ARI y MATTR.
serie$texto_es_orig <- quitar_intro(serie$texto_es)
serie$texto_en_orig <- quitar_intro(serie$texto_en)

serie$texto_es_limpio <- limpiar_texto(serie$texto_es)

part <- lapply(serie$texto_es_limpio, particion_lexica,
               diccionario = diccionario,
               stopwords = ing$stopwords,
               forzar_culturales = CFG$forzar_culturales)

serie$pal_generico <- lapply(part, `[[`, "generico")
serie$pal_cultural <- lapply(part, `[[`, "cultural")

serie$n_generico <- lengths(serie$pal_generico)
serie$n_cultural <- lengths(serie$pal_cultural)
serie$n_tokens   <- serie$n_generico + serie$n_cultural
serie$pct_cultural <- round(100 * serie$n_cultural / serie$n_tokens, 1)

# --- diagnostico: sensibilidad a la lista forzar_culturales -----------------
# Se recalcula la particion sin forzar ninguna palabra, para cuantificar el
# efecto de CFG$forzar_culturales sobre el porcentaje cultural por capitulo.
part0 <- lapply(serie$texto_es_limpio, particion_lexica,
                diccionario = diccionario, stopwords = ing$stopwords,
                forzar_culturales = character(0))
pct0 <- round(100 * lengths(lapply(part0, `[[`, "cultural")) /
                (lengths(lapply(part0, `[[`, "generico")) +
                 lengths(lapply(part0, `[[`, "cultural"))), 1)

diag_forzado <- data.frame(
  episode_id = serie$episode_id,
  title_es = serie$title_es,
  pct_cultural_sin_forzar = pct0,
  pct_cultural_con_forzar = serie$pct_cultural,
  delta = round(serie$pct_cultural - pct0, 2)
)
write_table_out(diag_forzado, "02_diag_forzar_culturales")
log_msg("efecto de forzar_culturales sobre pct_cultural: max delta = ",
        max(abs(diag_forzado$delta)), " pp en ",
        sum(diag_forzado$delta != 0), " capitulo(s)")

# --- diagnostico: cobertura del lexico tematico ------------------------------
vocab <- sort(unique(unlist(c(serie$pal_generico, serie$pal_cultural))))
sin_tema <- setdiff(vocab, names(ing$mapa_tema))
write_table_out(data.frame(word = sin_tema), "02_diag_palabras_sin_tema")
log_msg("vocabulario: ", length(vocab), " tipos | sin tema asignado: ",
        length(sin_tema),
        if (length(sin_tema)) paste0(" (", paste(utils::head(sin_tema, 10),
                                                 collapse = ", "), ")") else "")

log_msg("tokens totales: ", sum(serie$n_tokens),
        " | genericos: ", sum(serie$n_generico),
        " | culturales: ", sum(serie$n_cultural))

save_step(list(serie = serie, stopwords = ing$stopwords,
               mapa_tema = ing$mapa_tema, temas = ing$temas,
               sin_tema = sin_tema), "02_clean")

write_table_out(
  dplyr::select(serie, episode_id, season, title_es,
                n_tokens, n_generico, n_cultural, pct_cultural),
  "02_particion_lexica"
)
