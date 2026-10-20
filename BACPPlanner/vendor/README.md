# vendor/

[Español](#español) · [English](#english)

## Español

Esta carpeta de [BACP-Planner](../README.md) guarda la única librería externa de la app, copiada aquí para que funcione sin internet.

| Archivo | Qué es |
|---|---|
| `xlsx.full.min.js` | SheetJS Community Edition, versión 0.18.5 según el propio archivo, en su compilación completa para navegador (861 KB). Su cabecera dice "xlsx.js (C) 2013-present SheetJS -- http://sheetjs.com". |

`index.html` la carga en su línea 7, con una etiqueta `script` que apunta a `./vendor/xlsx.full.min.js`. La app la usa para leer los libros que se arrastran o eligen (`XLSX.read` y `XLSX.utils.sheet_to_json`), para armar los libros de exportación (`XLSX.utils.book_new`, `json_to_sheet` y `book_append_sheet`) y para descargarlos (`XLSX.writeFile`).

El archivo no trae el texto de su licencia. [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) aclara que este componente no queda cubierto por la licencia MIT del proyecto y pide conservar sus avisos y cumplir los términos de la versión incluida. Si se reemplaza por otra versión, hay que actualizar también ese archivo y probar la importación y exportación de los tres módulos.

## English

This folder of [BACP-Planner](../README.md) holds the app's only external library, copied here so that the app works offline.

| File | What it is |
|---|---|
| `xlsx.full.min.js` | SheetJS Community Edition, version 0.18.5 according to the file itself, in its full browser build (861 KB). Its header reads "xlsx.js (C) 2013-present SheetJS -- http://sheetjs.com". |

`index.html` loads it on line 7, with a `script` tag that points to `./vendor/xlsx.full.min.js`. The app uses it to read the workbooks that are dropped or chosen (`XLSX.read` and `XLSX.utils.sheet_to_json`), to build the export workbooks (`XLSX.utils.book_new`, `json_to_sheet` and `book_append_sheet`) and to download them (`XLSX.writeFile`).

The file does not include its licence text. [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) states that this component is not covered by the project's MIT licence and asks to keep its notices and comply with the terms of the bundled version. When replacing it with another version, update that file as well and test import and export in the three modules.
