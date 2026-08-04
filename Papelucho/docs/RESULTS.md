# Key results / Resultados principales

**EN.** Summary of what the corrected pipeline finds, with the conclusion each
result replaces. Every number here is reproduced by `Rscript run_all.R`; the
tables cited are in `outputs/tables/`.

**ES.** Resumen de lo que encuentra el pipeline corregido, con la conclusión que
reemplaza cada resultado. Todo número de acá se reproduce con `Rscript run_all.R`;
las tablas citadas están en `outputs/tables/`.

---

## 1. Corpus

| | Papelucho | Comparison |
|---|---|---|
| Books / Libros | 12 | 63 |
| Running tokens / Tokens corrientes | 227,125 | 6,585,686 |
| Median per book / Mediana por libro | 18,629 | 102,138 |
| Range / Rango | 13,685–25,456 | 9,619–253,615 |

**EN.** The comparison novels are about 5.5× longer at the median. This ratio
drives most of the artefacts corrected below.

**ES.** Las novelas de comparación son unas 5,5× más largas en la mediana. Esta
razón produce la mayoría de los artefactos corregidos abajo.

Cleaning applied in step 01 / Limpieza aplicada en el paso 01:

- Scraper page footers removed from 5 files (2 Papelucho, 3 comparison).
  *Pies de página de scraper eliminados de 5 archivos.*
- Editorial front matter removed from 62 of 63 comparison files and 1 of 12
  Papelucho files (4 lines total: title and author of `PAP06`).
  *Paratexto editorial eliminado de 62 de 63 archivos de comparación y 1 de 12 de
  Papelucho (4 líneas en total).*

---

## 2. Lexical diversity: the published direction reverses

**EN.** The previous draft reported TTR significantly **higher** in Papelucho
(p = 1.7e-7). Under fixed-size resampling (5,000 content tokens × 30 replicates
per book), seven of eleven indices change conclusion and four reverse direction.

**ES.** El borrador anterior reportaba la TTR significativamente **mayor** en
Papelucho (p = 1,7e-7). Bajo remuestreo de tamaño fijo, siete de once índices
cambian de conclusión y cuatro invierten de dirección.

| Index | Papelucho | Comparison | Cliff's δ | p (adj) | Higher in |
|---|---|---|---|---|---|
| TTR | 0.4747 | 0.5027 | −0.683 | 0.002 | Comparison |
| RTTR | 33.57 | 35.55 | −0.683 | 0.002 | Comparison |
| Herdan's C | 0.9125 | 0.9192 | −0.683 | 0.002 | Comparison |
| MATTR | 0.9292 | 0.9468 | −0.728 | <0.001 | Comparison |
| MTLD | 676.1 | 973.6 | −0.783 | <0.001 | Comparison |
| Hapax ratio | 0.6547 | 0.6959 | −0.923 | <0.001 | Comparison |
| Yule's K | 12.30 | 12.37 | −0.090 | 1.000 | — |
| Shannon's H | 7.295 | 7.345 | −0.413 | 0.074 | — |

Direction reversals / Inversiones de dirección: **TTR, Herdan's C, Maas, hapax ratio**.

**EN.** The corrected result is internally consistent across every index:
Papelucho shows **lower** lexical diversity, with large effect sizes. That is what
one expects of children's literature. The earlier contradiction — TTR significant
one way while RTTR, CTTR and MTLD pointed the other — was the signature of the
length artefact.

**ES.** El resultado corregido es internamente consistente en todos los índices:
Papelucho muestra diversidad léxica **menor**, con tamaños de efecto grandes.

`02_lexical_results_controlled.csv`, `02_lexical_contrast.csv`

---

## 3. Readability: word length, not sentence length

**EN.** This is the clearest finding in the project and it is new. Sentence-level
structure does not distinguish the two corpora at all. Word length separates them
perfectly.

**ES.** Este es el hallazgo más claro del proyecto y es nuevo. La estructura
oracional no distingue en nada a los dos corpus. El largo de palabra los separa
perfectamente.

