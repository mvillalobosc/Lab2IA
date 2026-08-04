# Análisis de text mining de la serie Papelucho

**Español** · [English](README.md)

Análisis computacional reproducible de patrones léxicos, estructurales y emocionales en la serie *Papelucho* de Marcela Paz (12 libros, 1947–1974), comparada contra un corpus de 63 novelas en español.

---

## Qué contiene este repositorio

Un pipeline de nueve pasos en R que arma un corpus curado, calcula diversidad léxica, legibilidad, perfiles morfosintácticos, sentimiento, emoción y distancias estilométricas, y después pone a prueba cada hallazgo contra los desbalances estructurales del corpus de comparación.

Cada tabla se exporta tres veces: un CSV legible por máquina, una tabla LaTeX en inglés y una en español.

---

## Inicio rápido

```bash
# 1. Instalar dependencias de R
Rscript -e 'install.packages(c(
  "dplyr","tidyr","readr","purrr","tibble","stringr","stringi",
  "ggplot2","tidytext","stopwords","udpipe","sentimentr","syuzhet",
  "zoo","ggdendro","ggrepel","uwot","cluster","scales"))'

# 2. Descargar el modelo POS del español (28 MB, no versionado en git)
Rscript scripts/download_udpipe_model.R

# 3. Poner los archivos de texto del corpus (ver docs/CORPUS.md)
#    data/raw/papelucho/*.txt   12 archivos
#    data/raw/comparison/*.txt  63 archivos

# 4. Correr todo
Rscript run_all.R

# ...o un solo paso
Rscript run_all.R 02
```

Antes de una corrida larga, o antes de un commit, la auditoría estática detecta
llamadas a funciones que no resuelven y shadowing silencioso en `summarise()` sin
ejecutar nada:

```bash
Rscript scripts/audit_pipeline.R
```

El tiempo de ejecución ronda una hora en un solo núcleo, dominado por el paso 04 (etiquetado POS) y el paso 05 (sentimiento por oración).

---

## Pipeline

| Paso | Script | Qué hace |
|---|---|---|
| 01 | `01_build_corpus.R` | Valida el metadata contra el disco, elimina pies de scraper y paratexto editorial, arma las representaciones raw y content, escribe un reporte de control de calidad |
| 02 | `02_lexical_diversity.R` | Once índices de diversidad bajo remuestreo de tamaño fijo para controlar el largo del texto |
| 03 | `03_readability.R` | Complejidad estructural más cuatro fórmulas de legibilidad validadas para el español |
| 04 | `04_pos_analysis.R` | Perfiles morfosintácticos desde el texto crudo, con muestreo de oraciones hasta un presupuesto fijo de tokens |
| 05 | `05_sentiment.R` | Sentimiento por oración con léxico español; arcos narrativos de 20 segmentos |
| 06 | `06_emotions.R` | Perfiles emocionales NRC normalizados por cada 1.000 tokens |
| 07 | `07_stylometry.R` | Agrupamiento con Burrows's Delta y soporte bootstrap de ramas |
| 08 | `08_umap.R` | Proyección UMAP con evaluación de estabilidad multi-semilla |
| 09 | `09_sensitivity.R` | Vuelve a probar cada hallazgo bajo tres diseños restringidos de corpus |

---

## Decisiones metodológicas

Este pipeline reemplaza una versión anterior del análisis. Los cambios de abajo no son preferencias de estilo; cada uno corrige un error específico que cambió una conclusión publicada. Quedan documentados acá y en el comentario de encabezado de cada script.

### 1. Dos representaciones del texto, nunca mezcladas

El pipeline mantiene dos versiones de cada libro:

- **raw** — puntuación, mayúsculas y palabras funcionales intactas. Se usa para legibilidad, etiquetado POS y sentimiento.
- **content** — palabras de contenido en minúscula, sin stopwords. Se usa solo para diversidad léxica y estilometría.

El análisis anterior las mezclaba: los conteos de oraciones salían del texto crudo mientras que los conteos de tokens salían del texto filtrado. Como el filtrado descarta cerca del 55% de las palabras corrientes, toda cifra de palabras por oración quedaba en algo menos de la mitad de su valor real, y los dos índices de legibilidad heredaban el error.

