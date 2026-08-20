# pichintun-nlp

[English](README.en.md) | **Español**

Pipeline reproducible en R para el análisis de lenguaje natural de los 34 capítulos de las cuatro temporadas de la serie infantil chilena *Pichintún*.

El análisis cubre cinco dimensiones: composición léxica (español genérico frente a voces indígenas y chilenismos), estructura temática sobre 16 categorías, sentimiento y emociones, complejidad y diversidad léxica, y los factores asociados a la recepción de la serie en YouTube.

---

## Contenido del repositorio

```
pichintun-nlp/
├── run_all.R                  Punto de entrada único
├── R/
│   ├── 00_config.R            Rutas, parámetros y estilo
│   ├── 01_ingest.R            Carga de diálogos, metadatos y léxicos
│   ├── 02_clean.R             Limpieza, tokenización, partición léxica
│   ├── 03_frequency.R         Frecuencia de palabras, keyness, distancias
│   ├── 04_topics.R            Los 16 temas por capítulo y temporada
│   ├── 05_sentiment.R         Sentimiento y 16 tipos emocionales
│   ├── 06_readability.R       ARI y MATTR
│   ├── 07_popularity.R        Random Forest y regresión múltiple
│   ├── 08_export.R            Consolidación y verificación
│   └── lib/
│       ├── packages.R         Declaración única de dependencias
│       ├── io.R               Lectura, escritura y cacheo
│       ├── text.R             Normalización y tokenización
│       └── stats_helpers.R    Distancias, dendrogramas, clustering
├── data/
│   ├── raw/                   Datos de entrada, versionados
│   └── processed/             Artefactos intermedios (.rds), regenerables
├── outputs/
│   ├── figures/               97 figuras PNG
│   └── tables/                31 tablas CSV y 1 libro Excel
└── report/
    └── pichintun_report.Rmd   Informe HTML a partir de las salidas
```

---

## Instalación y ejecución

Requiere **R 4.2 o superior**. Verificado en R 4.3.3 sobre Ubuntu 24.04.

```r
# 1. Instalar dependencias (una sola vez)
source("R/lib/packages.R")
check_packages(install_missing = TRUE)

# 2. Ejecutar el pipeline completo
```

```bash
Rscript run_all.R
```

Cada módulo guarda su resultado en `data/processed`, de modo que se puede reejecutar un módulo sin repetir los anteriores:

```bash
Rscript run_all.R 5 6 7     # solo sentimiento, legibilidad y popularidad
```

Tiempo de ejecución completo: alrededor de **6 minutos** en una máquina de escritorio corriente. El módulo 03 es el más costoso por las 34 nubes de palabras.

### Dependencias

`dplyr`, `tidyr`, `purrr`, `readr`, `stringr`, `tibble`, `ggplot2`, `tokenizers`, `tm`, `hunspell`, `quanteda`, `quanteda.textstats`, `quanteda.textplots`, `sentimentr`, `koRpus`, `koRpus.lang.es`, `fmsb`, `corrplot`, `dendextend`, `amap`, `mstknnclust`, `ggwordcloud`, `patchwork`, `gridExtra`, `scales`, `igraph`, `caret`, `randomForest`, `writexl`.

`koRpus.lang.es` no está en CRAN. Se instala desde el repositorio del autor:

```r
install.packages("koRpus.lang.es",
                 repos = c(l10n = "https://undocumeantit.github.io/repos/l10n"))
```

### Conteo de archivos

El repositorio versionado son **29 archivos**: 14 de código, 9 de datos, 5 de documentación y 1 informe, más los marcadores `.gitkeep`. Las 97 figuras y las 31 tablas de `outputs/` se regeneran con `Rscript run_all.R` y están excluidas por `.gitignore`, de modo que el repositorio se mantiene bajo el límite de 100 archivos de la carga por interfaz web de GitHub.

---

## Datos

Todos los datos de entrada están incluidos en `data/raw`, en UTF-8.

| Ruta | Contenido |
|---|---|
| `metadata/episodes.csv` | Llave maestra: 34 capítulos con temporada, orden, título, id de YouTube, fecha ISO y equipo de animación |
| `metadata/youtube_stats.csv` | Visualizaciones, likes, suscriptores, impresiones y CTR por capítulo |
| `dialogues_es.csv` | Transcripciones en español, una fila por capítulo |
| `dialogues_en.csv` | Traducciones al inglés, una fila por capítulo, requeridas por `sentimentr` |
| `lexicons/word_topics.csv` | 3.051 palabras clasificadas en 16 temas más "sin definir" |
| `lexicons/stopwords_extra.csv` | 450 stopwords propias del contexto, sumadas a las de `tm` |
| `dictionaries/es_ES.dic`, `.aff` | Diccionario hunspell del español |

