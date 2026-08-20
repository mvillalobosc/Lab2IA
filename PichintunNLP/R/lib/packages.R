# Declaracion unica de dependencias del pipeline.
# Cada paquete listado aqui se usa efectivamente en algun modulo.

PKGS_CRAN <- c(
  "dplyr", "tidyr", "purrr", "readr", "stringr", "tibble", "ggplot2",
  "tokenizers", "tm", "hunspell",
  "quanteda", "quanteda.textstats", "quanteda.textplots",
  "sentimentr", "koRpus", "koRpus.lang.es",
  "fmsb", "corrplot", "dendextend", "amap", "mstknnclust",
  "ggwordcloud", "patchwork", "gridExtra", "scales",
  "igraph", "caret", "randomForest", "writexl"
)

check_packages <- function(install_missing = FALSE) {
  installed <- rownames(installed.packages())
  missing <- setdiff(PKGS_CRAN, installed)
  if (length(missing) > 0) {
    if (isTRUE(install_missing)) {
      install.packages(missing, dependencies = TRUE)
      missing <- setdiff(PKGS_CRAN, rownames(installed.packages()))
    }
    if (length(missing) > 0) {
      stop("Faltan paquetes: ", paste(missing, collapse = ", "),
           "\nEjecute: source('R/lib/packages.R'); check_packages(install_missing = TRUE)")
    }
  }
  invisible(TRUE)
}

load_packages <- function() {
  check_packages()
  suppressPackageStartupMessages(
    invisible(lapply(PKGS_CRAN, library, character.only = TRUE))
  )
  invisible(TRUE)
}
