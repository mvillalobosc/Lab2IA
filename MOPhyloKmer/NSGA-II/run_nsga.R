# =====================================================================
# run_nsga.R  ·  NSGA-II para inferencia filogenetica libre de alineamiento
# ---------------------------------------------------------------------
# Optimiza simultaneamente Least Squares (LS) y Minimum Evolution (ME)
# sobre representaciones de distancia k-mer + Neighbour Joining.
#
# Mejoras respecto al original:
#   - rutas relativas (nada de C:/Users/...),
#   - dataset y parametros configurables en un solo bloque,
#   - crossover y mutacion vectorizados,
#   - vectores preasignados (sin crecer con c()),
#   - hypervolumen reiniciado por corrida,
#   - EXPORTA la traza de convergencia por generacion a results/ (CSV),
#   - codigo comentado y sin lineas de depuracion.
#
# Uso:  Rscript run_nsga.R           (usa la config de abajo)
# =====================================================================

# --- localizar la carpeta del script para rutas relativas robustas ---
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
def("DATASET",      "conrado_126.phylip")  # dataset a ejecutar
def("TIPO",         "DNA")                  # "DNA" o "AA"
def("K",            5)                       # longitud de palabra k-mer
def("POBLACION",    68)                      # tamano de poblacion
def("GENERACIONES", 50)                      # numero de generaciones
def("N_CORRIDAS",   11)                      # repeticiones independientes
def("P_CROSS",      0.39)                    # ponderacion de crossover
def("P_MUTA",       0.40)                    # probabilidad de mutacion
def("SEMILLA",      123)
def("VERBOSE",      TRUE)   # TRUE = imprime el paso en que va
def("PARALELO",     FALSE)  # TRUE = corre las N corridas en paralelo (multinucleo)
def("N_CORES",      max(1, parallel::detectCores() - 1))  # nucleos a usar
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

# --- helper: construir arbol phylo desde una matriz de distancias -----
#     (reemplaza el bloque NJ + limpieza repetido 4 veces en el original)
arbol_desde_matriz <- function(dist_mat, dist_original) {
  a <- NJ(dist_mat)
  a$dist_kmer     <- dist_mat
  a$dist_original <- dist_original
  a$edge.length[a$edge.length < 0] <- 0
  a <- multi2di(a)
  midpoint(a)
}

# =====================================================================
# UNA CORRIDA (encapsulada para poder paralelizar)
# ---------------------------------------------------------------------
# Ejecuta una corrida completa, escribe su traza + arbol en results/ y
# devuelve un data.frame de una fila con el resumen. La semilla depende
# de la corrida (SEMILLA + corrida) => resultados reproducibles y iguales
# en modo serial o paralelo.
# =====================================================================
barra <- function(i, n, ancho = 30) {
  hechos <- floor(ancho * i / n)
  sprintf("[%s%s] %3d%%", strrep("=", hechos), strrep(" ", ancho - hechos),
          round(100 * i / n))
}

