# =============================================================================
# utils.R : funciones de soporte. Todas las metricas implementadas aca tienen
# tests en tests/test_metricas.R que se ejecutan al inicio de run_all.R.
# =============================================================================

suppressPackageStartupMessages({
  library(stringi); library(dplyr); library(tidyr); library(data.table)
})

# letras del espanol con escapes unicode para ser independientes del locale
.LMIN <- "a-z\u00e1\u00e9\u00ed\u00f3\u00fa\u00fc\u00f1"
.LMAY <- "A-Z\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1"
.RE_LETRA <- paste0("[", .LMIN, .LMAY, "]")

# --------------------------------------------------------------------------- #
# Logging y registro de exclusiones
# --------------------------------------------------------------------------- #
log_msg <- function(...) {
  msg <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", paste0(...))
  cat(msg, "\n")
  ruta <- file.path(config$carpeta_salida, "logs", "pipeline.log")
  if (dir.exists(dirname(ruta))) cat(msg, "\n", file = ruta, append = TRUE)
  invisible(NULL)
}

registrar_exclusion <- function(modulo, id_libro, titulo, motivo, valor = NA) {
  ruta <- file.path(config$carpeta_salida, "logs", "log_exclusiones.csv")
  fila <- data.frame(fecha = as.character(Sys.time()), modulo = modulo,
                     id_libro = id_libro, titulo = titulo, motivo = motivo,
                     valor = as.character(valor))
  write.table(fila, ruta, sep = ",", row.names = FALSE, append = file.exists(ruta),
              col.names = !file.exists(ruta))
  log_msg("EXCLUSION [", modulo, "] ", titulo, " : ", motivo, " (", valor, ")")
}

registrar_advertencia <- function(modulo, id_libro, titulo, motivo, valor = NA) {
  ruta <- file.path(config$carpeta_salida, "logs", "log_advertencias.csv")
  fila <- data.frame(fecha = as.character(Sys.time()), modulo = modulo,
                     id_libro = id_libro, titulo = titulo, motivo = motivo,
                     valor = as.character(valor))
  write.table(fila, ruta, sep = ",", row.names = FALSE, append = file.exists(ruta),
              col.names = !file.exists(ruta))
  invisible(NULL)
}

guardar_tabla <- function(df, nombre) {
  ruta <- file.path(config$carpeta_salida, "tablas", paste0(nombre, ".csv"))
  write.csv(df, ruta, row.names = FALSE, fileEncoding = "UTF-8")
  invisible(ruta)
}

guardar_fig <- function(p, nombre, ancho = 9, alto = 6) {
  base <- file.path(config$carpeta_salida, "figuras", nombre)
  suppressMessages({
    ggplot2::ggsave(paste0(base, ".pdf"), p, width = ancho, height = alto,
                    device = grDevices::cairo_pdf)
    ggplot2::ggsave(paste0(base, ".png"), p, width = ancho, height = alto, dpi = 300)
  })
  invisible(base)
}

tema_pipeline <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"))
}

capas_etapas <- function() {
  bandas <- data.frame(xmin = c(0.5, 4.5, 8.5), xmax = c(4.5, 8.5, 12.5),
                       etapa = c("Basica inicial", "Basica superior", "Media"))
  ggplot2::geom_rect(data = bandas,
    ggplot2::aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = etapa),
    alpha = 0.10, inherit.aes = FALSE)
}

# --------------------------------------------------------------------------- #
# Normalizacion de titulos y parseo de nivel escolar
# --------------------------------------------------------------------------- #
normalizar_titulo <- function(x) {
  x <- stri_trans_general(stri_trans_tolower(as.character(x)), "Latin-ASCII")
  x <- stri_replace_all_regex(x, "[^a-z0-9 ]", " ")
  stri_trim_both(stri_replace_all_regex(x, "\\s+", " "))
}

