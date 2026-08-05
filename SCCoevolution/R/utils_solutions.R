# =============================================================================
# utils_solutions.R
# -----------------------------------------------------------------------------
# EN: Loads the fifteen ORF sets and the alignments they need.
#
#     WHY THIS FILE EXISTS
#     In the original project the fifteen gene sets were written out as literal
#     vectors inside the R scripts, and the same 130 lines were duplicated
#     verbatim in Upset/main.R and Upset/interseccion.R. A third copy, partly
#     commented out, sat at the top of Arboles/crear_arboles.R. Three copies of
#     the same data means three chances to edit one and forget the others, and
#     no way to tell afterwards which copy the published figure came from.
#
#     The sets now live in data/solutions.csv, in long format, and every script
#     reads them from there. Changing a solution is one edit in one file.
#
# ES: Carga los quince conjuntos de ORFs y los alineamientos que necesitan.
#
#     POR QUE EXISTE ESTE ARCHIVO
#     En el proyecto original los quince conjuntos de genes estaban escritos como
#     vectores literales dentro de los scripts de R, y las mismas 130 lineas
#     estaban duplicadas textualmente en Upset/main.R y Upset/interseccion.R. Una
#     tercera copia, parcialmente comentada, estaba al inicio de
#     Arboles/crear_arboles.R. Tres copias del mismo dato son tres oportunidades
#     de editar una y olvidar las otras, y despues no hay forma de saber de que
#     copia salio la figura publicada.
#
#     Los conjuntos ahora viven en data/solutions.csv, en formato largo, y todos
#     los scripts los leen de ahi. Cambiar una solucion es una edicion en un
#     archivo.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

# -----------------------------------------------------------------------------
# 1. Solutions
# -----------------------------------------------------------------------------

#' Read solutions.csv in long format
#' EN: One row per (solution, ORF) pair. The `source` column distinguishes the
#'     reference solution from the Pareto-front solutions.
#' ES: Una fila por par (solucion, ORF). La columna `source` distingue la
#'     solucion de referencia de las soluciones del frente de Pareto.
read_solutions_long <- function(path = FILES$solutions) {
  if (!file.exists(path)) {
    stop("Solutions file not found: ", path, call. = FALSE)
  }
  readr::read_csv(path, col_types = readr::cols(
    solution = readr::col_character(),
    orf      = readr::col_character(),
    source   = readr::col_character()
  ), progress = FALSE)
}

#' Return the solutions as a named list of ORF vectors
#' EN: The order of the list follows the order of first appearance in the file,
#'     so the reference solution stays first and S1 to S14 follow. UpSetR uses
#'     that order when keep.order = TRUE, and a set that silently reorders
#'     produces a different figure from the same data.
#' ES: El orden de la lista sigue el orden de primera aparicion en el archivo,
#'     asi la solucion de referencia queda primero y S1 a S14 despues. UpSetR usa
#'     ese orden cuando keep.order = TRUE, y un conjunto que se reordena en
#'     silencio produce una figura distinta con los mismos datos.
read_solutions <- function(path = FILES$solutions) {
  long <- read_solutions_long(path)
  split(long$orf, factor(long$solution, levels = unique(long$solution)))
}

#' Summary table: one row per solution
solution_summary <- function(solutions = read_solutions()) {
  tibble::tibble(
    solution = names(solutions),
    n_orfs   = lengths(solutions),
    orfs     = vapply(solutions, function(x) paste(sort(x), collapse = " "), character(1))
  )
}

# -----------------------------------------------------------------------------
# 2. Alignment availability
# -----------------------------------------------------------------------------

