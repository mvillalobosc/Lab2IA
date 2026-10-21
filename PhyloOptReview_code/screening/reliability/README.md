# screening/reliability

[Español](#español) · [English](#english)

## Español

Decisiones de la segunda lectura, hecha con el mismo protocolo en una sesión independiente y sin acceso a las primeras decisiones. El formato es el de `../output/`.

| Archivo | Muestra |
| --- | --- |
| `sample_300.jsonl` | 300 registros de la primera ronda, estratificados por lote |
| `sample_r2_100.jsonl` | 100 registros de la segunda ronda |
| `sample_r3_100.jsonl`, `sample_r3b_28.jsonl` | 100 y 28 registros de la tercera ronda, de las dos olas de exportación del bloque Q7 |

`04_verify_sample.R` vuelve a sacar las muestras con la semilla fija y compara estas decisiones con las de `../output/`. Los archivos de texto de cada muestra traen los resúmenes y no se distribuyen.

## English

Decisions of the second screening, made with the same protocol in an independent session and without access to the first decisions. The format is that of `../output/`.

| File | Sample |
| --- | --- |
| `sample_300.jsonl` | 300 records of the first round, stratified by batch |
| `sample_r2_100.jsonl` | 100 records of the second round |
| `sample_r3_100.jsonl`, `sample_r3b_28.jsonl` | 100 and 28 records of the third round, from the two export waves of block Q7 |

`04_verify_sample.R` draws the samples again with a fixed seed and compares these decisions with those of `../output/`. The text files of each sample contain the abstracts and are not distributed.
