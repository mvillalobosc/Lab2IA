# Changes from the previous analysis / Cambios respecto al análisis anterior

**EN.** This document lists every substantive change between the earlier version
of this analysis and the current pipeline, and states which published conclusions
each change affects. It exists so a reviewer can see exactly what was corrected
and why, without reading the code.

**ES.** Este documento lista cada cambio sustantivo entre la versión anterior de
este análisis y el pipeline actual, y declara qué conclusiones publicadas afecta
cada cambio. Existe para que un revisor pueda ver exactamente qué se corrigió y
por qué, sin leer el código.

---

## Summary table / Tabla resumen

| # | Issue | Affected conclusion | Status |
|---|---|---|---|
| 1 | Sentiment computed on unpunctuated text | Narrative arc | Invalidated |
| 2 | Sentiment scored with an English lexicon | All sentiment results | Invalidated |
| 3 | POS tagging on stopword-filtered text | All POS results | Invalidated |
| 4 | Emotion counts not normalised by length | All emotion results | Invalidated |
| 5 | Lexical diversity not controlled for length | 7 of 11 indices | Direction reversed |
| 6 | Readability: mixed token and sentence sources | ARI, Flesch-Kincaid | Values roughly doubled |
| 7 | Readability: English formulas on Spanish | Grade-level claims | Not interpretable |
| 8 | Clustering on TF-IDF of content words | Dendrogram | Measures series, not style |
| 9 | UMAP from a single seed | Projection figure | Not evidence of structure |
| 10 | No effect sizes, inconsistent correction | All significance claims | Understated uncertainty |
| 11 | Editorial front matter in one group only | All comparisons | Systematic bias |
| 12 | Scraper page footers in the corpus | Token counts, POS | Minor contamination |

---

## 1. Sentiment on unpunctuated text / Sentimiento sobre texto sin puntuación

**EN.** The previous `Sentimientos.R` read from `books/Papelucho_procesado/`,
whose files had all punctuation stripped. `sentimentr::get_sentences()` segments
on sentence-final punctuation, so it returned **one "sentence" per book**. The
subsequent `ntile(sentence_id, 20)` therefore produced one chunk, not twenty.
Every book's narrative arc collapsed to a single point before it was ever
plotted.

Verified empirically: `get_sentences()` on the processed *Papelucho* returns 1
segment; on the original text it returns 1,215.

**Fix.** Sentiment is computed on the raw representation. Step 05 checks that
every book yielded the requested number of segments and warns if not.

**ES.** El `Sentimientos.R` anterior leía de `books/Papelucho_procesado/`, cuyos
archivos tenían toda la puntuación eliminada. `sentimentr::get_sentences()`
segmenta por puntuación final de oración, así que devolvía **una "oración" por
libro**. El `ntile(sentence_id, 20)` posterior producía entonces un chunk, no
veinte. El arco narrativo de cada libro colapsaba a un punto antes de graficarse.

Verificado empíricamente: `get_sentences()` sobre el *Papelucho* procesado
devuelve 1 segmento; sobre el texto original devuelve 1.215.

**Corrección.** El sentimiento se calcula sobre la representación raw. El paso 05
verifica que cada libro haya producido el número pedido de segmentos y advierte si
no.

---

## 2. English lexicon on Spanish text / Léxico inglés sobre texto español

**EN.** `sentiment()` was called without a `polarity_dt` argument, which silently
defaults to the English Jockers-Rinker table.

Verified: `"me siento muy feliz y contento hoy"` scores **0.0000**; the English
equivalent `"i feel very happy and glad today"` scores **1.0205**.

**Fix.** `utils_sentiment_es.R` builds a Spanish polarity table (4,596 terms) and
65 valence shifters. A self-test runs before any analysis and aborts the script
if the lexicon fails on known Spanish cases.

**ES.** `sentiment()` se llamaba sin argumento `polarity_dt`, lo que usa en
silencio la tabla inglesa de Jockers-Rinker por defecto.

Verificado: `"me siento muy feliz y contento hoy"` puntúa **0,0000**; el
equivalente inglés `"i feel very happy and glad today"` puntúa **1,0205**.