### 2. Control de largo por remuestreo

Los libros de Papelucho tienen una mediana de ~19.000 tokens corrientes. Las novelas de comparación tienen una mediana de ~102.000. Casi toda medida clásica de riqueza léxica baja cuando el texto crece, así que la comparación cruda mide largo de libro y lo reporta como estilo.

Todo índice sensible al largo se calcula sobre muestras aleatorias de un número fijo de tokens, repetidas 30 veces por libro y promediadas. Los valores de texto completo también se reportan para que el tamaño del artefacto quede a la vista.

**Esto cambia conclusiones.** Siete de once índices cambian de dirección o de significancia al controlar el largo. TTR, C de Herdan, Maas y la proporción de hapax **invierten de dirección**.

### 3. Fórmulas de legibilidad validadas para el español

Flesch-Kincaid y ARI se ajustaron sobre textos escolares en inglés. El español tiene entre 15 y 20% más sílabas por palabra para la misma dificultad conceptual, así que los coeficientes ingleses inflan el nivel escolar estimado en varios años.

En su lugar se usan cuatro fórmulas españolas: Fernández Huerta (1959), Szigriszt-Pazos (1993) con las bandas interpretativas INFLESZ, Gutiérrez de Polini (1972) y el índice mu (Muñoz y Muñoz, 2006). Gutiérrez de Polini es la única calibrada específicamente sobre material para niños. Las fórmulas inglesas se siguen calculando y quedan claramente etiquetadas, para que los valores anteriores sigan siendo trazables.

### 4. Etiquetado POS sobre texto crudo

En español la lista de stopwords se compone casi por completo de palabras funcionales. Etiquetar un texto sin ellas no mide el perfil gramatical del texto: mide lo que la lista de stopwords contenga.

Etiquetando el mismo libro de las dos formas:

| Categoría | Texto crudo | Filtrado por stopwords | Distorsión |
|---|---|---|---|
| ADP (adposiciones) | 10,8% | 0,5% | ÷22 |
| CCONJ | 7,2% | 0,1% | ÷72 |
| PRON | 13,4% | 2,7% | ÷5 |
| ADJ | 3,6% | 16,7% | ×4,6 |
| VERB | 17,5% | 33,5% | ×1,9 |

La frecuencia de pronombres es una de las pocas medidas que habla directamente de un narrador infantil en primera persona, que es el rasgo formal definitorio de la serie. Filtrar los pronombres antes de etiquetar descarta justamente la evidencia que el estudio necesita.

### 5. Léxico de sentimiento en español con autotest

`sentimentr::sentiment()` llamado sin argumentos usa en silencio una tabla de polaridad **inglesa** por defecto. Sobre entrada en español puntúa casi todo en cero. Puntuar *"me siento muy feliz y contento hoy"* con la tabla por defecto devuelve exactamente **0,00**; el equivalente en inglés devuelve 1,02.

A eso se sumaba que el pipeline anterior calculaba el sentimiento sobre texto al que ya se le había quitado la puntuación, así que `get_sentences()` devolvía **una "oración" por libro** y el arco narrativo de 20 segmentos colapsaba a un solo punto.

Este pipeline construye una tabla de polaridad en español (4.596 términos de la lista NRC en español) más 65 valence shifters que cubren negación, amplificación, desamplificación y adversativos. Un autotest corre antes de cualquier análisis y **detiene el script** si el léxico no está puntuando bien el español, de modo que el modo de falla silenciosa no pueda repetirse.

### 6. Conteos emocionales normalizados por largo

`get_nrc_sentiment()` devuelve conteos absolutos. Meterlos a una prueba entre grupos cuando los libros de un grupo son cinco veces más largos produce ocho resultados "significativos" por construcción. Ahora los conteos se expresan por cada 1.000 tokens corrientes, y la corrección de Holm se aplica una vez sobre toda la familia.

### 7. Burrows's Delta en vez de agrupamiento TF-IDF

