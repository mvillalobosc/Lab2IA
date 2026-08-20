# =============================================================================
# 08_export.R  Consolidacion de resultados y libro Excel final
# =============================================================================

log_step("08  Consolidacion de resultados")

ing <- load_step("01_ingest")
cl  <- load_step("02_clean")
fr  <- load_step("03_frequency")
tp  <- load_step("04_topics")
sn  <- load_step("05_sentiment")
rd  <- load_step("06_readability")
pp  <- load_step("07_popularity")

serie <- rd$serie
etq   <- serie$title_es

# Una fila por capitulo con todas las metricas del pipeline.
maestro <- data.frame(
  episode_id        = serie$episode_id,
  season            = serie$season,
  episode_in_season = serie$episode_in_season,
  title_es          = etq,
  publish_date      = serie$publish_date,
  youtube_id        = serie$youtube_id,
  animation_team    = serie$animation_team,
  n_tokens          = serie$n_tokens,
  n_generico        = serie$n_generico,
  n_cultural        = serie$n_cultural,
  pct_cultural      = serie$pct_cultural,
  sentimiento       = round(serie$sentimiento, 6),
  ARI               = round(serie$ARI, 6),
  MATTR             = round(serie$MATTR, 6),
  views             = serie$views,
  likes             = serie$likes,
  subscribers_current = serie$subscribers_current,
  meses_expuesto    = round(pp$meses_expuesto, 2),
  check.names = FALSE
)
write_table_out(maestro, "08_maestro_capitulos")

maestro_temporada <- data.frame(
  temporada    = sort(unique(serie$season)),
  n_capitulos  = as.integer(table(serie$season)),
  tokens       = as.integer(tapply(serie$n_tokens, serie$season, sum)),
  pct_cultural = round(as.numeric(tapply(serie$n_cultural, serie$season, sum)) /
                       as.numeric(tapply(serie$n_tokens, serie$season, sum)) * 100, 2),
  sentimiento  = round(as.numeric(sn$sent_temp), 6),
  ARI          = round(rd$complejidad_temp$ARI, 6),
  MATTR        = round(rd$complejidad_temp$MATTR, 6),
  views        = as.numeric(tapply(serie$views, serie$season, sum)),
  likes        = as.numeric(tapply(serie$likes, serie$season, sum))
)
write_table_out(maestro_temporada, "08_maestro_temporadas")

hojas <- list(
  episodios          = maestro,
  temporadas         = maestro_temporada,
  particion_lexica   = data.frame(episode_id = serie$episode_id, title_es = etq,
                                  n_generico = serie$n_generico,
                                  n_cultural = serie$n_cultural,
                                  pct_cultural = serie$pct_cultural),
  temas_capitulo     = data.frame(episode_id = rownames(tp$temas_cap),
                                  title_es = etq, tp$temas_cap, check.names = FALSE),
  temas_proporcion   = data.frame(episode_id = rownames(tp$temas_cap_pct),
                                  title_es = etq, round(tp$temas_cap_pct, 5),
                                  check.names = FALSE),
  temas_temporada    = data.frame(temporada = rownames(tp$temas_temp),
                                  tp$temas_temp, check.names = FALSE),
  emociones_capitulo = data.frame(episode_id = serie$episode_id, title_es = etq,
                                  round(sn$emociones_cap, 6), check.names = FALSE),
  emociones_temporada= data.frame(temporada = rownames(sn$emociones_temp),
                                  round(sn$emociones_temp, 6), check.names = FALSE),
  complejidad        = data.frame(episode_id = serie$episode_id, title_es = etq,
                                  ARI = round(serie$ARI, 6),
                                  MATTR = round(serie$MATTR, 6)),
  vecinos_complejidad= rd$vecinos,
  resumen_modelos    = pp$resumen
)
for (nm in names(pp$resultados)) {
  hojas[[paste0("imp_", tolower(nm))]] <- pp$resultados[[nm]]$importancia
  if (!is.null(pp$resultados[[nm]]$coeficientes)) {
    hojas[[paste0("lm_", tolower(nm))]] <- pp$resultados[[nm]]$coeficientes
  }
}
write_workbook_out(hojas, "pichintun_resultados")

# --- verificacion de integridad ---------------------------------------------
chequeos <- data.frame(
  chequeo = c("capitulos", "temporadas", "tokens sin tema",
              "capitulos con NA en ARI", "capitulos con NA en MATTR",
              "capitulos con NA en sentimiento", "tipos emocionales",
              "modelos sobreparametrizados"),
  valor = c(nrow(serie), length(unique(serie$season)), length(cl$sin_tema),
            sum(is.na(serie$ARI)), sum(is.na(serie$MATTR)),
            sum(is.na(serie$sentimiento)), length(sn$tipos_emo),
            sum(pp$resumen$sobreparametrizado)),
  esperado = c("34", "4", "0", "0", "0", "0", "16", "informativo")
)
write_table_out(chequeos, "08_verificacion")
print(chequeos, row.names = FALSE)

n_fig <- length(list.files(CFG$dir_figures, pattern = "\\.png$"))
n_tab <- length(list.files(CFG$dir_tables, pattern = "\\.csv$"))
log_msg("figuras generadas: ", n_fig, " | tablas generadas: ", n_tab)
