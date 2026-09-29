# =============================================================================
#  00_config.R
#
#  Unico archivo que se edita a mano. Define rutas, columnas y umbrales, y
#  carga las funciones compartidas por el resto del pipeline.
#
#  ORGANIZACION DEL ANALISIS
#  El pipeline responde una pregunta filogeografica: donde estuvo el ancestro
#  comun de las cepas muestreadas y en que orden se colonizo el rango actual.
#  Por eso la unidad de analisis es el GRUPO GEOGRAFICO, no el linaje. Toda la
#  cadena inferencial (gradiente de diversidad, psi, aislamiento por distancia,
#  orden de divergencia) necesita que cada grupo tenga una coordenada real. El
#  linaje entra como atributo para diagnostico, no como criterio de agrupacion.
#
#  Agrupar por linaje convierte la coordenada en un centroide sin significado
#  geografico. Ese fue el origen de un error real en la version anterior: cuatro
#  clados chinos de cerevisiae quedaron fusionados en uno porque compartian un
#  centroide, y el analisis corrio con 30 grupos habiendo 33 linajes. Por eso
#  FUSIONAR_COORD existe y por eso 12_validar.R lo comprueba.
# =============================================================================

# =============================================================================
#  EJECUCION DESDE RSTUDIO
#
#  El pipeline esta pensado para correr con Rscript, pero tambien tiene que
#  poder abrirse en RStudio y correrse paso a paso, que es como se depura. Hay
#  tres cosas que rompen si no se resuelven aca:
#
#  1. El directorio de trabajo. Al apretar Source, RStudio no cambia el
#     directorio al del archivo. Cada script del pipeline arranca con un bloque
#     que localiza su propia carpeta y se para ahi, sin necesitar rstudioapi:
#     usa la ruta que R guarda en ofile al hacer source(). Si ese camino no
#     existe, cae en rstudioapi cuando esta instalado.
#
#  2. quit(). Varios pasos terminan con quit() cuando el resultado no da para
#     seguir. Con Rscript es lo correcto; dentro de RStudio MATA LA SESION y se
#     pierde todo lo que hubiera en memoria. Por eso existe detener(), que
#     ademas guarda el motivo en FILO_DETENIDO para poder inspeccionarlo.
#
#  3. commandArgs(). No hay argumentos de linea de comandos en una sesion
#     interactiva. 99_correr_todo.R lee options(filo.desde) y options(filo.hasta)
#     cuando no los encuentra.
#
#  Para correr todo desde RStudio, con el proyecto abierto en esta carpeta:
#
#      source("99_correr_todo.R")                       # los 12 pasos
#      options(filo.desde = "06", filo.hasta = "09")    # solo un tramo
#      source("99_correr_todo.R")
#
#  Y para correr un paso suelto, alcanza con abrirlo y apretar Source: cada uno
#  arranca con source("00_config.R") y levanta los intermedios que necesita.
# =============================================================================

# La unidad de analisis y las exclusiones las fija el ESCENARIO activo, que
# 99_correr_todo.R va rotando. Cuando se corre un paso suelto sin escenario,
# valen los valores por defecto de mas abajo.
.esc <- getOption("filo.escenario", NULL)

DATA <- "DATA"
OUT  <- if (!is.null(.esc)) file.path("resultados", .esc$nombre) else "resultados"

ARCHIVO_VCF       <- file.path(DATA, "filtered_eub.recode.vcf.bgz")
ARCHIVO_META      <- file.path(DATA, "MetaData_SEu.csv")
ARCHIVO_COORDS    <- file.path(DATA, "sitios_coords.csv")
# Tabla opcional chrom / pos / ancestral con el estado ancestral leido de un
# grupo externo (S. uvarum para eubayanus, S. paradoxus para cerevisiae). Se
# obtiene alineando el ensamblado del outgroup contra la referencia, NO mapeando
# lecturas: a 15% de divergencia el mapeo falla e introduce sesgo de referencia.
# Mientras no exista, POLARIZAR queda en "mayoria" y eso se declara como
# supuesto en 07_psi.R y en la validacion.
ARCHIVO_OUTGROUP  <- file.path(DATA, "outgroup_ancestral.tsv")

ESPECIE <- "Saccharomyces eubayanus"

