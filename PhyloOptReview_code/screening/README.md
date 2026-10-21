# screening

[Español](#español) · [English](#english)

## Español

| Carpeta | Contenido |
| --- | --- |
| `protocol/` | Protocolo escrito del cribado y la codificación, e instrucciones de cada lote |
| `output/` | Decisiones de los 36 lotes (`batch_01.jsonl` a `batch_36.jsonl`) |
| `reliability/` | Decisiones de la segunda lectura independiente de 528 registros |

Los lotes de entrada (`input/batch_XX.txt`) traen el título, las palabras clave y el resumen de cada registro, por lo que no se distribuyen; `02_screen.R` los vuelve a crear desde las exportaciones.

## English

| Folder | Content |
| --- | --- |
| `protocol/` | Written screening and coding protocol, and the instructions of each batch |
| `output/` | Decisions of the 36 batches (`batch_01.jsonl` to `batch_36.jsonl`) |
| `reliability/` | Decisions of the independent second screening of 528 records |

The input batches (`input/batch_XX.txt`) contain the title, keywords and abstract of each record, so they are not distributed; `02_screen.R` rebuilds them from the exports.