parse_nivel <- function(x) {
  vapply(as.character(x), function(v) {
    v0 <- stri_trans_general(stri_trans_tolower(v), "Latin-ASCII")
    num <- suppressWarnings(as.integer(stri_extract_first_regex(v0, "\\d+")))
    if (is.na(num)) {
      rom <- stri_extract_first_regex(v0, "\\b(viii|vii|vi|iv|iii|ii|i|v)\\b")
      if (!is.na(rom)) num <- match(rom, c("i","ii","iii","iv","v","vi","vii","viii"))
    }
    if (is.na(num)) return(NA_integer_)
    if (stri_detect_fixed(v0, "medio")) num <- num + 8L
    if (num >= 1L && num <= 12L) num else NA_integer_
  }, integer(1), USE.NAMES = FALSE)
}

etapa_de_nivel <- function(nivel) {
  cut(nivel, breaks = c(0, 4, 8, 12),
      labels = c("Basica inicial", "Basica superior", "Media"))
}

# Parseo de celdas con varios cursos: "3\u00b0 o 4\u00b0 medio",
# "7\u00b0 b\u00e1sico, 2\u00b0 medio". Un fragmento sin etapa explicita
# hereda la del fragmento siguiente ("3\u00b0 o 4\u00b0 medio" = 11 y 12).
# Devuelve una lista de vectores de niveles.
parse_niveles_multi <- function(x) {
  lapply(as.character(x), function(v) {
    if (is.na(v)) return(NA_integer_)
    v0 <- stri_trans_general(stri_trans_tolower(v), "Latin-ASCII")
    frags <- stri_trim_both(stri_split_regex(v0, ",| o | y ")[[1]])
    frags <- frags[nzchar(frags)]
    if (length(frags) == 0) return(NA_integer_)
    etapas <- ifelse(stri_detect_fixed(frags, "medio"), "medio",
              ifelse(stri_detect_fixed(frags, "basico"), "basico",
                     NA_character_))
    if (length(etapas) > 1)
      for (i in rev(seq_len(length(etapas) - 1)))
        if (is.na(etapas[i])) etapas[i] <- etapas[i + 1]
    niv <- mapply(function(f, e) {
      num <- suppressWarnings(as.integer(stri_extract_first_regex(f, "\\d+")))
      if (is.na(num)) {
        rom <- stri_extract_first_regex(f, "\\b(viii|vii|vi|iv|iii|ii|i|v)\\b")
        if (!is.na(rom))
          num <- match(rom, c("i","ii","iii","iv","v","vi","vii","viii"))
      }
      if (is.na(num)) return(NA_integer_)
      if (!is.na(e) && e == "medio") num <- num + 8L
      if (num >= 1L && num <= 12L) num else NA_integer_
    }, frags, etapas)
    niv <- unique(niv[!is.na(niv)])
    if (length(niv) == 0) NA_integer_ else sort(niv)
  })
}