| Measure | Papelucho | Comparison | Cliff's δ | Magnitude |
|---|---|---|---|---|
| Words per sentence | 13.22 | 14.77 | −0.019 | negligible |
| SD of words per sentence | 9.35 | 10.28 | −0.135 | negligible |
| Median words per sentence | 11.0 | 11.0 | 0.053 | negligible |
| Short sentences (%) | 42.6 | 41.5 | −0.077 | negligible |
| Long sentences (%) | 10.3 | 13.7 | −0.106 | negligible |
| **Letters per word** | **4.21** | **4.62** | **−1.000** | **large** |
| **Syllables per word** | **1.85** | **1.98** | **−1.000** | **large** |
| Fernández Huerta | 82.4 | 74.0 | 0.976 | large |
| Szigriszt-Pazos | 78.4 | 69.6 | 0.979 | large |
| **Gutiérrez de Polini** | **49.8** | **45.7** | **1.000** | **large** |
| Mu index | 70.3 | 64.9 | 0.852 | large |

**EN.** A Cliff's delta of **1.000** is perfect separation: every Papelucho book
uses shorter words than every comparison book, with no overlap. Gutiérrez de
Polini — the only formula in this set calibrated on material for children — also
separates the corpora perfectly.

INFLESZ bands: the single book in the corpus falling in the *very easy* band is a
Papelucho title. No Papelucho book falls below *fairly easy*.

**ES.** Un delta de Cliff de **1,000** es separación perfecta: todos los libros de
Papelucho usan palabras más cortas que todos los libros de comparación, sin
solapamiento.

Bandas INFLESZ: el único libro del corpus en la banda *muy fácil* es un título de
Papelucho.

`03_readability_results.csv`, `03_inflesz_bands.csv`

---

## 4. Part of speech: three near-perfect separations

**EN.** Computed on the raw text, 1,766,972 tokens tagged. These are the
strongest results in the project, and all three were invisible in the previous
analysis, which tagged text with the function words already removed.

**ES.** Calculado sobre el texto crudo, 1.766.972 tokens etiquetados. Son los
resultados mas fuertes del proyecto, y los tres eran invisibles en el analisis
anterior, que etiquetaba texto con las palabras funcionales ya eliminadas.

| Category | Papelucho | Comparison | Cliff's δ | p (adj) | Higher in |
|---|---|---|---|---|---|
| **CCONJ** (coordinating conj.) | **6.64%** | **3.96%** | **1.000** | <0.001 | **Papelucho** |
| **ADP** (adpositions) | **12.41%** | **14.36%** | **−0.987** | <0.001 | **Comparison** |
| **PRON** (pronouns) | **11.20%** | **8.15%** | **0.963** | <0.001 | **Papelucho** |
| SCONJ (subordinating conj.) | 4.45% | 3.58% | 0.807 | <0.001 | Papelucho |
| VERB | 16.85% | 15.38% | 0.796 | <0.001 | Papelucho |
| ADJ | 4.64% | 5.34% | −0.767 | <0.001 | Comparison |
| PROPN (proper nouns) | 2.81% | 5.10% | −0.720 | <0.001 | Comparison |
| DET (determiners) | 13.11% | 14.64% | −0.646 | 0.003 | Comparison |
| NOUN | 17.25% | 18.31% | −0.458 | 0.089 | — |
| ADV | 6.07% | 5.98% | −0.026 | 1.000 | — |
| AUX | 3.76% | 3.83% | 0.003 | 1.000 | — |
| **Lexical density** | **47.9%** | **50.5%** | **−0.937** | <0.001 | Comparison |

**EN.** A Cliff's delta of **1.000 on CCONJ** is perfect separation: every
Papelucho book uses more coordinating conjunctions than every comparison book,
with no overlap. ADP is almost perfectly separated in the opposite direction.

The pattern is coherent and reads directly: Papelucho chains clauses with
*y... y... y...* rather than subordinating through prepositional phrases, uses far
more pronouns (a first-person child narrator), more verbs, fewer adjectives, and
carries lower lexical density. That is the signature of spoken child language.

Comparison with what the previous pipeline reported for the same book:

| Category | This pipeline (raw) | Previous (stopword-filtered) |
|---|---|---|
| CCONJ | 7.2% | 0.1% |
| ADP | 10.8% | 0.5% |
| PRON | 13.4% | 2.7% |

The three categories that now separate the corpora most sharply are exactly the
three the earlier preprocessing deleted.

**ES.** Un delta de Cliff de **1,000 en CCONJ** es separacion perfecta: todos los
libros de Papelucho usan mas conjunciones coordinantes que todos los libros de
comparacion, sin solapamiento.

El patron es coherente y se lee directo: Papelucho encadena clausulas con
*y... y... y...* en vez de subordinar mediante sintagmas preposicionales, usa
muchos mas pronombres (narrador infantil en primera persona), mas verbos, menos
adjetivos, y tiene densidad lexica mas baja. Es la firma del lenguaje oral
infantil.

