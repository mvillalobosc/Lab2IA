# =============================================================================
# utils_io.R
# -----------------------------------------------------------------------------
# EN: Export helpers. Every table is written three times: a machine-readable
#     CSV, an English LaTeX table and a Spanish LaTeX table. Figures are written
#     as both PDF (vector, for the manuscript) and PNG (raster, for previews).
# ES: Utilidades de exportacion. Cada tabla se escribe tres veces: un CSV
#     legible por maquina, una tabla LaTeX en ingles y una en espanol. Las
#     figuras se escriben en PDF (vectorial, para el manuscrito) y PNG (raster,
#     para vistas previas).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

# -----------------------------------------------------------------------------
# 1. CSV
# -----------------------------------------------------------------------------

#' Write a data frame as UTF-8 CSV into outputs/tables
#' EN: readr writes UTF-8 without a BOM, which is what LaTeX, pandas and R all
#'     expect. Excel on Windows may need the file opened via Data > From Text.
#' ES: readr escribe UTF-8 sin BOM, que es lo que esperan LaTeX, pandas y R.
#'     Excel en Windows puede necesitar abrirlo con Datos > Desde texto.
write_table_csv <- function(df, name, subdir = NULL) {
  dir <- if (is.null(subdir)) PATHS$tables else file.path(PATHS$tables, subdir)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, paste0(name, ".csv"))
  readr::write_csv(df, path, na = "")
  invisible(path)
}

# -----------------------------------------------------------------------------
# 2. LaTeX
# -----------------------------------------------------------------------------

#' Escape LaTeX special characters
#' EN: Book titles contain ampersands and percent signs that would otherwise
#'     break compilation. Accented characters are left as UTF-8, which works
#'     with both XeLaTeX and pdfLaTeX plus inputenc.
#' ES: Los titulos de libros traen ampersands y porcentajes que romperian la
#'     compilacion. Los acentos se dejan en UTF-8, lo que funciona tanto en
#'     XeLaTeX como en pdfLaTeX con inputenc.
latex_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([&%$#_{}])", "\\\\\\1", x)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  x <- gsub("\\^", "\\\\textasciicircum{}", x)
  x
}

#' Write a data frame as a booktabs LaTeX table
#' EN: Produces a standalone table environment ready to be \input into a
#'     manuscript. Requires \usepackage{booktabs} in the preamble.
#' ES: Produce un entorno table autonomo listo para \input en un manuscrito.
#'     Requiere \usepackage{booktabs} en el preambulo.
write_table_latex <- function(df,
                              name,
                              caption,
                              label,
                              lang    = c("en", "es"),
                              align   = NULL,
                              digits  = 3,
                              note    = NULL,
                              subdir  = NULL) {

  lang <- match.arg(lang)

  dir <- if (is.null(subdir)) PATHS$tables else file.path(PATHS$tables, subdir)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  # Round numeric columns for display without touching the stored CSV values.
  df_fmt <- df %>%
    dplyr::mutate(dplyr::across(
      dplyr::where(is.numeric),
      ~ formatC(.x, format = "g", digits = digits, flag = "#")
    )) %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), latex_escape))

  n_col <- ncol(df_fmt)
  if (is.null(align)) {
    # First column left-aligned (labels), the rest right-aligned (numbers).
    align <- paste0("l", strrep("r", n_col - 1))
  }

  header <- paste(paste0("\\textbf{", latex_escape(names(df_fmt)), "}"),
                  collapse = " & ")
  body   <- apply(df_fmt, 1, function(r) paste(r, collapse = " & "))
  body   <- paste0(body, " \\\\")

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\small",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    body,
    "\\bottomrule",
    "\\end{tabular}"
  )

  if (!is.null(note)) {
    lines <- c(lines,
               "\\vspace{0.5em}",
               paste0("\\begin{minipage}{\\linewidth}\\footnotesize ", note,
                      "\\end{minipage}"))
  }

  lines <- c(lines, "\\end{table}")

  path <- file.path(dir, paste0(name, "_", lang, ".tex"))
  con  <- file(path, open = "wt", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(lines, con)
  invisible(path)
}