# --------------------------------------------------------------------------- #
# Lectura y limpieza de textos
# --------------------------------------------------------------------------- #
leer_texto <- function(ruta) {
  ext <- tolower(tools::file_ext(ruta))
  if (ext == "txt") {
    raw <- readBin(ruta, what = "raw", n = file.info(ruta)$size)
    enc <- stri_enc_detect(raw)[[1]]$Encoding[1]
    if (is.na(enc) || !enc %in% c("UTF-8", "ISO-8859-1", "windows-1252", "ASCII"))
      enc <- "UTF-8"
    txt <- stri_encode(raw, from = enc, to = "UTF-8")
    return(paste(txt, collapse = "\n"))
  }
  if (ext == "pdf") {
    pags <- NULL
    if (requireNamespace("pdftools", quietly = TRUE)) {
      pags <- pdftools::pdf_text(ruta)
    } else if (nzchar(pt <- encontrar_pdftotext())) {
      # fallback sin compilar nada: binario pdftotext de poppler-utils.
      # separa paginas con form feed (\f)
      salida <- suppressWarnings(system2(pt,
        c("-enc", "UTF-8", "-q", shQuote(ruta), "-"),
        stdout = TRUE, stderr = FALSE))
      pags <- strsplit(paste(salida, collapse = "\n"), "\f",
                       fixed = TRUE)[[1]]
    } else {
      stop("Archivo PDF detectado. Instalar pdftools (requiere ",
           "libpoppler-cpp-dev) o poppler-utils (binario pdftotext)")
    }
    txt <- paste(pags, collapse = "\n")
    # texto de las primeras paginas por separado: permite detectar portadas
    # escaneadas como imagen aunque el cuerpo tenga texto
    attr(txt, "inicio_paginas") <- substr(
      pags[seq_len(min(3, length(pags)))], 1, 1500)
    return(txt)
  }
  if (ext == "epub") {
    if (!requireNamespace("epubr", quietly = TRUE))
      stop("Archivo EPUB detectado. Instalar: install.packages('epubr')")
    dat <- epubr::epub(ruta)
    return(paste(dat$data[[1]]$text, collapse = "\n"))
  }
  if (ext == "docx") {
    # un docx es un zip; el texto vive en word/document.xml
    tmp <- tempfile("docx_")
    dir.create(tmp)
    utils::unzip(ruta, files = "word/document.xml", exdir = tmp)
    xml <- xml2::read_xml(file.path(tmp, "word", "document.xml"))
    parrafos <- xml2::xml_find_all(xml, ".//w:p",
      ns = xml2::xml_ns(xml))
    txt <- vapply(parrafos, function(p)
      paste(xml2::xml_text(xml2::xml_find_all(p, ".//w:t",
        ns = xml2::xml_ns(xml))), collapse = ""), character(1))
    unlink(tmp, recursive = TRUE)
    return(paste(txt, collapse = "\n"))
  }
  stop("Formato no soportado: .", ext, " (soportados: txt, pdf, epub, docx)")
}

limpiar_texto <- function(txt) {
  txt <- stri_trans_nfc(txt)
  # bloques Project Gutenberg (ingles y espanol)
  txt <- stri_replace_first_regex(txt, "(?s)^.*?\\*\\*\\*\\s*START OF.*?\\*\\*\\*", "")
  txt <- stri_replace_first_regex(txt, "(?s)\\*\\*\\*\\s*END OF.*$", "")
  # guiones de corte de linea: pala-\nbra -> palabra
  txt <- stri_replace_all_regex(txt, paste0("([", .LMIN, "])-\\s*\\n\\s*([", .LMIN, "])"), "$1$2")
  lineas <- stri_split_lines(txt)[[1]]
  lineas <- stri_trim_both(lineas)
  # numeros de pagina sueltos
  lineas <- lineas[!stri_detect_regex(lineas, "^[0-9ivxlc]{1,6}$")]
  # encabezados repetidos: lineas cortas identicas que aparecen 4+ veces
  cortas <- lineas[nchar(lineas) > 0 & nchar(lineas) < 60]
  rep_head <- names(which(table(cortas) >= 4))
  rep_head <- rep_head[!stri_detect_regex(rep_head, "[.!?]$")]
  if (length(rep_head) > 0) lineas <- lineas[!(lineas %in% rep_head)]
  txt <- paste(lineas, collapse = "\n")
  txt <- stri_replace_all_regex(txt, "\\n{2,}", "\n\n")
  stri_trim_both(stri_replace_all_regex(txt, "[ \\t]+", " "))
}

proporcion_stopwords_es <- function(txt, sw) {
  toks <- stri_extract_all_regex(stri_trans_tolower(txt), paste0("[", .LMIN, "]+"))[[1]]
  if (length(toks) < 20) return(NA_real_)
  mean(toks %in% sw)
}

