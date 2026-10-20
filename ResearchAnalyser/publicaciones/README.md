# publicaciones/

[Español](#español) · [English](#english)

## Español

Esta carpeta es el módulo Publicaciones de [ResearchAnalyser](../README.md). La página `index.html` carga las librerías de [lib/](lib/), los datos de [data/](data/), los scripts y estilos de esta carpeta y los recursos comunes de [../shared/](../shared/). El módulo de tesis reutiliza las librerías de `lib/` y la hoja `interface.css` de aquí.

### Página y scripts

`index.html` carga los scripts en este orden: librerías, `data/data.js`, `app_clave.js`, `app.js`, `app_viz.js`, `app_profile.js`, `../shared/asistente.js`, `app_chat.js`, `app_analytics.js`, `app_init.js`, `app_i18n_ext.js`, los tres scripts comunes de `../shared/` y al final `interface.js`.

| Archivo | Qué hace |
|---|---|
| `index.html` | Arma la página del módulo y su pie, que trae el contacto, la fecha de actualización de los datos y la cita del paper. |
| `app.js` | Es el núcleo: define la paleta, lee el CSV separado por `|`, calcula las métricas y guarda los textos de ayuda en castellano. |
| `app_init.js` | Trae las coordenadas y alias de países, conecta los eventos y el control de años, exporta CSV, arma los informes HTML y arranca el módulo leyendo `window.PAPERS_CSV`. |
| `app_viz.js` | Dibuja los perfiles y la vista de dominio, incluido el mapa de colaboración de Leaflet, y enlaza cada académico con Scopus y Web of Science. |
| `app_profile.js` | Arma el perfil individual de cada académico con autores, enlaces, cuartiles, citas, países e idiomas. |
| `app_analytics.js` | Calcula los hallazgos, la comparación con chi cuadrado y las oportunidades. |
| `app_chat.js` | Configura el asistente para esta base: campos, sinónimos y formato de las respuestas. El motor está en `../shared/asistente.js`. |
| `app_i18n_ext.js` | Traduce al inglés y al portugués las ayudas y las tablas; el castellano vive en `app.js`. |
| `app_clave.js` | Pide la contraseña antes de descargar la base completa y guarda solo su hash SHA-256. Es idéntico al de `../tesis/`. |
| `interface.js` | Agrega la navegación por tareas, el dibujo diferido de las vistas y el catálogo completo de publicaciones, y construye los enlaces a `../index.html`. |
| `regenerar_datos.py` | Reescribe `data/data.js` desde `data/BD_papers.csv`. Se ejecuta con `python regenerar_datos.py` dentro de esta carpeta. |

### Estilos

| Archivo | Qué hace |
|---|---|
| `interface.css` | Importa `interface-components.css` y declara cinco tipografías de `fonts/`. También la carga el módulo de tesis. |
| `interface-components.css` | Define tarjetas, secciones y componentes de la interfaz. |
| `summary.css` | Da estilo a la vista Resumen; todos sus selectores quedan dentro de `#p-resumen`. |
| `styles.css` | Es la hoja de una versión anterior ("Analizador Bibliometrico v15"). Ninguna página la carga. |

### Recursos sin carpeta propia de documentación

- `fonts/` tiene 13 tipografías `woff2` (Fraunces, Inter y Space Grotesk). Las usan `../shared/theme.css` (ocho) e `interface.css` (cinco); cuatro de ellas (`inter-latin-800-normal`, `space-grotesk-latin-400-normal`, `-500-normal` y `-700-normal`) solo las nombra `styles.css`, que ninguna página carga.
- `webfonts/` tiene los íconos de Font Awesome que carga `lib/fa.min.css`: `fa-regular-400.woff2` y `fa-solid-900.woff2`. Los dos `.ttf` no los nombra ningún archivo. `fa.min.css` también nombra `fa-brands-400.woff2` y `fa-v4compatibility.woff2`, que no están en esta carpeta; como ninguna página usa íconos de marca, el navegador no los pide.
- `IMG/` tiene `logo.png` (logo del Departamento, en la cabecera de la portada y de este módulo) y `logo2.png` (ícono de la pestaña). `../tesis/IMG/` guarda copias idénticas.
- `.nojekyll` es una marca vacía para GitHub Pages.

### Carpetas

- [data/](data/): la base de publicaciones, su versión empaquetada y el conversor en R.
- [lib/](lib/): librerías de terceros con sus versiones.

## English

This folder is the Publications module of [ResearchAnalyser](../README.md). Its `index.html` page loads the libraries in [lib/](lib/), the data in [data/](data/), the scripts and styles in this folder and the shared resources in [../shared/](../shared/). The theses module reuses the libraries in `lib/` and the `interface.css` stylesheet from here.

### Page and scripts

`index.html` loads the scripts in this order: libraries, `data/data.js`, `app_clave.js`, `app.js`, `app_viz.js`, `app_profile.js`, `../shared/asistente.js`, `app_chat.js`, `app_analytics.js`, `app_init.js`, `app_i18n_ext.js`, the three shared scripts in `../shared/` and finally `interface.js`.

| File | What it does |
|---|---|
| `index.html` | Builds the module page and its footer, which holds the contact address, the data update date and the paper citation. |
| `app.js` | Core of the module: it defines the colour palette, parses the `|`-separated CSV, computes the metrics and stores the Spanish help texts. |
| `app_init.js` | Holds country coordinates and aliases, wires the events and the year control, exports CSV files, builds the HTML reports and starts the module by reading `window.PAPERS_CSV`. |
| `app_viz.js` | Draws the profiles and the domain view, including the Leaflet collaboration map, and links each academic to Scopus and Web of Science. |
| `app_profile.js` | Builds each academic's individual profile with authors, links, quartiles, citations, countries and languages. |
| `app_analytics.js` | Computes the insights, the chi-squared comparison and the opportunities. |
| `app_chat.js` | Configures the assistant for this database: fields, synonyms and answer format. The engine lives in `../shared/asistente.js`. |
| `app_i18n_ext.js` | Translates the help texts and tables into English and Portuguese; the Spanish text lives in `app.js`. |
| `app_clave.js` | Asks for the password before the full database is downloaded and stores only its SHA-256 hash. It is identical to the one in `../tesis/`. |
| `interface.js` | Adds the task-based navigation, deferred rendering of the views and the full publication catalogue, and builds the links to `../index.html`. |
| `regenerar_datos.py` | Rewrites `data/data.js` from `data/BD_papers.csv`. Run it with `python regenerar_datos.py` inside this folder. |

### Stylesheets

| File | What it does |
|---|---|
| `interface.css` | Imports `interface-components.css` and declares five fonts from `fonts/`. The theses module loads it too. |
| `interface-components.css` | Defines cards, sections and interface components. |
| `summary.css` | Styles the Overview view; all its selectors stay inside `#p-resumen`. |
| `styles.css` | Stylesheet of an earlier version ("Analizador Bibliometrico v15"). No page loads it. |

### Resources without their own documentation folder

- `fonts/` holds 13 `woff2` fonts (Fraunces, Inter and Space Grotesk). `../shared/theme.css` uses eight of them and `interface.css` uses five; four (`inter-latin-800-normal`, `space-grotesk-latin-400-normal`, `-500-normal` and `-700-normal`) are named only by `styles.css`, which no page loads.
- `webfonts/` holds the Font Awesome icon fonts loaded by `lib/fa.min.css`: `fa-regular-400.woff2` and `fa-solid-900.woff2`. No file refers to the two `.ttf` files. `fa.min.css` also names `fa-brands-400.woff2` and `fa-v4compatibility.woff2`, which are not in this folder; since no page uses brand icons, the browser never requests them.
- `IMG/` holds `logo.png` (department logo, shown in the header of the home page and of this module) and `logo2.png` (browser tab icon). `../tesis/IMG/` keeps identical copies.
- `.nojekyll` is an empty marker for GitHub Pages.

### Folders

- [data/](data/): the publications database, its packed version and the R converter.
- [lib/](lib/): third-party libraries with their versions.
