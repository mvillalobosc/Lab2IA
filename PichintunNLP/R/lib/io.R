# =============================================================================
# io.R  Lectura, escritura y cacheo de artefactos intermedios
# =============================================================================

# Guarda un objeto en data/processed y lo devuelve invisible.
save_step <- function(obj, name) {
  f <- file.path(CFG$dir_processed, paste0(name, ".rds"))
  saveRDS(obj, f)
  log_msg("guardado: data/processed/", name, ".rds")
  invisible(obj)
}

# Lee un artefacto intermedio. Falla con mensaje explicito si no existe.
load_step <- function(name) {
  f <- file.path(CFG$dir_processed, paste0(name, ".rds"))
  if (!file.exists(f)) {
    stop("Falta el artefacto '", name, "'. Ejecute los modulos previos ",
         "o use run_all.R para correr el pipeline completo.")
  }
  readRDS(f)
}

step_exists <- function(name) {
  file.exists(file.path(CFG$dir_processed, paste0(name, ".rds")))
}

# Exporta una tabla a outputs/tables en CSV (UTF-8 con BOM para Excel).
write_table_out <- function(df, name) {
  f <- file.path(CFG$dir_tables, paste0(name, ".csv"))
  readr::write_excel_csv(as.data.frame(df), f)
  log_msg("tabla: outputs/tables/", name, ".csv  (", nrow(df), " x ", ncol(df), ")")
  invisible(f)
}

# Exporta varias tablas a un unico libro Excel.
write_workbook_out <- function(lst, name) {
  f <- file.path(CFG$dir_tables, paste0(name, ".xlsx"))
  writexl::write_xlsx(lapply(lst, as.data.frame), f)
  log_msg("libro: outputs/tables/", name, ".xlsx  (", length(lst), " hojas)")
  invisible(f)
}

# Guarda un grafico ggplot o una expresion de graficos base.
save_fig <- function(x, name, width = CFG$fig_width, height = CFG$fig_height) {
  f <- file.path(CFG$dir_figures, paste0(name, ".png"))
  if (inherits(x, "ggplot") || inherits(x, "patchwork")) {
    ggplot2::ggsave(f, x, width = width, height = height, dpi = CFG$fig_dpi, limitsize = FALSE)
  } else {
    grDevices::png(f, width = width, height = height, units = "in", res = CFG$fig_dpi)
    on.exit(grDevices::dev.off(), add = TRUE)
    if (is.function(x)) x() else print(x)
  }
  log_msg("figura: outputs/figures/", name, ".png")
  invisible(f)
}

# Guarda una lista de ggplots como paginas de una grilla nrow x ncol.
save_fig_grid <- function(plots, name, nrow = 2, ncol = 2,
                          width = CFG$fig_width, height = CFG$fig_height) {
  plots <- Filter(Negate(is.null), plots)
  if (length(plots) == 0) return(invisible(NULL))
  per <- nrow * ncol
  pages <- split(seq_along(plots), ceiling(seq_along(plots) / per))
  files <- character(0)
  for (i in seq_along(pages)) {
    sfx <- if (length(pages) > 1) sprintf("_p%02d", i) else ""
    f <- file.path(CFG$dir_figures, paste0(name, sfx, ".png"))
    grDevices::png(f, width = width, height = height, units = "in", res = CFG$fig_dpi)
    gridExtra::grid.arrange(grobs = plots[pages[[i]]], nrow = nrow, ncol = ncol)
    grDevices::dev.off()
    files <- c(files, f)
  }
  log_msg("figura: outputs/figures/", name, " (", length(pages), " pagina(s))")
  invisible(files)
}

# Convierte fechas con nombre de mes en espanol sin depender del locale del
# sistema. as.Date(x, "%B %d, %Y") devuelve NA bajo locale C, que es el caso
# habitual en servidores Linux.
parse_fecha_es <- function(x) {
  meses <- c(enero = 1, febrero = 2, marzo = 3, abril = 4, mayo = 5, junio = 6,
             julio = 7, agosto = 8, septiembre = 9, setiembre = 9, octubre = 10,
             noviembre = 11, diciembre = 12)
  x <- trimws(as.character(x))
  m <- regmatches(x, regexec("^([[:alpha:]]+)\\s+([0-9]{1,2}),\\s*([0-9]{4})$", x))
  vapply(m, function(p) {
    if (length(p) != 4L) return(NA_real_)
    mes <- meses[tolower(p[2])]
    if (is.na(mes)) return(NA_real_)
    as.numeric(as.Date(sprintf("%s-%02d-%02d", p[4], mes, as.integer(p[3]))))
  }, numeric(1)) |> as.Date(origin = "1970-01-01")
}
