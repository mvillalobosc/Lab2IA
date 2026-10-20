# data/fulltext/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la etapa de texto completo: la lista de candidatos que sale del mapa de evidencia y las evaluaciones de los textos que se leyeron. Los criterios y los campos están en [`protocols/fulltext_protocol.txt`](../../protocols/fulltext_protocol.txt) y el contexto, en el [README del proyecto](../../README.md#full-text-stage-datafulltext) (en castellano, en [README.es.md](../../README.es.md#etapa-de-texto-completo-datafulltext)).

| Archivo | Filas | Contenido | Lo escribe |
|---|---|---|---|
| `candidates.csv` | 163 | Candidatos a texto completo: estudios incluidos cuyo indicador `hardware_measured` es Y (prioridad 1, junto con los de categoría C4) o U (prioridad 2). Hay 54 de prioridad 1 y 109 de prioridad 2. Columnas `record_id`, `batch`, `priority`, `year`, `title`, `authors`, `venue`, `doi`, `open_access`, `categories`, `platform_snn`, `platform_ann`, `evidence`, `hardware_measured`, `note`. | `11_fulltext_candidates.R` |
| `assessment.tsv` | 5 | Evaluación de los cinco textos completos leídos, con 8 campos (`record_id`, `retrieval`, `url`, `version`, `decision`, `reason`, `precision_note`, `justification`): R00098, R00306 y R01006 quedaron INCLUDED, R00085 se excluyó con FT2 y R00185 con FT5. | Los revisores |
| `pairs.tsv` | 8 | Los pares ANN-SNN extraídos de los tres estudios incluidos (tres de R00098, tres de R00306 y dos de R01006), con 26 campos: modelos, plataformas y precisión de cada red, modelo de neurona, entrenamiento, pasos de tiempo, codificación, exactitud, energía, latencia, tipo de medición, tamaño de lote, actividad de disparo, citas textuales y notas. | Los revisores |
| `within_snn_control.tsv` | 1 | La misma SNN recurrente de R01006 en una GPU Jetson Xavier NX y en Loihi. Usa los 26 campos de los pares, pero es un control de sustrato y no un par ANN-SNN. | Los revisores |
| `historical_2019_blouw_assessment.tsv` | 1 | Evaluación (8 campos) de R00069, un trabajo de taller de 2019 exportado con año 2020 que la auditoría de año dejó fuera de la ventana. | Los revisores |
| `historical_2019_blouw_pairs.tsv` | 4 | Los pares ANN-SNN (26 campos) de ese mismo trabajo, conservados solo como contexto histórico. | Los revisores |

Los cinco TSV llevan una fila de encabezado y ningún script los lee ni los escribe. El protocolo describe archivos escritos por lote (`<batch>_eval.tsv`, `<batch>_pares.tsv` y `<batch>_c4.tsv`) sin encabezado; los distribuidos mantienen un archivo por tipo. Ninguno de los cinco estudios evaluados es de la categoría C4, así que no hay archivo de extracción C4.

## English

This folder holds the full-text stage: the candidate list taken from the evidence map and the assessments of the texts that were read. The criteria and the fields are in [`protocols/fulltext_protocol.txt`](../../protocols/fulltext_protocol.txt) and the context in the [project README](../../README.md#full-text-stage-datafulltext).

| File | Rows | Content | Written by |
|---|---|---|---|
| `candidates.csv` | 163 | Full-text candidates: included studies whose `hardware_measured` indicator is Y (priority 1, together with those in category C4) or U (priority 2). There are 54 of priority 1 and 109 of priority 2. Columns `record_id`, `batch`, `priority`, `year`, `title`, `authors`, `venue`, `doi`, `open_access`, `categories`, `platform_snn`, `platform_ann`, `evidence`, `hardware_measured`, `note`. | `11_fulltext_candidates.R` |
| `assessment.tsv` | 5 | Assessment of the five full texts that were read, with 8 fields (`record_id`, `retrieval`, `url`, `version`, `decision`, `reason`, `precision_note`, `justification`): R00098, R00306 and R01006 were INCLUDED, R00085 was excluded with FT2 and R00185 with FT5. | The reviewers |
| `pairs.tsv` | 8 | The ANN-SNN pairs extracted from the three included studies (three from R00098, three from R00306 and two from R01006), with 26 fields: models, platforms and precision of each network, neuron model, training, time steps, coding, accuracy, energy, latency, measurement type, batch size, firing activity, verbatim quotes and notes. | The reviewers |
| `within_snn_control.tsv` | 1 | The same recurrent SNN from R01006 on a Jetson Xavier NX GPU and on Loihi. It uses the 26 pair fields, but it is a substrate control and not an ANN-SNN pair. | The reviewers |
| `historical_2019_blouw_assessment.tsv` | 1 | Assessment (8 fields) of R00069, a 2019 workshop paper exported with the year 2020 that the year audit left outside the window. | The reviewers |
| `historical_2019_blouw_pairs.tsv` | 4 | The ANN-SNN pairs (26 fields) of that same paper, kept only as historical context. | The reviewers |

The five TSV files have a header row and no script reads or writes them. The protocol describes files written per batch (`<batch>_eval.tsv`, `<batch>_pares.tsv` and `<batch>_c4.tsv`) without a header; the distributed files keep one file per type. None of the five assessed studies is in category C4, so there is no C4 extraction file.
