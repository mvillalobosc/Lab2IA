# =============================================================================
# genera_corpus_demo.R : corpus sintetico para verificar el pipeline completo.
#   36 libros (3 por nivel, 12 niveles) con complejidad lexica, largo de
#   oracion y carga afectiva graduadas por nivel. Incluye a proposito:
#     1 titulo duplicado con contenido identico en niveles 3 y 6
#     1 fila del catalogo con archivo inexistente (ejercita exclusion)
#     1 libro corto bajo min_palabras (ejercita advertencia)
#   Uso: Rscript demo/genera_corpus_demo.R
# =============================================================================

set.seed(4242)
dir.create("demo/textos", recursive = TRUE, showWarnings = FALSE)

suj_simple <- c("el perro", "la ni\u00f1a", "el gato", "mam\u00e1", "el ni\u00f1o",
                "la abuela", "el p\u00e1jaro", "mi amigo", "la maestra",
                "el conejo")
suj_complejo <- c("el magistrado", "la institucion educativa",
                  "el protagonista atormentado", "la muchedumbre silenciosa",
                  "el investigador meticuloso", "la administracion provincial",
                  "el desconocido enigmatico", "la conciencia colectiva",
                  "el funcionario incorruptible", "la organizacion clandestina")
verbo_simple <- c("corre", "juega", "come", "salta", "canta", "mira", "abraza",
                  "duerme", "sonrie", "ayuda")
verbo_complejo <- c("contempla", "cuestiona", "reconstruye", "administra",
                    "interpreta", "deteriora", "manifiesta", "distorsiona",
                    "encubre", "presencia")
obj_simple <- c("en la casa", "con la pelota", "en el parque",
                "junto al arbol", "con su familia", "en la escuela",
                "bajo el sol", "con alegria y amor", "entre risas",
                "con una sonrisa feliz")
obj_complejo <- c("la decadencia irreversible del imperio",
                  "los documentos confidenciales del proceso",
                  "una transformacion imperceptible y devastadora",
                  "las consecuencias impredecibles del descubrimiento",
                  "la responsabilidad ineludible de sus decisiones",
                  "el desmoronamiento paulatino de sus certezas",
                  "una investigacion interminable y asfixiante",
                  "la burocracia implacable de la administracion",
                  "los recuerdos fragmentados de la guerra",
                  "la enfermedad silenciosa que avanzaba")
pos_pal <- c("alegria", "feliz", "amor", "sonrisa", "fiesta", "abrazo",
             "esperanza", "carino", "juego", "amistad")
neg_pal <- c("muerte", "tristeza", "dolor", "miedo", "guerra", "odio",
             "enfermedad", "angustia", "soledad", "tumba")
conectores <- c("aunque", "mientras", "porque", "cuando", "sin embargo",
                "a pesar de que", "de modo que", "puesto que")

oracion <- function(nivel) {
  w_comp <- (nivel - 1) / 11
  s <- if (stats::runif(1) < w_comp) sample(suj_complejo, 1) else sample(suj_simple, 1)
  v <- if (stats::runif(1) < w_comp) sample(verbo_complejo, 1) else sample(verbo_simple, 1)
  o <- if (stats::runif(1) < w_comp) sample(obj_complejo, 1) else sample(obj_simple, 1)
  frase <- paste(s, v, o)
  # clausula subordinada adicional en niveles altos
  if (stats::runif(1) < w_comp * 0.8) {
    s2 <- if (stats::runif(1) < w_comp) sample(suj_complejo, 1) else sample(suj_simple, 1)
    v2 <- if (stats::runif(1) < w_comp) sample(verbo_complejo, 1) else sample(verbo_simple, 1)
    frase <- paste(frase, sample(conectores, 1), s2, v2,
                   if (stats::runif(1) < w_comp) sample(obj_complejo, 1) else sample(obj_simple, 1))
  }
  # palabra afectiva: alegria baja y tristeza sube con el nivel
  p_neg <- 0.15 + 0.55 * w_comp
  if (stats::runif(1) < 0.5) {
    afect <- if (stats::runif(1) < p_neg) sample(neg_pal, 1) else sample(pos_pal, 1)
    frase <- paste0(frase, ", con ", afect)
  }
  paste0(toupper(substr(frase, 1, 1)), substr(frase, 2, nchar(frase)), ".")
}

libro <- function(nivel, n_palabras_obj) {
  out <- character(0); n <- 0
  while (n < n_palabras_obj) {
    par <- paste(replicate(sample(4:7, 1), oracion(nivel)), collapse = " ")
    out <- c(out, par)
    n <- n + stringi::stri_count_regex(par, "\\S+")
  }
  paste(out, collapse = "\n\n")
}

titulos <- c(
  "El perro saltarin", "La fiesta del bosque", "Mi amiga la luna",
  "El gato con botas rojas", "La cenicienta", "Un dia en la granja",
  "El tesoro del rio", "Las aventuras de Tomas", "La casa de chocolate",
  "El viaje de la tortuga", "Cuentos del valle", "La cenicienta",
  "El misterio del faro", "Cartas desde el sur", "La sombra del roble",
  "El ultimo verano", "Diario de un explorador", "La ciudad dormida",
  "El pacto de los hermanos", "Memorias del puerto", "La travesia",
  "El laberinto de piedra", "Cronica de una espera", "Los dias contados",
  "La condena del silencio", "El proceso interminable", "Ruinas y ceniza",
  "La peste del olvido", "El extranjero de la colina", "Bajo el volcan gris",
  "La agonia del imperio", "El tunel sin salida", "Los desterrados",
  "La nausea del tiempo", "El castillo de niebla", "Informe sobre ciegos")

niveles <- rep(1:12, each = 3)
cursos <- ifelse(niveles <= 8, paste0(niveles, "\u00b0 B\u00e1sico"),
                 paste0(niveles - 8, "\u00b0 Medio"))

filas <- list()
for (i in seq_along(titulos)) {
  nv <- niveles[i]
  archivo <- paste0(sprintf("%02d", i), "_",
                    gsub(" ", "_", tolower(titulos[i])), ".txt")
  n_obj <- 1200 + 140 * nv + sample(0:300, 1)
  if (i == 7) n_obj <- 180   # libro corto a proposito: dispara advertencia
  txt <- libro(nv, n_obj)
  # duplicado exacto: "La cenicienta" del nivel 3 (i = 5) se copia al 6 (i = 12)
  if (i == 12) txt <- readLines("demo/textos/05_la_cenicienta.txt",
                                warn = FALSE) |> paste(collapse = "\n")
  writeLines(txt, file.path("demo/textos", archivo), useBytes = TRUE)
  filas[[i]] <- data.frame(Titulo = titulos[i], Archivo = archivo,
                           Curso = cursos[i])
}
# fila con archivo inexistente: ejercita la exclusion justificada
filas[[length(filas) + 1]] <- data.frame(Titulo = "Libro fantasma",
                                         Archivo = "no_existe.txt",
                                         Curso = "5\u00b0 B\u00e1sico")
catalogo <- do.call(rbind, filas)
writexl::write_xlsx(catalogo, "demo/catalogo_demo.xlsx")
cat("Corpus demo generado:", nrow(catalogo), "filas de catalogo,",
    length(list.files("demo/textos")), "archivos de texto\n")
