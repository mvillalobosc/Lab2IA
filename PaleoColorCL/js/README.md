# js/

[Español](#español) · [English](#english)

## Español

Esta carpeta contiene toda la lógica de [PaleoColor CL](../README.md), escrita como módulos ES nativos sin dependencias externas ni empaquetador. Cada página carga un módulo de entrada y ese módulo importa el resto:

| Página | Scripts que carga |
|---|---|
| `index.html` | `vendor/jsQR.js` como script clásico y `app.js` como módulo. |
| `plantillas.html` | `vendor/qrcode.js` como script clásico y `plantillas.js` como módulo. |
| `textos.html` | `textos.js` como módulo. |

Todos los `import` relativos llevan el sufijo `?v=<versión>` (hoy `?v=99`). `tools/sellar_version.py` los reescribe cuando cambia `APP_VERSION` en `config.js`, para que el navegador no mezcle módulos de dos versiones guardados en su caché. Un módulo nuevo debe importarse con ese mismo sufijo.

### Módulos

| Archivo | Qué hace |
|---|---|
| `app.js` | Controla el visor: pantalla de inicio, cámara, ciclo de detección, menú e idioma. Une el seguimiento de la hoja, la captura de color, la animación y la tarjeta de datos. Su constante `BUILD` debe coincidir con `APP_VERSION`. |
| `config.js` | Define las constantes compartidas: `APP_VERSION`, la geometría de la hoja (1200 x 1704 px de página, el QR entre los puntos 480,126 y 720,366, cuatro marcas negras de 67 px), los marcos `vertical`, `apaisado` y `cuadrado`, las rutas de `assets/characters/`, el prefijo `clr2:` del QR y los parámetros de captura, registro y despliegue. |
| `characters.js` | Lee `assets/characters/index.json` y los manifiestos, valida cada manifiesto y obtiene el `id` del personaje a partir del texto del QR. |
| `tracker.js` | Busca el QR y las cuatro marcas en cada cuadro de video, calcula la homografía de la hoja y sostiene la pose mientras la hoja se mueve poco. |
| `geometry.js` | Implementa el álgebra de homografías (normalización de Hartley y ajuste por mínimos cuadrados) y utilidades de puntos que usan el seguimiento y la captura. |
| `texture.js` | Muestrea desde el video los colores pintados dentro del marco del personaje y arma la textura de cada parte. |
| `tear.js` | Dibuja un velo del color del papel sobre el dibujo impreso para que el personaje animado se vea nítido encima. |
| `animation.js` | Anima al personaje con su textura: aplica la coreografía, mueve las partes, dispara la voz y el ambiente y elige la voz del sistema según el idioma. |
| `rig.js` | Define los movimientos de cada parte (`pendulo`, `arrastre`, `cabeceo`, `respira` y `fija`) y las coreografías (`correteo`, `nada`, `vuela`, `alzada`, `parada`, `camina` y `desfile`). |
| `voice.js` | Sintetiza con WebAudio el gruñido o rugido de cada personaje; si un manifiesto trajera clips de audio, también podría reproducirlos. |
| `ambient.js` | Sintetiza el sonido de ambiente según el hábitat (tierra, agua o aire) y exporta las etiquetas y colores de cada hábitat. |
| `facts.js` | Dibuja la tarjeta de datos en realidad aumentada junto a la hoja, siempre derecha para que se pueda leer. |
| `icons.js` | Dibuja los íconos vectoriales con trazos, sin archivos de imagen ni fuentes de íconos. |
| `cover.js` | Arma la portada del visor con las siluetas de los manifiestos. |
| `i18n.js` | Guarda los textos del visor en castellano, inglés y portugués (`TRANSLATIONS`) y crea el traductor. La galería y el editor no lo usan. |
| `credits.js` | Reúne el nombre de la aplicación, la marca institucional (logo y colores), la cita de la memoria de origen y el correo de contacto que se imprimen en cada plantilla. |
| `template.js` | Genera la hoja imprimible de un personaje: QR, marcas, dibujo y pie con logo, cita y contacto. Comparte la geometría de `config.js`, de modo que el visor reconoce cualquier hoja. |
| `plantillas.js` | Controla la galería: búsqueda, filtros por hábitat y periodo, miniaturas, impresión y descarga de cada hoja como `plantilla_<id>.png`. |
| `textos.js` | Controla el editor de fichas: carga un manifiesto, muestra la tarjeta con `drawFactCard` tal como la verá el visor y descarga el manifiesto completo como `<id>.json`. |
| [`vendor/`](vendor/README.md) | Bibliotecas de terceros para leer y generar códigos QR. |

## English

This folder holds all the logic of [PaleoColor CL](../README.md), written as native ES modules with no external dependencies and no bundler. Each page loads one entry module, and that module imports the rest:

| Page | Scripts it loads |
|---|---|
| `index.html` | `vendor/jsQR.js` as a classic script and `app.js` as a module. |
| `plantillas.html` | `vendor/qrcode.js` as a classic script and `plantillas.js` as a module. |
| `textos.html` | `textos.js` as a module. |

Every relative `import` carries the `?v=<version>` suffix (today `?v=99`). `tools/sellar_version.py` rewrites them when `APP_VERSION` changes in `config.js`, so that the browser does not mix cached modules from two versions. A new module must be imported with the same suffix.

### Modules

| File | What it does |
|---|---|
| `app.js` | Runs the viewer: start screen, camera, detection loop, menu and language. It joins sheet tracking, colour capture, animation and the fact card. Its `BUILD` constant must match `APP_VERSION`. |
| `config.js` | Defines the shared constants: `APP_VERSION`, the sheet geometry (1200 x 1704 page pixels, the QR code between points 480,126 and 720,366, four 67 px black markers), the `vertical`, `apaisado` and `cuadrado` frames, the `assets/characters/` paths, the `clr2:` QR prefix and the capture, registration and display parameters. |
| `characters.js` | Reads `assets/characters/index.json` and the manifests, validates each manifest and extracts the character `id` from the QR text. |
| `tracker.js` | Finds the QR code and the four markers in each video frame, computes the sheet homography and holds the pose while the sheet moves little. |
| `geometry.js` | Implements homography algebra (Hartley normalisation and least-squares fitting) and point utilities used by tracking and capture. |
| `texture.js` | Samples the painted colours from the video inside the character frame and builds the texture of each part. |
| `tear.js` | Draws a paper-coloured veil over the printed drawing so that the animated character stands out on top. |
| `animation.js` | Animates the character with its texture: it applies the choreography, moves the parts, triggers voice and ambience and picks the system voice for the current language. |
| `rig.js` | Defines the movement of each part (`pendulo`, `arrastre`, `cabeceo`, `respira` and `fija`) and the choreographies (`correteo`, `nada`, `vuela`, `alzada`, `parada`, `camina` and `desfile`). |
| `voice.js` | Synthesises each character's growl or roar with WebAudio; if a manifest carried audio clips, it could also play them. |
| `ambient.js` | Synthesises the ambient sound for each habitat (land, water or air) and exports the habitat labels and colours. |
| `facts.js` | Draws the augmented-reality fact card next to the sheet, always upright so that it stays readable. |
| `icons.js` | Draws vector icons from paths, with no image files or icon fonts. |
| `cover.js` | Builds the viewer start screen from the manifest silhouettes. |
| `i18n.js` | Stores the viewer texts in Spanish, English and Portuguese (`TRANSLATIONS`) and creates the translator. The gallery and the editor do not use it. |
| `credits.js` | Gathers the application name, the institutional brand (logo and colours), the citation of the original thesis and the contact address printed on every template. |
| `template.js` | Generates the printable sheet of a character: QR code, markers, drawing and a footer with logo, citation and contact. It shares the geometry in `config.js`, so the viewer recognises any sheet. |
| `plantillas.js` | Runs the gallery: search, habitat and period filters, thumbnails, printing and download of each sheet as `plantilla_<id>.png`. |
| `textos.js` | Runs the fact editor: it loads a manifest, previews the card with `drawFactCard` exactly as the viewer will show it and downloads the whole manifest as `<id>.json`. |
| [`vendor/`](vendor/README.md) | Third-party libraries for reading and generating QR codes. |
