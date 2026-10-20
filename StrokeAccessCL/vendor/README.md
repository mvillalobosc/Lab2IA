# vendor

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda copias locales de las dos bibliotecas de terceros que usa la aplicación, para que el mapa funcione sin descargar nada de un CDN. `index.html` carga las hojas de estilo en el `<head>` y los scripts al final de la página, antes de los datos. Para el contexto general, revisa el [README del proyecto](../README.md).

| Archivo | Biblioteca | Uso |
|---|---|---|
| `leaflet.js` | Leaflet 1.9.4 (versión minificada; su cabecera dice "(c) 2010-2023 Vladimir Agafonkin, (c) 2010-2011 CloudMade") | Dibuja el mapa, las teselas, los polígonos GeoJSON y los marcadores. |
| `leaflet.css` | Leaflet 1.9.4 | Estilos base del mapa y de sus controles. |
| `leaflet.markercluster.js` | Leaflet.markercluster (versión minificada; el archivo no indica su número de versión) | Agrupa los marcadores de establecimientos cuando el mapa está alejado. |
| `MarkerCluster.css` | Leaflet.markercluster | Animaciones de los grupos de marcadores. La aplicación define el aspecto de los grupos en `css/estilos.css`, por eso no trae `MarkerCluster.Default.css`. |

Los cuatro archivos son idénticos, byte a byte, a los de `lib/` en el proyecto hermano [StrokeAccessRM](../../StrokeAccessRM/lib/README.md). Según el aviso de terceros de ese proyecto, Leaflet se distribuye con licencia BSD 2-Clause y Leaflet.markercluster con licencia MIT; los dos conservan sus licencias, que no cubre el archivo `LICENSE` de este proyecto.

`leaflet.css` hace referencia a imágenes en `images/` (`layers.png`, `layers-2x.png` y `marker-icon.png`), y esa carpeta no existe aquí. La aplicación no las necesita, porque dibuja todos sus marcadores con `L.divIcon` y no usa el control de capas de Leaflet; si algún cambio usa los marcadores por defecto de Leaflet, hay que agregar esas imágenes.

## English

This folder holds local copies of the two third-party libraries used by the application, so the map works without downloading anything from a CDN. `index.html` loads the stylesheets in the `<head>` and the scripts at the end of the page, before the data. For the general context, see the [project README](../README.md).

| File | Library | Use |
|---|---|---|
| `leaflet.js` | Leaflet 1.9.4 (minified build; its header reads "(c) 2010-2023 Vladimir Agafonkin, (c) 2010-2011 CloudMade") | Draws the map, tiles, GeoJSON polygons and markers. |
| `leaflet.css` | Leaflet 1.9.4 | Base styles for the map and its controls. |
| `leaflet.markercluster.js` | Leaflet.markercluster (minified build; the file does not state its version number) | Groups the facility markers when the map is zoomed out. |
| `MarkerCluster.css` | Leaflet.markercluster | Animations of the marker clusters. The application defines how clusters look in `css/estilos.css`, which is why it does not include `MarkerCluster.Default.css`. |

The four files are byte-for-byte identical to the ones in `lib/` of the sibling project [StrokeAccessRM](../../StrokeAccessRM/lib/README.md). According to that project's third-party notices, Leaflet is distributed under the BSD 2-Clause licence and Leaflet.markercluster under the MIT licence; both keep their own licences, which this project's `LICENSE` file does not cover.

`leaflet.css` refers to images in `images/` (`layers.png`, `layers-2x.png` and `marker-icon.png`), and that folder does not exist here. The application does not need them, because it draws all its markers with `L.divIcon` and does not use Leaflet's layers control; if a change uses Leaflet's default markers, those images must be added.