# --------------------------------------------------------------------------- #
# Silabeo del espanol (para Fernandez-Huerta, Szigriszt-Pazos y FK)
# Reglas: nucleos vocalicos; diptongos debil+fuerte, fuerte+debil, debil+debil;
# hiatos fuerte+fuerte y debil acentuada; u muda en qu/gu(e,i); y final = i.
# --------------------------------------------------------------------------- #
contar_silabas_palabra <- function(w) {
  w <- stri_trans_nfc(stri_trans_tolower(w))
  w <- stri_replace_all_regex(w, paste0("[^", .LMIN, "]"), "")
  if (nchar(w) == 0) return(0L)
  w <- stri_replace_all_fixed(w, "qu", "q")
  w <- stri_replace_all_regex(w, "gu(?=[ei])", "g")
  w <- stri_replace_all_regex(w, "y$", "i")
  ch <- stri_sub(w, seq_len(nchar(w)), length = 1)
  fuertes <- c("a", "e", "o", "\u00e1", "\u00e9", "\u00f3")
  debiles <- c("i", "u", "\u00fc")
  acentDeb <- c("\u00ed", "\u00fa")
  es_vocal <- ch %in% c(fuertes, debiles, acentDeb)
  if (!any(es_vocal)) return(1L)
  sil <- 0L; i <- 1L; n <- length(ch)
  while (i <= n) {
    if (!es_vocal[i]) { i <- i + 1L; next }
    j <- i
    while (j < n && es_vocal[j + 1L]) j <- j + 1L
    grupo <- ch[i:j]
    k <- 1L; L <- length(grupo)
    while (k <= L) {
      sil <- sil + 1L
      m <- k
      repeat {
        if (m >= L) break
        v1 <- grupo[m]; v2 <- grupo[m + 1L]
        f1 <- v1 %in% fuertes; f2 <- v2 %in% fuertes
        a1 <- v1 %in% acentDeb; a2 <- v2 %in% acentDeb
        if ((f1 && f2) || a1 || a2) break        # hiato
        m <- m + 1L                              # diptongo
        if (m - k >= 2L) break                   # maximo triptongo
      }
      k <- m + 1L
    }
    i <- j + 1L
  }
  max(sil, 1L)
}

contar_silabas <- function(palabras) {
  u <- unique(palabras)
  s <- vapply(u, contar_silabas_palabra, integer(1))
  unname(s[match(palabras, u)])
}

# --------------------------------------------------------------------------- #
# Legibilidad. Formulas:
#   ARI  = 4.71*(car/pal) + 0.5*(pal/ora) - 21.43            (Senter y Smith 1967)
#   RIX  = palabras con mas de 6 letras / oraciones          (Anderson 1983)
#   FK   = 0.39*(pal/ora) + 11.8*(sil/pal) - 15.59
#   FH   = 206.84 - 0.60*P - 1.02*F ; P = sil por 100 pal, F = pal por oracion
#   SP   = 206.835 - 62.3*(sil/pal) - (pal/ora)              (escala INFLESZ)
#   mu   = (n/(n-1)) * (media_letras / var_letras) * 100     (Munoz Baquedano)
# --------------------------------------------------------------------------- #
calcular_legibilidad <- function(palabras, oracion_id) {
  stopifnot(length(palabras) == length(oracion_id))
  n_pal <- length(palabras)
  n_ora <- length(unique(oracion_id))
  if (n_pal < 10 || n_ora < 1) return(NULL)
  letras <- stri_count_regex(palabras, .RE_LETRA)
  sil <- contar_silabas(palabras)
  pal_ora <- n_pal / n_ora
  car_pal <- sum(letras) / n_pal
  sil_pal <- sum(sil) / n_pal
  sil_100 <- sil_pal * 100          # silabas por cada 100 palabras
  var_letras <- stats::var(letras)
  mu <- if (n_pal > 1 && isTRUE(var_letras > 0))
    (n_pal / (n_pal - 1)) * (mean(letras) / var_letras) * 100 else NA_real_
  list(
    n_palabras = n_pal, n_oraciones = n_ora,
    long_oracion_media = pal_ora,
    letras_por_palabra = car_pal,
    silabas_por_palabra = sil_pal,
    ari = 4.71 * car_pal + 0.5 * pal_ora - 21.43,
    rix = sum(letras > 6) / n_ora,
    flesch_kincaid = 0.39 * pal_ora + 11.8 * sil_pal - 15.59,
    fernandez_huerta = 206.84 - 0.60 * sil_100 - 1.02 * pal_ora,
    szigriszt_pazos = 206.835 - 62.3 * sil_pal - pal_ora,
    perfil_mu = mu
  )
}

