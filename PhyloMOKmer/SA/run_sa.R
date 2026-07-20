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
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

set.seed(SEMILLA)
resumen <- data.frame(corrida = integer(), hv_best = numeric(),
                      segundos = numeric())

# --- barra de progreso simple en consola -----------------------------
barra <- function(i, n, ancho = 30) {
  hechos <- floor(ancho * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", hechos), strrep(" ", ancho - hechos),
          round(100 * i / n))
}
if (isTRUE(VERBOSE))
  cat(sprintf("\n==== MOSA | dataset: %s | %d corridas | %d niveles x %d iter ====\n",
              DATASET, N_CORRIDAS, PARADA, N_INTERNAS))

for (corrida in seq_len(N_CORRIDAS)) {
  t0 <- Sys.time()
  if (isTRUE(VERBOSE)) cat(sprintf("\n-- Corrida %d/%d --\n", corrida, N_CORRIDAS))

  # --- solucion inicial --------------------------------------------
  secuencias <- lectura_secuencia(file.path(DATA_DIR, DATASET), TIPO)
  arbol_base <- crear_arbol_base(secuencias, k = K)
  arbol_base <- calcular_objetivos(arbol_base)
  max_ls <- arbol_base$scores$ls * 10
  max_me <- arbol_base$scores$me * 10
  arbol_base <- calcular_objetivos_normalizados(arbol_base, max_ls, max_me)
  arbol_base <- calcular_hypervolumen(arbol_base)

  arbol_mejor    <- arbol_base   # mejor solucion encontrada (best-so-far)
  arbol_solucion <- arbol_base   # solucion actual

  # --- traza preasignada: filas = PARADA * N_INTERNAS --------------
  total <- PARADA * N_INTERNAS
  traza <- matrix(NA_real_, nrow = total, ncol = 2)  # (SCORE actual, BEST)
  fila  <- 0
  Temp  <- T0

  for (a in seq_len(PARADA)) {
    for (b in seq_len(N_INTERNAS)) {
      # vecino
      arbol_tmp <- perturbar_arbol(arbol_solucion)
      arbol_tmp <- calcular_objetivos(arbol_tmp)
      arbol_tmp <- calcular_objetivos_normalizados(arbol_tmp, max_ls, max_me)
      arbol_tmp <- calcular_hypervolumen(arbol_tmp)

      # deltaE en terminos de hipervolumen (mayor HV = mejor)
      deltaE <- arbol_solucion$scores$hyp - arbol_tmp$scores$hyp

      # actualizar best-so-far
      if (arbol_tmp$scores$hyp > arbol_mejor$scores$hyp)
        arbol_mejor <- arbol_tmp

      # aceptacion de Metropolis
      if (deltaE <= 0) {
        arbol_solucion <- arbol_tmp                     # mejora: se acepta
      } else if (runif(1) < exp(-deltaE / Temp)) {
        arbol_solucion <- arbol_tmp                     # empeora: se acepta con prob.
      }

      fila <- fila + 1
      traza[fila, ] <- c(arbol_solucion$scores$hyp, arbol_mejor$scores$hyp)
    }
    Temp <- Temp * ALPHA                                # enfriamiento
    if (isTRUE(VERBOSE))
      cat(sprintf("\r   nivel %3d/%d %s  T=%7.1f  BEST=%.4f",
                  a, PARADA, barra(a, PARADA), Temp, arbol_mejor$scores$hyp))
  }
  if (isTRUE(VERBOSE)) cat("\n")

  # --- guardar el mejor arbol (Newick) -----------------------------
  if (is.null(arbol_mejor$tip.label))
    arbol_mejor$tip.label <- rownames(arbol_base$dist_kmer)
  write.tree(arbol_mejor,
             file.path(RESULTS_DIR,
                       sprintf("tree_MOSA_%s_run%02d.nwk",
                               tools::file_path_sans_ext(DATASET), corrida)))

  # --- guardar traza de convergencia -------------------------------
  ds <- tools::file_path_sans_ext(DATASET)
  write.csv(
    data.frame(iteration   = seq_len(total),
               current     = traza[, 1],              # linea celeste
               best_so_far = cummax(traza[, 2])),     # linea azul (monotona)
    file.path(RESULTS_DIR, sprintf("conv_MOSA_%s_run%02d.csv", ds, corrida)),
    row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  resumen <- rbind(resumen,
                   data.frame(corrida = corrida,
                              hv_best = arbol_mejor$scores$hyp, segundos = seg))
  message(sprintf("Corrida %2d/%d  HVbest=%.4f  %.1fs",
                  corrida, N_CORRIDAS, arbol_mejor$scores$hyp, seg))
}

write.csv(resumen,
          file.path(RESULTS_DIR,
                    sprintf("resumen_MOSA_%s.csv",
                            tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Listo. Trazas y resumen en: ", RESULTS_DIR)
