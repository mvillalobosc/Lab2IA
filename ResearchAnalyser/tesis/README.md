# tesis/

[Español](#español) · [English](#english)

## Español

Esta carpeta es el módulo Tesis y memorias de [ResearchAnalyser](../README.md). La página `index.html` toma jQuery, DataTables, plotly.js, vis-network, Font Awesome y la hoja `interface.css` de [../publicaciones/](../publicaciones/), lee los datos de [data/](data/) y usa los recursos comunes de [../shared/](../shared/).

### Página y scripts

`index.html` carga, después de las librerías y de `data/data.js`, estos scripts en orden: `app_clave.js`, `app.js`, `app_profile.js`, `app_views.js`, `app_report.js`, `app_init.js`, `app_wordcloud.js`, `app_compare.js`, `app_analytics.js`, `../shared/asistente.js`, `app_chat.js`, `app_i18n.js`, los tres scripts comunes de `../shared/` y al final `interface.js`.

| Archivo | Qué hace |
|---|---|
| `index.html` | Arma la página del módulo; su pie indica el periodo de la base (2015 a 2025) y la fecha de actualización. |
| `app.js` | Es el núcleo: paleta de colores, programas de pregrado y posgrado, funciones de apoyo y filtros, entre ellos el de enlace al repositorio. |
| `app_init.js` | Lee el CSV separado por comas, carga `window.MEMORIAS_CSV` y `window.ACADEMICOS_CSV` desde `data/data.js`, conecta los eventos y arranca el módulo. Si `data.js` no define esas variables, pide `data/memorias.csv` y `data/academicos.csv` con `fetch`, lo que solo funciona cuando la carpeta se sirve por http. |
| `app_views.js` | Dibuja las vistas Resumen, Indicadores, Dominio y Registros, y coordina el redibujo de todas. |
| `app_profile.js` | Arma el perfil de cada académico: tarjeta, rol de guía o co-guía, diagrama de flujo de áreas, red de coautorías y nube de palabras. |
| `app_compare.js` | Compara dos académicos, o uno contra el resto del departamento, con una prueba chi cuadrado y residuos estandarizados. |
| `app_analytics.js` | Calcula hallazgos automáticos, oportunidades de colaboración y alertas de continuidad, y ofrece un buscador global. |
| `app_wordcloud.js` | Dibuja la nube de palabras con un motor propio, sin librerías. |
| `app_report.js` | Genera los informes HTML y CSV de cada vista con los filtros activos. |
| `app_chat.js` | Configura el asistente para esta base; el motor está en `../shared/asistente.js`. |
| `app_i18n.js` | Traduce la interfaz al portugués y al inglés y maneja las ayudas y las referencias ACM. |
| `app_clave.js` | Pide la contraseña antes de descargar la base completa y guarda solo su hash SHA-256. Es idéntico al de `../publicaciones/`. |
| `interface.js` | Agrega la capa de navegación y presentación del módulo, sobre las funciones originales de filtro, análisis, perfiles e informes. |
| `regenerar_datos.py` | Reescribe `data/data.js` desde `data/memorias.csv` y `data/academicos.csv`. Se ejecuta con `python regenerar_datos.py` dentro de esta carpeta. |

### Estilos

| Archivo | Qué hace |
|---|---|
| `styles.css` | Hoja original del módulo, que se conserva para los gráficos heredados; declara siete tipografías de `fonts/` y la página la carga. |
| `interface.css` | Ajusta el espacio de trabajo del módulo encima de `styles.css` y de `../publicaciones/interface.css`. |

### Recursos sin carpeta propia de documentación

- `fonts/` tiene siete tipografías `woff2` (Inter y Space Grotesk) que usa `styles.css`. Son copias idénticas de las que están en `../publicaciones/fonts/`.
- `IMG/` tiene `logo.png` y `logo2.png`, copias idénticas de `../publicaciones/IMG/`: la página usa el primero en la cabecera y el segundo como ícono de la pestaña, y `app_profile.js` usa `logo2.png` en los perfiles.
- `.nojekyll` es una marca vacía para GitHub Pages.

### Carpeta de datos

- [data/](data/): trabajos de título, académicos, los Excel de origen, la versión empaquetada y el conversor en R.

## English

This folder is the Theses and projects module of [ResearchAnalyser](../README.md). Its `index.html` page takes jQuery, DataTables, plotly.js, vis-network, Font Awesome and the `interface.css` stylesheet from [../publicaciones/](../publicaciones/), reads the data in [data/](data/) and uses the shared resources in [../shared/](../shared/).

### Page and scripts

After the libraries and `data/data.js`, `index.html` loads these scripts in order: `app_clave.js`, `app.js`, `app_profile.js`, `app_views.js`, `app_report.js`, `app_init.js`, `app_wordcloud.js`, `app_compare.js`, `app_analytics.js`, `../shared/asistente.js`, `app_chat.js`, `app_i18n.js`, the three shared scripts in `../shared/` and finally `interface.js`.

| File | What it does |
|---|---|
| `index.html` | Builds the module page; its footer states the period of the database (2015 to 2025) and the update date. |
| `app.js` | Core of the module: colour palette, undergraduate and graduate programmes, helper functions and filters, including the repository link filter. |
| `app_init.js` | Parses the comma-separated CSV, loads `window.MEMORIAS_CSV` and `window.ACADEMICOS_CSV` from `data/data.js`, wires the events and starts the module. When `data.js` does not define those variables, it requests `data/memorias.csv` and `data/academicos.csv` with `fetch`, which only works when the folder is served over http. |
| `app_views.js` | Draws the Overview, Indicators, Domain and Records views and coordinates redrawing all of them. |
| `app_profile.js` | Builds each academic's profile: card, supervisor or co-supervisor role, area flow diagram, co-authorship network and word cloud. |
| `app_compare.js` | Compares two academics, or one against the rest of the department, with a chi-squared test and standardised residuals. |
| `app_analytics.js` | Computes automatic insights, collaboration opportunities and continuity alerts, and provides a global search. |
| `app_wordcloud.js` | Draws the word cloud with its own engine, without libraries. |
| `app_report.js` | Generates the HTML and CSV reports of each view with the active filters. |
| `app_chat.js` | Configures the assistant for this database; the engine lives in `../shared/asistente.js`. |
| `app_i18n.js` | Translates the interface into Portuguese and English and handles the help texts and the ACM references. |
| `app_clave.js` | Asks for the password before the full database is downloaded and stores only its SHA-256 hash. It is identical to the one in `../publicaciones/`. |
| `interface.js` | Adds the module's navigation and presentation layer on top of the original filter, analysis, profile and report functions. |
| `regenerar_datos.py` | Rewrites `data/data.js` from `data/memorias.csv` and `data/academicos.csv`. Run it with `python regenerar_datos.py` inside this folder. |

### Stylesheets

| File | What it does |
|---|---|
| `styles.css` | Original stylesheet of the module, kept for the legacy charts; it declares seven fonts from `fonts/` and the page loads it. |
| `interface.css` | Adjusts the module workspace on top of `styles.css` and `../publicaciones/interface.css`. |

### Resources without their own documentation folder

- `fonts/` holds seven `woff2` fonts (Inter and Space Grotesk) used by `styles.css`. They are identical copies of the ones in `../publicaciones/fonts/`.
- `IMG/` holds `logo.png` and `logo2.png`, identical copies of `../publicaciones/IMG/`: the page uses the first one in the header and the second one as the browser tab icon, and `app_profile.js` uses `logo2.png` in the profiles.
- `.nojekyll` is an empty marker for GitHub Pages.

### Data folder

- [data/](data/): degree projects, academics, the source Excel files, the packed version and the R converter.
