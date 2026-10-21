# =============================================================================
# 10_bib.R
# Genera references.bib para el manuscrito. Lee las claves citadas en
# el manuscrito (.tex): las claves R##### corresponden a registros de la base de la
# revisión y se construyen con sus metadatos de Scopus y Web of Science (autores,
# título, fuente, año, volumen, número, páginas y DOI); las demás claves son
# referencias de contexto verificadas a mano (references/classics.bib). Los
# acentos se escriben con escapes de LaTeX y las palabras que deben conservar
# mayúsculas (siglas, nombres propios) se protegen con llaves, porque el estilo
# elsarticle-num pasa los títulos a minúsculas.
#
# Entradas
#   paper/main.tex                        manuscrito (o el .tex que se pase como argumento)
#   data/processed/db_final_all.csv       metadatos de todos los registros únicos
#   data/processed/db_included_coded.csv  identificadores de los estudios incluidos
#   references/classics.bib               referencias de contexto, que se copian tal cual
# Salida
#   references.bib, en la misma carpeta del manuscrito
# =============================================================================
# El locale C.UTF-8 hace que R trate como UTF-8 el manuscrito y los títulos con acentos o
# símbolos, igual en cualquier sistema.
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
# readr lee las bases en CSV, dplyr filtra los registros citados y stringr hace el trabajo
# con texto (claves, títulos, autores y fuentes).
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr) })
# Se ejecuta desde la carpeta raíz del repositorio, por ejemplo: Rscript R/10_bib.R

# ---- Claves citadas en el manuscrito --------------------------------------------------
# Ruta del manuscrito (.tex) como argumento; references.bib se escribe en la misma carpeta.
# Ejemplo: Rscript R/10_bib.R ../paper/main.tex
# commandArgs(trailingOnly = TRUE) entrega solo los argumentos escritos después del nombre
# del script. Sin argumento, el script busca el manuscrito en paper/main.tex.
args <- commandArgs(trailingOnly = TRUE)
tex_file <- if (length(args)) args[1] else "paper/main.tex"
# readLines() lee el manuscrito línea a línea y encoding = "UTF-8" marca el texto como
# UTF-8; warn = FALSE evita el aviso cuando la última línea no termina en salto de línea.
tex <- readLines(tex_file, encoding = "UTF-8", warn = FALSE)
# El script une todas las líneas con espacios, así que también lee un \cite que se corta
# entre dos líneas. La expresión \\cite\{([^}]*)\} busca cada \cite{...} y captura lo que
# va entre las llaves, porque [^}]* toma todo hasta la primera llave de cierre. Cada
# captura se separa por comas, ya que un \cite puede traer varias claves, y unique() deja
# una vez cada clave. La expresión reconoce solo la forma \cite{...}, así que no lee
# \citep{...} ni \cite[p. 3]{...}, y también cuenta los \cite que estén dentro de un
# comentario de LaTeX (%).
keys <- unique(unlist(str_split(unlist(str_match_all(paste(tex, collapse = " "), "\\\\cite\\{([^}]*)\\}")[[1]][, 2]), ",")))
# str_trim() quita los espacios que quedan cuando las claves se escriben con un espacio
# después de la coma, como en \cite{a, b}.
keys <- str_trim(keys)
# Las claves con forma R más cinco dígitos (^R[0-9]{5}$) son registros de la base de la
# revisión; las demás deben estar en references/classics.bib.
db_keys <- keys[str_detect(keys, "^R[0-9]{5}$")]
# allr tiene los metadatos de todos los registros únicos de la búsqueda, también de los
# excluidos, porque el manuscrito puede citar un registro que no entró a la revisión.
allr <- read_csv("data/processed/db_final_all.csv", show_col_types = FALSE, guess_max = 10000)
# Web of Science registra ACOPHY (R07427) con el título del volumen (Swarm
# Intelligence) en lugar de la serie; se usa la serie, como en los demás volúmenes
# de Lecture Notes in Computer Science.
allr$journal[allr$id == "R07427"] <- "Lecture Notes in Computer Science"
# El script se detiene si alguna clave R##### citada no existe en la base, por ejemplo por
# una errata en el manuscrito.
stopifnot(all(db_keys %in% allr$id))
# inc_ids guarda los identificadores de los estudios incluidos, que solo usa el mensaje
# siguiente.
inc_ids <- read_csv("data/processed/db_included_coded.csv", show_col_types = FALSE, guess_max = 10000)$id
# El mensaje informa cuántas claves cita el manuscrito, cuántas vienen de la base y
# cuántas de esas no son estudios incluidos.
cat("Claves citadas:", length(keys), " de la base:", length(db_keys), " (no incluidas:", sum(!db_keys %in% inc_ids), ")\n")