# --- Columnas de la metadata -------------------------------------------------
COL_CEPA   <- "Strain"
COL_GRUPO  <- if (!is.null(.esc)) .esc$grupo else "Site"
COL_SITIO  <- getOption("filo.sitio", "Site")   # columna que cruza con coordenadas
COL_LINAJE <- "Population"                           # solo diagnostico
COL_PAIS   <- "Country"
COL_CONT   <- "Continente"
COL_ECOL   <- "Sustate"      # ecologia o sustrato, para estratificar despues
COL_PLOIDIA<- ""   # vacio si la metadata no la trae

RENOMBRAR  <- c("467" = "CL467")
SUBSET_COL <- NULL
SUBSET_VAL <- NULL

# --- Formacion de grupos -----------------------------------------------------
# Linajes que no entran al analisis. "Admix" no es un linaje: es la etiqueta de
# las cepas sin asignacion limpia, y su diversidad es alta porque son mezclas.
# Dejarlas adentro contamina pi y el ranking de psi con el mismo efecto Wahlund
# que se quiere evitar.
EXCLUIR_LINAJE <- if (!is.null(.esc)) .esc$excluir else character(0)

# =============================================================================
#  ESCENARIOS
#
#  Cada uno es una corrida completa de los 12 pasos, con su propia carpeta bajo
#  resultados/. 99_correr_todo.R los recorre en orden, de modo que un solo
#  lanzamiento deja todos los analisis hechos.
#
#  sitio         La unidad geografica pura. Es la que sostiene el mapa y la
#                superficie de origen. Un sitio puede reunir varios linajes, asi
#                que su pi esta inflado por efecto Wahlund: sirve para describir
#                la geografia, no para comparar diversidad.
#
#  sitio_linaje  Cada grupo es un linaje en un lugar. Es la unica escala donde
#                pi mide diversidad DENTRO de linaje conservando la geografia, y
#                es la que hizo aparecer la senal: con esta medicion el modelo de
#                aislamiento por distancia pasa de ganar a ser el peor, y psi
#                seniala la Patagonia austral con soporte alto. Excluye Admix.
#
#  linaje        Agrupa solo por linaje. La geografia deja de tener sentido
#                (la coordenada es un centroide), asi que de esta corrida se
#                usan el arbol de linajes, f3 y los tiempos de divergencia, NO
#                el origen ni psi.
# =============================================================================
ESCENARIOS <- list(
  list(nombre = "sitio",        grupo = "Site",
       fusionar = TRUE,  excluir = character(0)),
  list(nombre = "sitio_linaje", grupo = c("Site", "Population"),
       fusionar = FALSE, excluir = "Admix"),
  list(nombre = "linaje",       grupo = "Population",
       fusionar = FALSE, excluir = character(0))
)

MIN_N_GRUPO <- 2L
PONDERAR    <- TRUE
PESO_PRECISION <- c(sitio = 1.00, pais = 0.40, continente = 0.15)

# Fusion de grupos que caen en el mismo punto. Con agrupacion geografica tiene
# sentido: dos nombres distintos para la misma coordenada son el mismo sitio.
# Con agrupacion por linaje NO tiene sentido y hay que apagarla, porque la
# coordenada de un linaje es un centroide.
FUSIONAR_COORD <- if (!is.null(.esc)) .esc$fusionar else TRUE
AGRUPAR_KM     <- 0

# --- Panel de variantes ------------------------------------------------------
CONTIG_EXCLUIR <- "mtDNA"
MIN_MAF        <- 0.05     # panel estricto, para estadisticos entre grupos
MIN_CALL       <- 0.80
MIN_DIST_LD    <- 20L
# Panel amplio, sin filtro de frecuencia. La senal de expansion vive en la cola
# de alelos raros: alelos privados y psi dependen de ella. Si el VCF de entrada
# ya viene filtrado por MAF aguas arriba, esta cola no existe y 03_diagnostico.R
# lo declara como limitacion en vez de dejarlo pasar en silencio.
FRAC_AMPLIO    <- 0.35
MAF_AMPLIO     <- 0.002   # casi sin filtro, pero no cero: sitios invariantes fuera
CALL_AMPLIO    <- 0.60
CHUNK          <- 20000L  # lineas del VCF por lote. Sube memoria, baja tiempo

