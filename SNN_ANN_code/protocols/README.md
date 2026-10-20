# protocols/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los protocolos escritos, en inglés, que se aplicaron en cada etapa de la revisión. Los scripts validan las decisiones contra los formatos y vocabularios que estos protocolos fijan, pero ningún script lee los archivos. El contexto está en el [README del proyecto](../README.md).

| Archivo | Etapa | Qué fija |
|---|---|---|
| `screening_protocol.txt` | Cribado por título y resumen | Las preguntas de investigación RQ1 a RQ3, las categorías de inclusión C1 a C6, las razones de exclusión E1 a E7, el uso de UNSURE (menos del 10 % de los registros), la lista de hardware a registrar y el formato de salida: una línea por registro con 5 campos separados por tabulador, sin encabezado y en el orden de entrada. |
| `charting_protocol.txt` | Confirmación de elegibilidad y codificación con el resumen completo | Los criterios de elegibilidad (con aclaraciones sobre qué no es C1 o C2), los 18 ítems de codificación con sus vocabularios (`NA` cuando el ítem no aplica y `NS` cuando aplica pero el texto no lo dice) y el formato de salida de 18 campos sin encabezado. |
| `fulltext_protocol.txt` | Texto completo | La recuperación legal del texto (editorial en acceso abierto, arXiv o repositorio, nunca espejos no autorizados), los criterios de inclusión P1 a P4 y de exclusión FT1 a FT5, la decisión INCLUDE_C4 para lottery tickets en SNN, la extracción de pares ANN-SNN (26 campos), la extracción C4 (12 campos) y la línea de evaluación (8 campos). |

Los nombres de los ítems del protocolo de codificación son abreviados (`elig`, `cats`, `arch`, `plat_snn`, `fulltext`); los scripts y las tablas de resultados usan nombres largos (`eligible`, `categories`, `architecture`, `platform_snn`, `hardware_measured`) en el mismo orden.

## English

This folder holds the written protocols, in English, applied at each stage of the review. The scripts validate the decisions against the formats and vocabularies these protocols define, but no script reads the files. The context is in the [project README](../README.md).

| File | Stage | What it defines |
|---|---|---|
| `screening_protocol.txt` | Title and abstract screening | Research questions RQ1 to RQ3, inclusion categories C1 to C6, exclusion reasons E1 to E7, the use of UNSURE (under 10 % of records), the list of hardware to record and the output format: one line per record with 5 tab-separated fields, no header and in input order. |
| `charting_protocol.txt` | Eligibility confirmation and charting on the complete abstract | The eligibility criteria (with clarifications on what is not C1 or C2), the 18 charting items with their vocabularies (`NA` when the item does not apply and `NS` when it applies but the text does not state it) and the 18-field output format without a header. |
| `fulltext_protocol.txt` | Full text | Legal retrieval of the text (open-access publisher, arXiv or repository, never unauthorised mirrors), inclusion criteria P1 to P4 and exclusion reasons FT1 to FT5, the INCLUDE_C4 decision for lottery tickets in SNNs, the extraction of ANN-SNN pairs (26 fields), the C4 extraction (12 fields) and the assessment line (8 fields). |

The item names in the charting protocol are abbreviated (`elig`, `cats`, `arch`, `plat_snn`, `fulltext`); the scripts and the result tables use long names (`eligible`, `categories`, `architecture`, `platform_snn`, `hardware_measured`) in the same order.
