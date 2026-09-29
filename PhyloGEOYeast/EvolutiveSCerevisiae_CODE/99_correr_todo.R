# =============================================================================
#  99_correr_todo.R
#  Ejecuta el pipeline completo en orden.
#
#  Cada paso deja un intermedio paso_*.rds que el siguiente levanta, asi que
#  cambiar un umbral solo obliga a repetir desde el paso afectado. El unico caro
#  es 02_variantes.R, que lee el VCF; si su resultado ya existe se saltea.
#
#  CORTE DURO
#  Si 12_validar.R encuentra alguna comprobacion en FALLA, el corredor se
#  detiene con estado 1. Es la diferencia con la version anterior: antes los
#  resultados podian contradecirse entre si y seguir su curso hasta el
#  manuscrito. Para inspeccionar sin cortar, correr con
#      options(filo.ignorar_validacion = TRUE)
#
#  USO DESDE LA TERMINAL
#      Rscript 99_correr_todo.R
#      Rscript 99_correr_todo.R 06        arranca desde el paso 06
#      Rscript 99_correr_todo.R 06 09     corre del 06 al 09
#
#  USO EN SEGUNDO PLANO, que es la forma normal de correrlo
#      rstudioapi::jobRunScript("99_correr_todo.R", name = "filogeografia",
#                               workingDir = getwd(), importEnv = FALSE)
#
#  Los ajustes NO van por options(): jobRunScript abre una sesion nueva que no
#  los hereda. Se editan en 00_config.R:
#      RAPIDO     <- TRUE     prueba en minutos, para ver si los numeros cierran
#      PASO_DESDE <- "06"     rehacer solo un tramo, sin releer el VCF
#
#  USO EN PRIMER PLANO, bloquea la consola
#      source("99_correr_todo.R")
#
#  Tambien sirve el boton Source con este archivo abierto. El bloque de arriba
#  se para solo en la carpeta correcta, asi que no importa donde este parada la
#  sesion ni hace falta setwd().
#
#  Para correr un tramo, y solo para eso, se limita con options():
#      options(filo.desde = "06", filo.hasta = "09"); source("99_correr_todo.R")
#      options(filo.desde = NULL,  filo.hasta = NULL)   <- volver a todos
#  En sesion interactiva nunca se llama a quit(): un paso que decide no seguir
#  corta el recorrido y deja el motivo en FILO_DETENIDO, con la sesion viva.
# =============================================================================

# --- Ubicacion del script -----------------------------------------------------
# RStudio no cambia el directorio de trabajo al apretar Source, asi que
# source("00_config.R") falla si la sesion esta parada en otra carpeta. Este
# bloque encuentra la carpeta del propio archivo y se para ahi. Tres vias, en
# orden de fiabilidad:
#   1. sys.frames(): cuando el archivo se ejecuta con source(), R guarda su ruta
#      en ofile. Funciona con el boton Source de RStudio y no necesita paquetes.
#   2. rstudioapi: para cuando se ejecutan lineas sueltas desde el editor, donde
#      no hay ofile. Se usa solo si el paquete esta instalado.
#   3. El directorio actual, si ya contiene 00_config.R.
# Con Rscript ninguna de las tres hace falta y el bloque no toca nada.
local({
  cand <- character(0)
  for (i in seq_len(sys.nframe())) {
    of <- get0("ofile", envir = sys.frames()[[i]], inherits = FALSE)
    if (!is.null(of) && is.character(of) && nzchar(of)) cand <- c(cand, of)
  }
  if (!length(cand) && requireNamespace("rstudioapi", quietly = TRUE) &&
      isTRUE(try(rstudioapi::isAvailable(), silent = TRUE))) {
    p <- try(rstudioapi::getSourceEditorContext()$path, silent = TRUE)
    if (!inherits(p, "try-error") && length(p) && nzchar(p)) cand <- p
    q <- try(rstudioapi::getActiveProject(), silent = TRUE)
    if (!length(cand) && !inherits(q, "try-error") && length(q) && nzchar(q))
      cand <- file.path(q, "x")
  }
  for (p in cand) {
    d <- tryCatch(dirname(normalizePath(p, mustWork = FALSE)), error = function(e) "")
    if (nzchar(d) && file.exists(file.path(d, "00_config.R"))) {
      if (!identical(normalizePath(d), normalizePath(getwd()))) {
        setwd(d); message("Directorio de trabajo: ", d)
      }
      return(invisible(NULL))
    }
  }
  if (!file.exists("00_config.R"))
    stop("No encuentro 00_config.R. Abri la carpeta del pipeline como proyecto ",
         "en RStudio, o corre setwd() a mano.", call. = FALSE)
})