# --- Remuestreo --------------------------------------------------------------
# La unidad de remuestreo son VENTANAS GENOMICAS, no SNPs sueltos ni cromosomas.
#   SNPs sueltos: estan ligados, tratarlos como independientes infla el soporte
#     y produce ramas al 100% que no lo merecen.
#   Cromosomas: correcto pero grueso. Levadura tiene 16, o sea 16 bloques, y el
#     jackknife queda con 15 grados de libertad.
#   Ventanas de 100 kb: cientos de bloques por genoma, mas grandes que la caida
#     del LD en levadura (pocos kb), asi que preservan el ligamiento y dan
#     resolucion real.
TAM_BLOQUE  <- 100000L
N_BOOTSTRAP <- 500L
N_PERMUTA   <- 1000L
SEMILLA     <- 20260819L

# Modo rapido. Submuestrea el panel y baja las replicas para que el pipeline
# entero corra en minutos. Sirve para ver si los NUMEROS tienen sentido antes de
# largar la corrida larga: un Ne absurdo o un ranking encabezado por un grupo de
# una cepa se detectan aca y no despues de dos horas.
#     options(filo.rapido = TRUE); source("99_correr_todo.R")
# Se edita ACA, no con options(). rstudioapi::jobRunScript abre una sesion
# nueva que no hereda options() de la consola, asi que un ajuste puesto en la
# consola nunca llegaria al job.
RAPIDO <- FALSE
if (RAPIDO) {
  N_BOOTSTRAP <- 20L
  N_PERMUTA   <- 50L
  GRILLA_PASO <- 2.0
  message("MODO RAPIDO: panel submuestreado, ", N_BOOTSTRAP, " replicas, grilla ",
          GRILLA_PASO, " grados. Los resultados NO son finales.")
}
FRAC_RAPIDO <- 0.05

# Tramo de pasos a ejecutar. Tambien aca y no con options(), por lo mismo.
PASO_DESDE <- "16"
PASO_HASTA <- "16"

# --- Origen ------------------------------------------------------------------
GRILLA_PASO   <- 0.5
GRILLA_MARGEN <- 5
POLARIZAR     <- "mayoria"   # "mayoria" | "outgroup" | "referencia"

# Modelo de dos refugios en 10_modelos.R: cuantos puntos de la grilla entran
# como candidatos y que separacion minima se les exige. Buscar el mejor par
# sobre la grilla completa seria inviable.
# f3 en 13_estructura.R: cuantos grupos entran como objetivo y como fuente. La
# busqueda es cubica en el numero de grupos, asi que se acota a los que tienen
# mas cepas, que son los unicos donde f3 tiene precision.
# Componentes de ancestria en 18_origen_cepa.R. Con K muy alto la factorizacion
# empieza a partir grupos reales en pedazos sin sentido; con K muy bajo funde
# poblaciones distintas. Un punto de partida razonable es el numero de linajes.
K_ANCESTRIA  <- 6L

N_OBJ_F3     <- 10L
N_FUENTES_F3 <- 25L

N_CAND_REFUGIO <- 30L
SEP_CAND_KM    <- 500

# --- Umbrales de reporte -----------------------------------------------------
# Umbral de cepas por grupo. Un grupo de una o dos cepas estima sus frecuencias
# alelicas con muchisimo ruido, y ese ruido se lee como senal: rama larga en el
# arbol, psi extremo, punto influyente en el gradiente. Se aplica en TODOS los
# pasos que estiman algo por grupo (06, 07, 08, 09), no solo en el arbol.
N_MIN_GRUPO_EST <- 3L
N_MIN_ARBOL     <- N_MIN_GRUPO_EST   # nombre viejo, se mantiene por compatibilidad
MIN_SITIOS_PSI<- 50L

# --- Calibracion temporal ----------------------------------------------------
# El resultado primario son UNIDADES DE DERIVA. La conversion a anos arrastra el
# error de mu, de generaciones por ano y de Ne, y los tres se multiplican: en la
# version anterior el rango iba de 1e5 a 9e8 anos, que no es una estimacion con
# incertidumbre sino la senal de que no hay modelo demografico abajo. Los anos
# se reportan como cota, nunca como valor central.
# Largo del genoma llamable, en pares de bases. Hace falta para convertir la
# diversidad del panel a diversidad por par de bases: pi_panel esta medido POR
# SITIO DEL PANEL y theta se define POR PAR DE BASES. Usar uno por el otro
# infla Ne en varios ordenes de magnitud.
LARGO_GENOMA <- 12071326L   # S. eubayanus CBS 12357, 16 cromosomas

