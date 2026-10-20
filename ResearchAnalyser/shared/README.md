# shared/

[Español](#español) · [English](#english)

## Español

Esta carpeta reúne los estilos y scripts comunes de [ResearchAnalyser](../README.md). Las páginas cargan solo los nueve archivos de la primera tabla; las cuatro subcarpetas son copias que ninguna página usa.

### Archivos que cargan las páginas

| Archivo | Qué hace | Lo cargan |
|---|---|---|
| `theme.css` | Capa visual compartida: paleta USACH, tipografías Fraunces e Inter y componentes. Toma las fuentes de `../publicaciones/fonts/`. | Portada, Publicaciones y Tesis |
| `portal.css` | Estilos de la portada, sobre los tokens de `theme.css`. | Portada |
| `portal.js` | Textos de la portada en los tres idiomas, selector de idioma y conteo de registros, que obtiene cargando desde la portada `publicaciones/data/data.js` y `tesis/data/data.js`. | Portada |
| `institutional.css` | Variables de color por módulo y el conmutador entre módulos. | Publicaciones y Tesis |
| `institutional.js` | Ajusta los colores de cada módulo sin tocar sus datos ni sus cálculos. | Publicaciones y Tesis |
| `academic-tools.css`, `academic-tools.js` | Controles para comparar académicos y para la vista de áreas, en los tres idiomas; los conteos salen de las funciones originales de cada módulo. | Publicaciones y Tesis |
| `asistente.js` | Motor del asistente local: reconoce intenciones y condiciones en español, inglés y portugués. Cada módulo lo configura en su `app_chat.js`. | Publicaciones y Tesis |
| `theme.js` | Aplica una apariencia común a los gráficos de plotly.js. | Publicaciones y Tesis |

Las páginas piden estos archivos con un parámetro de versión (por ejemplo `theme.css?v=20261012-asistente`) para que el navegador no use una copia vieja. Si cambias uno, conviene cambiar también ese parámetro en `../index.html`, `../publicaciones/index.html` y `../tesis/index.html`.

### Copias sin uso

Ninguna página del repositorio carga lo que hay en estas subcarpetas (en total, unos 6 MB):

- `lib/` repite las librerías de `../publicaciones/lib/` (el contenido es el mismo; `leaflet.css` solo cambia en los finales de línea) y suma `pako.min.js`.
- `fonts/` tiene diez tipografías iguales a las de `../publicaciones/fonts/`; le faltan las de Fraunces normal 400, 600 y 900 que usa `theme.css`.
- `webfonts/` tiene `fa-regular-400.woff2` y `fa-solid-900.woff2`, iguales a los de `../publicaciones/webfonts/`, y además `fa-brands-400.woff2` y `fa-v4compatibility.woff2`, que no están en esa carpeta.
- `img/` tiene `logo.png` y `logo2.png` (iguales a `../publicaciones/IMG/`), `logo-diinf-usach.png` y seis ilustraciones (`leo-usach-chat.webp`, `manga-publicaciones.webp`, `manga-tesis.webp`, `publicaciones-academica.webp`, `tesis-academica.webp`, `tesis-chat.webp`). Varias de estas ilustraciones (por ejemplo `manga-publicaciones.webp`, `manga-tesis.webp` y `tesis-academica.webp`) aparecen en las capturas del diseño anterior que guarda [../docs/](../docs/).

## English

This folder gathers the shared styles and scripts of [ResearchAnalyser](../README.md). The pages load only the nine files in the first table; the four subfolders are copies that no page uses.

### Files loaded by the pages

| File | What it does | Loaded by |
|---|---|---|
| `theme.css` | Shared visual layer: USACH palette, Fraunces and Inter fonts, and components. It takes the fonts from `../publicaciones/fonts/`. | Home page, Publications and Theses |
| `portal.css` | Home page styles, built on the tokens of `theme.css`. | Home page |
| `portal.js` | Home page texts in the three languages, language selector and record count, which it obtains by loading `publicaciones/data/data.js` and `tesis/data/data.js` from the home page. | Home page |
| `institutional.css` | Colour variables per module and the module switch. | Publications and Theses |
| `institutional.js` | Adjusts each module's colours without touching its data or calculations. | Publications and Theses |
| `academic-tools.css`, `academic-tools.js` | Controls to compare academics and for the areas view, in the three languages; the counts come from each module's original functions. | Publications and Theses |
| `asistente.js` | Engine of the local assistant: it recognises intents and conditions in Spanish, English and Portuguese. Each module configures it in its `app_chat.js`. | Publications and Theses |
| `theme.js` | Applies a common look to the plotly.js charts. | Publications and Theses |

The pages request these files with a version parameter (for example `theme.css?v=20261012-asistente`) so that the browser does not reuse an old copy. When you change one of them, also change that parameter in `../index.html`, `../publicaciones/index.html` and `../tesis/index.html`.

### Unused copies

No page in the repository loads the contents of these subfolders (about 6 MB in total):

- `lib/` repeats the libraries in `../publicaciones/lib/` (same content; `leaflet.css` differs only in line endings) and adds `pako.min.js`.
- `fonts/` holds ten fonts identical to those in `../publicaciones/fonts/`; it lacks the Fraunces normal 400, 600 and 900 fonts that `theme.css` uses.
- `webfonts/` holds `fa-regular-400.woff2` and `fa-solid-900.woff2`, identical to the ones in `../publicaciones/webfonts/`, plus `fa-brands-400.woff2` and `fa-v4compatibility.woff2`, which that folder lacks.
- `img/` holds `logo.png` and `logo2.png` (identical to `../publicaciones/IMG/`), `logo-diinf-usach.png` and six illustrations (`leo-usach-chat.webp`, `manga-publicaciones.webp`, `manga-tesis.webp`, `publicaciones-academica.webp`, `tesis-academica.webp`, `tesis-chat.webp`). Several of these illustrations (for example `manga-publicaciones.webp`, `manga-tesis.webp` and `tesis-academica.webp`) appear in the screenshots of the earlier design kept in [../docs/](../docs/).
