# =============================================================================
# 03_anotacion.R : anotacion morfosintactica con udpipe (spanish-gsd-ud-2.5).
# IMPORTANTE: se anota el texto CRUDO limpio, sin remover stopwords. Cada
# analisis posterior aplica su propio preprocesamiento sobre esta anotacion.
# Cache por libro en output/cache/anot/. Paraleliza con config$ncores.
# =============================================================================

dir_anot <- file.path(config$carpeta_salida, "cache", "anot")
ids <- P$catalogo$id_libro

anotar_libro <- function(id, mod = NULL) {
  rds <- file.path(dir_anot, paste0(id, ".rds"))
  if (config$usar_cache && file.exists(rds)) return(readRDS(rds))
  if (is.null(mod)) mod <- udpipe::udpipe_load_model(config$archivo_modelo)
  a <- udpipe::udpipe_annotate(mod, x = P$textos[[id]], doc_id = id,
                               tagger = "default", parser = "default")
  a <- as.data.frame(a)
  saveRDS(a, rds)
  a
}

t0 <- Sys.time()
if (config$ncores > 1) {
  lst <- parallel::mclapply(ids, anotar_libro, mc.cores = config$ncores)
} else {
  mod_serial <- udpipe::udpipe_load_model(config$archivo_modelo)
  lst <- lapply(seq_along(ids), function(k) {
    if (k %% 10 == 0) log_msg("  anotando libro ", k, " de ", length(ids))
    anotar_libro(ids[k], mod_serial)
  })
}
anot <- data.table::rbindlist(lst, fill = TRUE)
log_msg("Anotacion: ", nrow(anot), " tokens en ",
        round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")

anot <- as.data.frame(anot)
anot$token_id <- suppressWarnings(as.integer(anot$token_id))
anot$head_token_id <- suppressWarnings(as.integer(anot$head_token_id))
anot <- anot[!is.na(anot$token_id), ]           # descarta rangos multiword
anot$token_lower <- stringi::stri_trans_tolower(anot$token)
anot$lemma_lower <- stringi::stri_trans_tolower(anot$lemma)
anot$es_palabra <- anot$upos != "PUNCT" &
  stringi::stri_detect_regex(anot$token, .RE_LETRA)
anot$oracion_uid <- paste(anot$doc_id, anot$paragraph_id, anot$sentence_id,
                          sep = "_")

# tabla de oraciones
oraciones <- anot %>%
  dplyr::group_by(doc_id, oracion_uid) %>%
  dplyr::summarise(n_tokens = sum(es_palabra), .groups = "drop") %>%
  dplyr::group_by(doc_id) %>%
  dplyr::mutate(orden = dplyr::row_number()) %>%
  dplyr::ungroup()

P$anot <- anot
P$oraciones <- oraciones
saveRDS(anot, file.path(config$carpeta_salida, "cache", "anotacion_completa.rds"))
