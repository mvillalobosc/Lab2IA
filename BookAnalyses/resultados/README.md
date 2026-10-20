# resultados/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda los resultados de la corrida del manuscrito sobre el corpus real: 577 observaciones obra-nivel de 527 obras únicas y 26.620.497 palabras, con la versión `2026-08-19-b` del pipeline. El pipeline no escribe aquí. `run_all.R` deja sus salidas en `output/` (que no se versiona) y estos archivos son una selección copiada a mano desde esa carpeta, más algunas piezas que se hicieron fuera del repositorio. Volver a correr el pipeline no actualiza esta carpeta. Vuelve al [README del proyecto](../README.md).

| Carpeta | Contenido |
|---|---|
| [tablas/](tablas/) | 24 tablas CSV: métricas por libro, estadística por nivel, léxico, agrupamiento, desajustados y el mapeo de archivos. |
| [figuras_paper/](figuras_paper/) | Las 8 figuras del manuscrito, en PDF y PNG, con etiquetas en inglés. Ningún script del repositorio las produce. |
| [figuras_pipeline/](figuras_pipeline/) | 11 figuras diagnósticas de los módulos 04 a 08, en PDF y PNG, con títulos en castellano. |

Lo que falta respecto de una corrida completa también importa al leer estos archivos. No están las tablas de tópicos (`topicos_*`), las de sensibilidad sin duplicados (`estadistica_*_sin_duplicados`), `estadistica_gam_polaridad_oraciones.csv`, `desajustados_resumen_modelo.csv` ni `tiempos_ejecucion.csv`; tampoco las figuras `09_topicos_tendencia`, `10_gam_trayectorias` y `11_desajustados`, ni los logs de exclusiones y advertencias, `resultados_maestros.xlsx` o `resumen.md`.

## English

This folder holds the results of the manuscript run on the real corpus: 577 work-grade observations from 527 unique works and 26,620,497 words, with pipeline version `2026-08-19-b`. The pipeline does not write here. `run_all.R` leaves its outputs in `output/` (which is not versioned), and these files are a selection copied by hand from that folder, plus a few pieces made outside the repository. Running the pipeline again does not update this folder. Back to the [project README](../README.md).

| Folder | Contents |
|---|---|
| [tablas/](tablas/) | 24 CSV tables: per-book metrics, per-grade statistics, lexicon, clustering, mismatched books and the file mapping. |
| [figuras_paper/](figuras_paper/) | The 8 manuscript figures, in PDF and PNG, with English labels. No script in the repository produces them. |
| [figuras_pipeline/](figuras_pipeline/) | 11 diagnostic figures from modules 04 to 08, in PDF and PNG, with Spanish titles. |

What is missing compared with a full run also matters when reading these files. The topic tables (`topicos_*`), the sensitivity tables without duplicates (`estadistica_*_sin_duplicados`), `estadistica_gam_polaridad_oraciones.csv`, `desajustados_resumen_modelo.csv` and `tiempos_ejecucion.csv` are not here, and neither are the figures `09_topicos_tendencia`, `10_gam_trayectorias` and `11_desajustados`, the exclusion and warning logs, `resultados_maestros.xlsx` or `resumen.md`.
