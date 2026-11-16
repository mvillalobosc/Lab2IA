# =============================================================================
# tools/preparar_datos.R
# Genera las dos bases de datos que lee el dashboard:
#
#   data/bd_encuesta.js   conteos y porcentajes de la encuesta, por enfermedad
#                         y por región (window.BD_ENCUESTA)
#   data/bd_regiones.js   contorno simplificado de las 16 regiones de Chile
#                         (window.BD_REGIONES)
#
# El dashboard no calcula nada: solo muestra lo que este script deja escrito.
# Las bases traen solo agregados (cuántas personas de cada grupo dieron cada
# respuesta). Las respuestas fila por fila de la encuesta no salen de aquí.
#
# Entradas:
#   tools/data_encuesta_filtrado.xlsx   la encuesta (no viene en el repositorio)
#   tools/regiones.json                 límites regionales en GeoJSON
#
# Uso, desde la carpeta del dashboard (la que tiene index.html):
#   Rscript tools/preparar_datos.R
#   Rscript tools/preparar_datos.R ruta/a/otra_encuesta.xlsx
#
# Paquetes: readxl y jsonlite.
#
# Las fórmulas son las del dashboard Shiny original (app.R), con una
# corrección: "decisión compartida" (V114) se contaba comparando con "Si" y la
# base trae "SI", así que el Shiny mostraba siempre 0 %.
# =============================================================================

for (paquete in c("readxl", "jsonlite")) {
  if (!requireNamespace(paquete, quietly = TRUE)) {
    stop("Falta el paquete ", paquete, ". Instálelo con install.packages(\"", paquete, "\")",
         call. = FALSE)
  }
}
if (is.na(iconv("í", from = "UTF-8", to = ""))) {
  stop("R esta corriendo con una configuracion regional sin tildes. ",
       "Use una UTF-8, por ejemplo: LC_ALL=C.UTF-8 Rscript tools/preparar_datos.R", call. = FALSE)
}
if (!file.exists("index.html") || !dir.exists("tools")) {
  stop("Corra el script desde la carpeta del dashboard (la que tiene index.html).", call. = FALSE)
}

argumentos       <- commandArgs(trailingOnly = TRUE)
ARCHIVO_ENCUESTA <- if (length(argumentos) >= 1) argumentos[1] else file.path("tools", "data_encuesta_filtrado.xlsx")
ARCHIVO_REGIONES <- file.path("tools", "regiones.json")
SALIDA_ENCUESTA  <- file.path("data", "bd_encuesta.js")
SALIDA_REGIONES  <- file.path("data", "bd_regiones.js")

if (!file.exists(ARCHIVO_ENCUESTA)) {
  stop("No se encuentra ", ARCHIVO_ENCUESTA, ". Copie ahí la encuesta o pase su ruta como argumento.",
       call. = FALSE)
}


# =============================================================================
# CATÁLOGO: variables de la encuesta y código de cada respuesta
# =============================================================================
# Los códigos son los que usa el dashboard para traducir cada respuesta
# (js/textos.js). Si la encuesta trae una respuesta que no está aquí, el script
# se detiene: ninguna respuesta se pierde ni se agrupa sin que se note.

ENFERMEDADES <- c("V8", "V9", "V10", "V11", "V12", "V13",
                  "V14", "V15", "V16", "V17", "V18", "V20")

# Regiones: nombre en la encuesta (V4) -> código oficial. El orden es de norte
# a sur y es el que usa el dashboard.
REGIONES <- c(
  "de Arica y Parinacota"                        = 15,
  "de Tarapacá"                                  = 1,
  "de Antofagasta"                               = 2,
  "de Atacama"                                   = 3,
  "de Coquimbo"                                  = 4,
  "de Valparaíso"                                = 5,
  "Metropolitana de Santiago"                    = 13,
  "del Libertador Bernardo O'Higgins"            = 6,
  "del Maule"                                    = 7,
  "de Ñuble"                                     = 16,
  "del Biobío"                                   = 8,
  "de la Araucanía"                              = 9,
  "de Los Ríos"                                  = 14,
  "de Los Lagos"                                 = 10,
  "de Aysén del General Carlos Ibañez del Campo" = 11,
  "de Magallanes y la Antártica Chilena"         = 12
)

