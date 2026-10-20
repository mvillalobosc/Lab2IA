# data

[Español](#español) · [English](#english)

## Español

Esta carpeta trae las cuatro capas que dibuja el visor. Cada archivo es una sola línea de JavaScript con la forma `window.DATA_<NOMBRE>=<FeatureCollection>;`: asigna un GeoJSON a una variable global, de modo que `index.html` lo carga con una etiqueta `<script>` y la página funciona sin un servidor de datos. `scripts/validate-data.mjs` exige exactamente ese prefijo y el punto y coma final. Para el contexto general, revisa el [README del proyecto](../README.md); la sección 7 de ese README describe cada campo.

`index.html` carga los archivos en este orden: `comunas.js`, `resultados.js`, `isocronas.js` y `hospitales.js`.

| Archivo | Tamaño | Variable global | Contenido |
|---|---|---|---|
| `resultados.js` | 1,6 MB | `window.DATA_RESULTADOS` | 2.371 zonas censales de la Región Metropolitana con sus indicadores (2.327 `Polygon` y 44 `MultiPolygon`). |
| `comunas.js` | 118 KB | `window.DATA_COMUNAS` | 52 límites comunales (`Polygon`) de 6 provincias. |
| `isocronas.js` | 662 KB | `window.DATA_ISOCRONAS` | 6 isócronas de viaje en auto (`MultiPolygon`), de 10 a 60 minutos. |
| `hospitales.js` | 23 KB | `window.DATA_HOSPITALES` | 113 establecimientos de nivel hospitalario (`Point`). |

Según la ayuda de la aplicación, las capas vienen de la tesis de Garrido Delgado (2023): la microsimulación espacial combina el Censo 2017 y la encuesta CASEN 2022 con el paquete `rakeR` de R, el clustering usa K-Means de `scikit-learn` con cinco grupos, y las isócronas se calcularon con ORS Tools y OpenRouteService sobre la red vial de la BCN, a partir de los 21 hospitales de la base GRD 2019-2021. El repositorio no incluye el código que produjo estos archivos, así que no se pueden recalcular desde aquí.

### `resultados.js`

Cada zona censal trae 14 propiedades sin valores nulos. `geocodigo`, `nom_comuna` (en mayúsculas) y `codigo_com` son textos; el resto son números. Los porcentajes `P_AB`, `P_DB_Diabe` y `P_HT` se calculan sobre la población de 30 años o más, y los conteos `FonasaAoB`, `Diabetes` e `Hipertensi` permiten que el resumen comunal sume las zonas y vuelva a calcular los porcentajes. `minutos_vi` solo toma los valores 10, 20, 30, 40, 50, 60 y 70 (1.518, 491, 133, 79, 61, 29 y 60 zonas, en ese orden); el valor 70 queda fuera de las seis isócronas y la leyenda lo muestra como «> 60». `cluster` va de 0 a 4, con 199, 622, 1.049, 269 y 232 zonas por grupo.

Los 52 valores de `codigo_com` existen como `CUT` en `comunas.js`, y los nombres de `nom_comuna` coinciden con `NOM_COMUNA`.

### `comunas.js`

Cada comuna trae `NOM_COMUNA` (en mayúsculas), `CUT` (número) y `NOM_PROVIN`. El visor dibuja con esta capa los bordes punteados de todas las comunas y, al elegir una comuna, su contorno destacado y el encuadre del mapa. La lista del selector de comunas sale de `nom_comuna` en `resultados.js`.

### `isocronas.js`

Cada isócrona trae la propiedad `contour` con su tiempo en minutos (10, 20, 30, 40, 50 o 60). Son áreas unificadas para el conjunto de los 21 hospitales que atienden ACV, no una por hospital, y la aplicación no las recalcula.

### `hospitales.js`

Cada establecimiento trae `nombre`, `tipo` (`Hospital`, `Clínica` o `Instituto`: 38, 68 y 7), `comuna` (en mayúsculas) y `acv` (verdadero en 21 de ellos). Solo esos 21 traen además `f2019`, `f2020`, `f2021` y `fprom`, con las atenciones de ACV por año y su promedio. La ayuda de la aplicación dice que la lista viene de la planilla `Codigo_Hospital_RM`, con códigos DEIS, pero el archivo no guarda esos códigos.

## English

This folder holds the four layers drawn by the viewer. Each file is a single line of JavaScript of the form `window.DATA_<NAME>=<FeatureCollection>;`: it assigns a GeoJSON object to a global variable, so `index.html` loads it with a `<script>` tag and the page works without a data server. `scripts/validate-data.mjs` requires exactly that prefix and the final semicolon. For the general context, see the [project README](../README.md); section 7 of that README describes each field.

`index.html` loads the files in this order: `comunas.js`, `resultados.js`, `isocronas.js` and `hospitales.js`.

| File | Size | Global variable | Content |
|---|---|---|---|
| `resultados.js` | 1.6 MB | `window.DATA_RESULTADOS` | 2,371 census zones of the Metropolitan Region with their indicators (2,327 `Polygon` and 44 `MultiPolygon`). |
| `comunas.js` | 118 KB | `window.DATA_COMUNAS` | 52 municipality boundaries (`Polygon`) in 6 provinces. |
| `isocronas.js` | 662 KB | `window.DATA_ISOCRONAS` | 6 driving-time isochrones (`MultiPolygon`), from 10 to 60 minutes. |
| `hospitales.js` | 23 KB | `window.DATA_HOSPITALES` | 113 hospital-level facilities (`Point`). |

According to the application's help text, the layers come from Garrido Delgado's thesis (2023): the spatial microsimulation combines the 2017 Census and the 2022 CASEN survey with the R package `rakeR`, the clustering uses `scikit-learn` K-Means with five groups, and the isochrones were computed with ORS Tools and OpenRouteService over the BCN road network, starting from the 21 hospitals in the 2019-2021 DRG dataset. The repository does not include the code that produced these files, so they cannot be recomputed from here.

### `resultados.js`

Each census zone carries 14 properties with no null values. `geocodigo`, `nom_comuna` (upper case) and `codigo_com` are strings; the rest are numbers. The percentages `P_AB`, `P_DB_Diabe` and `P_HT` are computed over the population aged 30 or older, and the counts `FonasaAoB`, `Diabetes` and `Hipertensi` let the municipality summary add up the zones and recompute the percentages. `minutos_vi` only takes the values 10, 20, 30, 40, 50, 60 and 70 (1,518, 491, 133, 79, 61, 29 and 60 zones, in that order); the value 70 lies beyond the six isochrones and the legend shows it as "> 60". `cluster` goes from 0 to 4, with 199, 622, 1,049, 269 and 232 zones per group.

All 52 `codigo_com` values exist as `CUT` in `comunas.js`, and the `nom_comuna` names match `NOM_COMUNA`.

### `comunas.js`

Each municipality carries `NOM_COMUNA` (upper case), `CUT` (a number) and `NOM_PROVIN`. The viewer uses this layer to draw the dashed borders of all municipalities and, when a municipality is selected, its highlighted outline and the map framing. The list in the municipality selector comes from `nom_comuna` in `resultados.js`.

### `isocronas.js`

Each isochrone carries the `contour` property with its time in minutes (10, 20, 30, 40, 50 or 60). They are merged areas for the 21 stroke-treating hospitals as a whole, not one per hospital, and the application does not recompute them.

### `hospitales.js`

Each facility carries `nombre`, `tipo` (`Hospital`, `Clínica` or `Instituto`: 38, 68 and 7), `comuna` (upper case) and `acv` (true for 21 of them). Only those 21 also carry `f2019`, `f2020`, `f2021` and `fprom`, with the stroke admissions per year and their mean. The application's help text says that the list comes from the `Codigo_Hospital_RM` spreadsheet, with DEIS codes, but the file does not store those codes.