MU_REF <- 1.67e-10; MU_MIN <- 1.10e-10; MU_MAX <- 3.30e-10
GEN_ANO_REF <- 150;  GEN_ANO_MIN <- 1;   GEN_ANO_MAX <- 2900

# =============================================================================
#  REFERENCIAS
#
#  Cada metodo del pipeline, con la fuente que lo define y, cuando existe, la
#  critica que hay que declarar al usarlo. La lista se exporta para que la
#  aplicacion pueda mostrarla y para que el manuscrito no tenga que reconstruirla.
# =============================================================================
REFERENCIAS <- list(
  list(clave = "nei1987", paso = "04",
       cita = "Nei M (1987). Molecular Evolutionary Genetics. Columbia University Press.",
       uso = "Heterocigosidad esperada insesgada. En sitios bialelicos coincide con pi."),
  list(clave = "tajima1989", paso = "14",
       cita = "Tajima F (1989). Statistical method for testing the neutral mutation hypothesis by DNA polymorphism. Genetics 123:585-595.",
       uso = "D de Tajima. Negativo indica exceso de variantes raras, firma de expansion.",
       reparo = "El panel filtrado por MAF amputa la cola rara y sesga D hacia arriba."),
  list(clave = "watterson1975", paso = "14",
       cita = "Watterson GA (1975). On the number of segregating sites in genetical models without recombination. Theor Popul Biol 7:256-276.",
       uso = "Estimador theta basado en sitios segregantes."),
  list(clave = "hudson1992", paso = "05",
       cita = "Hudson RR, Slatkin M, Maddison WP (1992). Estimation of levels of gene flow from DNA sequence data. Genetics 132:583-589.",
       uso = "Estimador FST de Hudson."),
  list(clave = "bhatia2013", paso = "05",
       cita = "Bhatia G, Patterson N, Sankararaman S, Price AL (2013). Estimating and interpreting FST: the impact of rare variants. Genome Res 23:1514-1521.",
       uso = "Forma razon de promedios, que no se sesga con tamanos de muestra dispares."),
  list(clave = "saitou1987", paso = "08",
       cita = "Saitou N, Nei M (1987). The neighbor-joining method. Mol Biol Evol 4:406-425.",
       uso = "Construccion del arbol de grupos."),
  list(clave = "felsenstein1985", paso = "08",
       cita = "Felsenstein J (1985). Confidence limits on phylogenies: an approach using the bootstrap. Evolution 39:783-791.",
       uso = "Soporte de las particiones por remuestreo.",
       reparo = "Remuestrear SNP ligados infla el soporte: aca la unidad son ventanas del genoma."),
  list(clave = "kunsch1989", paso = "todos",
       cita = "Kunsch HR (1989). The jackknife and the bootstrap for general stationary observations. Ann Stat 17:1217-1241.",
       uso = "Bootstrap por bloques, que es lo que corresponde con datos ligados."),
  list(clave = "ramachandran2005", paso = "06",
       cita = "Ramachandran S et al. (2005). Support from the relationship of genetic and geographic distance in human populations for a serial founder effect originating in Africa. PNAS 102:15942-15947.",
       uso = "Caida de la diversidad con la distancia al origen como estimador de la fuente."),
  list(clave = "prugnolle2005", paso = "06",
       cita = "Prugnolle F, Manica A, Balloux F (2005). Geography predicts neutral genetic diversity of human populations. Curr Biol 15:R159-R160.",
       uso = "Ajuste del origen sobre una grilla de puntos candidatos."),
  list(clave = "peter2013", paso = "07",
       cita = "Peter BM, Slatkin M (2013). Detecting range expansions from genetic data. Evolution 67:3274-3289.",
       uso = "Indice de direccionalidad psi. Mas potente que FST y que las clinas de heterocigosidad.",
       reparo = "Requiere polarizar el alelo derivado. Sin grupo externo el supuesto de mayoria falla tras un cuello de botella."),
  list(clave = "kemppainen2024", paso = "11",
       cita = "Kemppainen P, Schembri R, Momigliano P (2024). Boundary effects cause false signals of range expansions in population genomic data. Mol Biol Evol 41:msae091.",
       uso = "Control de efecto de borde.",
       reparo = "CRITICO. En metapoblaciones en equilibrio, la deriva es mas fuerte en los bordes del rango y produce clinas de diversidad y de psi identicas a las de una expansion. La tasa de falsos positivos es alta. Un origen estimado sobre el borde del muestreo es sospechoso por construccion."),
  list(clave = "patterson2012", paso = "13",
       cita = "Patterson N et al. (2012). Ancient admixture in human history. Genetics 192:1065-1093.",
       uso = "Estadistico f3 de mezcla y su error estandar por jackknife de bloques. Umbral Z < -3."),
  list(clave = "excoffier1992", paso = "14",
       cita = "Excoffier L, Smouse PE, Quattro JM (1992). Analysis of molecular variance inferred from metric distances among DNA haplotypes. Genetics 131:479-491.",
       uso = "Particion jerarquica de la varianza."),
  list(clave = "wang2010", paso = "14",
       cita = "Wang C et al. (2010). Comparing spatial maps of human population-genetic variation using Procrustes analysis. Stat Appl Genet Mol Biol 9:13.",
       uso = "Procrustes entre el mapa genetico y el geografico, con significancia por permutacion."),
  list(clave = "mantel1967", paso = "05",
       cita = "Mantel N (1967). The detection of disease clustering and a generalized regression approach. Cancer Res 27:209-220.",
       uso = "Prueba de aislamiento por distancia por permutacion de los rotulos de grupo."),
  list(clave = "rousset1997", paso = "05",
       cita = "Rousset F (1997). Genetic differentiation and estimation of gene flow from F-statistics under isolation by distance. Genetics 145:1219-1228.",
       uso = "Regresion de FST/(1-FST) contra el logaritmo de la distancia."),
  list(clave = "lee2009", paso = "13",
       cita = "Lee DD, Seung HS (1999). Learning the parts of objects by non-negative matrix factorization. Nature 401:788-791.",
       uso = "Factorizacion no negativa, base de la estimacion de ancestria por cepa.",
       reparo = "No es un modelo de verosimilitud como ADMIXTURE: no da intervalos y la lectura de cada componente como poblacion real es interpretacion."),
  list(clave = "frichot2014", paso = "18",
       cita = "Frichot E, Mathieu F, Trouillon T, Bouchard G, Francois O (2014). Fast and efficient estimation of individual ancestry coefficients. Genetics 196:973-983.",
       uso = "Referencia del enfoque de minimos cuadrados para coeficientes de ancestria."),
  list(clave = "benjamini1995", paso = "16",
       cita = "Benjamini Y, Hochberg Y (1995). Controlling the false discovery rate. J R Stat Soc B 57:289-300.",
       uso = "Correccion por pruebas multiples en los marcadores diagnosticos."),
  list(clave = "peter2018", paso = "01",
       cita = "Peter J et al. (2018). Genome evolution across 1011 Saccharomyces cerevisiae isolates. Nature 556:339-344.",
       uso = "Origen del panel de cerevisiae y de las etiquetas de linaje."),
  list(clave = "nespolo2020", paso = "06",
       cita = "Nespolo RF et al. (2020). An Out-of-Patagonia migration explains the worldwide diversity and distribution of Saccharomyces eubayanus lineages. PLoS Genet 16:e1008777.",
       uso = "Resultado publicado contra el cual se contrasta el control positivo de eubayanus.")
)