Los cuatro archivos se unen por `episode_id`. `episodes.csv` es la única fuente de verdad: para agregar un capítulo basta con añadir una fila a cada uno de los cuatro CSV. Ningún script contiene listas de títulos, rutas ni rangos de filas escritos a mano.

Los diálogos van en dos CSV en vez de 68 archivos sueltos para mantener el repositorio bajo el límite de 100 archivos que impone la carga por interfaz web de GitHub. Cada texto ocupa una sola línea, de modo que los diffs siguen siendo legibles capítulo a capítulo.

---

## Los 16 temas

geografía, ecosistema, aprendizaje, trabajo, cultura/tradiciones, cocina, expresión artística, actividades, identidad, cotidiano, descripciones, relaciones, sentimientos, experiencias, salud/bienestar, infraestructura urbana.

Las palabras que no caen en ninguno de los 16 quedan bajo `sin definir` y se excluyen de las matrices temáticas. Cobertura efectiva: **94,1 %** de los tokens.

---

## Salidas principales

**Tablas** (`outputs/tables/`)

- `08_maestro_capitulos.csv`: una fila por capítulo con todas las métricas del pipeline
- `08_maestro_temporadas.csv`: lo mismo agregado por temporada
- `pichintun_resultados.xlsx`: 17 hojas con todo lo anterior más importancias, coeficientes y clusters
- `08_verificacion.csv`: chequeos de integridad de la corrida

**Diagnósticos** (relevantes al interpretar resultados)

- `02_diag_palabras_sin_tema.csv`: vocabulario fuera del léxico temático
- `02_diag_forzar_culturales.csv`: efecto de reclasificar palabras como culturales
- `07_resumen_modelos.csv`: R² ajustado, grados de libertad residuales y bandera de sobreparametrización

Todas las salidas se regeneran con `Rscript run_all.R` y están excluidas del control de versiones por `.gitignore`.

**Figuras** (`outputs/figures/`): nubes de palabras, gráficos de keyness, radar charts temáticos, curvas de sentimiento, dendrogramas, matrices de correlación, clusters MST-kNN y curvas de tendencia.

---

## Decisiones metodológicas

**El análisis afectivo corre sobre el inglés.** `sentimentr` solo dispone de léxicos en inglés. Los diálogos se analizan a partir de sus traducciones. Esto se hereda del diseño original y es una limitación real: la traducción puede alterar la carga afectiva, en especial en pasajes con voces indígenas sin equivalente directo.

**ARI sobre inglés, MATTR sobre español.** `quanteda` no dispone de la parametrización de ARI para español, de modo que la complejidad se mide sobre la traducción. La diversidad léxica (MATTR, ventana de 200 palabras) sí se mide sobre el español, que es donde interesa.

**Ambas métricas usan el texto sin limpiar.** ARI y MATTR requieren puntuación, mayúsculas y segmentación de oraciones intactas. El pipeline conserva el texto original en paralelo al limpiado.

**Normalización por tiempo de exposición.** Likes, suscriptores y visualizaciones se dividen por los meses transcurridos entre la publicación y la fecha de corte (`CFG$fecha_corte`, 13 de abril de 2023) antes de reescalar a [0, 1].

**Los temas entran como proporción, no como frecuencia.** Los capítulos tienen largos distintos, de modo que la frecuencia absoluta de un tema confunde presencia temática con extensión del capítulo.

---

## Advertencia sobre los modelos de popularidad

El criterio original selecciona para la regresión lineal toda variable con importancia de Random Forest sobre el 20 %. Con 34 capítulos eso deja pasar **27 predictores para Likes (6 grados de libertad residuales) y 26 para Visualizaciones (7 gl)**.

Esos dos modelos están sobreparametrizados: el R² ajustado (0,79 y 0,65) está inflado y los p-valores no son interpretables en el sentido habitual. El modelo de Suscriptores queda en 13 gl residuales, que es defendible.

El pipeline no cambia el criterio, pero lo declara: emite un `warning()` y marca la columna `sobreparametrizado` en `07_resumen_modelos.csv`. Para un análisis publicable conviene subir `CFG$umbral_importancia_rf` o aplicar regularización.

---

## Cambios respecto al código original