run_once_nsga <- function(corrida) {
  set.seed(SEMILLA + corrida)
  progreso <- isTRUE(VERBOSE) && !isTRUE(PARALELO)
  t0 <- Sys.time()
  ds <- tools::file_path_sans_ext(DATASET)
  if (progreso) cat(sprintf("\n-- Corrida %d/%d --\n", corrida, N_CORRIDAS))

  # --- poblacion inicial -------------------------------------------
  secuencias  <- lectura_secuencia(file.path(DATA_DIR, DATASET), TIPO)
  arbol_base  <- crear_arbol_base(secuencias, k = K)
  poblacion   <- crear_poblacion(arbol_base, POBLACION)
  puntajes    <- calcular_puntajes(poblacion)

  max_ls <- puntajes[[1]]$scores$ls * 10
  max_me <- puntajes[[1]]$scores$me * 10
  puntajesNorm <- calcular_puntajes_normalizados(puntajes, max_ls, max_me)

  me_ls  <- nom_dominated_sort_cw(puntajesNorm)
  orden  <- order(me_ls$ranking, -me_ls$crowding2)
  matriz_original <- puntajesNorm[[1]]$dist_original

  # --- HV del frente inicial = GENERACION 0 -------------------------
  idx0 <- as.numeric(rownames(me_ls[me_ls$ranking == 1, ]))
  vec0 <- t(vapply(idx0, function(b)
    c(puntajesNorm[[b]]$scores$ls_norm, puntajesNorm[[b]]$scores$me_norm), numeric(2)))
  hv0  <- calcular_hypervolumen(vec0)

  hv_gen    <- numeric(GENERACIONES + 1)
  hv_gen[1] <- hv0

  for (generacion in seq_len(GENERACIONES)) {
    n <- length(puntajesNorm)
    Q <- vector("list", n)
    n_cross <- round(n * 0.4)
    n_muta  <- round(n * 0.4)

    for (i in seq_len(n_cross - 1)) {
      p1 <- torneo_seleccion(puntajesNorm, me_ls, orden)
      p2 <- torneo_seleccion(puntajesNorm, me_ls, orden)
      Q[[i]] <- arbol_desde_matriz(crossover(p1, p2, P_CROSS), matriz_original)
    }
    for (i in n_cross:(n_cross + n_muta - 1)) {
      Q[[i]] <- arbol_desde_matriz(mutacion(P_MUTA, puntajesNorm[[i]]), matriz_original)
    }
    for (i in (n_cross + n_muta):n) {
      Q[[i]] <- arbol_desde_matriz(generate_randomTree(puntajesNorm[[i]]), matriz_original)
    }
    Q <- Q[!vapply(Q, is.null, logical(1))]
    class(Q) <- "multiPhylo"

    puntajesQ     <- calcular_puntajes(Q)
    puntajesNormQ <- calcular_puntajes_normalizados(puntajesQ, max_ls, max_me)
    unionPQ  <- rbind(puntajesNorm, puntajesNormQ)
    me_lsPQ  <- nom_dominated_sort_cw(unionPQ)
    ordenPQ  <- order(me_lsPQ$ranking, -me_lsPQ$crowding2)

    mitad <- floor(length(ordenPQ) / 2)
    nuevaPoblacion <- vector("list", mitad)
    for (i in seq_len(mitad)) {
      nuevaPoblacion[[i]] <- arbol_desde_matriz(
        unionPQ[[ordenPQ[i]]]$dist_kmer, matriz_original)
    }
    class(nuevaPoblacion) <- "multiPhylo"

    frente <- me_lsPQ[me_lsPQ$ranking == 1, ]
    idx    <- as.numeric(rownames(frente))
    vectores <- t(vapply(idx, function(b)
      c(unionPQ[[b]]$scores$ls_norm, unionPQ[[b]]$scores$me_norm), numeric(2)))
    hv_gen[generacion + 1] <- calcular_hypervolumen(vectores)

    puntajes     <- calcular_puntajes(nuevaPoblacion)
    puntajesNorm <- calcular_puntajes_normalizados(puntajes, max_ls, max_me)
    me_ls        <- nom_dominated_sort_cw(puntajesNorm)
    orden        <- order(me_ls$ranking, -me_ls$crowding2)

    if (progreso)
      cat(sprintf("\r   gen %3d/%d %s  HV=%.4f",
                  generacion, GENERACIONES, barra(generacion, GENERACIONES),
                  max(hv_gen[seq_len(generacion + 1)])))
  }
  if (progreso) cat("\n")

  best_so_far <- cummax(hv_gen)

  # --- arbol representativo + traza (cada corrida escribe su archivo) ---
  arbol_final <- nuevaPoblacion[[1]]
  if (is.null(arbol_final$tip.label))
    arbol_final$tip.label <- rownames(matriz_original)
  write.tree(arbol_final,
             file.path(RESULTS_DIR, sprintf("tree_NSGA_%s_run%02d.nwk", ds, corrida)))
  write.csv(
    data.frame(generation = 0:GENERACIONES, hypervolume = hv_gen,
               best_so_far = best_so_far),
    file.path(RESULTS_DIR, sprintf("conv_NSGA_%s_run%02d.csv", ds, corrida)),
    row.names = FALSE)

  seg <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(corrida = corrida, hv_max = max(hv_gen), segundos = seg)
}

# =====================================================================
# DESPACHO: serial o paralelo (a nivel de corridas)
# =====================================================================
if (isTRUE(VERBOSE))
  cat(sprintf("\n==== NSGA-II | %s | %d corridas | %d generaciones | %s ====\n",
              DATASET, N_CORRIDAS, GENERACIONES,
              if (isTRUE(PARALELO)) sprintf("PARALELO x%d nucleos", min(N_CORES, N_CORRIDAS)) else "serial"))

if (isTRUE(PARALELO)) {
  library(parallel)
  ncores <- min(N_CORES, N_CORRIDAS)
  cl <- makeCluster(ncores)
  on.exit(try(stopCluster(cl), silent = TRUE), add = TRUE)
  # exportar config + helpers a cada worker y cargar modulos
  clusterExport(cl, c("ROOT", "DATA_DIR", "RESULTS_DIR", "DATASET", "TIPO", "K",
                      "POBLACION", "GENERACIONES", "P_CROSS", "P_MUTA", "SEMILLA",
                      "N_CORRIDAS", "VERBOSE", "PARALELO",
                      "arbol_desde_matriz", "barra", "run_once_nsga"),
                envir = environment())
  clusterEvalQ(cl, {
    source(file.path(ROOT, "R", "packages.R"))
    for (.f in list.files(file.path(ROOT, "R"), pattern = "\\.R$", full.names = TRUE))
      if (!grepl("packages\\.R$", .f)) source(.f)
    TRUE
  })
  res <- parLapply(cl, seq_len(N_CORRIDAS), run_once_nsga)
} else {
  res <- lapply(seq_len(N_CORRIDAS), run_once_nsga)
}

resumen <- do.call(rbind, res)
for (i in seq_len(nrow(resumen)))
  message(sprintf("Corrida %2d/%d  HVmax=%.4f  %.1fs",
                  resumen$corrida[i], N_CORRIDAS, resumen$hv_max[i], resumen$segundos[i]))

write.csv(resumen,
          file.path(RESULTS_DIR,
                    sprintf("resumen_NSGA_%s.csv", tools::file_path_sans_ext(DATASET))),
          row.names = FALSE)
message("Listo. Trazas y resumen en: ", RESULTS_DIR)
