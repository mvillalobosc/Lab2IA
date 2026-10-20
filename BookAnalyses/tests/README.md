# tests/

[Español](#español) · [English](#english)

## Español

`test_metricas.R` contiene los tests unitarios de las métricas que implementa `R/utils.R`. Cada test es un `stopifnot()` sobre un caso calculado a mano, de modo que si una fórmula cambia el script se detiene con error. `run_all.R` lo carga justo después de `R/00_setup.R` y antes del módulo 01, así que un test que falla detiene el pipeline antes de leer el corpus.

Los tests cubren el silabeo del español (diptongos, hiatos con tilde y la diéresis de "pingüino"), las fórmulas de legibilidad sobre un texto construido a mano (ARI, RIX, Flesch-Kincaid, Fernández Huerta y Szigriszt-Pazos), los índices de diversidad (TTR, MATTR, hapax, entropía, Yule K y MTLD), la equivalencia entre Dunn y Kruskal-Wallis con dos grupos, Jonckheere-Terpstra, el delta de Cliff, epsilon cuadrado, V de Cramér, el Rand ajustado, el keyness por log-likelihood, la lectura de niveles escolares (`parse_nivel` y `parse_niveles_multi`, con celdas del catálogo real como "3° o 4° medio"), la extracción del id de una carpeta de Drive y el prefijo numérico de los archivos (`0639_...pdf`).

El archivo no hace `source()` de nada: espera que `config.R` y `R/utils.R` ya estén cargados. Para correrlo solo, desde la raíz del proyecto:

```bash
Rscript -e 'source("config.R"); source("R/utils.R"); source("tests/test_metricas.R")'
```

Si los tests pasan, imprime `Tests de metricas: TODOS OK`. Basta con tener instalados stringi, dplyr, tidyr y data.table, que `R/utils.R` carga al inicio, y no escribe ningún archivo. Vuelve al [README del proyecto](../README.md).

## English

`test_metricas.R` holds the unit tests for the metrics implemented in `R/utils.R`. Each test is a `stopifnot()` on a case worked out by hand, so the script stops with an error if a formula changes. `run_all.R` loads it right after `R/00_setup.R` and before module 01, so a failing test stops the pipeline before it reads the corpus.

The tests cover Spanish syllable counting (diphthongs, accented hiatus and the diaeresis in "pingüino"), the readability formulas on a hand-built text (ARI, RIX, Flesch-Kincaid, Fernández Huerta and Szigriszt-Pazos), the diversity indices (TTR, MATTR, hapax, entropy, Yule's K and MTLD), the equivalence between Dunn and Kruskal-Wallis with two groups, Jonckheere-Terpstra, Cliff's delta, epsilon squared, Cramér's V, the adjusted Rand index, log-likelihood keyness, school-grade parsing (`parse_nivel` and `parse_niveles_multi`, with cells from the real catalogue such as "3° o 4° medio"), extracting the id of a Drive folder and the numeric prefix of the files (`0639_...pdf`).

The file does not `source()` anything: it expects `config.R` and `R/utils.R` to be loaded already. To run it on its own, from the project root:

```bash
Rscript -e 'source("config.R"); source("R/utils.R"); source("tests/test_metricas.R")'
```

When everything passes it prints `Tests de metricas: TODOS OK`. It only needs stringi, dplyr, tidyr and data.table, which `R/utils.R` loads at the start, and it writes no files. Back to the [project README](../README.md).