# Variables de una sola respuesta: respuesta en la encuesta -> código.
# El orden de cada vector es el orden natural de la escala.
NIVELES <- list(
  sexo = c("Femenino" = "f", "Masculino" = "m", "Otro" = "o"),
  edad = c("0 a 18 años" = "e0_18", "19 a 30 años" = "e19_30", "31 a 45 años" = "e31_45",
           "45 a 60 años" = "e45_60", "más de 60 años" = "e60"),
  anios_dx = c("Menos de 1 año" = "d0_1", "De 1 a 5 años" = "d1_5", "De 5 a 10 años" = "d5_10",
               "De 10 a 15 años" = "d10_15", "Más de 15 años" = "d15"),
  actividad = c(
    "No realizo ninguna actividad física"             = "sin",
    "Menos de media hora a la semana"                 = "lt30",
    "Entre media hora y una hora a la semana"         = "m30_60",
    "Más de una hora y menos de 2 horas a la semana"  = "h1_2",
    "Más de dos horas y menos de 3 horas a la semana" = "h2_3",
    "Más de 3 horas y menos de 4 horas a las semana"  = "h3_4",
    "Más de 4 horas a la semana"                      = "gt4"),
  tabaco = c(
    "No consumo, ni nunca he consumido"                                           = "nunca",
    "Consumía, pero ya lo dejé"                                                   = "ex",
    "Consumo solamente los fines de semana o en eventos sociales, limitadamente"  = "ocasional",
    "Consumo todos los días, menos de 5 cigarros al día en promedio"              = "diario_lt5",
    "Consumo todos los días, más de 5 cigarros al día en promedio"                = "diario_gt5"),
  alcohol = c(
    "No consumo, ni nunca he consumido"                                           = "nunca",
    "Consumía, pero ya lo dejé"                                                   = "ex",
    "Consumo solamente los fines de semana o en eventos sociales, limitadamente"  = "ocasional",
    "Consumo al menos un par de veces a la semana"                                = "semanal"),
  dieta = c(
    "No tengo ninguna restricción ni régimen especial"               = "sin",
    "Soy intolerante a la lactosa"                                   = "lactosa",
    "Consumo alimentos bajos en sodio"                               = "sodio",
    "No consumo azúcares añadidas"                                   = "azucar",
    "Soy vegetariana(o)"                                             = "vegetariana",
    "Soy alérgico a algunos alimentos (huevo, frutos secos u otros)" = "alergia",
    "Soy vegana(o)"                                                  = "vegana",
    "Consumo solamente alimentos cocidos"                            = "cocidos"),
  salud = c("Excelente" = "excelente", "Bueno" = "bueno", "Regular" = "regular",
            "Malo" = "malo", "Muy malo" = "muy_malo"),
  dolor = c("SI" = "con", "NO" = "sin"),
  relacion = c("Excelente" = "excelente", "Buena" = "buena", "Regular" = "regular",
               "Mala" = "mala", "Muy mala" = "muy_mala"),
  preguntas = c(
    "Sí, y se da el tiempo de contestarlas"                     = "contesta",
    "Sí, pero no las contesta o las subestima"                  = "no_contesta",
    "No, no me da la opción ni el espacio para hacer preguntas" = "sin_espacio"),
  decision = c("SI" = "si", "NO" = "no"),
  ges = c(
    "SI"                                                                 = "si",
    "No, mi enfermedad reumática no tiene GES"                           = "no_tiene",
    "No, mi médico no me ha hablado del GES"                             = "no_informado",
    "No tengo claro qué es el GES"                                       = "desconoce",
    "No, estoy esperando la interconsulta para confirmación diagnóstica" = "esperando",
    "No, no tengo previsión de salud"                                    = "sin_prevision",
    "No, mi previsión de salud no tiene GES"                             = "prevision_sin"),
  gasto = c(
    "Menos de $50,000"                    = "g0_50",
    "Más de $50,000 y menos de $100,000"  = "g50_100",
    "Más de $100,000 y menos de $150,000" = "g100_150",
    "Más de $150,000 y menos de $200,000" = "g150_200",
    "Más de $200,000"                     = "g200"),
  credito = c(
    "No, no he tomado ningún crédito"                                       = "sin_credito",
    "No, tomé un crédito y no tuve problemas,"                              = "sin_problemas",
    "Sí, me negaron el crédito por no poder tomar un seguro de desgravamen" = "negado"),
  judicial = c(
    "No, nunca he judicializado el acceso a algún tratamiento"                                     = "nunca",
    "Sí, contra FONASA para obtener un tratamiento y lo recibí"                                    = "fonasa_gano",
    "Sí, contra FONASA para obtener un tratamiento, pero perdí en tribunales y no lo recibo"       = "fonasa_perdio",
    "Sí, contra mi ISAPRE para obtener un tratamineto y lo recibí"                                 = "isapre_gano",
    "Sí, contra mi ISAPRE para obtener un tratamiento, pero lo perdí en tribunales y no lo recibo" = "isapre_perdio"),
  nivel3 = c("Bajo" = "bajo", "Medio" = "medio", "Alto" = "alto")
)

