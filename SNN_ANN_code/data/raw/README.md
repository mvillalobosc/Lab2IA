# data/raw/

[Español](#español) · [English](#english)

## Español

Esta carpeta debería tener las exportaciones de Scopus y Web of Science, pero el repositorio solo distribuye `search_strings.txt`: las exportaciones traen resúmenes y palabras clave indexadas que pertenecen a las bases de datos, y el `.gitignore` del proyecto excluye `data/raw/*.csv`, `*.xls` y `*.xlsx`. Volver a la descripción general en el [README del proyecto](../../README.md).

| Archivo | Contenido |
|---|---|
| `search_strings.txt` | Las cuatro cadenas de búsqueda que se corrieron el 14 de octubre de 2026 (bloques A y B en Scopus y en Web of Science Core Collection, combinados con OR) y las instrucciones de exportación. |

### Cómo reconstruir las exportaciones

Según `search_strings.txt`, Scopus se exporta como CSV con "Citation information", "Bibliographical information" y "Abstract & keywords" y se guarda como `Scopus.csv` (6.092 registros en la fecha de búsqueda); Web of Science se exporta como "Full Record" en lotes de 1.000 y se guarda como `Wos1.xls` a `Wos5.xls` (4.688 registros). `01_deduplicate.R` busca exactamente esos nombres (`Scopus.csv` y los archivos que calzan con `^Wos.*\.xls$`), y `00_run_all.R` solo corre los pasos que necesitan los resúmenes si encuentra `Scopus.csv`.

Una búsqueda repetida hoy no devolverá los mismos registros, porque las bases cambian, y en ese caso `01_deduplicate.R` se detiene al no encontrar en `data/records/record_ids.csv` el identificador de los registros nuevos.

## English

This folder should hold the Scopus and Web of Science exports, but the repository only distributes `search_strings.txt`: the exports carry abstracts and indexed keywords that belong to the databases, and the project `.gitignore` excludes `data/raw/*.csv`, `*.xls` and `*.xlsx`. Back to the overview in the [project README](../../README.md).

| File | Content |
|---|---|
| `search_strings.txt` | The four search strings run on 14 October 2026 (blocks A and B in Scopus and in the Web of Science Core Collection, combined with OR) and the export instructions. |

### How to rebuild the exports

According to `search_strings.txt`, Scopus is exported as CSV with "Citation information", "Bibliographical information" and "Abstract & keywords" and saved as `Scopus.csv` (6,092 records on the search date); Web of Science is exported as "Full Record" in batches of 1,000 and saved as `Wos1.xls` to `Wos5.xls` (4,688 records). `01_deduplicate.R` looks for exactly those names (`Scopus.csv` and the files matching `^Wos.*\.xls$`), and `00_run_all.R` only runs the steps that need the abstracts when it finds `Scopus.csv`.

A search repeated today will not return the same records, because the databases change, and `01_deduplicate.R` then stops when it cannot find the identifier of the new records in `data/records/record_ids.csv`.
