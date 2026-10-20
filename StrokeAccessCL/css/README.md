# css

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene la única hoja de estilos propia de la aplicación. La carga `index.html`, después de las hojas de Leaflet que están en [vendor/](../vendor/README.md). Para el contexto general del proyecto, revisa el [README principal](../README.md).

### `estilos.css`

El archivo tiene 327 líneas y se ordena en siete bloques marcados con comentarios:

| Bloque | Qué define |
|---|---|
| `tokens` | Variables de color y forma en `:root`: `--mar` (`#394049`), `--mar-2` (`#EA7600`), `--cruz` (`#C8102E`, rojo de emergencia), los colores de los tres tiempos (`--t30` `#00A499`, `--t45` `#EAAA00`, `--t60` `#EA7600`), grises, sombra y radio de borde. |
| `layout` | La grilla de la página (encabezado de 58 px y panel lateral de 372 px junto al mapa), el encabezado con el logo del DIINF, sus botones y las banderas de idioma. |
| `panel` | Los pasos del panel lateral, las ayudas, los selectores, los botones de modo y los botones de 30, 45 y 60 minutos. |
| `cuadro de cobertura (firma)` | Las tarjetas de cobertura con sus barras, el bloque de riesgo regional, el buscador de establecimientos y las fichas de los establecimientos elegidos. |
| `punto` | El buscador de direcciones y sus sugerencias, los botones de consulta, el resultado con el veredicto por tiempo, la lista de hospitales cercanos y el bloque de funciones avanzadas. |
| `mapa` | Los ajustes sobre Leaflet: marcadores propios (`.pin-h`), grupos de marcadores (`.marker-cluster`), ventanas emergentes, leyenda, avisos (`.aviso`), píldora de preparación (`.prep`), recuadro de emergencia (`.emerg`), marcador del punto consultado (`.punto-marker`) y cursor de mira. |
| `overlays` | El velo de fondo, la tarjeta de bienvenida, la ventana de ayuda, el botón de descarga del CSV, las ventanas de las preguntas "?" y las barras de desplazamiento. |

Los textos usan Helvetica Neue, Helvetica o Arial, y los títulos usan Bebas Neue, que `index.html` pide a Google Fonts; sin conexión, el navegador usa Impact o una tipografía sans serif de reemplazo. La hoja tiene tres reglas `@media`: una desactiva las animaciones cuando el sistema pide menos movimiento, otra achica los botones de idioma bajo 640 px y la tercera, bajo 900 px, apila el mapa sobre el panel, pliega la leyenda y reduce avisos y ventanas.

Los colores de las isócronas que pinta el mapa también están en `js/app.js` (constante `TIER_COLOR`), así que un cambio de color debe hacerse en los dos archivos.

## English

This folder holds the application's only stylesheet of its own. `index.html` loads it after the Leaflet stylesheets stored in [vendor/](../vendor/README.md). For the general context of the project, see the [main README](../README.md).

### `estilos.css`

The file has 327 lines and is organised in seven blocks marked by comments:

| Block | What it defines |
|---|---|
| `tokens` | Colour and shape variables in `:root`: `--mar` (`#394049`), `--mar-2` (`#EA7600`), `--cruz` (`#C8102E`, emergency red), the colours of the three travel times (`--t30` `#00A499`, `--t45` `#EAAA00`, `--t60` `#EA7600`), greys, shadow and border radius. |
| `layout` | The page grid (a 58 px header and a 372 px side panel next to the map), the header with the DIINF logo, its buttons and the language flags. |
| `panel` | The side-panel steps, hints, selectors, mode buttons and the 30, 45 and 60 minute buttons. |
| `cuadro de cobertura (firma)` | The coverage cards with their bars, the regional risk block, the facility search box and the chips of the selected facilities. |
| `punto` | The address search box and its suggestions, the query buttons, the result with its travel-time verdict, the list of nearby hospitals and the advanced functions block. |
| `mapa` | Leaflet adjustments: custom markers (`.pin-h`), marker clusters (`.marker-cluster`), pop-ups, legend, notices (`.aviso`), the preparation pill (`.prep`), the emergency box (`.emerg`), the queried-point marker (`.punto-marker`) and the crosshair cursor. |
| `overlays` | The background veil, the welcome card, the help window, the CSV download button, the "?" pop-overs and the scrollbars. |

Body text uses Helvetica Neue, Helvetica or Arial, and headings use Bebas Neue, which `index.html` requests from Google Fonts; without a connection the browser falls back to Impact or a sans-serif typeface. The stylesheet has three `@media` rules: one disables animations when the system asks for reduced motion, another shrinks the language buttons below 640 px, and the third one, below 900 px, stacks the map above the panel, folds the legend and makes notices and windows smaller.

The isochrone colours drawn on the map are also defined in `js/app.js` (the `TIER_COLOR` constant), so a colour change must be made in both files.