# Columna de la encuesta de cada variable de una sola respuesta
COLUMNA <- c(sexo = "V1", edad = "V2", anios_dx = "V23", actividad = "V64", tabaco = "V66",
             alcohol = "V67", dieta = "V68", salud = "V69", dolor = "V54", relacion = "V112",
             preguntas = "V113", decision = "V114", ges = "V83", gasto = "V88",
             credito = "V116", judicial = "V117")

# Preguntas de respuesta múltiple: una columna SI/NO por opción
ESPECIALISTAS <- c(V24 = "reuma", V25 = "inmuno", V26 = "internista", V27 = "general",
                   V28 = "nefro", V29 = "dermato", V30 = "oftalmo", V31 = "otra")
FARMACOS <- c(V40 = "aines", V41 = "analgesicos", V42 = "antirreumaticos", V43 = "suplementos",
              V44 = "corticoides", V45 = "calcio", V46 = "gotas", V47 = "inmunosupresores",
              V48 = "biologicos", V49 = "opioides", V50 = "moleculas", V51 = "psicofarmacos")
RAZONES <- c(V71 = "recursos", V72 = "miedo", V73 = "exceso", V74 = "innecesario",
             V75 = "no_disponible", V76 = "otro_medico", V77 = "otra_persona", V78 = "medios")
FINANCIAMIENTO <- c(V89 = "sin_soporte", V90 = "bingos", V91 = "donacion", V92 = "menor_costo",
                    V93 = "importacion", V94 = "municipalidad", V95 = "medico")
COMPLEMENTARIAS <- c(V65 = "alternativas", V55 = "cannabis")

# Otras columnas SI/NO que alimentan indicadores
BINARIAS <- c("V32", "V33", "V34", "V35", "V70", "V82", "V85", "V96", "V99", "V115")


# =============================================================================
# LECTURA Y CONTROLES
# =============================================================================
datos <- as.data.frame(readxl::read_excel(ARCHIVO_ENCUESTA), stringsAsFactors = FALSE)
N_TOTAL <- nrow(datos)

# Misma unificación de respuestas que el análisis del artículo
for (columna in names(datos)) {
  x <- as.character(datos[[columna]])
  x[x %in% c("SI", "Si", "Sí", "SÍ")] <- "SI"
  x[x %in% c("NO", "No", "no")]       <- "NO"
  datos[[columna]] <- x
}

columnas_si_no <- c(ENFERMEDADES, names(ESPECIALISTAS), names(FARMACOS), names(RAZONES),
                    names(FINANCIAMIENTO), names(COMPLEMENTARIAS), BINARIAS)
necesarias <- c("V4", "V121", "V122", "V123", unname(COLUMNA), columnas_si_no)
faltan <- setdiff(necesarias, names(datos))
if (length(faltan) > 0) stop("La encuesta no trae estas columnas: ", paste(faltan, collapse = ", "), call. = FALSE)

for (columna in columnas_si_no) {
  raros <- setdiff(unique(datos[[columna]]), c("SI", "NO", NA))
  if (length(raros) > 0) stop(columna, " debe traer solo SI y NO. Tiene: ", paste(raros, collapse = " | "), call. = FALSE)
}
for (enfermedad in ENFERMEDADES) {
  if (anyNA(datos[[enfermedad]])) stop(enfermedad, " tiene respuestas faltantes.", call. = FALSE)
}
for (variable in names(COLUMNA)) {
  raros <- setdiff(unique(datos[[COLUMNA[[variable]]]]), c(names(NIVELES[[variable]]), NA))
  if (length(raros) > 0) {
    stop("Respuesta sin código en ", COLUMNA[[variable]], " (", variable, "): ",
         paste(raros, collapse = " | "), call. = FALSE)
  }
}
for (columna in c("V121", "V122", "V123")) {
  raros <- setdiff(unique(datos[[columna]]), c(names(NIVELES$nivel3), NA))
  if (length(raros) > 0) stop("Respuesta sin código en ", columna, ": ", paste(raros, collapse = " | "), call. = FALSE)
}
sin_region <- setdiff(unique(datos$V4), names(REGIONES))
if (length(sin_region) > 0 || anyNA(datos$V4)) {
  stop("Hay encuestados sin región reconocida: ", paste(sin_region, collapse = " | "), call. = FALSE)
}
datos$region <- unname(REGIONES[datos$V4])


