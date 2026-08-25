# =============================================================================
# test_metricas.R : tests unitarios de las metricas implementadas en utils.R.
# Se ejecutan automaticamente al inicio de run_all.R; si algo falla, el
# pipeline se detiene antes de tocar los datos.
# =============================================================================

casi_igual <- function(a, b, tol = 1e-8) abs(a - b) < tol

# --- Silabeo -----------------------------------------------------------------
stopifnot(contar_silabas_palabra("casa") == 2)
stopifnot(contar_silabas_palabra("pais") == 1)        # sin tilde: diptongo
stopifnot(contar_silabas_palabra("pa\u00eds") == 2)        # hiato por tilde
stopifnot(contar_silabas_palabra("ciudad") == 2)
stopifnot(contar_silabas_palabra("buey") == 1)
stopifnot(contar_silabas_palabra("poes\u00eda") == 4)
stopifnot(contar_silabas_palabra("guerra") == 2)
stopifnot(contar_silabas_palabra("ping\u00fcino") == 3)
stopifnot(contar_silabas_palabra("murci\u00e9lago") == 4)
stopifnot(contar_silabas_palabra("a\u00e9reo") == 4)
stopifnot(contar_silabas_palabra("rey") == 1)
stopifnot(contar_silabas_palabra("queso") == 2)

# --- Legibilidad: caso construido a mano ------------------------------------
# Texto: "el gato come pescado . la casa es grande ." : 2 oraciones, 8 palabras
pal <- c("el", "gato", "come", "pescado", "la", "casa", "es", "grande",
         "un", "perro")
ora <- c(1, 1, 1, 1, 2, 2, 2, 2, 3, 3)
leg <- calcular_legibilidad(pal, ora)
stopifnot(!is.null(leg))
# valores verificados a mano:
# letras = 2,4,4,7,2,4,2,6,2,5 = 38 ; letras/palabra = 3.8
# silabas = 1,2,2,3,1,2,1,2,1,2 = 17 ; sil/pal = 1.7 ; pal/ora = 10/3
stopifnot(casi_igual(leg$letras_por_palabra, 3.8))
stopifnot(casi_igual(leg$silabas_por_palabra, 1.7))
stopifnot(casi_igual(leg$ari, 4.71 * 3.8 + 0.5 * (10/3) - 21.43))
stopifnot(casi_igual(leg$rix, 1 / 3))                 # solo "pescado" > 6 letras
stopifnot(casi_igual(leg$flesch_kincaid, 0.39 * (10/3) + 11.8 * 1.7 - 15.59))
stopifnot(casi_igual(leg$fernandez_huerta, 206.84 - 0.60 * 170 - 1.02 * (10/3)))
stopifnot(casi_igual(leg$szigriszt_pazos, 206.835 - 62.3 * 1.7 - (10/3)))

# --- Diversidad --------------------------------------------------------------
# secuencia con TTR conocido: a b c a b c ... (30 tokens, 3 tipos)
toks <- rep(c("a", "b", "c"), 10)
d <- metricas_diversidad(toks, ventanas = c(5), hdd_m = 10)
stopifnot(d$tokens == 30, d$tipos == 3)
stopifnot(casi_igual(d$ttr, 0.1))
stopifnot(casi_igual(d$mattr_5, 3 / 5))               # toda ventana de 5 tiene 3 tipos
stopifnot(casi_igual(d$hapax_ratio, 0))               # ningun hapax
p <- rep(1/3, 3)
stopifnot(casi_igual(d$entropia_shannon, -sum(p * log2(p))))
# Yule K: V(10)=3 -> K = 1e4*(100*3 - 30)/900
stopifnot(casi_igual(d$yule_k, 1e4 * (300 - 30) / 900))
# hapax: agregando una palabra unica
d2 <- metricas_diversidad(c(toks, "zorro"), ventanas = c(5), hdd_m = 10)
stopifnot(casi_igual(d2$hapax_ratio, 1 / 4))
# MATTR ventana mayor que el texto -> NA
stopifnot(is.na(calc_mattr(match(toks, unique(toks)), 100)))
# MTLD texto perfectamente repetitivo cae bajo el umbral y da valor finito
stopifnot(is.finite(d$mtld))

# --- Dunn vs Kruskal-Wallis (2 grupos, sin empates: z^2 = H) ----------------
set.seed(11)
x <- c(rnorm(15), rnorm(15, 2))
g <- rep(c("A", "B"), each = 15)
H <- unname(stats::kruskal.test(x, factor(g))$statistic)
dn <- dunn_manual(x, g)
stopifnot(casi_igual(dn$z[1]^2, H, tol = 1e-6))

