# data/raw/lexicons/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las dos listas de palabras que el proyecto preparó a mano: el léxico temático y las stopwords propias. `R/01_ingest.R` las lee y `R/02_clean.R` y `R/04_topics.R` las aplican. Vuelve a [data/raw/](../README.md).

### word_topics.csv

Asigna un tema a cada palabra del vocabulario. Tiene 3.051 filas y tres columnas: `word`, `topic` y `annotator_note`. Las palabras están en minúsculas, con sus tildes, y ninguna tiene espacios. `R/01_ingest.R` se detiene si una palabra aparece dos veces y toma como temas todas las etiquetas distintas de `topic` salvo `sin definir`, de modo que una etiqueta mal escrita crea un tema nuevo en todas las matrices.

Las etiquetas de los temas están en castellano en el código y en las tablas de salida.

| Tema | Palabras |
|---|---|
| `descripciones` | 368 |
| `ecosistema` | 337 |
| `cultura/tradiciones` | 274 |
| `trabajo` | 222 |
| `cotidiano` | 222 |
| `actividades` | 206 |
| `cocina` | 204 |
| `aprendizaje` | 187 |
| `experiencias` | 162 |
| `geografía` | 141 |
| `expresión artística` | 123 |
| `relaciones` | 95 |
| `sentimientos` | 85 |
| `infraestructura urbana` | 75 |
| `identidad` | 65 |
| `salud/bienestar` | 49 |
| `sin definir` | 236 |

`R/04_topics.R` suma la frecuencia de cada palabra en su tema. Las palabras marcadas `sin definir` y las que no están en el léxico quedan juntas bajo `sin definir`, y esa columna se descarta de las matrices temáticas. En la copia versionada del libro Excel, 6.863 de los 7.297 tokens (94,1 %) caen en uno de los 16 temas. `R/02_clean.R` escribe en `02_diag_palabras_sin_tema.csv` las palabras del corpus que todavía no están en el léxico.

`annotator_note` trae una glosa breve en 91 filas, escrita a mano y sin vocabulario fijo, como `ropa`, `dios`, `traje` o abreviaturas como `instr`. Ningún módulo lee esta columna. En los gráficos de keyness, `CFG$tema_abrev` acorta cuatro etiquetas largas: `expresión artística` pasa a `creatividad`, `cultura/tradiciones` a `cultura`, `salud/bienestar` a `bienestar` e `infraestructura urbana` a `urbanizacion`.

Para agregar una palabra se suma una fila con la palabra tal como queda después de la limpieza (en minúsculas y con tildes) y con uno de los 16 temas o `sin definir`.

### stopwords_extra.csv

Son 449 palabras que el análisis descarta además de las stopwords de `tm`. Tiene dos columnas: `word` y `lexicon`, que vale `spanish` en todas las filas y que ningún módulo lee. La lista incluye nombres de personajes, con variantes de escritura como `isaac`, `isacc` e `issac`, interjecciones como `ah`, adverbios como `abajo` o `acá` y verbos frecuentes como `abrir` o `agarra`. Ninguna de estas palabras está en `word_topics.csv`.

`R/01_ingest.R` une la lista con `tm::stopwords("spanish")`, quita los duplicados y la ordena. `particion_lexica()` elimina esas palabras antes de consultar el diccionario, así que no entran en la partición léxica, las frecuencias ni los temas. ARI, MATTR y el sentimiento trabajan sobre el texto sin limpiar, y la lista no los afecta.

## English

This folder holds the two word lists the project prepared by hand: the topic lexicon and the extra stopwords. `R/01_ingest.R` reads them, and `R/02_clean.R` and `R/04_topics.R` apply them. Back to [data/raw/](../README.md).

### word_topics.csv

It assigns a topic to each word of the vocabulary. It has 3,051 rows and three columns: `word`, `topic` and `annotator_note`. The words are in lower case, with their accents, and none contains spaces. `R/01_ingest.R` stops when a word appears twice, and it takes every distinct `topic` label except `sin definir` as a topic, so a misspelt label creates a new topic in every matrix.

The topic labels are in Spanish in the code and in the output tables, and the table gives their meaning.

| Topic | Meaning | Words |
|---|---|---|
| `descripciones` | descriptions | 368 |
| `ecosistema` | ecosystem | 337 |
| `cultura/tradiciones` | culture and traditions | 274 |
| `trabajo` | work | 222 |
| `cotidiano` | everyday life | 222 |
| `actividades` | activities | 206 |
| `cocina` | cooking | 204 |
| `aprendizaje` | learning | 187 |
| `experiencias` | experiences | 162 |
| `geografía` | geography | 141 |
| `expresión artística` | artistic expression | 123 |
| `relaciones` | relationships | 95 |
| `sentimientos` | feelings | 85 |
| `infraestructura urbana` | urban infrastructure | 75 |
| `identidad` | identity | 65 |
| `salud/bienestar` | health and well-being | 49 |
| `sin definir` | no topic | 236 |

`R/04_topics.R` adds the frequency of each word to its topic. Words labelled `sin definir` and words missing from the lexicon end up together under `sin definir`, and that column is dropped from the topic matrices. In the versioned copy of the Excel workbook, 6,863 of the 7,297 tokens (94.1 %) fall into one of the 16 topics. `R/02_clean.R` writes the corpus words that are not in the lexicon to `02_diag_palabras_sin_tema.csv`.

`annotator_note` holds a short gloss in 91 rows, written by hand with no fixed vocabulary, such as `ropa` (clothing), `dios` (god), `traje` (costume) or abbreviations such as `instr`. No module reads this column. In the keyness plots, `CFG$tema_abrev` shortens four long labels: `expresión artística` becomes `creatividad`, `cultura/tradiciones` becomes `cultura`, `salud/bienestar` becomes `bienestar` and `infraestructura urbana` becomes `urbanizacion`.

To add a word, append a row with the word as it looks after cleaning (lower case, with accents) and one of the 16 topics or `sin definir`.

### stopwords_extra.csv

These are 449 words that the analysis drops on top of the `tm` stopwords. The file has two columns: `word` and `lexicon`, which is `spanish` in every row and which no module reads. The list includes character names, with spelling variants such as `isaac`, `isacc` and `issac`, interjections such as `ah`, adverbs such as `abajo` or `acá` and frequent verbs such as `abrir` or `agarra`. None of these words is in `word_topics.csv`.

`R/01_ingest.R` joins the list with `tm::stopwords("spanish")`, removes duplicates and sorts it. `particion_lexica()` removes those words before looking them up in the dictionary, so they stay out of the lexical split, the frequencies and the topics. ARI, MATTR and sentiment work on the uncleaned text, and the list does not affect them.