# =============================================================================
# FUNCIONES DE CONTEO
# =============================================================================
pct <- function(n, base) if (base > 0) round(n / base * 100, 1) else NA_real_

# Porcentaje de SI entre quienes respondieron (como mean(x == "SI", na.rm = TRUE))
pct_si <- function(x) pct(sum(x == "SI", na.rm = TRUE), sum(!is.na(x)))

# Tabla de una variable de una sola respuesta. base = respuestas válidas.
# Trae todos los niveles de la escala, también los que nadie eligió.
tabla_niveles <- function(x, niveles) {
  validos <- x[!is.na(x)]
  base    <- length(validos)
  list(
    base  = base,
    sin_respuesta = length(x) - base,
    filas = unname(lapply(names(niveles), function(nivel) {
      n <- sum(validos == nivel)
      list(niveles[[nivel]], n, pct(n, base))
    }))
  )
}

# Tabla de una pregunta de respuesta múltiple. base = personas del grupo, así
# que los porcentajes no suman 100.
tabla_multiple <- function(grupo, opciones) {
  base <- nrow(grupo)
  list(
    base  = base,
    sin_respuesta = 0L,
    filas = unname(lapply(names(opciones), function(columna) {
      n <- sum(grupo[[columna]] == "SI", na.rm = TRUE)
      list(opciones[[columna]], n, pct(n, base))
    }))
  )
}

# Respuesta más frecuente (código). Si hay empate devuelve todas las empatadas.
moda <- function(x, niveles) {
  validos <- x[!is.na(x)]
  if (length(validos) == 0) return(I(character(0)))
  conteo <- vapply(names(niveles), function(nivel) sum(validos == nivel), numeric(1))
  I(unname(niveles[conteo == max(conteo)]))
}

# Alguna fuente de financiamiento alternativo (V90 a V95). Reproduce el OR
# lógico de R con datos faltantes: una fila cuenta como SI si alguna es SI,
# como NO si todas son NO y queda fuera si no se puede saber.
alguna_si <- function(grupo, columnas) {
  m <- as.matrix(grupo[, columnas, drop = FALSE]) == "SI"
  alguna <- rowSums(m, na.rm = TRUE) > 0
  indeterminada <- !alguna & rowSums(is.na(m)) > 0
  pct(sum(alguna), sum(!indeterminada))
}