#' Check which ORFs in the solutions have an alignment on disk
#'
#' EN: The original crear_arboles.R warned about missing alignment files and
#'     then carried on building the tree from whatever was left. That is the
#'     wrong default for a published result: solution S10 lists three ORFs, one
#'     of which (YJR138W2) does not exist in the alignment database at all, so
#'     its tree was silently built from two genes instead of three and the
#'     figure caption still said three.
#'
#'     This function makes the check explicit and returns the result rather than
#'     hiding it in a warning. Scripts that build trees stop on a missing
#'     alignment unless the caller passes allow_missing = TRUE, in which case
#'     the actual number of genes used is recorded in the output.
#'
#' ES: El crear_arboles.R original advertia sobre archivos de alineamiento
#'     faltantes y despues seguia construyendo el arbol con lo que quedara. Ese
#'     es el default equivocado para un resultado publicado: la solucion S10
#'     lista tres ORFs, uno de los cuales (YJR138W2) no existe en la base de
#'     alineamientos, asi que su arbol se construyo en silencio con dos genes en
#'     vez de tres y el pie de figura seguia diciendo tres.
#'
#'     Esta funcion hace el chequeo explicito y devuelve el resultado en vez de
#'     esconderlo en un warning. Los scripts que construyen arboles se detienen
#'     ante un alineamiento faltante salvo que quien los llame pase
#'     allow_missing = TRUE, en cuyo caso el numero real de genes usados queda
#'     registrado en la salida.
check_alignments <- function(orfs, dir = PATHS$alignments) {
  files   <- file.path(dir, paste0(orfs, ".fasta.phylip"))
  present <- file.exists(files)
  list(
    orfs      = orfs,
    files     = files,
    present   = present,
    available = orfs[present],
    missing   = orfs[!present],
    n_missing = sum(!present)
  )
}