# =============================================================================
#  FUNCIONES COMPARTIDAS
# =============================================================================
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

paso <- function(nombre) file.path(OUT, paste0("paso_", nombre, ".rds"))

# Termina el paso actual. Con Rscript sale del proceso con el estado indicado,
# que es lo que necesita 99_correr_todo.R y cualquier automatizacion. En una
# sesion interactiva NO mata la sesion: deja el motivo en FILO_DETENIDO, avisa
# por consola y corta la ejecucion del script con una condicion silenciosa.
detener <- function(motivo, estado = 0L) {
  assign("FILO_DETENIDO", list(motivo = motivo, estado = estado),
         envir = globalenv())
  if (interactive()) {
    message("\n[detenido] ", motivo,
            "\n  El motivo queda en FILO_DETENIDO. La sesion sigue viva.")
    invokeRestart("abort")
  } else {
    quit(save = "no", status = estado)
  }
}

exigir_paso <- function(nombre, script) {
  f <- paso(nombre)
  if (!file.exists(f)) stop("Falta ", basename(f), ". Corre antes ", script, call. = FALSE)
  readRDS(f)
}

# OJO: nuevo_log() devuelve una funcion que en cada script se asigna a `log`,
# con lo que TAPA a base::log dentro de ese script. Cualquier logaritmo
# matematico en un script que use el registro tiene que escribirse base::log, o
# R llama al registro, imprime el argumento y devuelve NULL. Paso de verdad.
nuevo_log <- function(nombre) {
  f <- file.path(OUT, paste0(nombre, ".log"))
  con <- file(f, "wt")
  function(...) {
    if (identical(..1, ".cerrar")) { close(con); return(invisible(NULL)) }
    txt <- paste0(...)
    cat(txt, "\n", sep = "")
    writeLines(txt, con)
    # Sin flush el archivo queda vacio hasta cerrar la conexion, asi que un paso
    # que revienta no deja rastro justo cuando mas hace falta.
    flush(con)
  }
}
cerrar_log <- function(log) log(".cerrar")

