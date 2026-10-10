# =============================================================================
# GRUPOS MST-kNN DE S. eubayanus SIN ENRIQUECIMIENTO (LOS DEL PAPER)
# Manuel: deja este archivo junto a clusters_Eubayanus.R en la carpeta de
# resultados del bosque (Eubayanus_RF.csv.gz y Eubayanus_resumen.tsv) y
# ejecutalo con source("grupos_Eubayanus.R"). Toma las funciones de
# clusters_Eubayanus.R sin correrlo (PHYLO_LIBRARY_ONLY = 1), agrupa los arboles
# con el mismo MST-kNN (los solitarios vuelven como grupos de 1 ORF) y no hace el
# enriquecimiento, que el paper no reporta para S. eubayanus. Escribe
# Eubayanus_clusters.tsv y Eubayanus_clusters_resumen.tsv; en el resumen,
# enriquecido = "pendiente" es la marca que preparar_app.R y la app leen como
# "no calculado". Si despues corres clusters_Eubayanus.R completo, sus archivos
# reemplazan a estos (mismos grupos, mas el enriquecimiento por ortologos).
# Fecha: 2026-10-10.
# =============================================================================
script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) { f <- sys.frame(i)$ofile; if (is.character(f) && length(f) == 1L && nzchar(f)) return(dirname(normalizePath(path.expand(f)))) }
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) return(dirname(normalizePath(path.expand(sub("^--file=", "", arg[1L])))))
  getwd()
}
local({
  dir <- script_dir()
  pk <- c("data.table", "igraph", "mstknnclust")
  falta <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta)) install.packages(falta, repos = "https://cloud.r-project.org")
  f <- file.path(dir, "clusters_Eubayanus.R")
  if (!file.exists(f)) stop("No encuentro ", f)
  old <- Sys.getenv("PHYLO_LIBRARY_ONLY"); Sys.setenv(PHYLO_LIBRARY_ONLY = "1"); on.exit(Sys.setenv(PHYLO_LIBRARY_ONLY = old))
  env <- new.env(parent = globalenv()); sys.source(f, envir = env)
  cfg <- env$CONFIG; cfg$install_packages <- FALSE
  bosque <- env$read_forest(dir, cfg$species)
  member <- env$cluster_trees(bosque$rf, bosque$res, cfg)
  rfc <- env$cluster_rf(member, bosque$rf)
  member[, orf_sgd := NA_character_]
  member[, como_se_mapeo := NA_character_]
  env$logmsg("Grupos: ", data.table::uniqueN(member$cluster), " | con 2 o mas ORFs: ", sum(table(member$cluster) >= 2L),
             " | de 1 ORF: ", sum(table(member$cluster) == 1L))
  env$write_tsv(member, file.path(dir, paste0(cfg$species, "_clusters.tsv")))
  # resumen con las mismas columnas que summarize_clusters de clusters_Eubayanus.R
  s <- member[, .(tamano = .N, origen = origen[1L], genes_anotados = NA_integer_), by = cluster]
  s <- merge(s, rfc, by = "cluster")
  s[, `:=`(terminos_FDR = NA_integer_, principales = NA_character_, enriquecido = "pendiente")]
  data.table::setorder(s, cluster)
  env$write_tsv(s, file.path(dir, paste0(cfg$species, "_clusters_resumen.tsv")))
  env$logmsg("listo")
})
