# =============================================================================
# 12_reporte.R : consolida todo en un xlsx maestro, resumen.md y sessionInfo.
# =============================================================================

leer_csv <- function(nombre) {
  f <- file.path(config$carpeta_salida, "tablas", paste0(nombre, ".csv"))
  if (file.exists(f)) utils::read.csv(f, fileEncoding = "UTF-8") else NULL
}

hojas <- list(
  catalogo = P$catalogo,
  metricas_por_libro = P$maestra,
  validacion_por_nivel = leer_csv("resumen_validacion_por_nivel"),
  duplicados = leer_csv("duplicados"),
  mapeo_archivos = leer_csv("mapeo_archivos"),
  kw_jt = leer_csv("estadistica_kw_jt_completo"),
  kw_jt_sin_duplicados = leer_csv("estadistica_kw_jt_sin_duplicados"),
  dunn = leer_csv("estadistica_dunn_significativos_completo"),
  gam_metricas = leer_csv("estadistica_gam_por_metrica"),
  gam_polaridad_oraciones = leer_csv("estadistica_gam_polaridad_oraciones"),
  pos_chi2 = leer_csv("pos_chi2_global"),
  pos_residuos = leer_csv("pos_residuos_chi2"),
  lexico_chi2 = leer_csv("lexico_chi2_global_sin_propn"),
  lexico_residuos = leer_csv("lexico_residuos_top_sin_propn"),
  keyness = leer_csv("lexico_keyness_por_etapa"),
  clustering_eval = leer_csv("clustering_evaluacion"),
  clustering_membresias = leer_csv("clustering_membresias"),
  arcos = leer_csv("arcos_clusters"),
  arcos_por_etapa = leer_csv("arcos_proporcion_por_etapa"),
  topicos_etiquetas = leer_csv("topicos_etiquetas"),
  topicos_tendencia = leer_csv("topicos_tendencia_nivel"),
  desajustados = leer_csv("libros_desajustados"),
  exclusiones = {
    f <- file.path(config$carpeta_salida, "logs", "log_exclusiones.csv")
    if (file.exists(f)) utils::read.csv(f) else
      data.frame(nota = "sin exclusiones")
  },
  advertencias = {
    f <- file.path(config$carpeta_salida, "logs", "log_advertencias.csv")
    if (file.exists(f)) utils::read.csv(f) else
      data.frame(nota = "sin advertencias")
  }
)
hojas <- hojas[!vapply(hojas, is.null, logical(1))]
writexl::write_xlsx(hojas,
  file.path(config$carpeta_salida, "resultados_maestros.xlsx"))

# --- resumen.md --------------------------------------------------------------
kw <- P$kw_tab
lineas <- c(
  "# Resumen del pipeline",
  paste0("Fecha: ", Sys.Date()),
  "",
  paste0("Libros analizados: ", nrow(P$maestra), " en ",
         length(unique(P$maestra$nivel)), " niveles."),
  paste0("Tokens anotados: ", nrow(P$anot), "."),
  "",
  "## Metricas con mayor senal por nivel (Kruskal-Wallis)",
  ""
)
if (!is.null(kw) && nrow(kw) > 0) {
  top <- head(kw, 10)
  lineas <- c(lineas, sprintf(
    "%d. %s: H = %.1f, p Holm = %.2g, epsilon2 = %.3f, JT %s (p = %.3g)",
    seq_len(nrow(top)), top$metrica, top$H, top$p_kw_holm, top$epsilon2,
    top$jt_direccion, top$jt_p))
}
ev <- P$eval_clustering
if (!is.null(ev)) {
  lineas <- c(lineas, "", "## Clustering vs curriculo",
    sprintf("ARI etapa (k=3) en LSA: %.3f; ARI nivel (k=12): %.3f; Mantel r = %.3f (p = %.3g)",
            ev$ari_etapa_k3[1], ev$ari_nivel_k12[1], ev$mantel_r[1],
            ev$mantel_p[1]))
}
des <- P$desajustados
if (!is.null(des)) {
  nd <- sum(des$desajustado_modelo, na.rm = TRUE)
  lineas <- c(lineas, "", "## Libros candidatos a reasignacion",
    sprintf("%d libros con |nivel predicho - asignado| >= %d (ver libros_desajustados.csv)",
            nd, config$umbral_delta_nivel))
}
writeLines(lineas, file.path(config$carpeta_salida, "resumen.md"))

writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(config$carpeta_salida, "logs", "sessionInfo.txt"))
log_msg("Reporte: resultados_maestros.xlsx con ", length(hojas), " hojas")
