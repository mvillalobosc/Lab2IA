# =====================================================================
# run_sa.R  ·  Multi-Objective Simulated Annealing (MOSA) para
#              inferencia filogenetica libre de alineamiento
# ---------------------------------------------------------------------
# Optimiza el hipervolumen (agrega LS y ME) de un unico arbol que se
# perturba y acepta segun el criterio de Metropolis con enfriamiento.
#
# Mejoras respecto al original:
#   - rutas relativas y dataset/parametros configurables,
#   - corregido $score -> $scores (se apoyaba en partial matching de R),
#   - matriz de resultados preasignada (sin rbind incremental),
#   - EXPORTA la traza de convergencia por iteracion (ITE, SCORE actual,
#     BEST-so-far) a results/ (CSV) -> lineas celeste y azul de la figura,
#   - comentado y sin lineas de depuracion.
#
# Uso:  Rscript run_sa.R
# =====================================================================

.this_dir <- function() {
  fr <- rev(seq_len(sys.nframe()))
  for (i in fr) { of <- sys.frame(i)$ofile; if (!is.null(of)) return(dirname(normalizePath(of))) }
  a <- commandArgs(FALSE); m <- grep("^--file=", a)
  if (length(m)) dirname(normalizePath(sub("^--file=", "", a[m]))) else getwd()
}
ROOT <- .this_dir()