dist_km <- function(lat1, lon1, lat2, lon2) {
  r <- pi / 180
  a <- sin((lat2 - lat1) * r / 2)^2 +
    cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  6371 * 2 * asin(pmin(1, sqrt(a)))
}

normalizar_texto <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- iconv(x, to = "ASCII//TRANSLIT")
  gsub("[^a-z0-9]+", " ", x)
}

leer_tabla <- function(path) {
  prim <- readLines(path, n = 1, warn = FALSE)
  sep <- c(";", ",", "\t")[which.max(vapply(c(";", ",", "\t"), function(s)
    lengths(regmatches(prim, gregexpr(s, prim, fixed = TRUE))), integer(1)))]
  m <- read.table(path, header = TRUE, sep = sep, stringsAsFactors = FALSE,
                  quote = "\"", comment.char = "", check.names = FALSE)
  names(m) <- trimws(names(m))
  for (k in names(m)) if (is.character(m[[k]])) m[[k]] <- trimws(m[[k]])
  m
}

# Asigna a cada SNP el bloque de remuestreo al que pertenece. El bloque es la
# ventana de TAM_BLOQUE pares de bases dentro de su cromosoma.
bloques_de <- function(chrom, pos, tam = TAM_BLOQUE) {
  paste0(chrom, ":", floor(pos / tam))
}

# Bootstrap por bloques: devuelve una lista de vectores de indices de SNP, cada
# uno correspondiente a un remuestreo con reemplazo de los bloques. Remuestrear
# bloques y no SNPs es lo que impide que el ligamiento infle el soporte.
replicas_bloque <- function(bloq, B = N_BOOTSTRAP, semilla = SEMILLA) {
  set.seed(semilla)
  idx_por_bloque <- split(seq_along(bloq), bloq)
  nb <- length(idx_por_bloque)
  lapply(seq_len(B), function(b) unlist(idx_por_bloque[sample.int(nb, nb, replace = TRUE)],
                                        use.names = FALSE))
}

# He insesgado de Nei (1987) por sitio, promediado sobre el panel. En sitios
# bialelicos esta cantidad es identica a la diversidad nucleotidica pi sobre esos
# mismos sitios, asi que el pipeline la reporta como pi y no como dos columnas
# distintas. Es pi POR SITIO DEL PANEL, no por par de bases del genoma: no es
# comparable con valores de pi por kb publicados.
pi_por_grupo <- function(ALT, TOT, idx = NULL) {
  if (!is.null(idx)) { ALT <- ALT[idx, , drop = FALSE]; TOT <- TOT[idx, , drop = FALSE] }
  f <- ALT / pmax(TOT, 1)
  H <- (2 * TOT / pmax(TOT - 1, 1)) * f * (1 - f)
  H[TOT < 2] <- NA
  colMeans(H, na.rm = TRUE)
}

# Aviso cuando un numero se va del rango biologicamente creible. No corrige
# nada: avisa fuerte, en el momento, para que no viaje seis pasos aguas abajo.
plausible <- function(valor, nombre, minimo, maximo, unidad = "", log = NULL) {
  ok <- is.finite(valor) && valor >= minimo && valor <= maximo
  if (!ok) {
    txt <- sprintf("IMPLAUSIBLE: %s = %s %s, fuera del rango esperable [%s, %s]",
                   nombre, format(signif(valor, 4)), unidad,
                   format(minimo), format(maximo))
    if (!is.null(log)) log("  ", txt) else warning(txt, call. = FALSE)
  }
  ok
}

message("00_config.R cargado | especie=", ESPECIE, " | grupo=", COL_GRUPO,
        " | OUT=", OUT)
