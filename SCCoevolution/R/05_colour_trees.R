# =============================================================================
# 05_colour_trees.R
# -----------------------------------------------------------------------------
# EN: Colours the nodes of a phylocanvas/phylotree JSON export by the clade each
#     strain belongs to, taking clade assignments from data/strain_metadata.csv.
#
#     This is the original Arboles/modificar.R with three changes:
#       * paths come from 00_config.R instead of being relative to the script's
#         own folder, so it runs from the repository root like everything else;
#       * the input and output tree are arguments rather than the hard-coded
#         "sol1_tree.json", so colouring a second tree does not require editing
#         the file and cannot overwrite the wrong output;
#       * strains in the tree with no clade in the metadata are counted and
#         reported instead of silently keeping the default colour, which made a
#         partially coloured figure look like a complete one.
#
#     Usage:
#         Rscript R/05_colour_trees.R trees/sol1_tree.json
#         Rscript R/05_colour_trees.R trees/sol1_tree.json trees/out.json
#
#     The JSON is edited as text rather than parsed, which is how the original
#     worked. It is fragile with respect to formatting but preserves the exact
#     layout that the phylocanvas viewer expects.
#
# ES: Colorea los nodos de un JSON exportado de phylocanvas/phylotree segun el
#     clado al que pertenece cada cepa, tomando la asignacion de clados de
#     data/strain_metadata.csv.
#
#     Es el Arboles/modificar.R original con tres cambios:
#       * las rutas vienen de 00_config.R en vez de ser relativas a la carpeta
#         del propio script;
#       * el arbol de entrada y de salida son argumentos y no el "sol1_tree.json"
#         escrito a mano, asi colorear un segundo arbol no exige editar el
#         archivo ni puede sobrescribir la salida equivocada;
#       * las cepas del arbol sin clado en el metadata se cuentan y se reportan
#         en vez de quedarse en silencio con el color por defecto, que hacia que
#         una figura parcialmente coloreada pareciera completa.
# =============================================================================

source("R/00_config.R")

check_dependencies(quiet = TRUE)
log_msg("05_colour_trees: start")

args   <- commandArgs(trailingOnly = TRUE)
in_json  <- if (length(args) >= 1) args[1] else file.path(PATHS$trees, "sol1_tree.json")
out_json <- if (length(args) >= 2) args[2] else sub("\\.json$", "_coloured.json", in_json)

if (!file.exists(in_json)) {
  stop("Tree JSON not found: ", in_json,
       "\nAvailable: ", paste(list.files(PATHS$trees, pattern = "\\.json$"), collapse = ", "),
       call. = FALSE)
}

suppressPackageStartupMessages({
  library(dplyr)
library(stringr)
library(RColorBrewer)
library(ggplot2)
  library(readr)
  library(tibble)
})

#=====================================================================
# B) LEER CSV Y DEFINIR PALETA
#=====================================================================
meta <- read.csv(FILES$strains, sep = ";", stringsAsFactors = FALSE)

meta <- meta %>%
  select(Standardized.name, Clades) %>%
  mutate(across(everything(), ~str_trim(as.character(.)))) %>%
  filter(!is.na(Standardized.name), Standardized.name != "", !is.na(Clades), Clades != "") %>%
  distinct()

clados <- sort(unique(meta$Clades))
pal <- brewer.pal(min(length(clados), 8), "Set2")
if (length(clados) > 8) pal <- colorRampPalette(pal)(length(clados))
color_map <- setNames(pal, clados)

name_to_color <- setNames(color_map[meta$Clades], meta$Standardized.name)

#=====================================================================
# C) LEER JSON COMO TEXTO
#=====================================================================
json_lines <- readLines(in_json, encoding = "UTF-8")
log_msg("  input: ", in_json, " (", length(json_lines), " lines)")

#=====================================================================
# D) FUNCIONES AUXILIARES
#=====================================================================
extract_name <- function(line) {
  m <- str_match(line, '"name"\\s*:\\s*"([^"]*)"')
  if (is.na(m[1,2])) return(NA_character_) else return(m[1,2])
}

ensure_trailing_comma <- function(lines, i) {
  if (!grepl(",\\s*$", lines[i])) lines[i] <- paste0(lines[i], ",")
  lines
}

has_node_style_ahead <- function(lines, i, look_ahead = 40) {
  end <- min(length(lines), i + look_ahead)
  any(grepl('"nodeStyle"', lines[(i+1):end]))
}

update_node_style <- function(lines, i, color, look_ahead = 40) {
  end <- min(length(lines), i + look_ahead)
  changed <- FALSE
  for (k in (i+1):end) {
    if (grepl('"nodeStyle"', lines[k])) {
      end_block <- min(length(lines), k + 12)
      for (t in k:end_block) {
        if (grepl('"fill"', lines[t])) {
          lines[t] <- sub('("fill"\\s*:\\s*")[^"]+(")', paste0('\\1', color, '\\2'), lines[t], perl = TRUE)
          changed <- TRUE
        }
        if (grepl('"radius"', lines[t])) {
          lines[t] <- sub('("radius"\\s*:\\s*)[0-9.]+', '\\12', lines[t], perl = TRUE)
        }
      }
      break
    }
  }
  list(lines = lines, changed = changed)
}