#' Write CSV plus both LaTeX language versions in one call
#' EN: The single entry point used by the analysis scripts, so that no table can
#'     accidentally be exported in only one language.
#' ES: Punto de entrada unico usado por los scripts de analisis, para que
#'     ninguna tabla quede exportada por accidente en un solo idioma.
export_table <- function(df,
                         name,
                         caption_en,
                         caption_es,
                         label,
                         note_en = NULL,
                         note_es = NULL,
                         digits  = 3,
                         subdir  = NULL) {

  write_table_csv(df, name, subdir = subdir)

  write_table_latex(df, name, caption_en, paste0("tab:", label),
                    lang = "en", digits = digits, note = note_en, subdir = subdir)

  write_table_latex(df, name, caption_es, paste0("tab:", label, "-es"),
                    lang = "es", digits = digits, note = note_es, subdir = subdir)

  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# 3. Figures
# -----------------------------------------------------------------------------

#' Save a ggplot as PDF, optionally also as PNG
#' EN: PDF is vector and is what a journal requires, so it is always written.
#'     The PNG is a convenience preview only; it is off by default because
#'     writing both doubles the figure file count, and the repository is kept
#'     under the 100-file limit of the GitHub web uploader. Set png = TRUE to
#'     get the raster copies back.
#' ES: El PDF es vectorial y es lo que exige una revista, asi que siempre se
#'     escribe. El PNG es solo una vista previa de conveniencia; viene apagado
#'     por defecto porque escribir los dos duplica el conteo de archivos de
#'     figuras, y el repositorio se mantiene bajo el limite de 100 archivos del
#'     uploader web de GitHub. Poner png = TRUE para recuperar las copias raster.
save_figure <- function(plot, name, width = 10, height = 7, subdir = NULL,
                        png = FALSE) {

  dir <- if (is.null(subdir)) PATHS$figures else file.path(PATHS$figures, subdir)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  pdf_path <- file.path(dir, paste0(name, ".pdf"))
  png_path <- file.path(dir, paste0(name, ".png"))

  # cairo_pdf embeds fonts and handles UTF-8 book titles correctly; the base
  # pdf device drops accented glyphs on some Linux configurations.
  ok <- suppressWarnings(try(
    ggplot2::ggsave(pdf_path, plot, width = width, height = height,
                    device = grDevices::cairo_pdf),
    silent = TRUE
  ))
  if (inherits(ok, "try-error")) {
    ggplot2::ggsave(pdf_path, plot, width = width, height = height)
  }

  if (png) {
    ggplot2::ggsave(png_path, plot, width = width, height = height, dpi = 300)
  }

  invisible(if (png) c(pdf = pdf_path, png = png_path) else c(pdf = pdf_path))
}

#' Shared ggplot theme
#' EN: One theme for every figure so the manuscript is visually consistent.
#' ES: Un solo tema para todas las figuras para que el manuscrito sea
#'     visualmente consistente.
theme_papelucho <- function(base_size = 12) {
  ggplot2::theme_classic(base_size = base_size) +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.title      = ggplot2::element_text(face = "bold"),
      axis.title        = ggplot2::element_text(face = "bold"),
      axis.text         = ggplot2::element_text(colour = "black"),
      axis.line         = ggplot2::element_line(linewidth = 0.4, colour = "black"),
      axis.ticks        = ggplot2::element_line(linewidth = 0.4, colour = "black"),
      strip.background  = ggplot2::element_blank(),
      strip.text        = ggplot2::element_text(face = "bold"),
      plot.margin       = ggplot2::margin(6, 10, 6, 10)
    )
}


