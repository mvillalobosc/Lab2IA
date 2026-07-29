# =====================================================================
# compute_objectives(tree)  ·  ME and LS of a single tree
#   LS is measured against dist_original (fixed data), exactly as in NSGA-II.
# =====================================================================
compute_objectives <- function(tree) {
  tree$scores$me <- round(sum(tree$edge.length), 4)
  tree$scores$ls <- round(sum(abs(tree$dist_original - cophenetic.phylo(tree))), 4)
  tree
}