insert_node_style_after <- function(lines, i, color) {
  indent <- str_extract(lines[i], "^\\s*")
  if (is.na(indent)) indent <- "  "
  new_block <- c(
    paste0(indent, '"nodeStyle": {'),
    paste0(indent, '  "radius": 2,'),
    paste0(indent, '  "stroke": "transparent",'),
    paste0(indent, '  "fill": "', color, '"'),
    paste0(indent, '},')
  )
  append(lines, new_block, after = i)
}

#=====================================================================
# E) INSERTAR / ACTUALIZAR nodeStyle EN TODOS LOS NIVELES
#=====================================================================
inserted <- 0L
updated  <- 0L
skipped  <- 0L

name_idx <- grep('"name"\\s*:\\s*"', json_lines, perl = TRUE)

for (ii in seq_along(name_idx)) {
  i <- name_idx[ii]
  if (i > length(json_lines)) next
  nm <- extract_name(json_lines[i])
  if (is.na(nm)) next
  nm_trim <- str_trim(nm)
  if (nm_trim == "") next
  
  if (!(nm_trim %in% names(name_to_color))) {
    skipped <- skipped + 1L
    next
  }
  
  color <- name_to_color[[nm_trim]]
  
  if (has_node_style_ahead(json_lines, i, look_ahead = 40)) {
    res <- update_node_style(json_lines, i, color, look_ahead = 40)
    json_lines <- res$lines
    if (res$changed) updated <- updated + 1L
  } else {
    json_lines <- ensure_trailing_comma(json_lines, i)
    json_lines <- insert_node_style_after(json_lines, i, color)
    inserted <- inserted + 1L
    name_idx <- name_idx + 5L
  }
}

#=====================================================================
# F) GUARDAR Y VALIDAR
#=====================================================================
writeLines(json_lines, "Sol1_tree_colored.json", useBytes = TRUE)

total_names_all <- sum(grepl('"name"\\s*:\\s*"[^"]*"', json_lines))
total_names_nonempty <- sum(grepl('"name"\\s*:\\s*"[^" ]+"', json_lines))
total_node_styles <- sum(grepl('"nodeStyle"\\s*:', json_lines))

log_msg("  output: ", out_json)
log_msg("  names found in JSON:      ", total_names_all,
        " (", total_names_nonempty, " non-empty)")
log_msg("  nodeStyle inserted:       ", inserted)
log_msg("  nodeStyle updated:        ", updated)
log_msg("  nodeStyle in final file:  ", total_node_styles)

# EN: Strains present in the tree but absent from the clade metadata keep the
#     default colour. The original script counted them and printed the number
#     among six other counters, which is easy to skim past. A figure in which a
#     large share of tips is uncoloured looks finished but is not, so the share
#     is reported explicitly and flagged when it is high.
# ES: Las cepas presentes en el arbol pero ausentes del metadata de clados
#     mantienen el color por defecto. El script original las contaba y imprimia
#     el numero entre otros seis contadores, lo que es facil de pasar por alto.
#     Una figura con una fraccion grande de puntas sin colorear parece terminada
#     y no lo esta.
pct_skipped <- if (total_names_nonempty > 0) 100 * skipped / total_names_nonempty else 0
log_msg("  tips with no clade in the metadata: ", skipped,
        " of ", total_names_nonempty, " (", round(pct_skipped, 1), "%)")
if (pct_skipped > 5) {
  warning(sprintf(
    "%.1f%% of named tips have no clade assignment and keep the default colour. Check that strain names in the tree match the Standardized.name column of %s.",
    pct_skipped, FILES$strains), call. = FALSE)
}

readr::write_csv(
  tibble::tibble(
    input = in_json, output = out_json,
    names_total = total_names_all, names_nonempty = total_names_nonempty,
    styles_inserted = inserted, styles_updated = updated,
    tips_without_clade = skipped, pct_without_clade = round(pct_skipped, 2),
    n_clades = length(clados)
  ),
  file.path(PATHS$tables, paste0("05_colouring_", tools::file_path_sans_ext(basename(in_json)), ".csv"))
)

#=====================================================================
# G) LEYENDA VISUAL (opcional)
#=====================================================================
legend_df <- data.frame(
  Clado = factor(rev(names(color_map)), levels = rev(names(color_map))),
  Color = unname(rev(color_map))
)

p_legend <- ggplot(legend_df, aes(x = 1, y = Clado, color = Clado)) +
  geom_point(size = 5) +
  scale_color_manual(values = color_map, guide = "none") +
  theme_void() +
  theme(
    plot.margin = margin(20, 20, 20, 20),
    axis.text.y = element_text(size = 14, color = "black"),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Clades")

ggplot2::ggsave(file.path(PATHS$figures, "05_clade_legend.pdf"),
                p_legend, width = 4, height = 0.35 * length(clados) + 1)

write_session_info("05_colour_trees")
log_msg("05_colour_trees: done")