# -----------------------------------------------------------------------------
# 4. Publication-ready comparison tables
# -----------------------------------------------------------------------------
# EN: The full comparison output has twenty-one columns. That is the right shape
#     for a CSV a reader can re-analyse, and the wrong shape for a printed table:
#     it runs off the page and buries the three numbers that matter. This helper
#     produces the compact version, with metric names, column headers and cell
#     values all translated, so the Spanish table is genuinely in Spanish rather
#     than an English table with a Spanish caption.
# ES: La salida completa de comparacion tiene veintiuna columnas. Esa es la forma
#     correcta para un CSV que el lector pueda reanalizar, y la forma incorrecta
#     para una tabla impresa: se sale de la pagina y entierra los tres numeros
#     que importan. Esta funcion produce la version compacta, con nombres de
#     metrica, encabezados de columna y valores de celda traducidos, para que la
#     tabla en espanol este de verdad en espanol y no sea una tabla inglesa con
#     pie en espanol.

#' Format a comparison result table for printing in one language
#' @param results output of compare_many()
#' @param lang "en" or "es"
format_results_table <- function(results, lang = c("en", "es")) {

  lang <- match.arg(lang)

  out <- results %>%
    dplyr::transmute(
      metric        = label_for(metric, lang),
      median_focus,
      median_comparison,
      delta_ci      = format_delta(cliffs_delta, delta_lower, delta_upper),
      delta_magnitude,
      p_adjusted    = format_p(p_adjusted),
      higher_in,
      significant
    )

  # Round the two medians to a sensible number of significant digits, chosen
  # from the magnitude of the values themselves so that both a percentage and a
  # ratio below one print readably.
  rnd <- function(x) {
    if (all(is.na(x))) return(x)
    m <- stats::median(abs(x[is.finite(x) & x != 0]), na.rm = TRUE)
    d <- if (is.na(m) || m == 0) 3 else max(0, min(4, ceiling(-log10(m)) + 2))
    round(x, d)
  }
  out$median_focus      <- rnd(out$median_focus)
  out$median_comparison <- rnd(out$median_comparison)

  if (lang == "es") {
    tr <- function(x) {
      x <- as.character(x)
      hit <- match(x, names(VALUE_LABELS_ES))
      ifelse(is.na(hit), x, unname(VALUE_LABELS_ES[hit]))
    }
    out$delta_magnitude <- tr(out$delta_magnitude)
    out$higher_in       <- tr(out$higher_in)
    out$significant     <- tr(out$significant)
    # Spanish decimal comma, applied only at print time so the CSV keeps points.
    out$median_focus      <- gsub("\\.", ",", format(out$median_focus, trim = TRUE))
    out$median_comparison <- gsub("\\.", ",", format(out$median_comparison, trim = TRUE))
    out$delta_ci          <- gsub("\\.", ",", out$delta_ci)
    out$p_adjusted        <- gsub("\\.", ",", out$p_adjusted)
  } else {
    out$significant <- ifelse(out$significant, "Yes", "No")
  }

  names(out) <- column_label_for(names(out), lang)
  out
}

#' Export a comparison result as CSV plus compact LaTeX in both languages
#' EN: The CSV keeps every column for re-analysis; the two LaTeX files carry the
#'     compact, fully translated version for the manuscript.
#' ES: El CSV conserva todas las columnas para reanalisis; los dos archivos LaTeX
#'     llevan la version compacta y totalmente traducida para el manuscrito.
export_results <- function(results,
                           name,
                           caption_en,
                           caption_es,
                           label,
                           note_en = NULL,
                           note_es = NULL,
                           subdir  = NULL) {

  write_table_csv(results, name, subdir = subdir)

  for (lg in c("en", "es")) {
    tbl <- format_results_table(results, lang = lg)
    write_table_latex(
      tbl,
      name    = paste0(name, "_compact"),
      caption = if (lg == "en") caption_en else caption_es,
      label   = paste0("tab:", label, if (lg == "es") "-es" else ""),
      lang    = lg,
      align   = paste0("l", strrep("r", ncol(tbl) - 1)),
      digits  = 4,
      note    = if (lg == "en") note_en else note_es,
      subdir  = subdir
    )
  }

  invisible(TRUE)
}