# ---- Escapes de LaTeX -------------------------------------------------------------
# El BibTeX clásico trabaja byte a byte y no reconoce los caracteres UTF-8, así que acc
# cambia cada letra acentuada por su comando de LaTeX, siempre entre llaves (á pasa a
# {\'a}). BibTeX reconoce un grupo entre llaves que empieza con barra invertida como un
# solo carácter especial, de modo que el acento y su letra no se separan cuando BibTeX
# abrevia nombres o cambia mayúsculas. La í y sus variantes usan \i, la i sin punto, para
# que el acento no quede encima del punto.
acc <- c("á" = "{\\'a}", "à" = "{\\`a}", "â" = "{\\^a}", "ä" = "{\\\"a}", "ã" = "{\\~a}", "å" = "{\\aa}",
         "é" = "{\\'e}", "è" = "{\\`e}", "ê" = "{\\^e}", "ë" = "{\\\"e}", "í" = "{\\'\\i}", "ì" = "{\\`\\i}",
         "î" = "{\\^\\i}", "ï" = "{\\\"\\i}", "ó" = "{\\'o}", "ò" = "{\\`o}", "ô" = "{\\^o}", "ö" = "{\\\"o}",
         "õ" = "{\\~o}", "ø" = "{\\o}", "ú" = "{\\'u}", "ù" = "{\\`u}", "û" = "{\\^u}", "ü" = "{\\\"u}",
         "ñ" = "{\\~n}", "ç" = "{\\c{c}}", "ć" = "{\\'c}", "č" = "{\\v{c}}", "ř" = "{\\v{r}}", "š" = "{\\v{s}}",
         "ž" = "{\\v{z}}", "ý" = "{\\'y}", "ÿ" = "{\\\"y}", "ł" = "{\\l}", "ő" = "{\\H{o}}", "ű" = "{\\H{u}}",
         "ğ" = "{\\u{g}}", "ş" = "{\\c{s}}", "ı" = "{\\i}", "ą" = "{\\k{a}}", "ę" = "{\\k{e}}", "ń" = "{\\'n}",
         "ś" = "{\\'s}", "ź" = "{\\'z}", "ż" = "{\\.z}", "ě" = "{\\v{e}}", "ň" = "{\\v{n}}", "ť" = "{\\v{t}}",
         "ď" = "{\\v{d}}", "ă" = "{\\u{a}}", "Ă" = "{\\u{A}}", "ș" = "{\\c{s}}", "ț" = "{\\c{t}}", "ā" = "{\\=a}", "ō" = "{\\=o}", "ū" = "{\\=u}", "ē" = "{\\=e}", "ů" = "{\\r{u}}", "ß" = "{\\ss}", "æ" = "{\\ae}", "œ" = "{\\oe}",
         "Á" = "{\\'A}", "À" = "{\\`A}", "Â" = "{\\^A}", "Ä" = "{\\\"A}", "Å" = "{\\AA}", "É" = "{\\'E}",
         "È" = "{\\`E}", "Í" = "{\\'I}", "Ó" = "{\\'O}", "Ö" = "{\\\"O}", "Ø" = "{\\O}", "Ú" = "{\\'U}",
         "Ü" = "{\\\"U}", "Ñ" = "{\\~N}", "Ç" = "{\\c{C}}", "Č" = "{\\v{C}}", "Ř" = "{\\v{R}}", "Š" = "{\\v{S}}",
         "Ž" = "{\\v{Z}}", "Ł" = "{\\L}", "Ś" = "{\\'S}", "Æ" = "{\\AE}")