Las tres categorias que ahora separan los corpus con mayor nitidez son justamente
las tres que el preprocesamiento anterior eliminaba.

`04_pos_results.csv`, `04_lexical_density_result.csv`

---

## 5. Sentiment: volatile arcs, not a different average

**EN.** Mean sentiment does **not** differ between corpora. What differs is how
much the sentiment moves across the narrative.

**ES.** El sentimiento medio **no** difiere entre corpus. Lo que difiere es cuánto
se mueve el sentimiento a lo largo de la narración.

| Measure | Papelucho | Comparison | Cliff's δ | p (adj) | Significant |
|---|---|---|---|---|---|
| Mean sentiment | 0.0141 | 0.0232 | −0.362 | 0.146 | No |
| Median sentiment | 0.0142 | 0.0259 | −0.357 | 0.146 | No |
| **Sentiment variability (SD)** | **0.0451** | **0.0322** | **0.630** | **0.003** | **Yes** |
| **Sentiment range** | **0.1771** | **0.1222** | **0.651** | **0.002** | **Yes** |
| **Negative segments (%)** | **37.5** | **20.0** | **0.485** | **0.032** | **Yes** |
| Negative sentences (%) | 22.8 | 20.8 | 0.188 | 0.308 | No |

**EN.** Papelucho books swing harder in both directions and spend more of the
narrative in negative territory, while ending at a comparable average. This
distinction was invisible in the previous analysis, which produced one segment per
book instead of twenty and scored Spanish with an English lexicon.

It was also invisible in the first corrected run of this pipeline, because of a
`dplyr::summarise()` shadowing bug that returned NA for both variability measures.
See `docs/CHANGES.md`.

**ES.** Los libros de Papelucho oscilan más fuerte en ambas direcciones y pasan
más de la narración en terreno negativo, terminando en un promedio comparable.

`05_sentiment_results.csv`, `05_narrative_arc_by_book.csv`

---

## 6. Emotions: the raw-count analysis was entirely artefact

**EN.** With absolute counts, all ten categories are "significant" and all favour
the longer corpus. Normalised per 1,000 running tokens, three survive and four
categories reverse direction.

**ES.** Con conteos absolutos, las diez categorías son "significativas" y todas
favorecen al corpus más largo. Normalizadas por cada 1.000 tokens corrientes,
sobreviven tres y cuatro categorías invierten de dirección.

| | Raw counts | Per 1,000 tokens |
|---|---|---|
| Significant of 10 / Significativas de 10 | **10** | **3** |
| Direction reversals / Inversiones | — | **4** |

Surviving after normalisation / Sobreviven tras normalizar:

| Emotion | Papelucho | Comparison | Cliff's δ | p (adj) |
|---|---|---|---|---|
| Positive | 36.69 | 43.33 | −0.791 | <0.001 |
| Surprise | 10.83 | 12.33 | −0.574 | 0.016 |
| Anticipation | 19.11 | 20.88 | −0.524 | 0.035 |

Fear, joy, sadness and trust show negligible effects and are not significant.

**EN.** Note the direction: normalised, Papelucho is *less* emotionally loaded per
unit of text on the positive categories, not more.

**ES.** Notar la dirección: normalizado, Papelucho está *menos* cargado
emocionalmente por unidad de texto en las categorías positivas, no más.

`06_emotions_results_normalised.csv`, `06_emotions_normalisation_contrast.csv`

---

## 7. Stylometry: coherent series, moderate support, one outlier

**EN.** Under Burrows's Delta on 300 most frequent words:

- **11 of 12** Papelucho books form a single, perfectly pure cluster.
- The exception is `PAP03` (*Papelucho historiador*), which sits between
  *Guerra Mundial Z* and *El alquimista*. It is also the shortest book in the
  series (13,685 tokens).
- Bootstrap support for the 11-book cluster is **61.8%** over 1,000 feature
  resamples, **below** the ~70% threshold conventionally required to call a
  grouping stable.
- The exclusive 12-book clade does not appear in the observed tree at all, so its
  support is 0%.

**ES.** Bajo Burrows's Delta sobre 300 palabras más frecuentes:

- **11 de 12** libros de Papelucho forman un cluster único y perfectamente puro.
- La excepción es `PAP03` (*Papelucho historiador*), que queda entre
  *Guerra Mundial Z* y *El alquimista*. Es además el libro más corto de la serie.