# =============================================================================
# PERFIL DE UNA ENFERMEDAD
# =============================================================================
perfil_enfermedad <- function(enfermedad) {
  g <- datos[datos[[enfermedad]] == "SI", , drop = FALSE]
  n <- nrow(g)
  t <- function(variable) tabla_niveles(g[[COLUMNA[[variable]]]], NIVELES[[variable]])

  # Número de tipos de fármaco por persona (V40 a V51)
  n_farmacos <- rowSums(as.matrix(g[, names(FARMACOS), drop = FALSE]) == "SI", na.rm = TRUE)

  complejidad <- cut(n_farmacos, breaks = c(-Inf, 0, 1, 3, Inf),
                     labels = c("sin", "mono", "poli_baja", "poli_alta"))
  tabla_complejidad <- list(
    base = n, sin_respuesta = 0L,
    filas = unname(lapply(levels(complejidad), function(nivel) {
      k <- sum(complejidad == nivel)
      list(nivel, k, pct(k, n))
    }))
  )

  # Combinaciones de fármacos: las 10 más frecuentes entre quienes usan al
  # menos uno. En los empates manda el orden de las columnas de la encuesta.
  usa <- as.matrix(g[, names(FARMACOS), drop = FALSE]) == "SI"
  usa[is.na(usa)] <- FALSE
  clave <- apply(usa, 1, function(fila) paste(FARMACOS[fila], collapse = "+"))
  clave <- clave[clave != ""]
  combinaciones <- list()
  if (length(clave) > 0) {
    conteo <- table(clave)
    patron <- vapply(names(conteo), function(k) {
      paste(as.integer(FARMACOS %in% strsplit(k, "+", fixed = TRUE)[[1]]), collapse = "")
    }, character(1))
    orden  <- order(-as.integer(conteo), -xtfrm(patron))
    conteo <- conteo[orden][seq_len(min(10, length(conteo)))]
    combinaciones <- unname(lapply(names(conteo), function(k) {
      list(I(strsplit(k, "+", fixed = TRUE)[[1]]), as.integer(conteo[[k]]),
           pct(as.integer(conteo[[k]]), length(clave)))
    }))
  }

  # Adherencia y razones de no adherencia. Las razones se cuentan sobre todo
  # el grupo; "sin razón" son los no adherentes que no marcaron ninguna.
  no_adherente <- g$V70 != "SI" & !is.na(g$V70)
  con_razon    <- rowSums(as.matrix(g[, names(RAZONES), drop = FALSE]) == "SI", na.rm = TRUE) > 0
  n_adherente  <- sum(g$V70 == "SI", na.rm = TRUE)
  n_sin_razon  <- sum(no_adherente) - sum(no_adherente & con_razon)
  tabla_adherencia <- list(
    base = n, sin_respuesta = 0L,
    filas = c(
      list(list("adherente", n_adherente, pct(n_adherente, n))),
      unname(lapply(names(RAZONES), function(columna) {
        k <- sum(g[[columna]] == "SI", na.rm = TRUE)
        list(RAZONES[[columna]], k, pct(k, n))
      })),
      list(list("sin_razon", n_sin_razon, pct(n_sin_razon, n)))
    )
  )

  # Otras enfermedades reumáticas que declaran las mismas personas
  otras <- setdiff(ENFERMEDADES, enfermedad)
  coocurrencia <- lapply(otras, function(otra) {
    k <- sum(g[[otra]] == "SI")
    list(otra, k, pct(k, n))
  })
  coocurrencia <- coocurrencia[order(-vapply(coocurrencia, function(f) f[[2]], numeric(1)))]

  gasto_alto <- c("Más de $100,000 y menos de $150,000", "Más de $150,000 y menos de $200,000",
                  "Más de $200,000")

  list(
    n    = n,
    prev = pct(n, N_TOTAL),
    resumen = list(
      discapacidad   = pct_si(g$V33),
      dolor          = pct_si(g$V54),
      sexo           = moda(g$V1, NIVELES$sexo),
      sexo_pct       = pct(max(table(factor(g$V1, levels = names(NIVELES$sexo)))), sum(!is.na(g$V1))),
      edad           = moda(g$V2, NIVELES$edad),
      comorbilidad   = pct_si(g$V32),
      farmacos_media = round(mean(n_farmacos), 1),
      adherencia     = pct_si(g$V70),
      alternativos   = pct_si(g$V65),
      gasto          = moda(g$V88, NIVELES$gasto),
      financiamiento = alguna_si(g, c("V90", "V91", "V92", "V93", "V94", "V95")),
      continuidad    = pct_si(g$V99)
    ),
    combinada = list(
      credencial_n = sum(g$V34 == "SI", na.rm = TRUE),
      pension_n    = sum(g$V35 == "SI", na.rm = TRUE),
      otras        = coocurrencia
    ),
    perfil = list(
      sexo = t("sexo"), edad = t("edad"),
      actividad = t("actividad"), dieta = t("dieta"), tabaco = t("tabaco"), alcohol = t("alcohol"),
      dolor = t("dolor"), salud = t("salud"),
      anios_dx = t("anios_dx"),
      especialista = tabla_multiple(g, ESPECIALISTAS),
      relacion = t("relacion"), preguntas = t("preguntas"), decision = t("decision")
    ),
    tratamientos = list(
      aines          = pct_si(g$V40),
      biologicos     = pct_si(g$V48),
      politerapia    = pct(sum(n_farmacos >= 2), n),
      complejidad    = tabla_complejidad,
      farmacos       = tabla_multiple(g, FARMACOS),
      complementarias = tabla_multiple(g, COMPLEMENTARIAS),
      con_farmaco    = length(clave),
      combinaciones  = combinaciones
    ),
    acceso = list(
      adherencia_pct = pct_si(g$V70),
      ges_pct        = pct(sum(g$V83 == "SI", na.rm = TRUE), sum(!is.na(g$V83))),
      gasto_alto     = pct(sum(g$V88 %in% gasto_alto), n),
      financiamiento = alguna_si(g, c("V90", "V91", "V92", "V93", "V94", "V95")),
      credito_pct    = pct(sum(g$V115 %in% "SI"), n),
      seguro         = pct_si(g$V82),
      particular     = pct_si(g$V96),
      continuidad    = pct_si(g$V99),
      adherencia     = tabla_adherencia,
      ges            = t("ges"),
      gasto          = t("gasto"),
      financiamiento_fuentes = tabla_multiple(g, FINANCIAMIENTO),
      credito        = t("credito"),
      judicial       = t("judicial")
    )
  )
}


