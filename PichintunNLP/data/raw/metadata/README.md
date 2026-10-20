# data/raw/metadata/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los datos de cada capítulo que no son texto: su ficha y sus estadísticas de YouTube. Los dos archivos tienen 34 filas, una por capítulo, y se unen con los diálogos por `episode_id`. Vuelve a [data/raw/](../README.md).

### episodes.csv

Es la llave maestra del proyecto. `R/01_ingest.R` lo lee primero, se detiene si un `episode_id` o un `title_es` se repite, y exige que cada capítulo tenga diálogos en los dos idiomas y una fila en `youtube_stats.csv`.

| Columna | Contenido |
|---|---|
| `episode_id` | Identificador del capítulo, de `e01` a `e34`. |
| `season` | Temporada, de 1 a 4. |
| `episode_in_season` | Número del capítulo dentro de su temporada. |
| `episode_order` | Posición del capítulo en la serie, de 1 a 34. |
| `title_es` | Título en castellano. Las tablas y las figuras lo usan como etiqueta del capítulo. |
| `slug` | El título en minúsculas, sin tildes y con guiones bajos en lugar de espacios y signos. |
| `youtube_id` | Identificador del video en YouTube. |
| `publish_date` | Fecha de publicación en formato ISO (`AAAA-MM-DD`). |
| `animation_team` | Equipo de animación. |

| Temporada | Capítulos | `episode_id` | Publicación | Equipo de animación |
|---|---|---|---|---|
| 1 | 6 | `e01` a `e06` | 29 de abril a 5 de septiembre de 2016 | Máquina Visual |
| 2 | 10 | `e07` a `e16` | 7 de septiembre a 9 de noviembre de 2018 | Máquina Visual |
| 3 | 10 | `e17` a `e26` | 8 de mayo a 10 de julio de 2020 | Máquina Visual |
| 4 | 8 | `e27` a `e34` | 28 de julio a 15 de septiembre de 2022 | Tanu Comunicaciones |

El pipeline ordena los capítulos por `publish_date` y desempata por `title_es`. Con los datos actuales ese orden coincide con `episode_order` y con la numeración de `episode_id`, pero ningún módulo lee `episode_order` ni `slug`. El equipo de animación cambia solo en la temporada 4, de modo que la variable `Equipo` de `R/07_popularity.R` marca exactamente los capítulos de esa temporada.

### youtube_stats.csv

Son las estadísticas de cada video en la fecha de corte de la extracción, el 13 de abril de 2023, que `R/00_config.R` guarda en `CFG$fecha_corte`. Ninguna celda está vacía.

| Columna | Contenido | Uso en el pipeline |
|---|---|---|
| `episode_id` | Llave de unión con `episodes.csv`. | Unión en `R/01_ingest.R`. |
| `views` | Visualizaciones. | Respuesta `Visualizaciones` de `R/07_popularity.R`. |
| `likes` | Likes. | Respuesta `Likes`. |
| `subscribers_current` | Suscriptores. | Respuesta `Suscriptores`. |
| `subscribers` | Otro recuento de suscriptores. | No se usa. |
| `watch_time_hours` | Tiempo de reproducción, en horas. | No se usa. |
| `avg_view_duration` | Duración media de una visualización, en formato `h:mm:ss`. | No se usa. |
| `impressions` | Impresiones. | No se usa. |
| `impression_ctr_pct` | Porcentaje de impresiones que terminaron en un clic. | No se usa. |

`subscribers` y `subscribers_current` difieren en 18 capítulos, en 21 suscriptores como máximo, y el archivo no explica qué distingue a una columna de la otra. Las visualizaciones van de 13.181 (`e33`) a 3.900.018 (`e03`).