banda_inflesz <- function(sp) {
  cut(sp, breaks = c(-Inf, 40, 55, 65, 80, Inf),
      labels = c("muy dificil", "algo dificil", "normal",
                 "bastante facil", "muy facil"))
}

# --------------------------------------------------------------------------- #
# Diversidad lexica. Se calcula sobre formas superficiales en minuscula,
# sin remover stopwords ni lematizar.
# --------------------------------------------------------------------------- #
calc_mattr <- function(ids, w) {
  n <- length(ids)
  if (n < w) return(NA_real_)
  cnt <- integer(max(ids))
  tipos <- 0L
  for (i in seq_len(w)) {
    if (cnt[ids[i]] == 0L) tipos <- tipos + 1L
    cnt[ids[i]] <- cnt[ids[i]] + 1L
  }
  suma <- tipos / w
  if (n > w) {
    for (i in seq_len(n - w)) {
      sale <- ids[i]; entra <- ids[i + w]
      cnt[sale] <- cnt[sale] - 1L
      if (cnt[sale] == 0L) tipos <- tipos - 1L
      if (cnt[entra] == 0L) tipos <- tipos + 1L
      cnt[entra] <- cnt[entra] + 1L
      suma <- suma + tipos / w
    }
  }
  suma / (n - w + 1)
}

.mtld_una_direccion <- function(ids, umbral = 0.72) {
  n <- length(ids)
  cnt <- integer(max(ids))
  tipos <- 0L; toks <- 0L; factores <- 0
  for (i in seq_len(n)) {
    toks <- toks + 1L
    if (cnt[ids[i]] == 0L) tipos <- tipos + 1L
    cnt[ids[i]] <- cnt[ids[i]] + 1L
    ttr <- tipos / toks
    if (ttr < umbral) {
      factores <- factores + 1
      cnt[] <- 0L; tipos <- 0L; toks <- 0L
    }
  }
  if (toks > 0L) {
    ttr <- tipos / toks
    if (ttr < 1) factores <- factores + (1 - ttr) / (1 - umbral)
  }
  if (factores == 0) return(NA_real_)
  n / factores
}

calc_mtld <- function(ids) {
  f <- .mtld_una_direccion(ids)
  b <- .mtld_una_direccion(rev(ids))
  mean(c(f, b), na.rm = TRUE)
}

calc_hdd <- function(frecs, muestra = 42) {
  N <- sum(frecs)
  if (N < muestra + 8) return(NA_real_)
  sum(1 - stats::dhyper(0, frecs, N - frecs, muestra)) / muestra
}

metricas_diversidad <- function(tokens, ventanas = c(50, 100), hdd_m = 42) {
  tokens <- tokens[nchar(tokens) > 0]
  N <- length(tokens)
  if (N < 10) return(NULL)
  ids <- match(tokens, unique(tokens))
  tab <- tabulate(ids)
  V <- length(tab); V1 <- sum(tab == 1L)
  p <- tab / N
  m_vals <- table(tab)
  yule <- 1e4 * (sum(as.integer(names(m_vals))^2 * as.integer(m_vals)) - N) / N^2
  out <- list(
    tokens = N, tipos = V, ttr = V / N,
    mtld = calc_mtld(ids),
    hdd = calc_hdd(tab, hdd_m),
    yule_k = yule,
    entropia_shannon = -sum(p * log2(p)),
    hapax_ratio = V1 / V,
    maas = (log10(N) - log10(V)) / (log10(N)^2)
  )
  for (w in ventanas) out[[paste0("mattr_", w)]] <- calc_mattr(ids, w)
  out
}

pendiente_zipf <- function(tokens, min_frec = 5) {
  tab <- sort(table(tokens), decreasing = TRUE)
  tab <- tab[tab >= min_frec]
  if (length(tab) < 20) return(NA_real_)
  unname(coef(stats::lm(log(as.numeric(tab)) ~ log(seq_along(tab))))[2])
}