# sym reemplaza los símbolos tipográficos y griegos que traen los títulos de Scopus y Web
# of Science. La semirraya (U+2013) y la raya (U+2014) pasan a --, el signo menos y los
# guiones Unicode (U+2212, U+2010, U+2011) pasan a un guion simple, y las comillas curvas
# y los apóstrofos Unicode pasan a las comillas de LaTeX (` ' `` ''). Las letras griegas
# y los signos matemáticos van en modo matemático, y la virgulilla ~ se escribe $\sim$
# porque en LaTeX es un espacio que no se corta. El espacio duro (U+00A0) pasa a espacio
# normal. El menos en círculo (U+2296) pasa a $\Theta$ porque un título de la base
# escribe así la theta de la notación asintótica ("A ⊖(n) speed-up"). Los comandos sin
# argumento terminan en {} para que LaTeX no se coma el espacio que los sigue.
sym <- c("–" = "--", "—" = "--", "−" = "-", "‐" = "-", "‑" = "-", "’" = "'", "‘" = "`", "“" = "``", "”" = "''",
         "Ω" = "$\\Omega$", "⊖" = "$\\Theta$", "Θ" = "$\\Theta$", "ℓ" = "$\\ell$", "μ" = "$\\mu$", "µ" = "$\\mu$",
         "×" = "$\\times$", "≥" = "$\\geq$", "≤" = "$\\leq$", "⋯" = "$\\cdots$", "…" = "\\ldots{}",
         "α" = "$\\alpha$", "β" = "$\\beta$", "γ" = "$\\gamma$", "λ" = "$\\lambda$", "π" = "$\\pi$",
         "σ" = "$\\sigma$", "χ" = "$\\chi$", "φ" = "$\\phi$", "ε" = "$\\epsilon$", "δ" = "$\\delta$",
         "Δ" = "$\\Delta$", "∼" = "$\\sim$", "~" = "$\\sim$", "→" = "$\\rightarrow$", "®" = "\\textregistered{}",
         "™" = "\\texttrademark{}", "°" = "$^\\circ$", "²" = "$^2$", "₁" = "$_1$", " " = " ", "′" = "'", "ʼ" = "'")
# escape_tex() deja un texto listo para BibTeX. Primero antepone una barra a &, %, # y _,
# que son caracteres especiales en LaTeX. Después aplica sym y acc con fixed(), que busca
# el carácter literal en vez de leerlo como expresión regular. Si aún queda algún
# carácter fuera de ASCII, el script avisa cuáles son y los translitera con iconv()
# (ASCII//TRANSLIT); sub = "" descarta los que no tienen equivalente.
escape_tex <- function(x) {
  if (is.na(x)) return(x)
  # En el reemplazo, "\\\\\\1" produce una barra literal seguida del carácter capturado.
  x <- str_replace_all(x, "([&%#_])", "\\\\\\1")
  for (k in names(sym)) x <- str_replace_all(x, fixed(k), sym[[k]])
  for (k in names(acc)) x <- str_replace_all(x, fixed(k), acc[[k]])
  # [^\x01-\x7f] encuentra cualquier carácter fuera del rango ASCII (códigos 1 a 127).
  if (str_detect(x, "[^\\x01-\\x7f]")) {
    bad <- unique(str_extract_all(x, "[^\\x01-\\x7f]")[[1]])
    message("Caracteres transliterados: ", paste(bad, collapse = " "))
    x <- iconv(x, "UTF-8", "ASCII//TRANSLIT", sub = "")
  }
  x
}