Las tres columnas que se usan también aparecen en `01_episodios.csv` y en `08_maestro_capitulos.csv`. `R/07_popularity.R` divide cada una por los meses que el capítulo llevaba publicado en la fecha de corte (los días divididos por 30), que van de 7 meses para `e34` a 84,7 meses para `e01` y `e02`, y después reescala el resultado a [0, 1]. Si se cargan estadísticas de una extracción nueva, hay que cambiar también `CFG$fecha_corte`. El módulo se detiene si algún capítulo queda con una exposición nula o negativa, como pasaría con un capítulo publicado después de la fecha de corte.

## English

This folder holds the per-episode data that is not text: each episode's record and its YouTube statistics. Both files have 34 rows, one per episode, and they join the dialogues on `episode_id`. Back to [data/raw/](../README.md).

### episodes.csv

This is the master key of the project. `R/01_ingest.R` reads it first, stops when an `episode_id` or a `title_es` repeats, and requires every episode to have dialogues in both languages and a row in `youtube_stats.csv`.

| Column | Contents |
|---|---|
| `episode_id` | Episode identifier, from `e01` to `e34`. |
| `season` | Season, from 1 to 4. |
| `episode_in_season` | Episode number within its season. |
| `episode_order` | Position of the episode in the series, from 1 to 34. |
| `title_es` | Spanish title. Tables and figures use it as the episode label. |
| `slug` | The title in lower case, without accents and with underscores in place of spaces and punctuation. |
| `youtube_id` | YouTube video identifier. |
| `publish_date` | Publication date in ISO format (`YYYY-MM-DD`). |
| `animation_team` | Animation team. |

| Season | Episodes | `episode_id` | Published | Animation team |
|---|---|---|---|---|
| 1 | 6 | `e01` to `e06` | 29 April to 5 September 2016 | Máquina Visual |
| 2 | 10 | `e07` to `e16` | 7 September to 9 November 2018 | Máquina Visual |
| 3 | 10 | `e17` to `e26` | 8 May to 10 July 2020 | Máquina Visual |
| 4 | 8 | `e27` to `e34` | 28 July to 15 September 2022 | Tanu Comunicaciones |

The pipeline sorts the episodes by `publish_date` and breaks ties by `title_es`. With the current data that order matches `episode_order` and the numbering of `episode_id`, but no module reads `episode_order` or `slug`. The animation team changes only in season 4, so the `Equipo` variable in `R/07_popularity.R` marks exactly the episodes of that season.

### youtube_stats.csv

These are the statistics of each video on the cut-off date of the extraction, 13 April 2023, which `R/00_config.R` stores in `CFG$fecha_corte`. No cell is empty.

| Column | Contents | Use in the pipeline |
|---|---|---|
| `episode_id` | Join key with `episodes.csv`. | Join in `R/01_ingest.R`. |
| `views` | Views. | `Visualizaciones` response in `R/07_popularity.R`. |
| `likes` | Likes. | `Likes` response. |
| `subscribers_current` | Subscribers. | `Suscriptores` response. |
| `subscribers` | Another subscriber count. | Not used. |
| `watch_time_hours` | Watch time, in hours. | Not used. |
| `avg_view_duration` | Average length of one view, as `h:mm:ss`. | Not used. |
| `impressions` | Impressions. | Not used. |
| `impression_ctr_pct` | Percentage of impressions that ended in a click. | Not used. |

`subscribers` and `subscribers_current` differ in 18 episodes, by 21 subscribers at most, and the file does not explain what sets one column apart from the other. Views range from 13,181 (`e33`) to 3,900,018 (`e03`).

The three columns in use also appear in `01_episodios.csv` and `08_maestro_capitulos.csv`. `R/07_popularity.R` divides each one by the months the episode had been online on the cut-off date (days divided by 30), which range from 7 months for `e34` to 84.7 months for `e01` and `e02`, and then rescales the result to [0, 1]. When statistics from a new extraction are loaded, `CFG$fecha_corte` must change as well. The module stops when an episode ends up with zero or negative exposure, as would happen with an episode published after the cut-off date.