# --------------------------------------------------------------------------- #
# Estadistica: implementaciones manuales con test unitario
# --------------------------------------------------------------------------- #

# Dunn (1964) post hoc de Kruskal-Wallis, con correccion de empates y Holm
dunn_manual <- function(x, g, metodo_ajuste = "holm") {
  ok <- stats::complete.cases(x, g)
  x <- x[ok]; g <- droplevels(factor(g[ok]))
  N <- length(x)
  r <- rank(x)
  emp <- table(r)
  T_emp <- sum(emp^3 - emp)
  medias <- tapply(r, g, mean)
  ns <- tapply(r, g, length)
  niveles <- levels(g)
  comb <- utils::combn(niveles, 2)
  res <- vapply(seq_len(ncol(comb)), function(k) {
    i <- comb[1, k]; j <- comb[2, k]
    se <- sqrt((N * (N + 1) / 12 - T_emp / (12 * (N - 1))) *
               (1 / ns[i] + 1 / ns[j]))
    z <- (medias[i] - medias[j]) / se
    c(z = unname(z), p = 2 * stats::pnorm(-abs(z)))
  }, c(z = 0, p = 0))
  data.frame(grupo1 = comb[1, ], grupo2 = comb[2, ],
             z = res["z", ], p = res["p", ],
             p_ajustada = stats::p.adjust(res["p", ], metodo_ajuste))
}

# Jonckheere-Terpstra con p por permutacion (grupos en orden creciente)
jt_test <- function(x, g, B = 2000, semilla = 1) {
  ok <- stats::complete.cases(x, g)
  x <- x[ok]; g <- as.integer(factor(g[ok], levels = sort(unique(g[ok]))))
  grupos <- sort(unique(g))
  calc_J <- function(x, g) {
    J <- 0
    for (a in seq_along(grupos)[-length(grupos)]) {
      for (b in (a + 1):length(grupos)) {
        xi <- x[g == grupos[a]]; xj <- x[g == grupos[b]]
        J <- J + sum(outer(xi, xj, "<")) + 0.5 * sum(outer(xi, xj, "=="))
      }
    }
    J
  }
  J_obs <- calc_J(x, g)
  set.seed(semilla)
  J_perm <- replicate(B, calc_J(x, sample(g)))
  mu <- mean(J_perm)
  p <- (1 + sum(abs(J_perm - mu) >= abs(J_obs - mu))) / (B + 1)
  list(J = J_obs, J_esperado = mu, p = p,
       direccion = ifelse(J_obs > mu, "creciente", "decreciente"))
}

# Delta de Cliff
cliff_delta <- function(x, y) {
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  if (length(x) == 0 || length(y) == 0) return(NA_real_)
  (sum(outer(x, y, ">")) - sum(outer(x, y, "<"))) / (length(x) * length(y))
}

# Epsilon cuadrado para Kruskal-Wallis
epsilon_cuadrado <- function(H, n) H / ((n^2 - 1) / (n + 1))

# V de Cramer
cramer_v <- function(tab) {
  chi <- suppressWarnings(stats::chisq.test(tab, correct = FALSE))
  sqrt(as.numeric(chi$statistic) / (sum(tab) * (min(dim(tab)) - 1)))
}

# Log-likelihood keyness (Dunning 1993). a: frec en foco, b: frec en resto,
# c: total foco, d: total resto. Signo positivo: sobreuso en foco.
ll_keyness <- function(a, b, c, d) {
  E1 <- c * (a + b) / (c + d)
  E2 <- d * (a + b) / (c + d)
  t1 <- ifelse(a > 0, a * log(a / E1), 0)
  t2 <- ifelse(b > 0, b * log(b / E2), 0)
  ll <- 2 * (t1 + t2)
  ll * sign(a / c - b / d)
}

