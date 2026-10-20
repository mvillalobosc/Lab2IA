# data/raw/

[Español](#español) · [English](#english)

## Español

Aquí están todos los insumos del pipeline. `R/00_config.R` fija la ruta de cada archivo en `CFG`, `R/01_ingest.R` lee y valida los CSV y `R/02_clean.R` carga el diccionario. Los archivos se unen por `episode_id` (`e01` a `e34`), y `metadata/episodes.csv` es la llave maestra: para agregar un capítulo hay que sumar una fila con su `episode_id` a `episodes.csv`, `youtube_stats.csv` y los dos archivos de diálogos. Los dos CSV de diálogos no están sueltos en el repositorio: van cifrados en `dialogues.7z`, porque son transcripciones de una serie de terceros en las que los niños que narran cada capítulo dicen sus nombres reales. La contraseña no se publica; hay que pedírsela a los autores. Desde la carpeta del proyecto, `7z x data/raw/dialogues.7z -odata/raw` los deja en esta carpeta, y el `.gitignore` de la raíz del repositorio Lab2IA los ignora una vez descomprimidos. Vuelve a [data/](../README.md).

| Archivo o carpeta | Contenido |
|---|---|
| `dialogues.7z` | Archivo 7z cifrado con AES-256, nombres de archivo incluidos, que trae `dialogues_es.csv` y `dialogues_en.csv`. |
| `dialogues_es.csv` | Sale de `dialogues.7z`. Las transcripciones en castellano, una fila por capítulo (34) con `episode_id`, `title_es` y `text`. Cada texto ocupa una sola línea. Los 16 capítulos de las temporadas 1 y 2 traen la canción de entrada, que `R/02_clean.R` elimina; los de las temporadas 3 y 4 no la traen. Los capítulos tienen entre 313 y 839 palabras. |
| `dialogues_en.csv` | Sale de `dialogues.7z`. Las traducciones al inglés, con las mismas columnas. Las usan `R/05_sentiment.R` (sentimentr solo tiene léxicos en inglés) y el ARI de `R/06_readability.R`. |
| [metadata/](metadata/) | `episodes.csv` y `youtube_stats.csv`. |
| [lexicons/](lexicons/) | El léxico temático (`word_topics.csv`) y las stopwords propias (`stopwords_extra.csv`). |
| [dictionaries/](dictionaries/) | El diccionario hunspell del español que separa el vocabulario genérico del cultural. |

`dialogues_es.csv`, `dialogues_en.csv` y `metadata/episodes.csv` tienen finales de línea CRLF y los demás LF; readr los lee igual, pero conviene no cambiarlos al editarlos para no generar diferencias en todas las líneas.

## English

All the pipeline inputs are here. `R/00_config.R` sets the path of each file in `CFG`, `R/01_ingest.R` reads and validates the CSV files and `R/02_clean.R` loads the dictionary. The files join on `episode_id` (`e01` to `e34`), and `metadata/episodes.csv` is the master key: adding an episode means appending a row with its `episode_id` to `episodes.csv`, `youtube_stats.csv` and both dialogue files. The two dialogue CSVs are not loose in the repository: they are encrypted in `dialogues.7z`, because they are transcripts of a third-party series in which the children who narrate each episode give their real names. The password is not published; ask the authors for it. From the project folder, `7z x data/raw/dialogues.7z -odata/raw` places them in this folder, and the `.gitignore` at the root of the Lab2IA repository ignores them once unpacked. Back to [data/](../README.md).

| File or folder | Contents |
|---|---|
| `dialogues.7z` | 7z archive encrypted with AES-256, file names included, holding `dialogues_es.csv` and `dialogues_en.csv`. |
| `dialogues_es.csv` | Comes out of `dialogues.7z`. The Spanish transcripts, one row per episode (34) with `episode_id`, `title_es` and `text`. Each text takes a single line. The 16 episodes of seasons 1 and 2 carry the opening song, which `R/02_clean.R` removes; those of seasons 3 and 4 do not carry it. Episodes have between 313 and 839 words. |
| `dialogues_en.csv` | Comes out of `dialogues.7z`. The English translations, with the same columns. `R/05_sentiment.R` uses them (sentimentr only has English lexicons), and so does the ARI in `R/06_readability.R`. |
| [metadata/](metadata/) | `episodes.csv` and `youtube_stats.csv`. |
| [lexicons/](lexicons/) | The topic lexicon (`word_topics.csv`) and the extra stopwords (`stopwords_extra.csv`). |
| [dictionaries/](dictionaries/) | The Spanish hunspell dictionary that separates generic from cultural vocabulary. |

`dialogues_es.csv`, `dialogues_en.csv` and `metadata/episodes.csv` use CRLF line endings and the other files LF; readr reads both, but keep them as they are when editing so that every line does not show up as changed.