# ---- Protección de mayúsculas en títulos ----------------------------------------------
# elsarticle-num pasa a minúsculas todo el título salvo la primera letra, la primera letra
# después de dos puntos y lo que va entre llaves. Esta sección decide qué palabras de cada
# título van entre llaves para que conserven sus mayúsculas, como las siglas (DNA, MCMC),
# los nombres de programas con mayúsculas internas (RAxML, PhyML) y los nombres propios
# (Bayesian, Robinson).
# words_of() separa un título en palabras por cualquier secuencia de espacios (\s+).
words_of <- function(t) str_split(t, "\\s+")[[1]]
# is_title_case() decide si un título viene en Title Case, con mayúscula inicial en casi
# todas las palabras. Mira las palabras desde la segunda, porque la primera siempre va con
# mayúscula, y solo las de cuatro letras o más, porque las palabras cortas (of, and, the)
# van en minúsculas incluso en Title Case. Si al menos el 60 % de esas palabras empieza
# con mayúscula, el título está en Title Case. La expresión ^[^A-Za-z]*[A-Z] admite
# signos antes de la primera letra, como un paréntesis o una comilla.
is_title_case <- function(t) {
  w <- words_of(t)[-1]; w <- w[nchar(str_replace_all(w, "[^A-Za-z]", "")) >= 4]
  length(w) > 0 && mean(str_detect(w, "^[^A-Za-z]*[A-Z]")) >= 0.6
}
# is_upper() indica si un texto viene casi entero en mayúsculas. Deja solo las letras y
# exige que más del 80 % sean mayúsculas. Así vienen los nombres de revista de Web of
# Science y unos pocos títulos.
is_upper <- function(t) { l <- str_replace_all(t, "[^A-Za-z]", ""); nchar(l) > 0 && mean(str_detect(str_split(l, "")[[1]], "[A-Z]")) > 0.8 }
# Nombres propios: palabras que en los títulos de toda la base aparecen con mayúscula
# inicial fuera de la primera posición y casi nunca en minúsculas (p. ej. Bayesian,
# Markov, Robinson); las palabras comunes aparecen a menudo en minúsculas.
# tt reúne los títulos de toda la base, no solo los citados, para tener más apariciones de
# cada palabra, y descarta los títulos en mayúsculas, que no dicen nada sobre qué palabras
# son nombres propios.
tt <- allr$title[!is.na(allr$title)]
tt <- tt[!sapply(tt, is_upper)]
# tok junta las palabras de todos los títulos, sin la primera de cada uno, que siempre va
# con mayúscula. Cada palabra queda solo con letras (incluidas las acentuadas del rango
# À-ÿ) y guiones, se corta en sus partes por los guiones (Robinson-Foulds da Robinson y
# Foulds) y pierde las partes de una sola letra.
tok <- unlist(lapply(tt, function(t) { w <- unlist(str_split(str_replace_all(words_of(t)[-1], "[^A-Za-zÀ-ÿ-]", ""), "-")); w[nchar(w) > 1] }))
# key es la forma en minúsculas de cada palabra, para contar juntas sus apariciones.
key <- str_to_lower(tok)
# capn cuenta cuántas veces aparece cada palabra con mayúscula inicial y lown cuántas veces
# aparece en minúscula. Los rangos À-Þ y ß-ÿ son las mayúsculas y minúsculas acentuadas de
# Latin-1.
capn <- tapply(str_detect(tok, "^[A-ZÀ-Þ]"), key, sum); lown <- tapply(str_detect(tok, "^[a-zß-ÿ]"), key, sum)
# Una palabra cuenta como nombre propio si nunca aparece en minúscula, o si aparece al
# menos tres veces con mayúscula y lo hace en el 90 % de los casos o más. Una palabra rara
# que solo aparece en títulos en Title Case también entra; protegerla solo conserva la
# mayúscula que ya traía el título.
prop_key <- names(capn)[(capn >= 1 & lown == 0) | (capn >= 3 & capn / (capn + lown) >= 0.9)]
# proper guarda esas palabras con su mayúscula inicial, tal como aparecen en los títulos.
proper <- unique(tok[key %in% prop_key & str_detect(tok, "^[A-ZÀ-Þ]")])
# Nombres propios frecuentes en el área que también aparecen en minúsculas en algunos títulos
proper <- union(proper, c("Robinson", "Foulds", "Bayesian", "Markov", "Monte", "Carlo", "Gibbs", "Metropolis", "Hastings",
  "Fitch", "Sankoff", "Wagner", "Hamming", "Jaccard", "Steiner", "Dollo", "Camin", "Sokal", "Euclidean", "Laplacian",
  "Pareto", "Fréchet", "Fermat", "Weber", "Billera", "Holmes", "Vogtmann", "Kingman", "Yule", "Dirichlet", "Poisson",
  "Gaussian", "Brownian", "Ornstein", "Uhlenbeck", "Jukes", "Cantor", "Kimura", "Felsenstein", "Hennig", "Hennigian",
  "Darwin", "Darwinian", "Mendelian", "Boolean", "Manhattan", "Prüfer", "Newick", "Nexus", "Cavender", "Farris", "Neyman",
  "Shannon", "Kullback", "Leibler", "Wasserstein", "Hasse", "Python", "Julia", "Java", "Spark", "Apache", "Indo", "European"))