El punto de partida fue un único `Pichintun.Rmd` de 2.098 líneas con 61 chunks. Los cambios relevantes:

**Errores que impedían la ejecución**

1. Las fechas venían como `"Mayo 2, 2016"` y se parseaban con `as.Date(x, "%B %d, %Y")`, que depende del locale. Bajo locale C, habitual en servidores Linux, devuelve `NA` y todo el módulo de popularidad colapsaba a `NA` sin aviso. Las fechas ahora están en ISO 8601.
2. `tokenize_sentence()` (singular) no existe en el paquete `tokenizers`. La función es `tokenize_sentences()`.
3. `plotly::as.widget()` fue retirado del paquete. Las curvas de tendencia se generan ahora con `ggplot2`.
4. `if (is.na(temas_cap[i, tema]))` con índice de largo cero es error en R 4.2 o superior, no aviso.
5. Se declaraban dependencias que no estaban en el vector de instalación (`dendextend`, `amap`, `quanteda.textstats`, `quanteda.textplots`, `koRpus.lang.es`, `tibble`) y se cargaban paquetes sin usar (`xlsx`, que arrastra Java, `syuzhet`, `wordcloud2`, `varImp`).

**Errores que alteraban resultados en silencio**

6. **La canción introductoria no se eliminaba en 18 de los 34 capítulos.** El patrón se aplicaba con `stringr::fixed()` sobre una cadena cuyas tildes no coincidían con las del archivo, y dejaba residuos ("islas", "pampa", "salar") contaminando las frecuencias. Detalle relevante: la temporada 3 no incluye la canción.
7. `as.integer(labels(dend))` devolvía `NA` cuando la matriz tenía nombres de fila, y el coloreado de los dendrogramas por temporada quedaba mal asignado.
8. La reclasificación de "chile" como palabra cultural ocurría a mitad del módulo de frecuencias, **después** de calcular el porcentaje de modismos que alimenta los modelos. Nubes por temporada y Random Forest usaban particiones léxicas distintas. Ahora se aplica una sola vez, en `02_clean.R`. Efecto cuantificado: hasta 3,3 puntos porcentuales en 10 capítulos, tabla en `02_diag_forzar_culturales.csv`.

**Fragilidad estructural**

9. Los 34 capítulos se abrían con 34 llamadas `read_lines()` escritas a mano, con prefijo de archivo distinto por temporada (`C-`, `A-`, ninguno). Reemplazado por `episodes.csv` más dos CSV de diálogos unidos por `episode_id`, con validación de capítulos faltantes y de textos vacíos.
10. Los bloques de temporada estaban codificados como rangos fijos de filas (`1:6`, `7:16`, `17:26`, `27:34`) sobre un data frame ordenado por fecha. Hoy coinciden, de modo que los resultados publicados son correctos, pero agregar un capítulo los corrompía en silencio. Reemplazado por `split()` sobre la columna `season`.
11. El orden de la serie dependía del desempate alfabético que dejaba `merge()`, que no es estable entre versiones de R. Ahora es explícito: fecha y luego título.
12. Ruta absoluta `C:/Users/ekama/Documents/Pichintún/` codificada en el script. Ahora las rutas se resuelven desde la raíz del repositorio.

**Rendimiento y limpieza**

13. La asignación palabra a tema usaba `temas_palabra$tema[temas_palabra$palabra == p]` dentro de un bucle anidado, del orden de 1,2 × 10⁵ subconjuntos de data frame. Resuelto con un vector nombrado y `rowsum` por grupo.
14. Se fuerza un locale UTF-8 al inicio. Sin eso, R emite cientos de avisos `unable to translate` y degrada las etiquetas con tilde.
15. Eliminados los chunks `test`, `test32`, `test33`, `test322` y `test342`, que repetían análisis ya presentes.
16. Los tres bloques casi idénticos de Random Forest y regresión (likes, suscriptores, visualizaciones) se unificaron en una función.

---

## Reproducibilidad

Las semillas de los tres modelos Random Forest están fijas en `R/00_config.R` (`seed_likes`, `seed_subscribers`, `seed_views`). El resto del pipeline es determinista salvo la disposición de las nubes de palabras y los grafos de clustering, que son puramente visuales.

`08_export.R` corre una verificación de integridad al final y escribe `08_verificacion.csv`.

---

## Cita

Véase `CITATION.cff`.

## Licencia

Código bajo licencia MIT. Los diálogos de la serie son material de terceros incluido con fines de investigación académica. Véase `LICENSE`.