# =============================================================================
# PERFIL DE UNA REGIÓN
# =============================================================================
perfil_region <- function(codigo) {
  g <- datos[datos$region == codigo, , drop = FALSE]
  n <- nrow(g)

  prevalencias <- lapply(ENFERMEDADES, function(enfermedad) {
    k <- sum(g[[enfermedad]] == "SI")
    list(enfermedad, k, pct(k, n))
  })
  prevalencias <- prevalencias[order(-vapply(prevalencias, function(f) f[[2]], numeric(1)))]

  list(
    n            = n,
    pct_muestra  = pct(n, N_TOTAL),
    traslado     = pct_si(g$V85),
    discapacidad = pct_si(g$V33),
    credencial   = pct_si(g$V34),
    enfermedades = prevalencias,
    sexo         = tabla_niveles(g$V1, NIVELES$sexo),
    edad         = tabla_niveles(g$V2, NIVELES$edad),
    educacion      = tabla_niveles(g$V121, NIVELES$nivel3),
    envejecimiento = tabla_niveles(g$V122, NIVELES$nivel3),
    pobreza        = tabla_niveles(g$V123, NIVELES$nivel3)
  )
}


# =============================================================================
# RED DE ENFERMEDADES COMBINADAS
# =============================================================================
# Nodo: una enfermedad y sus encuestados. Arista: personas que declaran las
# dos. Grado: con cuántas de las otras 11 comparte al menos una persona. El
# nivel (alto, medio, bajo) parte los grados en terciles, como el Shiny.
es_si   <- as.matrix(datos[, ENFERMEDADES]) == "SI"
ambas   <- crossprod(es_si)
aristas <- list()
for (i in seq_along(ENFERMEDADES)) {
  for (j in seq_along(ENFERMEDADES)) {
    if (i < j && ambas[i, j] > 0) {
      aristas[[length(aristas) + 1]] <- list(ENFERMEDADES[i], ENFERMEDADES[j], as.integer(ambas[i, j]))
    }
  }
}
grado <- vapply(seq_along(ENFERMEDADES), function(i) sum(ambas[i, -i] > 0), numeric(1))
corte <- quantile(grado, c(1 / 3, 2 / 3))
nivel <- ifelse(grado >= corte[[2]], "alto", ifelse(grado >= corte[[1]], "medio", "bajo"))
nodos <- lapply(seq_along(ENFERMEDADES), function(i) {
  list(id = ENFERMEDADES[i], n = as.integer(sum(es_si[, i])), grado = as.integer(grado[i]),
       nivel = nivel[i])
})


# =============================================================================
# BASE DE LA ENCUESTA
# =============================================================================
por_enfermedad <- setNames(lapply(ENFERMEDADES, perfil_enfermedad), ENFERMEDADES)
por_region     <- setNames(lapply(unname(REGIONES), perfil_region), as.character(REGIONES))

# Controles de cierre: cada encuestado está en una y solo una región, y cada
# tabla de una sola respuesta suma su base.
stopifnot(sum(vapply(por_region, function(r) r$n, numeric(1))) == N_TOTAL)
revisar_tabla <- function(tabla, donde) {
  suma <- sum(vapply(tabla$filas, function(f) f[[2]], numeric(1)))
  if (suma != tabla$base) stop("La tabla ", donde, " no suma su base (", suma, " de ", tabla$base, ")", call. = FALSE)
}
for (enfermedad in ENFERMEDADES) {
  p <- por_enfermedad[[enfermedad]]
  for (variable in setdiff(names(p$perfil), "especialista")) revisar_tabla(p$perfil[[variable]], paste(enfermedad, variable))
  for (variable in c("ges", "gasto", "credito", "judicial")) revisar_tabla(p$acceso[[variable]], paste(enfermedad, variable))
  revisar_tabla(p$tratamientos$complejidad, paste(enfermedad, "complejidad"))
}
for (codigo in names(por_region)) {
  for (variable in c("sexo", "edad", "educacion", "envejecimiento", "pobreza")) {
    revisar_tabla(por_region[[codigo]][[variable]], paste("región", codigo, variable))
  }
}