TF-IDF premia términos que aparecen en pocos documentos. En un corpus de novelas esos son nombres de personajes y lugares, así que un dendrograma TF-IDF recupera **qué libros comparten elenco**, un hecho sobre pertenencia a una serie, no sobre estilo. Burrows's Delta trabaja sobre las palabras más frecuentes incluyendo las funcionales, que es donde el estilo autoral efectivamente vive.

El soporte de las ramas se estima remuestreando el conjunto de rasgos 1.000 veces. Las ramas bajo ~70% de soporte no deberían interpretarse. El análisis TF-IDF se conserva como chequeo de sensibilidad etiquetado, y `07_method_comparison.csv` cuantifica cuánto más fuerte sigue TF-IDF la pertenencia a la serie.

### 8. Estabilidad de UMAP en vez de una proyección

UMAP es estocástico. Con 75 puntos, una sola corrida puede producir una separación visualmente convincente que desaparece con otra semilla. Publicar un gráfico de una semilla es un sorteo de una distribución de imágenes posibles, no evidencia de estructura.

UMAP se corre sobre cinco semillas × tres configuraciones de vecinos × tres de distancia mínima. Se reportan dos cantidades: preservación de vecindario (¿la proyección es fiel del todo?) y silueta de grupo (¿la separación se sostiene?), ambas contrastadas contra la silueta en el espacio original de Delta. **UMAP se usa solo para visualizar**: toda afirmación estadística se apoya en la matriz de distancias, nunca en coordenadas de la proyección.

### 9. Tamaños de efecto junto a cada valor p

Con n = 12 contra n = 63, un valor p significativo dice casi nada sobre qué tan grande es una diferencia. Cada comparación reporta Cliff's delta con IC bootstrap del 95% y la correlación rango-biserial. Un resultado se declara significativo solo si el p ajustado está bajo 0,05 **y** el tamaño de efecto es al menos pequeño.

---

## Composición del corpus: leer esto antes de interpretar cualquier cosa

El corpus de comparación tiene tres desbalances estructurales que ningún ajuste estadístico puede eliminar del todo.

| Problema | Magnitud |
|---|---|
| Concentración de autoría | R. A. Salvatore aporta 16 de 63 libros (25,4%); los 5 autores principales aportan 38 |
| Traducción | 60 de 63 libros de comparación son traducciones; Papelucho es español chileno original |
| Público objetivo | La mayoría de los libros de comparación son ficción adulta; Papelucho es literatura infantil |

Mann-Whitney asume observaciones independientes. Dieciséis novelas de un mismo autor que comparten ambientación y voz narrativa no son dieciséis extracciones independientes, así que los valores p sobre el corpus completo son anticonservadores. La prosa traducida además difiere sistemáticamente de la prosa original en la lengua meta (los *universales de traducción* documentados en los estudios de traducción), así que las diferencias léxicas pueden ser efectos de traducción y no efectos Papelucho.

**El paso 09 vuelve a probar cada hallazgo bajo tres diseños restringidos:** público emparejado, solo español original, y un libro por autor repetido 200 veces. Un hallazgo que sobrevive a los tres es robusto a la composición del corpus. Un hallazgo que aparece solo en el corpus completo es una afirmación sobre cómo se armó el grupo de comparación.

Si los hallazgos principales no sobreviven al paso 09, hay que reconstruir el corpus. Ninguna cantidad de estadística cuidadosa arregla un grupo de comparación que difiere en más aspectos que el estudiado.

---

## Limitaciones conocidas

- **El conteo de sílabas** es por reglas (conteo de grupos vocálicos con corrección de hiatos). La exactitud contra español revisado a mano ronda el 96%, suficiente para índices a nivel de corpus pero no para afirmaciones a nivel de palabra.
- **El léxico NRC en español** es una traducción automática del original inglés. Hereda errores de traducción y no cubre el uso chileno, lo que importa en un corpus de literatura infantil chilena.
- **El léxico NRC asigna emociones fuera de contexto.** La ironía, la negación y el lenguaje figurado le son invisibles. Para un narrador cuyo humor depende de decir lo contrario de lo que quiere decir, esto es una restricción real.
- **No existe lista publicada de valence shifters en español para `sentimentr`.** La de `utils_sentiment_es.R` se armó desde la gramática estándar de la negación y la modificación de grado del español. No está validada externamente.
- **Los resultados de sentimiento deben leerse como una señal gruesa**, no como una medición precisa.