#' Unpack the alignment database if it is not already on disk
#'
#' EN: The full database is 6015 alignments of 1011 taxa, 8.4 GB unpacked. It
#'     ships as two zip parts because GitHub rejects any single file above
#'     100 MB, and the whole database compresses to 144 MB. The split is by file,
#'     not by byte range, so each part is a valid archive on its own; there is no
#'     need to concatenate them before unpacking.
#'
#'     The full database matters because the multi-objective search evaluates
#'     candidate ORF subsets against all 6015 genes. Shipping only the 106 that
#'     the final solutions happen to use would let a reader rebuild the published
#'     trees but not re-run the optimisation that produced them, which for a
#'     methods paper is the part that most needs to be reproducible.
#'
#'     Unpacking is idempotent and needs 8.4 GB of free disk.
#'
#' ES: La base completa son 6015 alineamientos de 1011 taxones, 8,4 GB
#'     descomprimidos. Viaja en dos partes zip porque GitHub rechaza cualquier
#'     archivo individual sobre 100 MB, y la base entera comprime a 144 MB. La
#'     division es por archivo, no por rango de bytes, asi que cada parte es un
#'     archivo valido por si sola; no hay que concatenarlas antes de descomprimir.
#'
#'     La base completa importa porque la busqueda multiobjetivo evalua
#'     subconjuntos candidatos de ORFs contra los 6015 genes. Distribuir solo los
#'     106 que las soluciones finales usan permitiria reconstruir los arboles
#'     publicados pero no volver a correr la optimizacion que los produjo, que en
#'     un paper de metodo es justamente la parte que mas necesita ser
#'     reproducible.
#'
#'     Descomprimir es idempotente y necesita 8,4 GB de disco libre.
ensure_alignments <- function(dir = PATHS$alignments,
                              db_dir = PATHS$alignments_db,
                              required_orfs = NULL) {

  parts <- sort(list.files(db_dir, pattern = "^alignments_part\\d+\\.zip$",
                           full.names = TRUE))

  present <- list.files(dir, pattern = "\\.phylip$")

  # --- Selective path -------------------------------------------------------
  # EN: When the caller names the ORFs it needs, only those are extracted. The
  #     whole database is 8.4 GB unpacked, and unpacking all of it to build one
  #     tree from one gene both wastes time and can fill a disk that has room
  #     for the analysis but not for the raw corpus. Extraction is per file, so
  #     the cost scales with what is actually used.
  # ES: Cuando quien llama nombra los ORFs que necesita, solo esos se extraen. La
  #     base completa son 8,4 GB descomprimidos, y descomprimirla entera para
  #     construir un arbol de un gen desperdicia tiempo y puede llenar un disco
  #     que tiene espacio para el analisis pero no para el corpus crudo. La
  #     extraccion es por archivo, asi que el costo escala con lo que se usa.
  if (!is.null(required_orfs)) {

    want <- paste0(required_orfs, ".fasta.phylip")
    todo <- setdiff(want, present)

    if (length(todo) == 0) return(invisible(length(present)))

    if (length(parts) == 0) {
      stop("Alignments needed but no archive parts in ", db_dir,
           "\nMissing: ", paste(sub("\\.fasta\\.phylip$", "", todo), collapse = ", "),
           call. = FALSE)
    }

    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

    message("Extracting ", length(todo), " alignment(s) from the database ...")
    for (p in parts) {
      inside <- utils::unzip(p, list = TRUE)$Name
      hit    <- inside[basename(inside) %in% todo]
      if (length(hit) > 0) {
        utils::unzip(p, files = hit, exdir = dir, junkpaths = TRUE)
      }
    }

    still <- setdiff(want, list.files(dir, pattern = "\\.phylip$"))
    if (length(still) > 0) {
      message("  not in the database: ",
              paste(sub("\\.fasta\\.phylip$", "", still), collapse = ", "))
    }
    return(invisible(length(list.files(dir, pattern = "\\.phylip$"))))
  }

  # --- Full unpack ----------------------------------------------------------
  # EN: Only for re-running the optimisation, which does need every gene.
  #     Requires about 8.4 GB of free disk.
  # ES: Solo para volver a correr la optimizacion, que si necesita todos los
  #     genes. Requiere unos 8,4 GB de disco libre.
  if (length(present) > 0) return(invisible(length(present)))

  if (length(parts) == 0) {
    stop("No alignments in ", dir, " and no archive parts in ", db_dir,
         "\nSee the Data section of the README.", call. = FALSE)
  }

  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  free_note <- "unpacking the full database needs about 8.4 GB of free disk"
  message("Unpacking ", length(parts), " archive part(s) into ", dir,
          " (", free_note, ") ...")
  for (p in parts) {
    message("  ", basename(p))
    utils::unzip(p, exdir = dir, junkpaths = TRUE)
  }

  n <- length(list.files(dir, pattern = "\\.phylip$"))
  message("  ", n, " alignments ready")

  # The manifest is the authority on how many there should be, so a truncated
  # unpack is caught here rather than surfacing later as a missing gene.
  if (file.exists(FILES$manifest)) {
    expected <- nrow(readr::read_csv(FILES$manifest, show_col_types = FALSE))
    if (n < expected) {
      warning(n, " alignments unpacked but the manifest lists ", expected,
              ". The archive may be incomplete or the disk may be full.",
              call. = FALSE)
    }
  }

  invisible(n)
}

# -----------------------------------------------------------------------------
# 3. Solution labels
# -----------------------------------------------------------------------------

#' Format a solution name for a plot
#' EN: "S1" becomes "S[1]" in plain text or "S<sub>1</sub>" in HTML, which is
#'     what plotly needs. The original script built these labels by stripping
#'     non-digits from a hand-written vector, which broke for the label covering
#'     two coincident solutions.
#' ES: "S1" pasa a "S[1]" en texto plano o "S<sub>1</sub>" en HTML, que es lo que
#'     necesita plotly. El script original armaba estas etiquetas quitando los no
#'     digitos de un vector escrito a mano, lo que fallaba con la etiqueta que
#'     cubre dos soluciones coincidentes.
label_solution <- function(x, format = c("plain", "html")) {
  format <- match.arg(format)
  idx <- sub("^S", "", x)
  if (format == "plain") paste0("S[", idx, "]") else paste0("S<sub>", idx, "</sub>")
}