# acronyms lista siglas y nombres de programas con su escritura correcta. fix_title() la
# usa para recuperar esa escritura en los títulos que vienen enteros en mayúsculas,
# después de pasarlos a minúsculas.
acronyms <- c("DNA", "RNA", "MCMC", "NSGA-II", "SPR", "TBR", "NNI", "ML", "MP", "RF", "BHV", "SNP", "SNPs", "GPU", "FPGA",
              "MPI", "HGT", "ILS", "ASTRAL", "BEAST", "RAxML", "IQ-TREE", "PhyML", "TNT", "PAUP", "MSA", "UPGMA", "NJ", "MRP")
# protect_word() decide si una palabra va entre llaves y, si corresponde, la envuelve.
# core es la palabra sin puntuación (quedan letras, dígitos y guiones) y parts son sus
# partes separadas por guiones. La palabra se protege si cumple alguna de estas reglas.
#   has_inner   tiene una mayúscula después de una minúscula o un dígito (RAxML, PhyML,
#               3D) o mezcla mayúsculas con dígitos (NSGA2, K2P).
#   all_caps    alguna parte tiene dos letras o más y ninguna minúscula (DNA, NSGA-II).
#   sentence    en un título en minúsculas, la palabra empieza con mayúscula, porque fuera
#               de la primera palabra eso marca un nombre propio o una sigla.
#   title       en un título en Title Case, alguna parte con mayúscula inicial está en
#               proper, porque ahí todas las palabras empiezan con mayúscula y solo los
#               nombres propios deben conservarla.
protect_word <- function(w, mode) {
  core <- str_replace_all(w, "[^A-Za-z0-9À-ÿ-]", "")
  if (core == "") return(w)
  parts <- str_split(core, "-")[[1]]
  has_inner <- any(str_detect(parts, "[a-z0-9][A-Z]")) || (str_detect(core, "[A-Z]") && str_detect(core, "[0-9]"))
  all_caps <- any(nchar(str_replace_all(parts, "[^A-Za-z]", "")) >= 2 & !str_detect(parts, "[a-z]"))
  starts_cap <- str_detect(core, "^[A-Z]")
  prot <- has_inner || all_caps ||
    (mode == "sentence" && starts_cap) ||
    (mode == "title" && any(parts[str_detect(parts, "^[A-ZÀ-Þ]")] %in% proper))
  if (!prot) return(w)
  # La expresión separa la palabra en signos iniciales, núcleo y signos finales; el .*? del
  # medio es perezoso, así que los signos finales quedan en el tercer grupo. Las llaves
  # envuelven solo el núcleo, de modo que "(RAxML)," queda "({RAxML}),".
  m <- str_match(w, "^([^A-Za-z0-9À-ÿ]*)(.*?)([^A-Za-z0-9À-ÿ]*)$")
  paste0(m[2], "{", m[3], "}", m[4])
}
# wl lista nombres propios del área con su escritura correcta. restore_case() la usa para
# devolverles la mayúscula en cualquier título (bayesian pasa a Bayesian) antes de decidir
# qué palabras se protegen.
wl <- c("Robinson", "Foulds", "Bayesian", "Markov", "Monte", "Carlo", "Gibbs", "Metropolis", "Hastings", "Fitch", "Sankoff",
        "Wagner", "Hamming", "Jaccard", "Steiner", "Dollo", "Euclidean", "Laplacian", "Pareto", "Billera", "Holmes", "Vogtmann",
        "Kingman", "Yule", "Dirichlet", "Poisson", "Gaussian", "Brownian", "Jukes", "Cantor", "Kimura", "Felsenstein", "Hennigian",
        "Darwinian", "Mendelian", "Boolean", "Manhattan", "Newick")
