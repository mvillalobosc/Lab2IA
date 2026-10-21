Sys.setenv(N_CORES = length(parallel::mcaffinity()) - 1)
source("consciencia_discreta.R", encoding = "UTF-8")