- El soporte bootstrap del cluster de 11 libros es **61,8%**, **bajo** el umbral de
  ~70% que se exige convencionalmente para declarar estable una agrupación.

### The TF-IDF dendrogram was measuring series membership

**EN.** Proportion of book pairs from the same series (or same author) landing in
the same cluster:

| k | Delta: series | TF-IDF: series | Delta: author | TF-IDF: author |
|---|---|---|---|---|
| 5 | 0.741 | **1.000** | 0.841 | **0.984** |
| 10 | 0.518 | **1.000** | 0.538 | **0.968** |
| 15 | 0.511 | **1.000** | 0.534 | **0.964** |

**EN.** TF-IDF recovers series membership **perfectly at every cut level**. That
is the direct quantitative demonstration that the original dendrogram was
clustering on shared character and place names, not on style.

**ES.** TF-IDF recupera la pertenencia a la serie **perfectamente en todos los
niveles de corte**. Esa es la demostración cuantitativa directa de que el
dendrograma original agrupaba por nombres de personajes y lugares compartidos, no
por estilo.

`07_cluster_support.csv`, `07_method_comparison.csv`, `07_papelucho_cluster_support.csv`

---

## 8. UMAP inflates apparent separation by about 3.7×

**EN.** Across 45 runs (5 seeds × 3 neighbour settings × 3 min-distance settings):

| Quantity | Value |
|---|---|
| Silhouette in the original Delta space | **0.173** |
| Silhouette in UMAP projections, median | **0.639** |
| Silhouette in UMAP projections, range | 0.417 – 0.892 |
| Neighbourhood preservation, median | 0.577 |

**Verdict:** *weakly stable — separation holds in sign but varies substantially in
magnitude across seeds.*

**EN.** The real separation between the two corpora in the feature space is weak
(0.173). UMAP projections show it at roughly 3.7× that value, and the apparent
strength varies more than twofold depending on the seed. A single UMAP plot from a
single seed is not evidence of structure. Every statistical claim in this project
therefore rests on the distance matrix, never on projection coordinates.

**ES.** La separación real entre los dos corpus en el espacio de rasgos es débil
(0,173). Las proyecciones UMAP la muestran a unas 3,7× ese valor, y la fuerza
aparente varía más del doble según la semilla. Un gráfico UMAP de una sola semilla
no es evidencia de estructura.

`08_umap_stability.csv`, `08_umap_verdict.csv`

---

## 9. Sensitivity: the findings survive the corpus imbalances

**EN.** Every metric was re-tested under three restricted designs plus 200 draws
of one randomly chosen book per comparison author. Of 34 metrics: **17 robust,
4 supported, 0 fragile.**

**ES.** Cada metrica se volvio a probar bajo tres disenos restringidos mas 200
sorteos de un libro elegido al azar por cada autor de comparacion. De 34 metricas:
**17 robustas, 4 sostenidas, 0 fragiles.**

| Design / Diseño | Papelucho | Comparison |
|---|---|---|
| Full corpus / Corpus completo | 12 | 63 |
| Audience-matched / Público emparejado | 12 | 30 |
| Original Spanish only / Solo español original | 12 | 3 |
| One book per author / Un libro por autor | 12 | 22 |

Cliff's delta under each design / Delta de Cliff bajo cada diseño:

| Measure | Full | Audience | Spanish | Author (median) | Draws sig. |
|---|---|---|---|---|---|
| **CCONJ** | **1.00** | **1.00** | **1.00** | **1.00** | **100%** |
| **Letters per word** | **−1.00** | **−1.00** | **−1.00** | **−1.00** | **100%** |
| **Syllables per word** | **−1.00** | **−1.00** | **−1.00** | **−1.00** | **100%** |
| **Gutiérrez de Polini** | **1.00** | **1.00** | **1.00** | **1.00** | **100%** |
| ADP | −0.99 | −0.97 | −1.00 | −0.99 | 100% |
| PRON | 0.96 | 0.92 | 1.00 | 0.98 | 100% |
| Lexical density | −0.94 | −0.99 | −0.94 | −0.86 | 100% |
| Hapax ratio | −0.92 | −0.97 | −0.94 | −0.91 | 100% |
| SCONJ | 0.81 | 0.78 | 0.89 | 0.78 | 100% |
| VERB | 0.80 | 0.59 | 0.56 | 0.86 | 100% |
| MTLD | −0.78 | −0.66 | −0.83 | −0.73 | 100% |
| ADJ | −0.77 | −0.70 | −0.61 | −0.79 | 100% |
| TTR | −0.68 | −0.57 | −0.61 | −0.71 | 97% |
| Sentiment variability | 0.63 | 0.83 | 0.78 | 0.68 | 98% |
| Sentiment range | 0.65 | 0.81 | 0.61 | 0.67 | 85% |
| **PROPN** | **−0.72** | **−0.79** | **−0.33** | **−0.55** | **0%** |