# restore_case() revisa cada parte de una palabra con guiones. Si la parte, sin signos y en
# minúsculas, coincide con un nombre de wl, la reemplaza por la escritura de wl; así
# "robinson-foulds" queda "Robinson-Foulds" y "bayesian," queda "Bayesian,".
restore_case <- function(w) {
  parts <- str_split(w, "-")[[1]]
  hit <- match(str_to_lower(str_replace_all(parts, "[^A-Za-z]", "")), str_to_lower(wl))
  if (all(is.na(hit))) return(w)
  for (k in which(!is.na(hit))) parts[k] <- str_replace(parts[k], regex(wl[hit[k]], ignore_case = TRUE), wl[hit[k]])
  paste(parts, collapse = "-")
}
# fix_title() prepara el título de cada entrada en cinco pasos.
fix_title <- function(t) {
  # (1) Pasa a mayúsculas los números romanos i, ii, iii e iv que van justo antes de dos
  # puntos ("part ii:" queda "part II:"). \b exige que el número empiece en un borde de
  # palabra y (?=:) revisa que siga un dos puntos sin incluirlo en la coincidencia.
  t <- str_replace_all(t, "\\b(i|ii|iii|iv)(?=:)", function(x) toupper(x))
  # (2) Devuelve la mayúscula a los nombres propios de wl en cada palabra.
  t <- paste(sapply(words_of(t), restore_case), collapse = " ")
  # (3) Si el título sigue casi entero en mayúsculas, lo pasa a minúsculas, deja en
  # mayúscula la primera letra y recupera la escritura de las siglas de acronyms (raxml
  # vuelve a RAxML).
  if (is_upper(t)) {
    t <- str_to_lower(t); substr(t, 1, 1) <- toupper(substr(t, 1, 1))
    w <- words_of(t)
    # up es la palabra sin signos (quedan letras, dígitos y guiones) en mayúsculas; si
    # coincide con una sigla, el reemplazo usa la escritura de acronyms.
    w <- sapply(w, function(x) { up <- toupper(str_replace_all(x, "[^A-Za-z0-9-]", "")); if (up %in% toupper(acronyms)) str_replace(x, regex(up, ignore_case = TRUE), acronyms[toupper(acronyms) == up][1]) else x })
    t <- paste(w, collapse = " ")
  }
  # (4) Decide si el título está en Title Case o en minúsculas (sentence case), porque las
  # reglas de protección cambian entre uno y otro.
  mode <- if (is_title_case(t)) "title" else "sentence"
  # (5) Protege las palabras. La primera no necesita llaves para su inicial, porque el
  # estilo conserva la primera letra del título. Solo pasa por protect_word(), con las
  # reglas de Title Case, si tiene una mayúscula después de su primera letra (^.+[A-Z],
  # como RAxML) o si empieza con dos mayúsculas o más (^[A-Z]{2,}, como DNA).
  w <- words_of(t)
  first <- w[1]
  w <- c(if (str_detect(str_replace_all(first, "[^A-Za-z0-9]", ""), "^.+[A-Z]|^[A-Z]{2,}")) protect_word(first, "title") else first,
         sapply(w[-1], protect_word, mode = mode))
  # str_squish() quita los espacios repetidos y los de los extremos.
  str_squish(paste(w, collapse = " "))
}

# ---- Autores ---------------------------------------------------------------------------
# fmt_author() escribe un autor como "Apellido, Iniciales", la forma que BibTeX separa sin
# ambigüedad. Web of Science entrega "Gernandt, DS", y en ese caso el código corta en la
# primera coma. Scopus entrega "Matasci N." o "Teixeira L.H.", sin coma.
fmt_author <- function(a) {
  a <- str_trim(a)
  if (str_detect(a, ",")) {
    p <- str_split_fixed(a, ",", 2); last <- str_trim(p[1]); ini <- str_trim(p[2])
    # Si las iniciales vienen pegadas y sin puntos (DS), les agrega punto y espacio (D. S.).
    if (str_detect(ini, "^[A-Z]+$")) ini <- paste0(str_split(ini, "")[[1]], ".", collapse = " ")
  } else {
    # La expresión ^(.*?)\s+((?:[A-Z][a-zA-Z]?\.-?\s?)+)$ toma como iniciales el bloque
    # final de letras con punto, cada una con una mayúscula, a veces seguida de otra letra
    # (Ch.) o de un guion (J.-P.), y deja el resto como apellido.
    m <- str_match(a, "^(.*?)\\s+((?:[A-Z][a-zA-Z]?\\.-?\\s?)+)$")
    # Si el nombre no calza con esa forma, va entero entre llaves para que BibTeX no lo
    # divida en nombre y apellido.
    if (is.na(m[1])) return(paste0("{", a, "}"))
    last <- str_trim(m[2]); ini <- str_trim(m[3])
    # \.(?=[A-Z]) agrega un espacio después de cada punto seguido de otra inicial, así que
    # L.H. queda L. H.
    ini <- str_replace_all(ini, "\\.(?=[A-Z])", ". ")
  }
  paste0(last, ", ", ini)
}
# fmt_authors() separa la lista de autores por ";", que usan las dos bases, descarta los
# vacíos, formatea cada autor y los une con " and ", el separador de autores de BibTeX.
fmt_authors <- function(s) {
  v <- str_trim(str_split(s, ";")[[1]]); v <- v[v != ""]
  paste(sapply(v, fmt_author), collapse = " and ")
}