source(file.path(ROOT, "R", "packages.R"))
for (f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
  if (!grepl("packages\\.R$", f)) source(f)

# =====================================================================
# CONFIGURACION  (editar aqui)
# =====================================================================
# valores por defecto; si main.R ya los definio, se respetan.
def <- function(nombre, valor) if (!exists(nombre, inherits = TRUE)) assign(nombre, valor, envir = .GlobalEnv)
def("DATA_DIR",    normalizePath(file.path(ROOT, "..", "data")))
def("RESULTS_DIR", normalizePath(file.path(ROOT, "..", "results")))
def("DATASET",     "primates_14.phylip")
def("TIPO",        "DNA")
def("K",           5)
def("N_INTERNAS",  100)    # iteraciones por nivel de temperatura (equilibrio)
def("PARADA",      75)     # niveles de temperatura (criterio de parada)
def("T0",          5000)   # temperatura inicial
def("ALPHA",       0.69)   # factor de enfriamiento geometrico
def("N_CORRIDAS",  11)
def("SEMILLA",     123)
def("VERBOSE",     TRUE)   # TRUE = imprime el paso en que va
def("PARALELO",    FALSE)  # TRUE = corre las N corridas en paralelo (multinucleo)
def("N_CORES",     max(1, parallel::detectCores() - 1))
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

# =====================================================================
# UNA CORRIDA (encapsulada para poder paralelizar)
# =====================================================================
barra <- function(i, n, ancho = 30) {
  hechos <- floor(ancho * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", hechos), strrep(" ", ancho - hechos),
          round(100 * i / n))
}

medoide <- function(P) {
  if (nrow(P) <= 1) return(1L)
  which.min(rowSums(as.matrix(dist(P))))
}

run_once_sa <- function(corrida) {
  set.seed(SEMILLA + corrida)
  progreso <- isTRUE(VERBOSE) && !isTRUE(PARALELO)
  t0 <- Sys.time()
  ds <- tools::file_path_sans_ext(DATASET)
  if (progreso) cat(sprintf("\n-- Corrida %d/%d --\n", corrida, N_CORRIDAS))

  # --- solucion inicial --------------------------------------------
  secuencias <- lectura_secuencia(file.path(DATA_DIR, DATASET), TIPO)
  arbol_base <- crear_arbol_base(secuencias, k = K)
  arbol_base <- calcular_objetivos(arbol_base)
  max_ls <- arbol_base$scores$ls * 10
  max_me <- arbol_base$scores$me * 10
  arbol_base <- calcular_objetivos_normalizados(arbol_base, max_ls, max_me)
  arbol_base <- calcular_hypervolumen(arbol_base)

  arbol_mejor    <- arbol_base
  arbol_solucion <- arbol_base

  total <- PARADA * N_INTERNAS
  traza <- matrix(NA_real_, nrow = total, ncol = 2)
  fila  <- 0
  Temp  <- T0

  # archivo de no-dominados (para la frontera y el arbol medoide)
  arch_ls <- arbol_base$scores$ls
  arch_me <- arbol_base$scores$me
  arch_tr <- list(arbol_base)

  for (a in seq_len(PARADA)) {
    for (b in seq_len(N_INTERNAS)) {
      arbol_tmp <- perturbar_arbol(arbol_solucion)
      arbol_tmp <- calcular_objetivos(arbol_tmp)
      arbol_tmp <- calcular_objetivos_normalizados(arbol_tmp, max_ls, max_me)
      arbol_tmp <- calcular_hypervolumen(arbol_tmp)

      # actualizar archivo de no-dominados (minimiza LS y ME)
      nl <- arbol_tmp$scores$ls; nm <- arbol_tmp$scores$me
      if (!any(arch_ls <= nl & arch_me <= nm & (arch_ls < nl | arch_me < nm))) {
        keep <- !(nl <= arch_ls & nm <= arch_me & (nl < arch_ls | nm < arch_me))
        arch_ls <- c(arch_ls[keep], nl)
        arch_me <- c(arch_me[keep], nm)
        arch_tr <- c(arch_tr[keep], list(arbol_tmp))
      }

      deltaE <- arbol_solucion$scores$hyp - arbol_tmp$scores$hyp
      if (arbol_tmp$scores$hyp > arbol_mejor$scores$hyp) arbol_mejor <- arbol_tmp

      if (deltaE <= 0) {
        arbol_solucion <- arbol_tmp
      } else if (runif(1) < exp(-deltaE / Temp)) {
        arbol_solucion <- arbol_tmp
      }
      fila <- fila + 1
      traza[fila, ] <- c(arbol_solucion$scores$hyp, arbol_mejor$scores$hyp)
    }
    Temp <- Temp * ALPHA
    if (progreso)
      cat(sprintf("\r   nivel %3d/%d %s  T=%7.1f  BEST=%.4f",
                  a, PARADA, barra(a, PARADA), Temp, arbol_mejor$scores$hyp))
  }
  if (progreso) cat("\n")

  # --- frontera + arbol MEDOIDE de la frontera -----------------------
  Pn  <- cbind(arch_ls / max_ls, arch_me / max_me)   # objetivos normalizados
  med <- medoide(Pn)
  write.csv(data.frame(ls = arch_ls, me = arch_me),
            file.path(RESULTS_DIR, sprintf("front_MOSA_%s_run%02d.csv", ds, corrida)),
            row.names = FALSE)
  arbol_medoide <- arch_tr[[med]]
  if (is.null(arbol_medoide$tip.label))
    arbol_medoide$tip.label <- rownames(arbol_base$dist_kmer)
  write.tree(arbol_medoide,
             file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s_run%02d.nwk", ds, corrida)))
  write.csv(
    data.frame(iteration = seq_len(total), current = traza[, 1],
               best_so_far = cummax(traza[, 2])),
    file.path(RESULTS_DIR, sprintf("conv_MOSA_%s_run%02d.csv", ds, corrida)),
    row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(corrida = corrida, hv_best = arbol_mejor$scores$hyp, segundos = seg)
}

# =====================================================================
# DESPACHO: serial o paralelo (a nivel de corridas)
# =====================================================================
if (isTRUE(VERBOSE))
  cat(sprintf("\n==== MOSA | %s | %d corridas | %d niveles x %d iter | %s ====\n",
              DATASET, N_CORRIDAS, PARADA, N_INTERNAS,
              if (isTRUE(PARALELO)) sprintf("PARALELO x%d nucleos", min(N_CORES, N_CORRIDAS)) else "serial"))

if (isTRUE(PARALELO)) {
  library(parallel)
  ncores <- min(N_CORES, N_CORRIDAS)
  cl <- makeCluster(ncores)
  on.exit(try(stopCluster(cl), silent = TRUE), add = TRUE)
  clusterExport(cl, c("ROOT", "DATA_DIR", "RESULTS_DIR", "DATASET", "TIPO", "K",
                      "N_INTERNAS", "PARADA", "T0", "ALPHA", "SEMILLA",
                      "N_CORRIDAS", "VERBOSE", "PARALELO", "barra", "medoide", "run_once_sa"),
                envir = environment())
  clusterEvalQ(cl, {
    source(file.path(ROOT, "R", "packages.R"))
    for (.f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
      if (!grepl("packages\\.R$", .f)) source(.f)
    TRUE
  })
  res <- parLapply(cl, seq_len(N_CORRIDAS), run_once_sa)
  stopCluster(cl)
} else {
  res <- lapply(seq_len(N_CORRIDAS), run_once_sa)
}

resumen <- do.call(rbind, res)

# --- consolidar: dejar SOLO el medoide y la frontera de la MEJOR corrida ---
ds <- tools::file_path_sans_ext(DATASET)
mejor <- resumen$corrida[which.max(resumen$hv_best)]
file.copy(file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s_run%02d.nwk", ds, mejor)),
          file.path(RESULTS_DIR, sprintf("medoid_MOSA_%s.nwk", ds)), overwrite = TRUE)
file.copy(file.path(RESULTS_DIR, sprintf("front_MOSA_%s_run%02d.csv", ds, mejor)),
          file.path(RESULTS_DIR, sprintf("front_MOSA_%s.csv", ds)), overwrite = TRUE)
unlink(list.files(RESULTS_DIR, pattern = sprintf("^medoid_MOSA_%s_run.*\\.nwk$", ds), full.names = TRUE))
unlink(list.files(RESULTS_DIR, pattern = sprintf("^front_MOSA_%s_run.*\\.csv$", ds), full.names = TRUE))
for (i in seq_len(nrow(resumen)))
  message(sprintf("Corrida %2d/%d  HVbest=%.4f  %.1fs",
                  resumen$corrida[i], N_CORRIDAS, resumen$hv_best[i], resumen$segundos[i]))

write.csv(resumen,
          file.path(RESULTS_DIR,
                    sprintf("resumen_MOSA_%s.csv", tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Listo. Trazas y resumen en: ", RESULTS_DIR)
