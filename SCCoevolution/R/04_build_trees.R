# =============================================================================
# 04_build_trees.R
# -----------------------------------------------------------------------------
# EN: Builds a neighbour-joining tree for each solution from its ORF alignments.
#
#     Distances are Hamming distances computed per gene and averaged across the
#     genes of a solution, then a neighbour-joining tree is built from the
#     averaged matrix. That is the procedure the original crear_arboles.R used
#     and it is preserved here.
#
#     WHAT WAS FIXED
#
#     1. SELECTING A SOLUTION MEANT EDITING THE SCRIPT. The original had three
#        gene vectors at the top, two commented out, and you switched solutions
#        by moving the comment markers. The output filename was separately
#        hard-coded as "sol1_tree.nwk", so building solution 2 while forgetting
#        to change that line silently overwrote solution 1's tree with solution
#        2's topology. This script takes the solution name as an argument and
#        derives the filename from it.
#
#     2. MISSING ALIGNMENTS WERE A WARNING, NOT AN ERROR. The original warned
#        and then built the tree from whatever files existed. Solution S10 lists
#        YJR138W2, which does not exist in the alignment database at all, so its
#        tree was built from two genes rather than three without anything in the
#        output recording that. Here a missing alignment stops the build unless
#        allow_missing = TRUE is passed, and the number of genes actually used is
#        written into the summary table either way.
#
#     3. NOTHING RECORDED WHAT PRODUCED A TREE. Each tree now gets a row in
#        outputs/tables/04_tree_summary.csv with the solution, the genes used,
#        the genes missing and the number of tips.
#
#     Usage:
#         Rscript R/04_build_trees.R              # every solution
#         Rscript R/04_build_trees.R S2 S9        # only these
#
# ES: Construye un arbol de neighbour-joining para cada solucion a partir de los
#     alineamientos de sus ORFs.
#
#     Las distancias son distancias de Hamming calculadas por gen y promediadas
#     entre los genes de una solucion, y despues se construye el arbol de
#     neighbour-joining con la matriz promediada. Es el procedimiento del
#     crear_arboles.R original y se conserva.
#
#     QUE SE ARREGLO
#
#     1. ELEGIR UNA SOLUCION IMPLICABA EDITAR EL SCRIPT. El original tenia tres
#        vectores de genes arriba, dos comentados, y se cambiaba de solucion
#        moviendo los comentarios. El nombre del archivo de salida estaba
#        escrito aparte como "sol1_tree.nwk", asi que construir la solucion 2 y
#        olvidar cambiar esa linea sobrescribia en silencio el arbol de la
#        solucion 1 con la topologia de la 2.
#
#     2. LOS ALINEAMIENTOS FALTANTES ERAN UN WARNING, NO UN ERROR. La solucion
#        S10 lista YJR138W2, que no existe en la base de alineamientos, asi que
#        su arbol se construyo con dos genes en vez de tres sin que nada lo
#        registrara.
#
#     3. NADA REGISTRABA QUE PRODUJO CADA ARBOL. Ahora cada arbol tiene una fila
#        en outputs/tables/04_tree_summary.csv.
# =============================================================================

source("R/00_config.R")
source("R/utils_solutions.R")

check_dependencies(quiet = TRUE)
log_msg("04_build_trees: start")

suppressPackageStartupMessages({
  library(ape)
  library(phangorn)
  library(dplyr)
  library(readr)
})

sols <- read_solutions()

# Only unpack what this run needs. Rebuilding one tree should not force an
# 8.4 GB unpack of the whole database.
args_pre <- commandArgs(trailingOnly = TRUE)
needed   <- unique(unlist(sols[if (length(args_pre)) intersect(args_pre, names(sols)) else names(sols)]))
ensure_alignments(required_orfs = needed)

args     <- args_pre
selected <- if (length(args) == 0) names(sols) else args

unknown <- setdiff(selected, names(sols))
if (length(unknown) > 0) {
  stop("Unknown solution(s): ", paste(unknown, collapse = ", "),
       "\nAvailable: ", paste(names(sols), collapse = ", "), call. = FALSE)
}

