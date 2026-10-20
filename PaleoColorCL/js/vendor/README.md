# js/vendor/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las dos bibliotecas de terceros que usa [PaleoColor CL](../../README.md) y el texto de la licencia de una de ellas. Las dos bibliotecas se cargan como scripts clásicos (no como módulos) y quedan disponibles como variables globales. `tools/sellar_version.py` no reescribe nada dentro de esta carpeta.

| Archivo | Qué es y quién lo usa |
|---|---|
| `jsQR.js` | Lector de códigos QR jsQR 1.4.0 (build UMD, 257 KB), publicado con licencia Apache 2.0 en [github.com/cozmo/jsQR](https://github.com/cozmo/jsQR). Es idéntico byte a byte al `dist/jsQR.js` del paquete npm `jsqr@1.4.0`, aunque el archivo no trae cabecera de licencia ni número de versión. Lo carga `index.html`, y `js/tracker.js` lo llama como `window.jsQR(...)` para leer el QR de la hoja en cada cuadro de video. |
| `jsQR-LICENSE.txt` | Texto completo de la licencia Apache 2.0, copiado sin cambios del archivo `LICENSE` del paquete npm `jsqr@1.4.0`. Va junto a `jsQR.js` porque esa licencia pide entregar una copia con el código. Ninguna página lo carga. |
| `qrcode.js` | Generador de códigos QR ("QR Code Generator for JavaScript", Copyright (c) 2009 Kazuhiko Arase), publicado bajo licencia MIT según su cabecera. Lo carga `plantillas.html`, y `js/template.js` lo llama como `window.qrcode(1, "M")` para dibujar el QR versión 1 con corrección M de cada plantilla. |

Con corrección M y un `id` de hasta 9 caracteres, el QR queda en versión 1 (21 x 21 módulos), que es lo que el comentario de `js/template.js` exige para que jsQR lo lea a distancia. Las licencias de estas bibliotecas no están en el archivo `LICENSE` del proyecto: `qrcode.js` conserva la licencia MIT de su cabecera y `jsQR.js` la Apache 2.0 de `jsQR-LICENSE.txt`.

## English

This folder stores the two third-party libraries that [PaleoColor CL](../../README.md) uses and the licence text of one of them. Both libraries are loaded as classic scripts (not as modules) and become global variables. `tools/sellar_version.py` rewrites nothing inside this folder.

| File | What it is and who uses it |
|---|---|
| `jsQR.js` | QR code reader jsQR 1.4.0 (UMD build, 257 KB), released under the Apache 2.0 licence at [github.com/cozmo/jsQR](https://github.com/cozmo/jsQR). It is byte-for-byte identical to `dist/jsQR.js` in the npm package `jsqr@1.4.0`, although the file carries no licence header and no version number. `index.html` loads it, and `js/tracker.js` calls it as `window.jsQR(...)` to read the sheet QR code in each video frame. |
| `jsQR-LICENSE.txt` | Full text of the Apache 2.0 licence, copied unchanged from the `LICENSE` file of the npm package `jsqr@1.4.0`. It sits next to `jsQR.js` because that licence asks for a copy to be delivered with the code. No page loads it. |
| `qrcode.js` | QR code generator ("QR Code Generator for JavaScript", Copyright (c) 2009 Kazuhiko Arase), released under the MIT licence according to its header. `plantillas.html` loads it, and `js/template.js` calls it as `window.qrcode(1, "M")` to draw the version 1 QR code with M error correction on every template. |

With M correction and an `id` of up to 9 characters, the QR code stays at version 1 (21 x 21 modules), which is what the comment in `js/template.js` requires for jsQR to read it from a distance. The licences of these libraries are not included in the project `LICENSE` file: `qrcode.js` keeps the MIT licence in its header and `jsQR.js` the Apache 2.0 licence in `jsQR-LICENSE.txt`.