bd_encuesta <- list(
  meta = list(
    generado     = format(Sys.Date(), "%Y-%m-%d"),
    encuestados  = N_TOTAL,
    preguntas    = ncol(datos) - 1L,
    enfermedades = length(ENFERMEDADES),
    regiones     = length(REGIONES)
  ),
  enfermedades  = I(ENFERMEDADES),
  regiones      = I(unname(REGIONES)),
  red           = list(nodos = nodos, aristas = aristas),
  porEnfermedad = por_enfermedad,
  porRegion     = por_region
)

escribir_js <- function(objeto, variable, ruta, descripcion) {
  json <- jsonlite::toJSON(objeto, auto_unbox = TRUE, digits = NA, na = "null", null = "null")
  lineas <- c(
    paste0("/* ", descripcion),
    "   Archivo generado por tools/preparar_datos.R. No se edita a mano:",
    "   para cambiarlo, se vuelve a correr el script. */",
    paste0("window.", variable, " = ", json, ";")
  )
  con <- file(ruta, open = "wb")
  writeLines(enc2utf8(lineas), con, useBytes = TRUE)
  close(con)
}

dir.create("data", showWarnings = FALSE)
escribir_js(bd_encuesta, "BD_ENCUESTA", SALIDA_ENCUESTA,
            paste0("Base de la encuesta: conteos y porcentajes por enfermedad y por región (",
                   N_TOTAL, " encuestados)."))


# =============================================================================
# BASE DE REGIONES (contorno simplificado para el mapa)
# =============================================================================
# El GeoJSON original pesa casi 900 KB. Para un mapa de pantalla basta mucho
# menos: se proyecta a Mercator, se simplifica cada contorno (Douglas-Peucker)
# y se descartan las islas diminutas. Las islas oceánicas (Rapa Nui, Juan
# Fernández y Desventuradas, al oeste de 76° O) quedan fuera del dibujo porque
# obligarían a achicar el continente hasta dejarlo ilegible; sus encuestados
# siguen contados en la Región de Valparaíso.
ANCHO_MAPA     <- 220      # unidades del viewBox
TOLERANCIA     <- 0.35     # Douglas-Peucker, en unidades del viewBox
AREA_MINIMA    <- 3        # islas más chicas que esto no se dibujan
LONGITUD_OESTE <- -76.5

geo <- jsonlite::fromJSON(ARCHIVO_REGIONES, simplifyVector = FALSE)

mercator <- function(lon, lat) cbind(lon * pi / 180, log(tan(pi / 4 + lat * pi / 360)))

anillos_de <- function(geometria) {
  poligonos <- if (geometria$type == "MultiPolygon") geometria$coordinates else list(geometria$coordinates)
  # Solo el anillo exterior de cada polígono
  lapply(poligonos, function(p) {
    do.call(rbind, lapply(p[[1]], function(punto) c(punto[[1]], punto[[2]])))
  })
}

douglas_peucker <- function(puntos, tolerancia) {
  n <- nrow(puntos)
  if (n < 3) return(puntos)
  conservar <- rep(FALSE, n); conservar[c(1, n)] <- TRUE
  pila <- list(c(1, n))
  while (length(pila) > 0) {
    tramo <- pila[[length(pila)]]; pila[[length(pila)]] <- NULL
    a <- tramo[1]; b <- tramo[2]
    if (b - a < 2) next
    p1 <- puntos[a, ]; p2 <- puntos[b, ]
    medio <- puntos[(a + 1):(b - 1), , drop = FALSE]
    largo <- sqrt(sum((p2 - p1)^2))
    distancia <- if (largo == 0) sqrt(rowSums((medio - matrix(p1, nrow(medio), 2, byrow = TRUE))^2))
                 else abs((p2[1] - p1[1]) * (p1[2] - medio[, 2]) - (p1[1] - medio[, 1]) * (p2[2] - p1[2])) / largo
    if (max(distancia) > tolerancia) {
      k <- a + which.max(distancia)
      conservar[k] <- TRUE
      pila[[length(pila) + 1]] <- c(a, k)
      pila[[length(pila) + 1]] <- c(k, b)
    }
  }
  puntos[conservar, , drop = FALSE]
}

