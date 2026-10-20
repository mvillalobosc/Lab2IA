# data/raw/dictionaries/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el diccionario hunspell del español que `R/02_clean.R` usa para separar el vocabulario genérico del cultural. Es material de terceros y se incluye tal como se distribuye. Vuelve a [data/raw/](../README.md).

| Archivo | Contenido |
|---|---|
| `es_ES.dic` | La lista de palabras. La primera línea indica el número de entradas: 70.157. |
| `es_ES.aff` | Las reglas de prefijos y sufijos con que hunspell reconoce las formas derivadas de cada entrada, como plurales y conjugaciones. |
| `es_ES.README.txt` | El README original del diccionario, en castellano. Se conserva sin cambios y este README.md no lo reemplaza. |

Los dos archivos del diccionario están en UTF-8, como declara la línea `SET UTF-8` de `es_ES.aff`.

### Origen y licencia

Según `es_ES.README.txt`, es la versión 2.6 del diccionario para corrección ortográfica en español de LibreOffice y Apache OpenOffice, desarrollado inicialmente por Santiago Bosio, y está hecho para «es (ALL)». El diccionario, formado por el archivo de afijos y la lista de palabras, se distribuye bajo tres licencias disjuntas entre las que quien lo usa puede elegir: GNU GPL versión 3 o posterior, GNU LGPL versión 3 o posterior y MPL versión 1.1 o posterior. Ese README remite a los archivos `LICENSE.md` y `CONTRIBUTING.md` del proyecto original, que no vienen en esta carpeta. La licencia MIT del proyecto cubre el código, no este diccionario.

### Cómo lo usa el pipeline

`R/02_clean.R` carga `es_ES.dic` con `hunspell::dictionary()`, que busca el `.aff` con el mismo nombre en la misma carpeta, así que los dos archivos tienen que quedar juntos y con el mismo nombre. `particion_lexica()`, en `R/lib/text.R`, revisa cada token ya en minúsculas y sin stopwords. Los que el diccionario reconoce cuentan como español genérico y los demás como vocabulario cultural: voces indígenas, chilenismos y nombres propios.

El diccionario reconoce `chile` como palabra común del español, y por eso `CFG$forzar_culturales` la pasa al grupo cultural. `02_diag_forzar_culturales.csv` muestra cuánto cambia el porcentaje cultural de cada capítulo por esa regla. Cambiar el diccionario mueve palabras entre los dos grupos y cambia `pct_cultural`, la variable `Modismos_etnicas` de los modelos de popularidad y las figuras que separan los dos grupos.

## English

This folder holds the Spanish hunspell dictionary that `R/02_clean.R` uses to split generic from cultural vocabulary. It is third-party material, included as it is distributed. Back to [data/raw/](../README.md).

| File | Contents |
|---|---|
| `es_ES.dic` | The word list. Its first line gives the number of entries: 70,157. |
| `es_ES.aff` | The prefix and suffix rules hunspell uses to recognise the forms derived from each entry, such as plurals and verb forms. |
| `es_ES.README.txt` | The original README of the dictionary, in Spanish. It is kept unchanged, and this README.md does not replace it. |

Both dictionary files are in UTF-8, as the `SET UTF-8` line in `es_ES.aff` declares.

### Origin and licence

According to `es_ES.README.txt`, this is version 2.6 of the Spanish spell-checking dictionary for LibreOffice and Apache OpenOffice, first developed by Santiago Bosio, and it is made for "es (ALL)". The dictionary, made up of the affix file and the word list, is distributed under three disjoint licences among which the user may choose: GNU GPL version 3 or later, GNU LGPL version 3 or later, and MPL version 1.1 or later. That README points to the `LICENSE.md` and `CONTRIBUTING.md` files of the original project, which are not in this folder. The MIT licence of the project covers the code, not this dictionary.

### How the pipeline uses it

`R/02_clean.R` loads `es_ES.dic` with `hunspell::dictionary()`, which looks for the `.aff` file with the same name in the same folder, so both files must stay together under the same name. `particion_lexica()`, in `R/lib/text.R`, checks each token after it has been lower-cased and stripped of stopwords. Tokens the dictionary recognises count as generic Spanish and the rest as cultural vocabulary: Indigenous words, Chilean idioms and proper nouns.

The dictionary recognises `chile` as a common Spanish word, so `CFG$forzar_culturales` moves it to the cultural group. `02_diag_forzar_culturales.csv` shows how much that rule changes the cultural percentage of each episode. Changing the dictionary moves words between the two groups and changes `pct_cultural`, the `Modismos_etnicas` variable of the popularity models and the figures that separate the two groups.
