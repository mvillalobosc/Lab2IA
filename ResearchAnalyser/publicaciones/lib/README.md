# publicaciones/lib/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda las librerías de terceros que usa [ResearchAnalyser](../../README.md), copiadas aquí para que la app funcione sin internet. Las carga el módulo Publicaciones (`../index.html`) y también el módulo de tesis (`../../tesis/index.html`) y la portada (`../../index.html`), que las piden con rutas a esta carpeta. Las versiones y licencias que siguen son las que declara la cabecera de cada archivo.

| Archivo | Librería y versión | Licencia según la cabecera | La cargan |
|---|---|---|---|
| `jquery.min.js` | jQuery 3.7.1 | jquery.org/license | Publicaciones y Tesis |
| `datatables.min.js`, `datatables.min.css` | DataTables 1.13.7 | datatables.net/license | Publicaciones y Tesis |
| `dt-buttons.min.js`, `dt-buttons.min.css` | Buttons for DataTables 2.4.2 | datatables.net/license | Publicaciones |
| `dt-buttons-html5.min.js` | Botones de exportación HTML5 de Buttons, con FileSaver.js 1.3.3 | datatables.net/license; FileSaver.js con licencia MIT | Publicaciones |
| `plotly.min.js` | plotly.js 2.27.0 | MIT | Publicaciones y Tesis |
| `vis-network.min.js` | vis-network 9.1.9 | Apache 2.0 o MIT, a elección | Publicaciones y Tesis |
| `leaflet.js`, `leaflet.css` | Leaflet 1.9.4 | la cabecera trae el copyright de Vladimir Agafonkin y CloudMade y remite a leafletjs.com | Publicaciones |
| `fa.min.css` | Font Awesome Free 6.5.1 | íconos CC BY 4.0, fuentes SIL OFL 1.1, código MIT | Portada, Publicaciones y Tesis |

`images/` tiene los cinco íconos de Leaflet (`layers.png`, `layers-2x.png`, `marker-icon.png`, `marker-icon-2x.png` y `marker-shadow.png`) que piden `leaflet.css` y los marcadores por defecto de Leaflet. Las tipografías de Font Awesome que nombra `fa.min.css` están en `../webfonts/`.

`../../shared/lib/` guarda una copia de esta carpeta (más `pako.min.js`) que ninguna página carga; lo explica [shared/](../../shared/).

## English

This folder holds the third-party libraries used by [ResearchAnalyser](../../README.md), copied here so that the app works offline. The Publications module (`../index.html`) loads them, and so do the theses module (`../../tesis/index.html`) and the home page (`../../index.html`), which request them with paths into this folder. The versions and licences below are the ones declared in each file's header.

| File | Library and version | Licence according to the header | Loaded by |
|---|---|---|---|
| `jquery.min.js` | jQuery 3.7.1 | jquery.org/license | Publications and Theses |
| `datatables.min.js`, `datatables.min.css` | DataTables 1.13.7 | datatables.net/license | Publications and Theses |
| `dt-buttons.min.js`, `dt-buttons.min.css` | Buttons for DataTables 2.4.2 | datatables.net/license | Publications |
| `dt-buttons-html5.min.js` | HTML5 export buttons for Buttons, bundling FileSaver.js 1.3.3 | datatables.net/license; FileSaver.js under the MIT licence | Publications |
| `plotly.min.js` | plotly.js 2.27.0 | MIT | Publications and Theses |
| `vis-network.min.js` | vis-network 9.1.9 | Apache 2.0 or MIT, at the user's choice | Publications and Theses |
| `leaflet.js`, `leaflet.css` | Leaflet 1.9.4 | the header carries the copyright of Vladimir Agafonkin and CloudMade and points to leafletjs.com | Publications |
| `fa.min.css` | Font Awesome Free 6.5.1 | icons CC BY 4.0, fonts SIL OFL 1.1, code MIT | Home page, Publications and Theses |

`images/` holds the five Leaflet icons (`layers.png`, `layers-2x.png`, `marker-icon.png`, `marker-icon-2x.png` and `marker-shadow.png`) requested by `leaflet.css` and by Leaflet's default markers. The Font Awesome fonts named in `fa.min.css` are in `../webfonts/`.

`../../shared/lib/` keeps a copy of this folder (plus `pako.min.js`) that no page loads; [shared/](../../shared/) explains it.