# Indice de Rand ajustado entre dos particiones
rand_ajustado <- function(a, b) {
  tab <- table(a, b)
  n <- sum(tab)
  sum_ij <- sum(choose(tab, 2))
  sum_a <- sum(choose(rowSums(tab), 2))
  sum_b <- sum(choose(colSums(tab), 2))
  esperado <- sum_a * sum_b / choose(n, 2)
  maximo <- (sum_a + sum_b) / 2
  if (maximo == esperado) return(0)
  (sum_ij - esperado) / (maximo - esperado)
}

# extrae el ID de una URL de carpeta o archivo de Google Drive
extraer_id_drive <- function(url) {
  m <- stri_match_first_regex(as.character(url),
    "(?:folders/|/d/|id=)([A-Za-z0-9_-]{10,})")
  m[, 2]
}

# Busca el binario pdftotext: ruta del config, PATH y rutas tipicas de
# instalaciones de usuario (conda, ~/.local). Devuelve "" si no hay.
encontrar_pdftotext <- function() {
  cand <- c(
    if (!is.null(config$ruta_pdftotext) && !is.na(config$ruta_pdftotext))
      path.expand(config$ruta_pdftotext),
    Sys.which("pdftotext"),
    Sys.glob(c("~/.local/*/bin/pdftotext", "~/.conda/envs/*/bin/pdftotext",
               "~/miniconda3/bin/pdftotext", "~/mambaforge/bin/pdftotext",
               "/opt/*/bin/pdftotext", "/usr/local/bin/pdftotext")))
  cand <- cand[nzchar(cand)]
  cand <- cand[file.exists(cand)]
  if (length(cand) > 0) normalizePath(cand[1]) else ""
}

# Numero inicial de un nombre de archivo tipo "0639_Titulo.pdf" -> 639
numero_de_archivo <- function(x) {
  as.integer(stri_match_first_regex(as.character(x),
                                    "^0*(\\d+)[_\\- ]")[, 2])
}

