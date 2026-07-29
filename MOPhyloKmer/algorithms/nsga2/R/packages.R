# =====================================================================
# packages.R  ·  Safe dependency loading
# ---------------------------------------------------------------------
# It never installs or updates packages while loading.
# Avoids reloading namespaces already used by other packages.
# =====================================================================
# User library first
.user_lib <- path.expand(
  "~/R/x86_64-pc-linux-gnu-library/4.3"
)
dir.create(
  .user_lib,
  recursive = TRUE,
  showWarnings = FALSE
)
.libPaths(
  unique(c(.user_lib, .libPaths()))
)
# Packages required by the project
.deps <- c(
  "ecr",
  "ape",
  "seqinr",
  "kmer",
  "phylotools",
  "phangorn",
  "stringr",
  "phytools",
  "treespace",
  "igraph",
  "ggplot2",
  "factoextra",
  "insect"
)
# ---------------------------------------------------------------------
# Check for missing packages
# ---------------------------------------------------------------------
.missing <- .deps[
  !vapply(
    .deps,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]
if (length(.missing) > 0L) {
  stop(
    paste0(
      "The following packages are missing:\n",
      paste0("  - ", .missing, collapse = "\n"),
      "\n\nInstall them before running packages.R."
    ),
    call. = FALSE
  )
}
# ---------------------------------------------------------------------
# Safe loading function
# ---------------------------------------------------------------------
.load_package_safely <- function(
    package,
    attach_required = TRUE
) {
  
  search_name <- paste0("package:", package)
  
  # Already attached: nothing to do
  if (search_name %in% search()) {
    return(invisible(TRUE))
  }
  
  # The namespace was already loaded by another dependency.
  # That same copy is attached, without trying to replace it.
  if (package %in% loadedNamespaces()) {
    
    suppressPackageStartupMessages(
      attachNamespace(
        getNamespace(package)
      )
    )
    
    return(invisible(TRUE))
  }
  
  # Conventional load when the namespace does not exist yet
  suppressPackageStartupMessages(
    library(
      package,
      character.only = TRUE,
      quietly = TRUE,
      warn.conflicts = FALSE,
      attach.required = attach_required
    )
  )
  
  invisible(TRUE)
}
# ---------------------------------------------------------------------
# Load packages
# ---------------------------------------------------------------------
for (.p in .deps) {
  
  if (identical(.p, "treespace")) {
    
    # Do not attach ape and ade4 again as required packages
    .load_package_safely(
      package = .p,
      attach_required = FALSE
    )
    
  } else {
    
    .load_package_safely(
      package = .p
    )
  }
}
# ---------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------
rm(
  .deps,
  .missing,
  .p,
  .load_package_safely,
  .user_lib
)