# --- Jonckheere-Terpstra -----------------------------------------------------
set.seed(21)
xj <- c(rnorm(10, 0), rnorm(10, 1), rnorm(10, 2))
gj <- rep(1:3, each = 10)
jt1 <- jt_test(xj, gj, B = 500, semilla = 3)
stopifnot(jt1$p < 0.05, jt1$direccion == "creciente")
jt2 <- jt_test(sample(xj), gj, B = 500, semilla = 3)
stopifnot(jt2$p > 0.05)

# --- Cliff, epsilon2, Cramer, Rand ajustado ---------------------------------
stopifnot(casi_igual(cliff_delta(c(3, 4, 5), c(1, 2)), 1))
stopifnot(casi_igual(cliff_delta(c(1, 2), c(3, 4, 5)), -1))
stopifnot(casi_igual(cliff_delta(c(1, 2), c(1, 2)), 0))
stopifnot(casi_igual(epsilon_cuadrado(10, 100), 10 / (9999 / 101)))
tab <- matrix(c(30, 10, 10, 30), 2)
stopifnot(cramer_v(tab) > 0.3, cramer_v(tab) <= 1)
stopifnot(casi_igual(rand_ajustado(c(1,1,2,2), c(1,1,2,2)), 1))
stopifnot(casi_igual(rand_ajustado(c(1,1,2,2), c(2,2,1,1)), 1))
set.seed(5)
stopifnot(abs(rand_ajustado(sample(1:2, 200, TRUE), sample(1:2, 200, TRUE))) < 0.2)

# --- Keyness LL --------------------------------------------------------------
# uso identico en ambos corpus -> LL = 0
stopifnot(casi_igual(ll_keyness(10, 10, 1000, 1000), 0))
stopifnot(ll_keyness(50, 5, 1000, 1000) > 0)
stopifnot(ll_keyness(5, 50, 1000, 1000) < 0)

# --- parse_nivel -------------------------------------------------------------
stopifnot(identical(parse_nivel(c("1", "8\u00b0 B\u00e1sico", "1\u00b0 Medio", "IV medio",
                                  "3 basico", "II Medio")),
                    c(1L, 8L, 9L, 12L, 3L, 10L)))
stopifnot(is.na(parse_nivel("sin dato")))

# --- parse_niveles_multi (celdas con varios cursos del catalogo real) --------
pm <- parse_niveles_multi(c("5\u00b0 b\u00e1sico",
                            "3\u00b0 o 4\u00b0 medio",
                            "7\u00b0 b\u00e1sico, 2\u00b0 medio",
                            "7\u00b0 b\u00e1sico, 8\u00b0 b\u00e1sico, 2\u00b0 medio",
                            "2\u00b0 medio, 3\u00b0 medio, 4\u00b0 medio",
                            "6\u00b0 y 7\u00b0 b\u00e1sico"))
stopifnot(identical(pm[[1]], 5L))
stopifnot(identical(pm[[2]], c(11L, 12L)))
stopifnot(identical(pm[[3]], c(7L, 10L)))
stopifnot(identical(pm[[4]], c(7L, 8L, 10L)))
stopifnot(identical(pm[[5]], c(10L, 11L, 12L)))
stopifnot(identical(pm[[6]], c(6L, 7L)))
stopifnot(is.na(parse_niveles_multi("sin dato")[[1]]))

# --- extraer_id_drive --------------------------------------------------------
stopifnot(identical(
  extraer_id_drive("https://drive.google.com/drive/folders/1d2KgpXucOBDLyaYifzUtgq1R4p055QC-?usp=sharing"),
  "1d2KgpXucOBDLyaYifzUtgq1R4p055QC-"))
stopifnot(identical(extraer_id_drive("https://drive.google.com/file/d/ABC123def456_-x/view"),
                    "ABC123def456_-x"))
stopifnot(is.na(extraer_id_drive("sin url")))

# --- numero_de_archivo (prefijo de los PDF del Drive) ------------------------
stopifnot(identical(numero_de_archivo(c("0639_Chorlitos en la cabeza.pdf",
                                        "1826_Los juegos del hambre.pdf",
                                        "12- Titulo.pdf", "sin_prefijo.pdf")),
                    c(639L, 1826L, 12L, NA_integer_)))

cat("Tests de metricas: TODOS OK\n")