# Construye el catalogo desde el xlsx: filtros, parseo de niveles y
# expansion multi curso. Usado por 01_ingesta y por emparejar_contenido.
construir_catalogo <- function() {
  cat_raw <- if (!is.null(config$hoja_xlsx) && !is.na(config$hoja_xlsx))
    readxl::read_excel(config$ruta_xlsx, sheet = config$hoja_xlsx) else
    readxl::read_excel(config$ruta_xlsx)
  log_msg("Catalogo: ", nrow(cat_raw), " filas leidas de ", config$ruta_xlsx)
  nfc <- function(x) stringi::stri_trans_nfc(as.character(x))
  for (col in names(config$filtros_mantener)) {
    if (!col %in% colnames(cat_raw))
      stop("Columna de filtro no encontrada: ", col, "\nColumnas disponibles: ",
           paste(colnames(cat_raw), collapse = " | "))
    antes <- nrow(cat_raw)
    cat_raw <- cat_raw[!is.na(cat_raw[[col]]) &
                       nfc(cat_raw[[col]]) %in% nfc(config$filtros_mantener[[col]]), ]
    log_msg("Filtro mantener ", col, " = {",
            paste(config$filtros_mantener[[col]], collapse = ", "), "}: ",
            antes, " -> ", nrow(cat_raw), " filas")
  }
  for (col in names(config$filtros_excluir_regex)) {
    if (!col %in% colnames(cat_raw))
      stop("Columna de filtro no encontrada: ", col, "\nColumnas disponibles: ",
           paste(colnames(cat_raw), collapse = " | "))
    antes <- nrow(cat_raw)
    fuera <- !is.na(cat_raw[[col]]) &
      stringi::stri_detect_regex(nfc(cat_raw[[col]]),
                                 config$filtros_excluir_regex[[col]])
    cat_raw <- cat_raw[!fuera, ]
    log_msg("Filtro excluir ", col, " ~ /", config$filtros_excluir_regex[[col]],
            "/ (NA se conservan): ", antes, " -> ", nrow(cat_raw), " filas")
  }
  cols <- colnames(cat_raw)
  falta <- setdiff(na.omit(c(config$col_titulo, config$col_nivel)), cols)
  if (length(falta) > 0)
    stop("Columnas no encontradas en el xlsx: ", paste(falta, collapse = ", "),
         "\nColumnas disponibles: ", paste(cols, collapse = " | "),
         "\nAjustar col_titulo / col_archivo / col_nivel en config.R")
  catalogo <- tibble::tibble(
    titulo = as.character(cat_raw[[config$col_titulo]]),
    nivel_bruto = as.character(cat_raw[[config$col_nivel]]),
    autor = if (!is.null(config$col_autor) && !is.na(config$col_autor) &&
                config$col_autor %in% cols)
      as.character(cat_raw[[config$col_autor]]) else NA_character_,
    numero = if (!is.null(config$col_numero) && !is.na(config$col_numero) &&
                 config$col_numero %in% cols)
      suppressWarnings(as.integer(cat_raw[[config$col_numero]])) else
      NA_integer_,
    archivo_cat = if (!is.na(config$col_archivo) && config$col_archivo %in% cols)
      as.character(cat_raw[[config$col_archivo]]) else NA_character_)
  catalogo$titulo_norm <- normalizar_titulo(catalogo$titulo)
  niveles_lista <- parse_niveles_multi(catalogo$nivel_bruto)
  sin_nivel <- which(vapply(niveles_lista, function(v) all(is.na(v)), logical(1)))
  for (i in sin_nivel)
    registrar_exclusion("01_ingesta", NA, catalogo$titulo[i],
                        "nivel no interpretable", catalogo$nivel_bruto[i])
  if (length(sin_nivel) > 0 && config$detener_si_faltan)
    stop(length(sin_nivel), " libros con nivel no interpretable. Ver log_exclusiones.csv")
  largos <- vapply(niveles_lista, function(v) sum(!is.na(v)), integer(1))
  if (isTRUE(config$expandir_multicurso)) {
    keep <- largos > 0
    catalogo <- catalogo[rep(which(keep), largos[keep]), ]
    catalogo$nivel <- unlist(lapply(niveles_lista[keep], function(v) v[!is.na(v)]))
    catalogo$multicurso <- rep(largos[keep] > 1, largos[keep])
    n_multi <- sum(largos > 1)
    if (n_multi > 0)
      log_msg("Expansion multi curso: ", n_multi, " obras en mas de un nivel ",
              "generan ", sum(largos[largos > 1]), " filas")
  } else {
    catalogo$nivel <- vapply(niveles_lista, function(v) v[!is.na(v)][1], integer(1))
    catalogo$multicurso <- largos > 1
    catalogo <- catalogo[!is.na(catalogo$nivel), ]
  }
  catalogo$id_libro <- sprintf("L%04d", seq_len(nrow(catalogo)))
  catalogo$etapa <- etapa_de_nivel(catalogo$nivel)
  catalogo
}

# Lectura con cache del texto extraido (evita re-extraer PDFs grandes).
# La cache se invalida si el archivo cambia de tamano o fecha.
leer_texto_cache <- function(ruta) {
  dir_c <- file.path(config$carpeta_salida, "cache", "texto")
  dir.create(dir_c, recursive = TRUE, showWarnings = FALSE)
  info <- file.info(ruta)
  clave <- paste0(basename(ruta), "_", info$size, "_",
                  as.integer(info$mtime), "_v3.rds")
  rds <- file.path(dir_c, gsub("[^A-Za-z0-9._-]", "_", clave))
  if (file.exists(rds)) return(readRDS(rds))
  txt <- leer_texto(ruta)
  saveRDS(txt, rds)
  txt
}

# hash de texto para detectar contenidos duplicados
digest_texto <- function(txt) {
  if (requireNamespace("digest", quietly = TRUE)) return(digest::digest(txt))
  rlang::hash(txt)
}

# z robusto dentro de grupo (mediana y MAD)
z_robusto <- function(x) {
  med <- stats::median(x, na.rm = TRUE)
  mad <- stats::mad(x, na.rm = TRUE)
  if (is.na(mad) || mad == 0) return(rep(NA_real_, length(x)))
  (x - med) / mad
}