source("00_config.R")

PASOS <- c(
  "01_datos.R",           # metadata, coordenadas, definicion de los grupos
  "02_variantes.R",       # VCF a conteos, panel estricto y amplio, bloques
  "03_diagnostico.R",     # espectro, geometria, cobertura, clones
  "04_diversidad.R",      # pi por grupo, rarefaccion, descomposicion Wahlund
  "05_diferenciacion.R",  # FST de Hudson, Nei, aislamiento por distancia
  "06_gradiente.R",       # origen por caida de la diversidad
  "07_psi.R",             # direccionalidad, evidencia independiente
  "08_arbol.R",           # arbol de grupos con soporte por bootstrap
  "09_tiempos.R",         # orden de divergencia en unidades de deriva
  "10_modelos.R",         # el origen contra modelos alternativos
  "11_controles.R",       # nulos, campanas, Wahlund, estratos
  "13_estructura.R",      # PCA de estructura y prueba f3 de mezcla
  "14_indicadores.R",     # Ho, Fis, LD, privados, Tajima, AMOVA, Procrustes
  "15_asignacion.R",      # asignacion de cada cepa a su grupo mas parecido
  "16_marcadores.R",      # marcadores diagnosticos y anotacion en genes
  "17_potencia.R",        # potencia, identificabilidad, sensibilidad, diseno
  "18_origen_cepa.R",     # ancestria por cepa, vecinos, atipicas, privados
  "12_validar.R"          # control de salida, cruza todo lo anterior
)

# Los pasos a correr salen de la linea de comandos con Rscript, y de options()
# en una sesion interactiva, donde commandArgs() no trae nada.
args  <- commandArgs(trailingOnly = TRUE)
args  <- args[grepl("^[0-9]{2}$", args)]
desde <- if (length(args) >= 1) args[1] else PASO_DESDE
hasta <- if (length(args) >= 2) args[2] else PASO_HASTA
# options() sobrevive a toda la sesion. Si en una corrida anterior se limito el
# tramo y despues se pide todo, el pipeline correria en silencio solo ese tramo.
# Se avisa, y se ofrece como quitarlo.
if (desde != "01" || hasta != "12")
  message("Tramo limitado a ", desde, "-", hasta,
          " por PASO_DESDE y PASO_HASTA en 00_config.R")
i0 <- which(substr(PASOS, 1, 2) == desde)
i1 <- which(substr(PASOS, 1, 2) == hasta)
if (!length(i0) || !length(i1)) stop("Paso no reconocido. Ver la lista PASOS.", call. = FALSE)

faltan <- PASOS[!file.exists(PASOS)]
if (length(faltan)) stop("Faltan estos archivos en el directorio de trabajo:\n  ",
                         paste(faltan, collapse = "\n  "), call. = FALSE)

cat("\n==============================================================\n")
cat(" Pipeline filogeografico | especie: ", ESPECIE, "\n", sep = "")
cat(" Grupo: ", paste(COL_GRUPO, collapse = " + "), " | salida: ", OUT, "\n", sep = "")
if (isTRUE(RAPIDO))
  cat(" MODO RAPIDO: resultados preliminares, no finales\n")
cat(" Pasos ", desde, " a ", hasta,
    if (desde == "01" && hasta == "12") "  (todos)" else "  (tramo parcial)",
    "\n", sep = "")
cat("==============================================================\n")

t_ini <- Sys.time()
tiempos <- data.frame(escenario = character(0), paso = character(0),
                      segundos = numeric(0), stringsAsFactors = FALSE)
resumen <- data.frame(escenario = character(0), estado = character(0),
                      salida = character(0), stringsAsFactors = FALSE)

