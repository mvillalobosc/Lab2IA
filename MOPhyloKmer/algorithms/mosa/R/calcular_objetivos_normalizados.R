# =====================================================================
# compute_normalized_objectives(tree, max_ls, max_me)
# =====================================================================
compute_normalized_objectives <- function(tree, max_ls, max_me) {
  tree$scores$me_norm <- round(tree$scores$me / max_me, 4)
  tree$scores$ls_norm <- round(tree$scores$ls / max_ls, 4)
  tree
}