# -----------------------------------------------------------------------------
# Build one tree
# -----------------------------------------------------------------------------

build_tree <- function(solution, orfs, allow_missing = FALSE) {

  chk <- check_alignments(orfs)

  if (chk$n_missing > 0) {
    msg <- paste0("Solution ", solution, " lists ", length(orfs),
                  " ORFs but ", chk$n_missing, " have no alignment: ",
                  paste(chk$missing, collapse = ", "))
    if (!allow_missing) {
      stop(msg, "\nPass allow_missing = TRUE to build the tree from the ",
           length(chk$available), " available alignments instead.", call. = FALSE)
    }
    warning(msg, call. = FALSE)
  }

  if (length(chk$available) == 0) {
    stop("Solution ", solution, " has no usable alignments.", call. = FALSE)
  }

  dist_total <- NULL
  for (f in chk$files[chk$present]) {
    aln <- phangorn::read.phyDat(f, format = "phylip")
    d   <- as.matrix(phangorn::dist.hamming(aln))
    # Guard against alignments whose taxon sets differ; averaging matrices with
    # different row orders would silently mix distances between wrong strains.
    if (is.null(dist_total)) {
      dist_total <- d
    } else {
      if (!identical(dimnames(d), dimnames(dist_total))) {
        common <- intersect(rownames(d), rownames(dist_total))
        stop("Alignment ", basename(f), " has a different taxon set (",
             nrow(d), " taxa) from the previous ones (", nrow(dist_total),
             "); ", length(common), " taxa in common. Trees cannot be averaged ",
             "across alignments with mismatched taxa.", call. = FALSE)
      }
      dist_total <- dist_total + d
    }
  }

  dist_mean <- dist_total / length(chk$available)
  tree      <- ape::nj(stats::as.dist(dist_mean))

  list(
    tree        = tree,
    n_requested = length(orfs),
    n_used      = length(chk$available),
    missing     = chk$missing,
    n_tips      = length(tree$tip.label)
  )
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

summaries <- list()

for (s in selected) {
  log_msg("  building ", s, " (", length(sols[[s]]), " ORFs)")

  # allow_missing is TRUE so the whole run does not abort on the one known bad
  # ORF; the summary table records exactly what happened for every solution.
  res <- try(build_tree(s, sols[[s]], allow_missing = TRUE), silent = TRUE)

  if (inherits(res, "try-error")) {
    log_msg("    FAILED: ", conditionMessage(attr(res, "condition")))
    summaries[[s]] <- tibble::tibble(
      solution = s, n_orfs_requested = length(sols[[s]]),
      n_orfs_used = NA_integer_, missing_orfs = NA_character_,
      n_tips = NA_integer_, status = "failed"
    )
    next
  }

  out <- file.path(PATHS$trees, paste0(tolower(s), "_tree.nwk"))
  ape::write.tree(res$tree, file = out)

  summaries[[s]] <- tibble::tibble(
    solution         = s,
    n_orfs_requested = res$n_requested,
    n_orfs_used      = res$n_used,
    missing_orfs     = if (length(res$missing)) paste(res$missing, collapse = " ") else "",
    n_tips           = res$n_tips,
    status           = if (res$n_used < res$n_requested) "built with missing ORFs" else "ok"
  )

  log_msg("    ", res$n_used, "/", res$n_requested, " ORFs, ",
          res$n_tips, " tips -> ", basename(out))
}

summary_tbl <- dplyr::bind_rows(summaries)
readr::write_csv(summary_tbl, file.path(PATHS$tables, "04_tree_summary.csv"))

incomplete <- summary_tbl %>% dplyr::filter(status != "ok")
if (nrow(incomplete) > 0) {
  log_msg("  ", nrow(incomplete), " tree(s) not built from the full ORF set:")
  print(as.data.frame(incomplete), row.names = FALSE)
}

write_session_info("04_build_trees")
log_msg("04_build_trees: done")