### Reading the Spanish-only column

**EN.** That design compares 12 books against 3. At that size the smallest
attainable p-value cannot clear a Holm-corrected threshold across a family of 34
tests, no matter how large the true difference is. So **no** metric reaches
significance there, and significance is not the right thing to read. Direction and
effect size are. Both hold: every headline measure keeps its sign and keeps a
large effect, several at exactly ±1.00.

This matters because the translation confound was the most serious threat to the
POS findings. Translated prose tends to make connectors explicit and to
subordinate more, which is precisely the dimension where Papelucho separates. The
answer is that CCONJ, ADP and PRON hold at ±1.00, ±1.00 and +1.00 against
original-Spanish comparison books, so those findings are not a translation
artefact.

**ES.** Ese diseño compara 12 libros contra 3. A ese tamaño el menor p alcanzable
no puede superar un umbral corregido por Holm en una familia de 34 pruebas, por
grande que sea la diferencia real. Así que **ninguna** métrica alcanza
significancia ahí, y la significancia no es lo que hay que leer. La dirección y el
tamaño de efecto sí. Ambos se sostienen.

Esto importa porque el confundido de traducción era la amenaza más seria a los
hallazgos de POS. La prosa traducida tiende a explicitar conectores y a subordinar
más, que es justo la dimensión donde Papelucho se separa. La respuesta es que
CCONJ, ADP y PRON se mantienen en ±1,00 contra libros de comparación en español
original, así que no son artefacto de traducción.

### The one measure that does not hold

**EN.** **Proper nouns (PROPN)** drop from −0.72 on the full corpus to −0.33 under
the Spanish-only design, and reach significance in **0%** of the author draws.
That is exactly what one expects: proper nouns are character and place names, and
the comparison corpus is dominated by fantasy series with distinctive invented
naming. The PROPN result is a fact about the comparison corpus, not about
Papelucho, and should not be reported as a finding.

**ES.** Los **nombres propios (PROPN)** caen de −0,72 en el corpus completo a
−0,33 bajo el diseño de solo español, y alcanzan significancia en el **0%** de los
sorteos por autor. Es exactamente lo esperable: los nombres propios son nombres de
personajes y lugares, y el corpus de comparación está dominado por series de
fantasía con nomenclatura inventada distintiva. El resultado de PROPN es un hecho
sobre el corpus de comparación, no sobre Papelucho, y no debería reportarse como
hallazgo.

`09_sensitivity_summary.csv`, `09_sensitivity_by_design.csv`, `09_sensitivity_author_draws.csv`

---

## 10. What still needs a decision

**EN.** The sensitivity analysis answers the question it was built to answer: the
headline findings are not artefacts of how the comparison corpus was assembled.
Three caveats remain, and they are limitations to state in the paper rather than
problems to fix in code.

- The original-Spanish design rests on **three** comparison books. Direction and
  effect size are stable there, but three books cannot establish a population.
  Adding Chilean and Latin American children's literature from a comparable
  period would turn a suggestive result into a demonstrated one.
- The comparison corpus was inherited, not designed. It remains 25.4% one author
  and 95% translations.
- PROPN should be dropped from the reported findings.

**ES.** El análisis de sensibilidad responde la pregunta para la que se construyó:
los hallazgos principales no son artefactos de cómo se armó el corpus de
comparación. Quedan tres salvedades, que son limitaciones a declarar en el paper y
no problemas a arreglar en código.

- El diseño de español original descansa en **tres** libros de comparación. La
  dirección y el tamaño de efecto son estables ahí, pero tres libros no
  establecen una población. Sumar literatura infantil chilena y latinoamericana
  de un período comparable convertiría un resultado sugerente en uno demostrado.
- El corpus de comparación se heredó, no se diseñó. Sigue siendo 25,4% un solo
  autor y 95% traducciones.
- PROPN debería sacarse de los hallazgos reportados.