# ---- Fuentes -------------------------------------------------------------------------
# small son las palabras que van en minúsculas dentro del nombre de una revista, salvo al
# comienzo, y upper_words son las siglas que deben quedar en mayúsculas (IEEE, BMC, PLOS).
small <- c("of", "and", "in", "on", "the", "for", "to", "a", "an", "at", "by", "with", "from", "de", "y")
upper_words <- c("IEEE", "ACM", "SIAM", "BMC", "PLOS", "PNAS", "DNA", "RNA", "USA", "ONE", "II", "III", "IV", "LNCS", "IFIP", "AIP", "SPIE", "WABI", "RECOMB", "LIPICS")
# fix_source() limpia el nombre de la revista o de las actas. Primero quita la coletilla
# "(including subseries ...)" que Scopus agrega a Lecture Notes in Computer Science;
# [^)]* toma todo hasta el paréntesis de cierre. Si el nombre viene en mayúsculas, como lo
# escribe Web of Science (MOLECULAR BIOLOGY AND EVOLUTION), lo pasa a Title Case.
fix_source <- function(j) {
  if (is.na(j)) return(j)
  j <- str_trim(str_replace(j, "\\s*\\(including subseries[^)]*\\)", ""))
  if (is_upper(j)) {
    # Cada palabra empieza con mayúscula, salvo las de small fuera de la primera posición;
    # las siglas de upper_words quedan en mayúsculas y las palabras con barra (IEEE/ACM) se
    # revisan parte por parte.
    w <- str_split(str_to_lower(j), "\\s+")[[1]]
    w <- sapply(seq_along(w), function(i) {
      # core es la palabra solo con letras, en mayúsculas, para compararla con upper_words.
      x <- w[i]; core <- toupper(str_replace_all(x, "[^a-z]", ""))
      if (core %in% upper_words) return(toupper(x))
      if (str_detect(x, "/")) return(paste(sapply(str_split(x, "/")[[1]], function(y) if (toupper(y) %in% upper_words) toupper(y) else str_to_title(y)), collapse = "/"))
      if (i > 1 && x %in% small) return(x)
      str_to_title(x)
    })
    j <- paste(w, collapse = " ")
  }
  j
}

