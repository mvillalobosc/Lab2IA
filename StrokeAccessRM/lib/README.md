# lib

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda copias locales de las dos bibliotecas de terceros que usa el visor, para que el mapa funcione sin descargar nada de un CDN. `index.html` carga las tres hojas de estilo en el `<head>` y los dos scripts al final de la página, antes de los datos. Las licencias de estas bibliotecas están resumidas en [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md); para el contexto general, revisa el [README del proyecto](../README.md).

| Archivo | Biblioteca | Uso |
|---|---|---|
| `leaflet.js` | Leaflet 1.9.4, versión minificada (licencia BSD 2-Clause) | Dibuja el mapa, las teselas, las capas GeoJSON y los marcadores. |
| `leaflet.css` | Leaflet 1.9.4 | Estilos base del mapa y de sus controles. |
| `images/` | Leaflet 1.9.4 | Cinco íconos PNG de Leaflet: `leaflet.css` apunta a `layers.png`, `layers-2x.png` (control de capas) y `marker-icon.png`, y `leaflet.js` arma desde esa misma carpeta las rutas de `marker-icon-2x.png` y `marker-shadow.png` (marcador por defecto). El visor dibuja sus propios marcadores con `L.divIcon`, así que hoy no muestra estos íconos. |
| `leaflet.markercluster.js` | Leaflet.markercluster, versión minificada (licencia MIT; el archivo no indica su número de versión) | Agrupa los marcadores de establecimientos cuando el mapa está alejado. |
| `MarkerCluster.css` | Leaflet.markercluster | Animaciones de los grupos de marcadores. |
| `MarkerCluster.Default.css` | Leaflet.markercluster | Colores y forma por defecto de los grupos de marcadores. |

`scripts/validate-data.mjs` revisa que `index.html` nombre los cinco archivos de esta carpeta (sin contar `images/`) y que existan.

`leaflet.js`, `leaflet.css`, `leaflet.markercluster.js` y `MarkerCluster.css` son idénticos, byte a byte, a los de `vendor/` en el proyecto hermano [StrokeAccessCL](../../StrokeAccessCL/vendor/README.md). Ese proyecto no trae `MarkerCluster.Default.css` ni la carpeta `images/`.

## English

This folder holds local copies of the two third-party libraries used by the viewer, so the map works without downloading anything from a CDN. `index.html` loads the three stylesheets in the `<head>` and the two scripts at the end of the page, before the data. The licences of these libraries are summarised in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md); for the general context, see the [project README](../README.md).

| File | Library | Use |
|---|---|---|
| `leaflet.js` | Leaflet 1.9.4, minified build (BSD 2-Clause licence) | Draws the map, tiles, GeoJSON layers and markers. |
| `leaflet.css` | Leaflet 1.9.4 | Base styles for the map and its controls. |
| `images/` | Leaflet 1.9.4 | Five Leaflet PNG icons: `leaflet.css` points to `layers.png`, `layers-2x.png` (layers control) and `marker-icon.png`, and `leaflet.js` builds the paths of `marker-icon-2x.png` and `marker-shadow.png` (default marker) from the same folder. The viewer draws its own markers with `L.divIcon`, so it does not show these icons today. |
| `leaflet.markercluster.js` | Leaflet.markercluster, minified build (MIT licence; the file does not state its version number) | Groups the facility markers when the map is zoomed out. |
| `MarkerCluster.css` | Leaflet.markercluster | Animations of the marker clusters. |
| `MarkerCluster.Default.css` | Leaflet.markercluster | Default colours and shape of the marker clusters. |

`scripts/validate-data.mjs` checks that `index.html` names the five files of this folder (not counting `images/`) and that they exist.

`leaflet.js`, `leaflet.css`, `leaflet.markercluster.js` and `MarkerCluster.css` are byte-for-byte identical to the ones in `vendor/` of the sibling project [StrokeAccessCL](../../StrokeAccessCL/vendor/README.md). That project does not include `MarkerCluster.Default.css` or the `images/` folder.
