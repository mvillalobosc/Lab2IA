# ¿Medida o supuesta? Evidencia sobre la eficiencia energética de redes neuronales de espigas frente a redes artificiales

Datos, protocolos y scripts en R de la revisión sistemática *Measured or assumed? A systematic review of the energy-efficiency evidence for spiking versus artificial neural networks* (Baladrón Pezoa, Aravena Karstegl, Gulppi Paredes, Inostroza-Ponta y Villalobos Cid, Departamento de Ingeniería Informática, Universidad de Santiago de Chile; manuscrito enviado a *Neural Computing and Applications*, 2026).

[English version](README.md)

La revisión sigue PRISMA 2020. Buscó en Scopus y Web of Science, el 14 de octubre de 2026, los estudios publicados entre 2020 y 2026 que comparan redes neuronales artificiales (ANN) y redes neuronales de espigas (SNN) con alguna métrica de eficiencia, o que aplican poda, esparsidad o métodos de lottery tickets a cualquiera de los dos paradigmas. Cada registro se cribó por título y resumen, cada registro que pasó se codificó con dieciocho ítems sobre su resumen completo, y un conjunto pequeño de textos completos se evaluó en busca de pares ANN–SNN con energía medida en hardware por ambos lados.

## Cifras principales

| Etapa | Registros |
|---|---|
| Identificados (Scopus 6.092; Web of Science 4.688) | 10.780 |
| Duplicados eliminados | 4.454 |
| Cribados por título y resumen | 6.326 |
| Excluidos en el cribado | 4.217 |
| Evaluados con el resumen completo y codificados | 2.109 |
| Excluidos en esa etapa (E0 a E7) | 638 |
| Incluidos en el mapa de evidencia | 1.471 |
| Candidatos a la etapa de texto completo | 163 |
| Textos completos evaluados / incluidos | 5 / 3 |

Categorías de los 1.471 estudios incluidos (un estudio puede estar en varias): C1 comparación de eficiencia ANN–SNN 727; C2 poda o esparsidad en SNN 383; C3 lottery tickets en ANN 331; C4 lottery tickets en SNN 6; C5 revisiones 58; C6 metodología de benchmarking 46.

## Estructura del repositorio

```
scripts/      scripts en R, numerados en el orden de ejecución
protocols/    protocolos escritos que se aplicaron en cada etapa
data/
  raw/        cadenas de búsqueda e instrucciones de exportación (las exportaciones no se distribuyen)
  records/    metadatos públicos de los 6.334 registros únicos (sin resúmenes) y conteos de identificación
  screening/  decisiones de título y resumen, piloto, muestra de concordancia y re-cribado
  charting/   codificación de los 2.109 registros evaluados con resumen completo, muestra de verificación, adjudicaciones
  fulltext/   lista de candidatos y evaluaciones a texto completo realizadas
  results/    decisiones consolidadas, mapa de evidencia, estadísticas de concordancia y conteos
figures/      figuras 2 a 5 del manuscrito (PDF vectorial)
```

### Scripts

| Script | Función |
|---|---|
| `00_run_all.R` | Corre la cadena completa en orden; salta los pasos que necesitan las exportaciones crudas cuando no están |
| `01_deduplicate.R` | Une las exportaciones, elimina duplicados por DOI y título normalizado, asigna los bloques de búsqueda y escribe `records.csv` y los conteos de identificación |
| `02_screening_batches.R` | Arma los lotes de cribado (resumen mostrado hasta 1.400 caracteres), el piloto estratificado de 200 registros y la muestra aleatoria de concordancia de 430 |
| `03_screening_agreement.R` | Acuerdo y kappa de Cohen entre dos cribados independientes |
| `04_check_screening_batches.R` | Valida los archivos de cribado contra la definición de los lotes |
| `05_full_abstract_batches.R` | Lotes con el resumen completo para una lista de registros |
| `06_rescreen_set.R` | Duplicados tardíos y regla reproducible que define los 1.114 registros re-cribados con resumen completo |
| `07_consolidate_screening.R` | Decisión final de cribado por registro, concordancia con el segundo cribado y conteos |
| `08_charting_batches.R` | Lotes de codificación (resumen completo) y muestra de verificación del 10 % |
| `09_check_charting.R` | Valida los archivos de codificación y calcula la concordancia por ítem con la segunda codificación |
| `10_build_map.R` | Aplica las adjudicaciones de elegibilidad y la auditoría de año de publicación y escribe el mapa de evidencia |
| `11_fulltext_candidates.R` | Lista los candidatos a la etapa de texto completo |
| `12_figures.R` | Figuras 2 a 5 |

### Cómo reproducir el análisis

Requisitos: R 4.x con `data.table`, `readxl`, `stringi`, `jsonlite`, `ggplot2`, `patchwork` y `scales`. Desde la raíz del repositorio:

```
Rscript scripts/00_run_all.R
```

Sin las exportaciones crudas, la cadena parte de los archivos de decisiones distribuidos y reconstruye todos los resultados de `data/results/` y las figuras. Con las exportaciones en su lugar (ver `data/raw/search_strings.txt`), reconstruye además el conjunto de registros y todos los lotes, y comprueba que cada lote coincide registro a registro con los archivos de decisiones. Los identificadores de registro están fijados en `data/records/record_ids.csv`, de modo que los archivos de decisiones siguen calzando con independencia de la configuración regional de la máquina.