---

## Estructura del repositorio

```
├── R/
│   ├── 00_config.R              Rutas, parámetros, etiquetas bilingües, chequeo de dependencias
│   ├── utils_text.R             Normalización, segmentación en oraciones, conteo de sílabas
│   ├── utils_stats.R            Cliff's delta, IC bootstrap, corrección por pruebas múltiples
│   ├── utils_io.R               Exportación CSV + LaTeX bilingüe, guardado de figuras
│   ├── utils_sentiment_es.R     Tabla de polaridad y valence shifters en español
│   └── 01_…09_*.R               Pasos de análisis
├── data/
│   ├── metadata/corpus_metadata.csv   Curado: autor, serie, año, público, idioma
│   ├── raw/                     Textos de los libros (no versionados; ver docs/CORPUS.md)
│   └── derived/                 Intermedios del pipeline (se regeneran)
├── outputs/
│   ├── tables/                  CSV + *_en.tex + *_es.tex
│   ├── figures/                 PDF (vectorial) + PNG (300 dpi)
│   └── logs/                    sessionInfo por paso, tiempos del pipeline
├── scripts/
│   ├── download_udpipe_model.R
│   └── audit_pipeline.R         Chequeos estáticos: llamadas, shadowing, etiquetas
├── docs/
├── run_all.R
└── LICENSE
```

---

## Reproducibilidad

- Toda la aleatoriedad se siembra desde `PARAMS$seed` en `R/00_config.R`.
- `sessionInfo()` se escribe en `outputs/logs/` para cada paso.
- El modelo UDPipe queda fijado a `spanish-gsd-ud-2.5-191206`, no resuelto por la cadena genérica `"spanish"`, que puede cambiar entre versiones del paquete y alteraría en silencio los resultados del etiquetado.
- Se fuerza un locale UTF-8 al inicio; `LC_COLLATE=C` mantiene el orden de archivos estable a nivel de bytes entre máquinas.

---

## Disponibilidad del corpus

Los textos de los libros están protegidos por derechos de autor y **no** se distribuyen con este repositorio. `data/metadata/corpus_metadata.csv` lista cada título, autor y edición para que el corpus pueda reconstruirse. Ver `docs/CORPUS.md`.

---

## Cita

```bibtex
@misc{papelucho_textmining,
  author = {Villalobos-Pérez, Sebastián and Chourio-Acevedo, Luz and
            Leiva-Lobos, Edmundo and Villalobos-Cid, Manuel},
  title  = {A text mining analysis of the Papelucho series},
  year   = {2026},
  note   = {Departamento de Ingeniería Informática, Universidad de Santiago de Chile}
}
```

## Licencia

Código bajo licencia MIT. Los textos del corpus no están cubiertos por esta licencia y no se distribuyen acá.

---

## Publicar en GitHub

El repositorio son **97 archivos** y sube de una, incluso arrastrando y soltando
en github.com, que acepta como máximo 100 archivos por vez.

```bash
git init
git add .
git commit -m "Análisis de text mining de la serie Papelucho"
git branch -M main
git remote add origin https://github.com/<usuario>/papelucho-textmining.git
git push -u origin main
```

`run_all.R` llama a `scripts/bundle_outputs.R` al final para mantener bajo el
conteo: las 54 tablas LaTeX individuales se juntan en `tables_en.tex` y
`tables_es.tex`, los nueve `sessionInfo` en `session_info.txt`, se descartan las
vistas previas PNG a favor de las versiones vectoriales en PDF, y se eliminan
cuatro CSV intermedios por réplica. Todo lo eliminado se regenera volviendo a
correr el pipeline. Para conservarlo todo, borrar los bloques correspondientes de
`scripts/bundle_outputs.R`; el repositorio queda con unos 180 archivos, que git
maneja sin problema pero que hay que subir desde la terminal.
