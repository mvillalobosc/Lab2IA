# data

[Español](#español) · [English](#english)

## Español

Esta carpeta trae los datos que la aplicación carga al abrir. Cada archivo es JavaScript que asigna un objeto a una variable global de `window`, de modo que `index.html` los carga con etiquetas `<script>` y la página funciona sin un servidor de datos. Para el contexto general, revisa el [README del proyecto](../README.md).

`index.html` carga los cuatro archivos en este orden, antes de `js/i18n.js` y `js/app.js`:

| Archivo | Tamaño | Variable global | Contenido |
|---|---|---|---|
| `establecimientos.js` | 23 KB | `window.ESTABLISHMENTS` | Arreglo con los 93 establecimientos con atención de ACV, repartidos en 16 regiones y 67 comunas. |
| `regiones.js` | 32 KB | `window.REGIONES` | GeoJSON `FeatureCollection` con las 16 regiones de Chile. |
| `comunas.js` | 930 KB | `window.COMUNAS` | GeoJSON `FeatureCollection` con las 345 comunas de Chile. |
| `isocronas.js` | 18 MB | `window.ISOCRONAS` | Coberturas en auto de 30, 45 y 60 minutos de los 93 establecimientos. |

Según la ayuda de la aplicación, los establecimientos vienen de las planillas georreferenciadas del proyecto, con coordenadas depuradas, y los límites administrativos vienen de la cartografía oficial de comunas y regiones con códigos CUT. El repositorio no incluye scripts que generen `establecimientos.js`, `regiones.js` ni `comunas.js`.

### `establecimientos.js`

Cada registro tiene diez campos:

| Campo | Contenido |
|---|---|
| `code` | Código del establecimiento (por ejemplo, `101100`). |
| `name` | Nombre del establecimiento. |
| `lat`, `lon` | Coordenadas en WGS84. |
| `comuna`, `provincia`, `region` | Nombres de la comuna, la provincia y la región. |
| `cod_comuna` | Código CUT de la comuna; debe existir en `comunas.js`. |
| `codregion` | Código de la región; debe existir en `regiones.js`. |
| `id` | Identificador interno único, de 1 a 93. Es la clave que usan `isocronas.js`, el estado de `js/app.js`, la caché del navegador (`iso_<id>`) y la columna `codigo` del CSV que descarga la app. |

`generar_isocronas.mjs` lee este archivo quitando el prefijo `window.ESTABLISHMENTS=` y el punto y coma final, así que el contenido debe seguir siendo JSON válido.

### `regiones.js` y `comunas.js`

Las 16 regiones tienen las propiedades `codregion` y `Region`. Las 345 comunas (52 de ellas en la Región Metropolitana) tienen `cod_comuna`, `codregion`, `Comuna`, `Provincia` y `Region`. En los dos archivos hay geometrías `Polygon` y `MultiPolygon`. La aplicación usa `regiones.js` para llenar el selector de regiones, encuadrar el mapa en la región elegida y ponderar la cifra nacional por superficie, y usa `comunas.js` para encuadrar la comuna elegida, saber en qué comuna cae un punto consultado y estimar la cobertura comunal. El selector de comunas no sale de `comunas.js`: muestra solo las comunas que tienen algún establecimiento y las toma de `establecimientos.js`.

### `isocronas.js`

El archivo tiene dos líneas de comentario y una línea de datos. La variable `window.ISOCRONAS` es un objeto cuyas claves son los `id` de los establecimientos (de `"1"` a `"93"`); cada una trae las claves `"30"`, `"45"` y `"60"` con una geometría GeoJSON `Polygon` en coordenadas `[lon, lat]` redondeadas a cuatro decimales. En total hay 279 polígonos. El encabezado indica que el archivo se descargó desde la propia aplicación y que las coberturas se calcularon con OpenRouteService, perfil `driving-car`.

El archivo pesa 18 MB y el navegador tiene que descargarlo entero para abrir la página. Si falta o le faltan establecimientos, la aplicación calcula en vivo lo que falta con OpenRouteService y lo guarda en el navegador. Para regenerarlo hay dos caminos, que el README del proyecto explica en la sección 13.3: descargarlo desde la ventana de ayuda cuando están las 93 coberturas o correr `generar_isocronas.mjs`, que lo escribe aquí.

## English

This folder holds the data that the application loads when it opens. Each file is JavaScript that assigns an object to a global `window` variable, so `index.html` loads them through `<script>` tags and the page works without a data server. For the general context, see the [project README](../README.md).

`index.html` loads the four files in this order, before `js/i18n.js` and `js/app.js`:

| File | Size | Global variable | Content |
|---|---|---|---|
| `establecimientos.js` | 23 KB | `window.ESTABLISHMENTS` | Array with the 93 stroke-care facilities, spread over 16 regions and 67 communes. |
| `regiones.js` | 32 KB | `window.REGIONES` | GeoJSON `FeatureCollection` with the 16 regions of Chile. |
| `comunas.js` | 930 KB | `window.COMUNAS` | GeoJSON `FeatureCollection` with the 345 communes of Chile. |
| `isocronas.js` | 18 MB | `window.ISOCRONAS` | 30, 45 and 60 minute driving coverage for the 93 facilities. |

According to the application's help text, the facilities come from the project's georeferenced spreadsheets, with cleaned coordinates, and the administrative boundaries come from the official cartography of communes and regions with CUT codes. The repository includes no scripts that generate `establecimientos.js`, `regiones.js` or `comunas.js`.

### `establecimientos.js`

Each record has ten fields:

| Field | Content |
|---|---|
| `code` | Facility code (for example, `101100`). |
| `name` | Facility name. |
| `lat`, `lon` | WGS84 coordinates. |
| `comuna`, `provincia`, `region` | Names of the commune, province and region. |
| `cod_comuna` | CUT code of the commune; it must exist in `comunas.js`. |
| `codregion` | Region code; it must exist in `regiones.js`. |
| `id` | Unique internal identifier, from 1 to 93. It is the key used by `isocronas.js`, the state in `js/app.js`, the browser cache (`iso_<id>`) and the `codigo` column of the CSV downloaded from the application. |

`generar_isocronas.mjs` reads this file by removing the `window.ESTABLISHMENTS=` prefix and the final semicolon, so the content must remain valid JSON.

### `regiones.js` and `comunas.js`

The 16 regions have the properties `codregion` and `Region`. The 345 communes (52 of them in the Santiago Metropolitan Region) have `cod_comuna`, `codregion`, `Comuna`, `Provincia` and `Region`. Both files contain `Polygon` and `MultiPolygon` geometries. The application uses `regiones.js` to fill the region selector, frame the map on the selected region and weight the national figure by area, and it uses `comunas.js` to frame the selected commune, find the commune of a queried point and estimate commune-level coverage. The commune selector does not come from `comunas.js`: it lists only the communes that have at least one facility and takes them from `establecimientos.js`.

### `isocronas.js`

The file has two comment lines and one data line. The `window.ISOCRONAS` variable is an object whose keys are the facility `id` values (from `"1"` to `"93"`); each one holds the keys `"30"`, `"45"` and `"60"` with a GeoJSON `Polygon` geometry in `[lon, lat]` coordinates rounded to four decimals. There are 279 polygons in total. The header states that the file was downloaded from the application itself and that the coverage was computed with OpenRouteService, `driving-car` profile.

The file weighs 18 MB and the browser has to download all of it to open the page. If it is missing or lacks facilities, the application computes the missing coverage live with OpenRouteService and stores it in the browser. There are two ways to regenerate it, described in section 13.3 of the project README: download it from the help window once all 93 coverages are available, or run `generar_isocronas.mjs`, which writes it here.