Las decisiones de cribado y codificación las produjeron modelos de lenguaje (Claude Opus 5.5, Claude Fable 5.1 y Claude Sonnet 5.5, Anthropic, octubre de 2026) aplicando los protocolos escritos de `protocols/`, bajo la supervisión de los autores, que verificaron muestras aleatorias y adjudicaron los desacuerdos. El piloto, la muestra de concordancia y la muestra de verificación están incluidos para que la confiabilidad de cada etapa pueda recalcularse.

## Diccionario de datos

### `data/records/records.csv` (6.334 filas, una por registro único)

| Columna | Contenido |
|---|---|
| `record_id` | Identificador usado en todos los demás archivos (R00001 a R06334) |
| `source`, `source_id` | Base de datos del registro conservado y su identificador nativo (EID de Scopus o UT de WoS) |
| `wos_id` | Identificador de WoS cuando el registro aparecía en ambas bases |
| `block` | Bloque de búsqueda que calza: A (comparación ANN–SNN con término de eficiencia), B (esparsidad y lottery tickets), A+B, none |
| `title`, `year`, `doi`, `document_type`, `venue`, `authors`, `language`, `citations`, `open_access`, `author_keywords` | Metadatos bibliográficos tal como se exportaron |

Los resúmenes y las palabras clave indexadas no se redistribuyen; pertenecen a las bases de datos y se regeneran a partir de las exportaciones.

### Archivos de cribado (`data/screening/`)

Separados por tabulador, sin encabezado, cinco campos: `record_id`, `decision` (INCLUDE, EXCLUDE, UNSURE), `code` (categorías C1 a C6 unidas con `+`, o una razón de exclusión E1 a E7), `hardware` mencionado y `note`. `batch_ids.csv` asigna cada registro a su lote; `pilot/` contiene los dos cribados independientes del piloto; `kappa_sample/` el segundo cribado de la muestra de concordancia; `rescreen/` las dos rondas de re-cribado con resumen completo y las listas de identificadores que las definen.

### Archivos de codificación (`data/charting/`)

Separados por tabulador, sin encabezado, dieciocho campos en el orden del protocolo `protocols/charting_protocol.txt`: `record_id`, `eligible`, `reason`, `categories`, `paradigm`, `architecture`, `task`, `platform_snn`, `platform_ann`, `evidence`, `metrics`, `comparison`, `sparsity_method`, `lth_variant`, `granularity`, `cost_in_objective`, `hardware_measured`, `note`. `primary/` es la codificación de los 2.109 registros; `verification/` la segunda codificación independiente de 211 registros; `eligibility_adjudication.csv` la decisión del tercer revisor sobre los diecinueve desacuerdos de elegibilidad; `year_audit.csv` los tres registros excluidos con código E0 porque su año bibliográfico queda fuera de 2020–2026.

### Resultados (`data/results/`)

| Archivo | Contenido |
|---|---|
| `screening_decisions.csv` | Decisión final de título y resumen para cada uno de los 6.326 registros cribados, con la etapa que la produjo |
| `charting_primary.csv` | Codificación principal de los 2.109 registros, con nombres de columna |
| `mapping.csv` | Mapa de evidencia final: codificación tras adjudicación y auditoría de año, unida a los metadatos bibliográficos; `eligible == "Y"` marca los 1.471 estudios incluidos |
| `field_agreement.csv` | Acuerdo y kappa por ítem codificado en la muestra de verificación |
| `screening_disagreements.csv`, `eligibility_disagreements.csv` | Registros en que los dos cribados o las dos codificaciones no coincidieron |
| `counts_screening.json`, `counts_mapping.json` | Conteos usados en el diagrama de flujo PRISMA y en las tablas |

### Etapa de texto completo (`data/fulltext/`)

`candidates.csv` lista los 163 estudios cuyo resumen indicaba o sugería energía medida en hardware por ambos lados, más los seis estudios de la categoría C4. `assessment.tsv` registra los cinco textos completos evaluados (tres incluidos, dos excluidos), `pairs.tsv` los ocho pares ANN–SNN extraídos de los estudios incluidos, y `within_snn_control.tsv` la misma SNN recurrente ejecutada en una GPU y en Loihi, que es un control de sustrato y no un par ANN–SNN. Los archivos `historical_2019_blouw_*.tsv` contienen la evaluación de un trabajo de taller de 2019 exportado con año 2020 y excluido de la ventana por la auditoría de año. Los demás candidatos no se han evaluado a texto completo; el manuscrito presenta el conjunto evaluado como ilustrativo y no como una síntesis exhaustiva.

## Códigos

Categorías de inclusión: C1 comparación empírica ANN–SNN con métrica de eficiencia; C2 poda, esparsidad o reducción de actividad en SNN; C3 familia de lottery tickets en ANN; C4 familia de lottery tickets en SNN; C5 revisión; C6 metodología de benchmarking o medición. Razones de exclusión: E0 año de publicación fuera de 2020–2026 (auditoría de año); E1 no es un artículo de investigación o revisión; E2 nivel de dispositivo, material o circuito sin evaluación a nivel de red; E3 modelado neurocientífico sin tarea de aprendizaje automático; E4 trabajo solo de SNN sin comparación de eficiencia con una ANN y sin contenido de esparsidad; E5 trabajo solo de ANN sin SNN y sin lottery tickets; E6 fuera de tema; E7 poda general de ANN fuera de la familia de lottery tickets y sin SNN. Los vocabularios de los ítems codificados están en `protocols/charting_protocol.txt`.

## Licencia y cita

El código se publica bajo licencia MIT (`LICENSE`); los datos y protocolos bajo CC BY 4.0. Al usar los datos, cite el manuscrito; la referencia se agregará cuando el artículo se publique.