for (esc in ESCENARIOS) {
  # El escenario viaja por options() porque cada paso vuelve a cargar
  # 00_config.R en su propio entorno, y ahi es donde se resuelven COL_GRUPO,
  # FUSIONAR_COORD, EXCLUIR_LINAJE y OUT.
  options(filo.escenario = esc)
  salida <- file.path("resultados", esc$nombre)
  dir.create(salida, showWarnings = FALSE, recursive = TRUE)

  cat("\n##############################################################\n")
  cat(" ESCENARIO: ", esc$nombre, "\n", sep = "")
  cat("   grupo    : ", paste(esc$grupo, collapse = " + "), "\n", sep = "")
  cat("   fusionar : ", esc$fusionar, "\n", sep = "")
  cat("   excluir  : ",
      if (length(esc$excluir)) paste(esc$excluir, collapse = ", ") else "nada",
      "\n", sep = "")
  cat("   salida   : ", salida, "\n", sep = "")
  cat("##############################################################\n")

  falla_esc <- NULL
  for (k in i0:i1) {
    s <- PASOS[k]
    cat("\n-------------------------------------------------------------\n")
    cat(" ", esc$nombre, " / ", s, "\n", sep = "")
    cat("-------------------------------------------------------------\n")
    t0 <- Sys.time()
    estado <- withCallingHandlers(
      tryCatch({ source(s, local = new.env()); "ok" },
               error = function(e) conditionMessage(e),
               interrupt = function(e) "detenido"),
      warning = function(w) invokeRestart("muffleWarning"))
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    tiempos <- rbind(tiempos, data.frame(escenario = esc$nombre, paso = s,
                                         segundos = round(dt, 1),
                                         stringsAsFactors = FALSE))
    if (identical(estado, "detenido")) {
      d <- if (exists("FILO_DETENIDO", envir = globalenv()))
        get("FILO_DETENIDO", envir = globalenv()) else list(motivo = s)
      cat("\n", s, " se detuvo: ", d$motivo, "\n", sep = "")
      break
    }
    if (!identical(estado, "ok")) {
      # Un escenario que revienta NO corta los demas: se anota y se sigue con el
      # siguiente. Cortar todo por uno obligaria a relanzar la corrida entera.
      cat("\nERROR en ", s, ":\n  ", estado, "\n", sep = "")
      cat("Se abandona ", esc$nombre, " y se sigue con el siguiente escenario.\n", sep = "")
      falla_esc <- paste0(s, ": ", substr(estado, 1, 60))
      break
    }
    cat("  (", round(dt, 1), " s)\n", sep = "")
  }

  val <- file.path(salida, "12_validacion.tsv")
  est <- if (!is.null(falla_esc)) paste("ERROR", falla_esc)
    else if (file.exists(val)) {
      tb <- read.table(val, header = TRUE, sep = "\t", quote = "", comment.char = "")
      sprintf("%d FALLA / %d AVISO / %d OK", sum(tb$estado == "FALLA"),
              sum(tb$estado == "AVISO"), sum(tb$estado == "OK"))
    } else "sin validacion"
  resumen <- rbind(resumen, data.frame(escenario = esc$nombre, estado = est,
                                       salida = salida, stringsAsFactors = FALSE))
}
options(filo.escenario = NULL)

cat("\n==============================================================\n")
cat(" Terminado en ", round(as.numeric(difftime(Sys.time(), t_ini, units = "mins")), 1),
    " minutos\n", sep = "")
cat("\n Escenarios:\n")
for (i in seq_len(nrow(resumen)))
  cat(sprintf("   %-14s %-32s %s\n", resumen$escenario[i], resumen$estado[i],
              resumen$salida[i]))
cat("\n Tiempo por escenario:\n")
agg <- aggregate(segundos ~ escenario, tiempos, sum)
for (i in seq_len(nrow(agg)))
  cat(sprintf("   %-14s %8.1f s\n", agg$escenario[i], agg$segundos[i]))
write.table(tiempos, file.path("resultados", "tiempos.tsv"), sep = "\t",
            row.names = FALSE, quote = FALSE)
cat("==============================================================\n")
