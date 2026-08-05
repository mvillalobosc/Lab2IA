# =============================================================================
# utils_objectives.R
# -----------------------------------------------------------------------------
# EN: The two objective functions the optimisation minimises.
#
#     WHY THIS FILE EXISTS
#     The MOSA and NSGA-II implementation is not part of this repository. What
#     the project ships are the optimiser's outputs: the Pareto fronts in
#     pareto_fronts.csv, the hypervolume runs in hypervolume.csv, and the fifteen
#     solutions in solutions.csv. Without the search code those numbers can be
#     read but not checked.
#
#     The objective functions, however, are fully specified by the manuscript and
#     computable from the data that is here. Implementing them makes the
#     *evaluation* reproducible even while the *search* is not: anyone can take a
#     published solution, recompute its two objective values from the alignments
#     and the reference tree, and confirm that the point lies where the published
#     front says it does. That is the strongest reproducibility claim this
#     repository can support until the optimiser source is added.
#
#     THE TWO OBJECTIVES
#       f1  Number of selected ORFs, normalised. Minimised: fewer genes is a
#           cheaper marker panel.
#       f2  Normalised Robinson-Foulds distance between the tree inferred from
#           the selected ORFs and the whole-genome reference tree. Minimised: a
#           smaller value means the small panel recovers the reference topology.
#
#     Both range in [0, 1] and are minimised, so the front runs from
#     few-genes/high-distance to many-genes/low-distance.
#
# ES: Las dos funciones objetivo que minimiza la optimizacion.
#
#     POR QUE EXISTE ESTE ARCHIVO
#     La implementacion de MOSA y NSGA-II no es parte de este repositorio. Lo que
#     el proyecto distribuye son las salidas del optimizador: los frentes de
#     Pareto en pareto_fronts.csv, las corridas de hipervolumen en
#     hypervolume.csv, y las quince soluciones en solutions.csv. Sin el codigo de
#     busqueda esos numeros se pueden leer pero no verificar.
#
#     Las funciones objetivo, en cambio, estan completamente especificadas en el
#     manuscrito y son calculables con los datos que si estan. Implementarlas
#     vuelve reproducible la *evaluacion* aunque la *busqueda* no lo sea:
#     cualquiera puede tomar una solucion publicada, recalcular sus dos valores
#     objetivo desde los alineamientos y el arbol de referencia, y confirmar que
#     el punto queda donde dice el frente publicado. Es la afirmacion de
#     reproducibilidad mas fuerte que este repositorio puede sostener hasta que
#     se agregue el codigo del optimizador.
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(phangorn)
  library(dplyr)
})

# -----------------------------------------------------------------------------
# 1. Tree inference from a candidate ORF subset
# -----------------------------------------------------------------------------

#' Build a neighbour-joining tree from a set of ORF alignments
#'
#' EN: Hamming distances are computed per gene and averaged across the genes of
#'     the subset, then neighbour-joining is applied to the averaged matrix.
#'     This is the procedure used throughout the project.
#'
#'     Averaging requires that every alignment covers the same taxa in the same
#'     order. That is checked rather than assumed: adding two distance matrices
#'     whose row orders differ would mix distances between different strains and
#'     produce a tree that looks plausible and is wrong.
#'
#' ES: Las distancias de Hamming se calculan por gen y se promedian entre los
#'     genes del subconjunto, y despues se aplica neighbour-joining a la matriz
#'     promediada. Es el procedimiento usado en todo el proyecto.
#'
#'     Promediar exige que todos los alineamientos cubran los mismos taxones en
#'     el mismo orden. Eso se verifica en vez de asumirse: sumar dos matrices de
#'     distancia con ordenes de fila distintos mezclaria distancias entre cepas
#'     distintas y produciria un arbol verosimil y equivocado.
tree_from_orfs <- function(orfs, dir = PATHS$alignments) {

  files   <- file.path(dir, paste0(orfs, ".fasta.phylip"))
  present <- file.exists(files)

  if (!any(present)) {
    stop("No alignments found for: ", paste(orfs, collapse = ", "), call. = FALSE)
  }

  dist_total <- NULL
  for (f in files[present]) {
    aln <- phangorn::read.phyDat(f, format = "phylip")
    d   <- as.matrix(phangorn::dist.hamming(aln))
    if (is.null(dist_total)) {
      dist_total <- d
    } else {
      if (!identical(dimnames(d), dimnames(dist_total))) {
        stop("Alignment ", basename(f), " covers a different taxon set from the ",
             "previous ones; distance matrices cannot be averaged.", call. = FALSE)
      }
      dist_total <- dist_total + d
    }
  }

  list(
    tree   = ape::nj(stats::as.dist(dist_total / sum(present))),
    n_used = sum(present),
    missing = orfs[!present]
  )
}

# -----------------------------------------------------------------------------
# 2. Objective 1: panel size
# -----------------------------------------------------------------------------