**Corrección.** `utils_sentiment_es.R` construye una tabla de polaridad en español
(4.596 términos) y 65 valence shifters. Un autotest corre antes de cualquier
análisis y aborta el script si el léxico falla en casos españoles conocidos.

---

## 3. POS tagging on filtered text / Etiquetado POS sobre texto filtrado

**EN.** `Palabras.R` tagged `books/*_procesado/`, from which Spanish stopwords
had been removed. Since the Spanish stopword list is almost entirely function
words, the resulting profile describes the stopword list, not the text.

Measured on the same book, raw versus filtered:

| Category | Raw | Filtered | Distortion |
|---|---|---|---|
| ADP | 10.8% | 0.5% | ÷22 |
| CCONJ | 7.2% | 0.1% | ÷72 |
| PRON | 13.4% | 2.7% | ÷5 |
| DET | 11.1% | 2.6% | ÷4 |
| SCONJ | 7.0% | 1.0% | ÷7 |
| ADJ | 3.6% | 16.7% | ×4.6 |
| NOUN | 15.2% | 27.6% | ×1.8 |
| VERB | 17.5% | 33.5% | ×1.9 |

**Fix.** Step 04 tags the raw text. Sentence-level sampling to a fixed token
budget keeps runtime bounded and equalises the contribution of each book.

**ES.** `Palabras.R` etiquetaba `books/*_procesado/`, de donde se habían quitado
las stopwords del español. Como la lista de stopwords del español es casi
enteramente palabras funcionales, el perfil resultante describe la lista de
stopwords, no el texto.

**Corrección.** El paso 04 etiqueta el texto crudo. El muestreo por oraciones
hasta un presupuesto fijo de tokens acota el tiempo de ejecución e iguala la
contribución de cada libro.

---

## 4. Emotion counts not normalised / Conteos emocionales sin normalizar

**EN.** `Emociones.R` fed the raw output of `get_nrc_sentiment()` — absolute
counts — into `wilcox.test()`. With a median of 102,000 running tokens in the
comparison group against 19,000 in Papelucho, the comparison group wins all eight
emotions by construction. No multiple-testing correction was applied either.