area_de <- function(p) abs(sum(p[, 1] * c(p[-1, 2], p[1, 2]) - c(p[-1, 1], p[1, 1]) * p[, 2])) / 2

# Límites del continente, para escalar todo al viewBox
todos <- list()
for (rasgo in geo$features) {
  for (anillo in anillos_de(rasgo$geometry)) {
    if (min(anillo[, 1]) >= LONGITUD_OESTE) todos[[length(todos) + 1]] <- mercator(anillo[, 1], anillo[, 2])
  }
}
limites <- do.call(rbind, todos)
x0 <- min(limites[, 1]); x1 <- max(limites[, 1])
y0 <- min(limites[, 2]); y1 <- max(limites[, 2])
escala    <- ANCHO_MAPA / (x1 - x0)
ALTO_MAPA <- ceiling((y1 - y0) * escala)
a_pantalla <- function(m) cbind((m[, 1] - x0) * escala, (y1 - m[, 2]) * escala)

codigo_geo <- vapply(geo$features, function(r) as.numeric(r$properties$codregion), numeric(1))
if (!setequal(codigo_geo, REGIONES)) stop("regiones.json no trae las 16 regiones esperadas.", call. = FALSE)

regiones_mapa <- lapply(unname(REGIONES), function(codigo) {
  rasgo   <- geo$features[[which(codigo_geo == codigo)]]
  anillos <- anillos_de(rasgo$geometry)
  anillos <- anillos[vapply(anillos, function(a) min(a[, 1]) >= LONGITUD_OESTE, logical(1))]
  pantalla <- lapply(anillos, function(a) a_pantalla(mercator(a[, 1], a[, 2])))
  areas    <- vapply(pantalla, area_de, numeric(1))
  mayor    <- which.max(areas)
  elegidos <- which(areas >= AREA_MINIMA | seq_along(areas) == mayor)

  trazo <- vapply(elegidos, function(k) {
    p <- douglas_peucker(pantalla[[k]], TOLERANCIA)
    p <- round(p, 1)
    p <- p[c(TRUE, rowSums(abs(diff(p))) > 0), , drop = FALSE]
    if (nrow(p) < 3) return("")
    paste0("M", paste(sprintf("%s %s", p[, 1], p[, 2]), collapse = "L"), "Z")
  }, character(1))

  principal <- pantalla[[mayor]]
  list(cod = codigo, d = paste(trazo[trazo != ""], collapse = ""),
       cx = round(mean(range(principal[, 1])), 1), cy = round(mean(range(principal[, 2])), 1))
})

escribir_js(list(ancho = ANCHO_MAPA, alto = ALTO_MAPA, regiones = regiones_mapa),
            "BD_REGIONES", SALIDA_REGIONES,
            "Contorno simplificado de las 16 regiones de Chile, de norte a sur (proyección de Mercator).")


# =============================================================================
# INFORME
# =============================================================================
cat("\nBases generadas desde ", ARCHIVO_ENCUESTA, "\n", sep = "")
cat("  ", SALIDA_ENCUESTA, ": ", N_TOTAL, " encuestados, ", length(ENFERMEDADES), " enfermedades, ",
    length(REGIONES), " regiones (", round(file.size(SALIDA_ENCUESTA) / 1024), " KB)\n", sep = "")
cat("  ", SALIDA_REGIONES, ": viewBox ", ANCHO_MAPA, " x ", ALTO_MAPA, " (",
    round(file.size(SALIDA_REGIONES) / 1024), " KB)\n", sep = "")
cat("\nEncuestados por enfermedad:\n")
for (enfermedad in ENFERMEDADES) cat(sprintf("  %-4s %4d  (%5.1f %%)\n", enfermedad, por_enfermedad[[enfermedad]]$n, por_enfermedad[[enfermedad]]$prev))
cat("\nEncuestados por región (suma ", sum(vapply(por_region, function(r) r$n, numeric(1))), " de ", N_TOTAL, "):\n", sep = "")
for (i in seq_along(REGIONES)) cat(sprintf("  %-46s %4d\n", names(REGIONES)[i], por_region[[i]]$n))