#' Normalised number of ORFs
#'
#' EN: The published fronts report objective 1 on a [0, 1] scale. The
#'     normalisation constant is not stated in the data files, so it is inferred
#'     here from the solutions themselves by min-max scaling over the observed
#'     panel sizes, and the constant used is returned alongside the value so the
#'     assumption is visible rather than buried.
#'
#'     If the manuscript defines a different constant, pass it explicitly through
#'     k_min and k_max. Silently guessing a normalisation and then comparing
#'     against published numbers would make any mismatch impossible to interpret.
#'
#' ES: Los frentes publicados reportan el objetivo 1 en escala [0, 1]. La
#'     constante de normalizacion no aparece en los archivos de datos, asi que
#'     aca se infiere de las propias soluciones por escalado min-max sobre los
#'     tamanos observados, y la constante usada se devuelve junto al valor para
#'     que el supuesto quede visible y no enterrado.
#'
#'     Si el manuscrito define otra constante, pasarla explicitamente por k_min y
#'     k_max. Adivinar una normalizacion en silencio y despues comparar contra
#'     numeros publicados volveria imposible interpretar cualquier discrepancia.
objective_panel_size <- function(k, k_min, k_max) {
  if (k_max == k_min) return(0)
  (k - k_min) / (k_max - k_min)
}

# -----------------------------------------------------------------------------
# 3. Objective 2: topological distance to the reference
# -----------------------------------------------------------------------------

#' Normalised Robinson-Foulds distance to the reference tree
#'
#' EN: RF distance counts the splits present in one tree and absent from the
#'     other, in both directions. Normalising by the maximum possible value for
#'     the number of taxa puts it on [0, 1], where 0 is identical topology and 1
#'     is no shared split.
#'
#'     Both trees are pruned to their shared taxa first. RF is undefined across
#'     different leaf sets, and phangorn will either error or compare the wrong
#'     things depending on version, so the intersection is taken explicitly and
#'     the number of taxa actually compared is returned.
#'
#' ES: La distancia RF cuenta las particiones presentes en un arbol y ausentes en
#'     el otro, en ambas direcciones. Normalizar por el maximo posible para el
#'     numero de taxones la deja en [0, 1], donde 0 es topologia identica y 1 es
#'     ninguna particion compartida.
#'
#'     Los dos arboles se podan primero a sus taxones comunes. RF no esta
#'     definida entre conjuntos de hojas distintos, y phangorn segun la version
#'     tira error o compara cosas equivocadas, asi que la interseccion se toma de
#'     forma explicita y se devuelve el numero de taxones efectivamente
#'     comparados.
objective_nrf <- function(tree, reference) {

  common <- intersect(tree$tip.label, reference$tip.label)

  if (length(common) < 4) {
    stop("Only ", length(common), " taxa in common; RF distance needs at least 4.",
         call. = FALSE)
  }

  t1 <- ape::keep.tip(tree,      common)
  t2 <- ape::keep.tip(reference, common)

  rf <- phangorn::RF.dist(t1, t2, normalize = TRUE, check.labels = TRUE)

  list(
    nrf        = as.numeric(rf),
    n_taxa     = length(common),
    n_dropped  = length(union(tree$tip.label, reference$tip.label)) - length(common)
  )
}

# -----------------------------------------------------------------------------
# 4. Full evaluation of one candidate subset
# -----------------------------------------------------------------------------

#' Evaluate a candidate ORF subset on both objectives
#' EN: This is the function an optimiser would call. Exposing it here means that
#'     when the MOSA and NSGA-II source is added, it plugs into an evaluation
#'     that is already tested against the published solutions.
#' ES: Esta es la funcion que llamaria un optimizador. Exponerla aca implica que
#'     cuando se agregue el codigo de MOSA y NSGA-II, se enchufa a una evaluacion
#'     ya probada contra las soluciones publicadas.
evaluate_subset <- function(orfs, reference, k_min, k_max,
                            dir = PATHS$alignments) {

  built <- tree_from_orfs(orfs, dir = dir)
  d     <- objective_nrf(built$tree, reference)

  tibble::tibble(
    n_orfs_requested = length(orfs),
    n_orfs_used      = built$n_used,
    missing_orfs     = if (length(built$missing)) paste(built$missing, collapse = " ") else "",
    # EN: Objective 1 is the size of the subset the optimiser selected, not the
    #     number of alignments that happened to be readable. A solution that
    #     names three ORFs costs three ORFs even if one alignment is missing from
    #     the database; using the readable count instead would silently credit a
    #     broken solution with being smaller than it is. The missing_orfs column
    #     records the shortfall separately, where it can be seen.
    # ES: El objetivo 1 es el tamano del subconjunto que selecciono el
    #     optimizador, no el numero de alineamientos que resultaron legibles. Una
    #     solucion que nombra tres ORFs cuesta tres ORFs aunque falte un
    #     alineamiento en la base; usar el conteo legible le acreditaria en
    #     silencio a una solucion rota ser mas chica de lo que es. La columna
    #     missing_orfs registra el faltante aparte, donde se puede ver.
    f1_panel_size    = objective_panel_size(length(orfs), k_min, k_max),
    f2_nrf           = d$nrf,
    n_taxa_compared  = d$n_taxa
  )
}