# ---- Entradas de la base ---------------------------------------------------------------
# d tiene solo los registros de la base que cita el manuscrito.
d <- allr %>% filter(id %in% db_keys)
# Los registros de congreso publicados en revistas (por ejemplo, los números de ISMB
# en Bioinformatics) se escriben como artículos, y en las actas se omite el número
# (en Lecture Notes corresponde a la parte del volumen). Web of Science marca con
# "+" las páginas finales desconocidas, y los volúmenes de algunas series traen un
# sufijo en mayúsculas (LNCS, LNNS) que se elimina.
# proc_pat reconoce, sin distinguir mayúsculas, los nombres de fuente que corresponden a
# actas o series de congresos.
proc_pat <- regex("Lecture Notes|Proceedings|Conference|Symposium|Workshop|Congress|LIPIcs|Series", ignore_case = TRUE)
# entry() arma el texto de una entrada BibTeX a partir de una fila de la base.
entry <- function(r) {
  # Un registro es de congreso si su tipo de documento dice Conference o Proceedings
  # (Scopus usa "Conference paper" y Web of Science "Proceedings Paper"). Si además trae
  # número y su fuente no parece de actas, se publicó en una revista y va como artículo.
  conf <- str_detect(coalesce(r$doctype, ""), "Conference|Proceedings")
  if (conf && !is.na(r$issue) && r$issue != "NA" && !str_detect(coalesce(r$journal, ""), proc_pat)) conf <- FALSE
  # pages quita los "NA" de las páginas faltantes ("NA-NA") y el "+" con que Web of
  # Science marca una página final desconocida; -?\+$ toma ese + y el guion que lo
  # precede, así que "151-+" queda "151".
  pages <- str_replace(str_replace_all(coalesce(r$pages, ""), "NA", ""), "-?\\+$", "")
  # Si no quedan páginas, el campo usa el número de artículo (artno, como e16162). Si
  # quedan, el código borra un guion final suelto y cambia el guion del rango por --, que
  # LaTeX imprime como semirraya.
  pages <- if (pages %in% c("", "-")) coalesce(r$artno, "") else str_replace(str_replace(pages, "-$", ""), "-", "--")
  # f es un vector con nombre, donde cada nombre es un campo de BibTeX. El título pasa
  # primero por fix_title() y después por escape_tex(), así que los acentos de una palabra
  # protegida quedan dentro de sus llaves.
  f <- c(author = escape_tex(fmt_authors(r$authors)), title = escape_tex(fix_title(r$title)))
  # Las actas llevan el nombre de la fuente en booktitle y los artículos, en journal.
  if (conf) f["booktitle"] <- escape_tex(fix_source(r$journal)) else f["journal"] <- escape_tex(fix_source(r$journal))
  # El año pasa a texto, como los demás campos.
  f["year"] <- as.character(r$year)
  # El volumen pierde el sufijo de serie en mayúsculas que traen algunas actas, con lo que
  # venga después. La expresión \s+[A-Z]{2,}\b.*$ quita desde el primer espacio seguido de
  # dos o más mayúsculas, así que "3701 LNCS" y "3992 LNCS - II" quedan "3701" y "3992".
  if (!is.na(r$volume) && r$volume != "NA") f["volume"] <- str_trim(str_replace(r$volume, "\\s+[A-Z]{2,}\\b.*$", ""))
  # El número (issue) solo va en los artículos, porque en las actas de Lecture Notes
  # corresponde a la parte del volumen.
  if (!conf && !is.na(r$issue) && r$issue != "NA") f["number"] <- r$issue
  # Las páginas entran si quedó algo distinto de vacío o NA.
  if (pages != "" && pages != "NA") f["pages"] <- pages
  # El DOI se guarda sin el prefijo https://doi.org/ o http://dx.doi.org/, si lo trae.
  if (!is.na(r$doi)) f["doi"] <- str_replace(r$doi, "^https?://(dx\\.)?doi\\.org/", "")
  # Cada campo va en su línea con dos espacios de sangría. %-9s rellena el nombre del campo
  # hasta nueve caracteres, el largo de booktitle, para alinear los signos =.
  body <- paste(sprintf("  %-9s = {%s}", names(f), f), collapse = ",\n")
  # La entrada es @article o @inproceedings y su clave es el identificador R##### del
  # registro, la misma que cita el manuscrito. El \n final deja una línea en blanco entre
  # entradas, porque writeLines() agrega otro salto.
  sprintf("@%s{%s,\n%s\n}\n", if (conf) "inproceedings" else "article", r$id, body)
}
# out tiene una entrada por cada registro citado de la base.
out <- sapply(seq_len(nrow(d)), function(i) entry(d[i, ]))
# classics.bib trae las referencias de contexto verificadas a mano, que el script copia sin
# cambios.
classic <- readLines("references/classics.bib", encoding = "UTF-8", warn = FALSE)
# ^@\w+\{([^,]+), lee la clave de cada entrada, es decir, lo que va entre la llave de
# apertura y la primera coma. Las líneas que no abren una entrada dan NA y se descartan.
cl_keys <- str_match(classic, "^@\\w+\\{([^,]+),")[, 2]; cl_keys <- cl_keys[!is.na(cl_keys)]
# Toda clave citada que no sea R##### debe existir en classics.bib; si falta alguna, el
# script se detiene y la nombra.
missing <- setdiff(keys[!str_detect(keys, "^R[0-9]{5}$")], cl_keys)
if (length(missing)) stop("Claves sin entrada: ", paste(missing, collapse = ", "))
# references.bib queda con las referencias de contexto primero, una línea en blanco y
# después las entradas de la base. El script copia todas las entradas de classics.bib,
# aunque el manuscrito no las cite, y BibTeX solo imprime las citadas. useBytes = TRUE
# escribe el texto tal como está, sin volver a codificarlo.
writeLines(c(classic, "", out), file.path(dirname(tex_file), "references.bib"), useBytes = TRUE)
# El mensaje final informa cuántas entradas salieron de la base y cuántas de classics.bib.
cat("references.bib:", length(out), "entradas de la base +", length(cl_keys), "de contexto\n")