**Fix.** Counts are expressed per 1,000 running tokens. A relative emotion
profile (each book's eight emotions rescaled to sum to one) is reported alongside.
Holm correction is applied once across the family of ten tests. The raw-count
analysis is reproduced in `06_emotions_results_rawcount.csv` solely to document
the size of the artefact.

**ES.** `Emociones.R` metía la salida cruda de `get_nrc_sentiment()` — conteos
absolutos — a `wilcox.test()`. Con una mediana de 102.000 tokens corrientes en el
grupo de comparación contra 19.000 en Papelucho, el grupo de comparación gana las
ocho emociones por construcción. Tampoco se aplicaba corrección por pruebas
múltiples.

**Corrección.** Los conteos se expresan por cada 1.000 tokens corrientes. Se
reporta además un perfil emocional relativo. La corrección de Holm se aplica una
vez sobre la familia de diez pruebas.

---

## 5. Lexical diversity not length-controlled / Diversidad léxica sin controlar largo

**EN.** This is the change that most affects the published conclusions.

The previous `complexity_readability_results.csv` reported TTR as significantly
**higher** in Papelucho (p = 1.7e-7). But RTTR and CTTR pointed the opposite way
in the same table, and MTLD — the index specifically designed to be
length-robust — was not significant (p = 0.19). That internal contradiction is the
signature of a length artefact.

Under fixed-size resampling (5,000 content tokens, 30 replicates per book), seven
of eleven indices change conclusion, and four reverse direction outright:

| Index | Whole text | Length-controlled |
|---|---|---|
| TTR | higher in Papelucho | **higher in Comparison** |
| Herdan's C | higher in Papelucho | **higher in Comparison** |
| Maas | higher in Comparison | **higher in Papelucho** |
| Hapax ratio | higher in Papelucho | **higher in Comparison** |
| MATTR | not significant | significant |
| MTLD | not significant | significant |
| Shannon's H | significant | not significant |

The corrected result is consistent across every index: Papelucho shows **lower**
lexical diversity than the comparison corpus, with large effect sizes. This is
what one would expect of children's literature, and it is the opposite of what the
draft reported.

**ES.** Este es el cambio que más afecta las conclusiones publicadas.

El `complexity_readability_results.csv` anterior reportaba la TTR como
significativamente **mayor** en Papelucho (p = 1,7e-7). Pero RTTR y CTTR apuntaban
al lado opuesto en la misma tabla, y MTLD — el índice diseñado específicamente
para ser robusto al largo — no era significativo (p = 0,19). Esa contradicción
interna es la firma de un artefacto de largo.

Bajo remuestreo de tamaño fijo, siete de once índices cambian de conclusión y
cuatro invierten de dirección. El resultado corregido es consistente en todos los
índices: Papelucho muestra diversidad léxica **menor** que el corpus de
comparación, con tamaños de efecto grandes.

---

## 6. Readability computed from mixed sources / Legibilidad con fuentes mezcladas

**EN.** `Complejidad.R` computed `words_per_sentence` as tokens from the
**stopword-filtered** text divided by sentences from the **original** text. Since
stopword removal discards roughly 55% of running words, every words-per-sentence
figure was slightly under half its true value, and both ARI and Flesch-Kincaid
inherited the error.

Measured: the previous table reported ~7.6 words per sentence for Papelucho; the
correct value is 11.7 to 19.4 depending on the book.

**Fix.** Every quantity in every formula comes from the same raw representation.

**ES.** `Complejidad.R` calculaba `words_per_sentence` como tokens del texto
**filtrado por stopwords** dividido por oraciones del texto **original**. Como el
filtrado descarta cerca del 55% de las palabras corrientes, toda cifra quedaba en
algo menos de la mitad de su valor real, y tanto ARI como Flesch-Kincaid heredaban
el error.

Medido: la tabla anterior reportaba ~7,6 palabras por oración para Papelucho; el
valor correcto va de 11,7 a 19,4 según el libro.

---

## 7. English readability formulas on Spanish / Fórmulas inglesas sobre español

**EN.** ARI and Flesch-Kincaid were fitted on English school texts. Spanish
carries roughly 15–20% more syllables per word for the same conceptual
difficulty, so the English coefficients inflate estimated grade level by several
years. The inflation is roughly constant, so text rankings survive, but the
absolute values cannot be reported as grade levels for Spanish readers.

**Fix.** Four Spanish-validated formulas are used: Fernández Huerta,
Szigriszt-Pazos with INFLESZ bands, Gutiérrez de Polini, and the Mu index. The
English formulas are still computed and clearly labelled for traceability.

**New finding.** With the corrected computation, the difference between the two
corpora is driven by **word length, not sentence length**:

| Measure | Papelucho | Comparison | Cliff's δ | Magnitude |
|---|---|---|---|---|
| Words per sentence | 13.2 | 14.8 | −0.019 | negligible |
| SD of words per sentence | 9.4 | 10.3 | −0.135 | negligible |
| % long sentences | 10.3 | 13.7 | −0.106 | negligible |
| **Letters per word** | **4.21** | **4.62** | **−1.000** | **large** |
| **Syllables per word** | **1.85** | **1.98** | **−1.000** | **large** |
| Gutiérrez de Polini | 49.8 | 45.7 | **1.000** | large |

A Cliff's delta of 1.000 means **perfect separation**: every Papelucho book uses
shorter words than every comparison book, with no overlap. Sentence length
distinguishes nothing.

**ES.** ARI y Flesch-Kincaid se ajustaron sobre textos escolares en inglés. El
español tiene entre 15 y 20% más sílabas por palabra para la misma dificultad
conceptual. Se usan cuatro fórmulas validadas para el español.

**Hallazgo nuevo.** Con el cálculo corregido, la diferencia entre los dos corpus
está impulsada por el **largo de palabra, no el de oración**. Un Cliff's delta de
1,000 significa **separación perfecta**: todos los libros de Papelucho usan
palabras más cortas que todos los libros de comparación, sin solapamiento.

---

## 8. Clustering on TF-IDF content words / Agrupamiento sobre TF-IDF de contenido

**EN.** `Dendograma.R` clustered on correlation distance over the 500 highest
TF-IDF terms of the stopword-filtered text. TF-IDF by construction rewards terms
appearing in few documents; in a corpus of novels those are character and place
names. The resulting dendrogram recovers which books share a cast — a fact about
series membership, not style. It would look identical if every book had the same
author.

**Fix.** Step 07 uses Burrows's Delta on the 300 most frequent words including
function words, with 1,000 bootstrap replicates for branch support. The TF-IDF
analysis is retained as a labelled sensitivity check, and
`07_method_comparison.csv` quantifies how much more strongly TF-IDF tracks series
membership than Delta does.

**ES.** `Dendograma.R` agrupaba por distancia de correlación sobre los 500
términos de mayor TF-IDF del texto filtrado. TF-IDF premia términos que aparecen
en pocos documentos; en un corpus de novelas esos son nombres de personajes y
lugares. El dendrograma resultante recupera qué libros comparten elenco, no
estilo.

**Corrección.** El paso 07 usa Burrows's Delta sobre las 300 palabras más
frecuentes incluyendo funcionales, con 1.000 réplicas bootstrap para el soporte de
ramas.

---

## 9. UMAP from a single seed / UMAP de una sola semilla

**EN.** `UMAP.R` ran `set.seed(123)` once and plotted the result. UMAP is
stochastic; with 75 points a single run can produce a visually convincing
separation that vanishes under a different seed. One plot from one seed is one
draw from a distribution of possible pictures, not evidence of structure.

**Fix.** Step 08 runs UMAP across five seeds × three neighbour settings × three
min-distance settings, reporting neighbourhood preservation and group silhouette
for every run, benchmarked against the silhouette in the original Delta space. A
seed-stability panel is exported for supplementary material. UMAP is used for
display only; every statistical claim rests on the distance matrix.

**ES.** `UMAP.R` corría `set.seed(123)` una vez y graficaba el resultado. UMAP es
estocástico; con 75 puntos una sola corrida puede producir una separación
visualmente convincente que desaparece con otra semilla.

**Corrección.** El paso 08 corre UMAP sobre cinco semillas × tres configuraciones
de vecinos × tres de distancia mínima. UMAP se usa solo para visualizar.

---

## 10. No effect sizes, inconsistent correction / Sin tamaños de efecto

**EN.** `Complejidad.R` applied Holm correction; `Palabras.R` and `Emociones.R`
applied none. No analysis reported an effect size. With n = 12 versus n = 63, a
significant p-value says almost nothing about how large a difference is.

**Fix.** Every comparison reports Cliff's delta with a bootstrap 95% CI and the
rank-biserial correlation. Holm correction is applied once per family of tests. A
result is called significant only when the adjusted p-value is below 0.05 **and**
the effect size is at least small. Results that are significant with a negligible
effect are flagged rather than silently reported.

**ES.** `Complejidad.R` aplicaba corrección de Holm; `Palabras.R` y `Emociones.R`
no aplicaban ninguna. Ningún análisis reportaba tamaño de efecto.

**Corrección.** Cada comparación reporta Cliff's delta con IC bootstrap del 95% y
la correlación rango-biserial.

---

## 11. Editorial front matter in one group only / Paratexto en un solo grupo

**EN.** 62 of 63 comparison files open with editorial paratext (original title,
translator, publisher, copyright, ISBN). None of the 12 Papelucho files do. This
gives the comparison group a block of non-narrative text in a different register,
containing English or German source titles and publisher proper nouns, which
inflates its type count and distorts its POS profile. Because the asymmetry
affects one group only, it biases every comparison in the same direction.

**Fix.** Step 01 removes front matter, but only when the file gives positive
evidence of it: a strong bibliographic marker, or a line reproducing the title or
author from the metadata. A cap at 3% of the file prevents runaway deletion.
Everything removed is logged with a preview in `01_corpus_qa.csv`.

**Note on a bug found during development.** An earlier version of this detector
classified any short line without final punctuation as paratext. Because several
Papelucho source files are hard-wrapped at ~50 characters, that rule deleted the
opening narrative paragraphs of four books. The positive-evidence gate exists
specifically to make that class of error impossible, and the current detector
removes only 4 lines total across all 12 Papelucho files (the title and author
lines of one book).

**ES.** 62 de 63 archivos de comparación abren con paratexto editorial. Ninguno de
los 12 de Papelucho lo hace. Como la asimetría afecta a un solo grupo, sesga toda
comparación en la misma dirección.

**Corrección.** El paso 01 elimina el paratexto, pero solo cuando el archivo da
evidencia positiva de él. Un tope del 3% del archivo evita eliminaciones
desbocadas.

**Nota sobre un bug encontrado durante el desarrollo.** Una versión anterior de
este detector clasificaba como paratexto cualquier línea corta sin puntuación
final. Como varios archivos fuente de Papelucho están cortados a ~50 caracteres,
esa regla borró los párrafos narrativos iniciales de cuatro libros. La compuerta
de evidencia positiva existe justamente para volver imposible esa clase de error.

---

## 12. Scraper page footers / Pies de página de scraper

**EN.** Two Papelucho files carry more than forty instances each of
`www.lectulandia.com - Página N`, injected at every page break by the ebook site
they were downloaded from. Three comparison files carry a handful. These lines
contribute a repeated non-narrative n-gram, add a false sentence boundary in the
middle of a paragraph, and inflate proper-noun and numeral counts in the POS
profile.

**Fix.** Step 01 removes them throughout the file, before front matter detection.
The pattern is anchored to whole lines so a URL inside the narrative is untouched.

**ES.** Dos archivos de Papelucho traen más de cuarenta instancias cada uno de
`www.lectulandia.com - Página N`, inyectadas en cada salto de página por el sitio
de ebooks del que se bajaron. Tres archivos de comparación traen unas pocas.

**Corrección.** El paso 01 las elimina en todo el archivo, antes de la detección
de paratexto.

---

## Two implementation bugs found during development

**EN.** Both were caught by auditing before delivery, and both are documented in
the code where they occurred.

1. **MATTR was too slow to run.** The naive rolling implementation took 0.74 s per
   replicate, which for 30 replicates × 75 books is 28 minutes. It was
   reimplemented in linear time using a difference array over the ranges where
   each token counts as a new type. The fast version was verified to return
   values **identical** to the naive one on samples from this corpus, and is
   about 250× faster.

2. **A `dplyr::summarise()` shadowing bug silently returned NA.** Writing
   `mean_sentiment = mean(mean_sentiment)` creates a column that shadows the
   source column for every expression that follows, so the subsequent
   `sd(mean_sentiment)` computed the standard deviation of a single scalar and
   returned NA for every book. The per-segment column was renamed to
   `chunk_sentiment`, and step 05 now aborts if per-book variability collapses.

**ES.** Los dos se detectaron auditando antes de entregar, y ambos están
documentados en el código donde ocurrieron.

1. **MATTR era demasiado lento para correr.** La implementación rodante ingenua
   tomaba 0,74 s por réplica, que para 30 réplicas × 75 libros son 28 minutos. Se
   reimplementó en tiempo lineal con un arreglo de diferencias. La versión rápida
   se verificó **idéntica** a la ingenua sobre muestras de este corpus, y es unas
   250× más rápida.

2. **Un bug de shadowing en `dplyr::summarise()` devolvía NA en silencio.**
   Escribir `mean_sentiment = mean(mean_sentiment)` crea una columna que ensombrece
   a la fuente para toda expresión posterior, así que el `sd(mean_sentiment)`
   siguiente calculaba la desviación estándar de un solo escalar y devolvía NA en
   todos los libros. La columna por segmento se renombró a `chunk_sentiment`, y el
   paso 05 ahora aborta si la variabilidad por libro colapsa.
