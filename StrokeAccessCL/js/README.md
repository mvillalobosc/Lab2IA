# js

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el código de la aplicación que corre en el navegador. Son scripts clásicos, sin módulos ni empaquetador, que `index.html` carga al final de la página: primero `i18n.js` y después `app.js`, cuando ya están cargados Leaflet ([vendor/](../vendor/README.md)) y los datos ([data/](../data/README.md)). Para el contexto general, revisa el [README del proyecto](../README.md).

### `app.js`

El archivo tiene 1013 líneas y contiene toda la lógica de la aplicación. Lee las variables globales `window.ESTABLISHMENTS`, `window.REGIONES`, `window.COMUNAS` y `window.ISOCRONAS`, y usa `window.I18N` para todos los textos que arma en pantalla. Está dividido en bloques con comentarios:

| Bloque | Qué hace |
|---|---|
| Resultados de la tesis | Define `COBERTURA_REGIONAL` (tabla 5.1, porcentaje de población y de territorio cubiertos a 45 minutos por región), `POB_CUBIERTA` (tabla 5.2, población cubierta por región) y `SALUD_REGIONAL` (tabla A.6, hipertensión, diabetes y población de 60 años o más según CASEN 2022). También define los tres tiempos (`TIERS`), sus colores (`TIER_COLOR`), la dirección de la API de OpenRouteService (`ORS_URL`) y el encuadre de Chile (`CHILE_BOUNDS`). |
| Estado | Define el objeto `S` con los filtros, los tiempos activos, las geometrías y capas de isócronas, el establecimiento destacado, los modos de consulta y de simulación y el último punto consultado. |
| Utilidades | Normaliza textos, traduce con `window.I18N`, da formato a los números, calcula distancias con la fórmula de Haversine, decide si un punto cae en un polígono (ray casting) y calcula cajas y áreas en km². |
| Mapa base y marcadores | Crea el mapa Leaflet con teselas de `tile.openstreetmap.org` y dibuja los 93 marcadores agrupados con Leaflet.markercluster (los grupos se deshacen desde el zoom 9). |
| Selección de hospital | Destaca un establecimiento y toda su cobertura cuando el usuario lo elige. |
| Preparación y avisos | Muestra la píldora de avance y los mensajes transitorios sobre el mapa. |
| Isócronas | `cargarCoberturaNacional()` usa primero `data/isocronas.js`; si le faltan establecimientos, toma lo que haya en la caché del navegador (`iso_<id>`) y calcula el resto con OpenRouteService en lotes de tres, con una espera de 20 segundos si la API responde 429. `orsKey()` devuelve la clave que ingresó el usuario (`acv_key`) o una cadena vacía si no hay ninguna; si el navegador bloquea el almacenamiento, devuelve la clave escrita en el campo de la ayuda (`inpKey`) durante esa visita. |
| Paso 1 y buscador | Llena los selectores de región y comuna, encuadra el mapa y maneja la búsqueda de establecimientos con selección múltiple. |
| Paso 3 | `calcularNacional()` pondera las tablas de la memoria por población y superficie, y `actualizarCobertura()` arma la tarjeta nacional, regional, comunal o del establecimiento destacado. `estimarCoberturaComuna()` sortea hasta 420 puntos al azar dentro de la comuna y cuenta cuántos caen en alguna isócrona de 45 minutos de su región. |
| Paso 4 | Busca direcciones en Nominatim (Chile, hasta cinco resultados), usa el GPS del navegador si la página está en un contexto seguro y, con `evaluarPunto()`, informa el menor tiempo cuya isócrona contiene el punto (o más de 60 minutos) y los tres establecimientos más cercanos en línea recta, con enlaces de ruta a Google Maps. |
| Funciones avanzadas | Pide a OpenRouteService las coberturas de un establecimiento hipotético y las dibuja con línea punteada; la simulación no se guarda. |
| Ayudas | Maneja la bienvenida (`acv_bienv`), la ventana de ayuda, el campo de la clave propia y las ventanas de las preguntas "?". |
| Descargas | `descargarIsocronas()` arma un nuevo `isocronas.js` cuando están las 93 coberturas. `descargarCSV()` descarga `establecimientos_acv_chile.csv` (UTF-8 con BOM) con las columnas `id`, `codigo`, `nombre`, `comuna`, `provincia`, `region`, `lat` y `lon`; `id` es el identificador interno y `codigo` es el código del establecimiento (`code`). |
| Eventos, arranque e idioma | Conecta los botones y, al cambiar el idioma, vuelve a dibujar los elementos dinámicos sin perder la selección. Al final del archivo, el arranque calcula la cifra nacional, crea el mapa y empieza a cargar las isócronas. |

### `i18n.js`

El archivo tiene 695 líneas y define `window.I18N`. Su diccionario `DICT` tiene 187 claves en cada idioma (`es`, `en` y `pt`) y acepta reemplazos con la forma `{token}`. Expone estas funciones:

| Función | Qué hace |
|---|---|
| `t(clave, parámetros)` | Devuelve el texto en el idioma activo; si la clave no existe en ese idioma, usa el español, y si tampoco existe, devuelve la clave. |
| `applyStatic()` | Traduce los elementos de `index.html` marcados con `data-i18n`, `data-i18n-html`, `data-i18n-ph`, `data-i18n-title` y `data-i18n-aria`, además del título de la página. |
| `setLang(idioma)` | Cambia el idioma, lo guarda en `localStorage` (`acv_lang`) si el navegador lo permite, vuelve a traducir la página y avisa a quienes se registraron con `onChange`. |
| `lang()`, `locale()` | Devuelven el idioma activo y su configuración regional (`es-CL`, `en-US` o `pt-BR`). |
| `syncSwitcher()` | Marca la bandera del idioma activo. |

Al abrir, la aplicación usa el idioma guardado; si no hay ninguno, o si el navegador bloquea el almacenamiento, usa el del navegador cuando es español, inglés o portugués, y si no, el español. Los textos que trae `index.html` son solo el contenido inicial: `applyStatic()` los reemplaza por los de `DICT`, así que cualquier cambio de texto se hace en `DICT` y en los tres idiomas.

## English

This folder holds the application code that runs in the browser. They are classic scripts, without modules or a bundler, which `index.html` loads at the end of the page: first `i18n.js` and then `app.js`, once Leaflet ([vendor/](../vendor/README.md)) and the data ([data/](../data/README.md)) are loaded. For the general context, see the [project README](../README.md).

### `app.js`

The file has 1013 lines and holds all the application logic. It reads the global variables `window.ESTABLISHMENTS`, `window.REGIONES`, `window.COMUNAS` and `window.ISOCRONAS`, and uses `window.I18N` for every text it builds on screen. It is divided into blocks marked by comments:

| Block | What it does |
|---|---|
| Thesis results | Defines `COBERTURA_REGIONAL` (table 5.1, share of population and territory covered within 45 minutes per region), `POB_CUBIERTA` (table 5.2, covered population per region) and `SALUD_REGIONAL` (table A.6, hypertension, diabetes and population aged 60 or older from CASEN 2022). It also defines the three travel times (`TIERS`), their colours (`TIER_COLOR`), the OpenRouteService API address (`ORS_URL`) and the map bounds of Chile (`CHILE_BOUNDS`). |
| State | Defines the `S` object with the filters, active travel times, isochrone geometries and layers, the highlighted facility, the query and simulation modes and the last queried point. |
| Utilities | Normalises text, translates through `window.I18N`, formats numbers, computes distances with the Haversine formula, tests whether a point lies in a polygon (ray casting) and computes bounding boxes and areas in km². |
| Base map and markers | Creates the Leaflet map with tiles from `tile.openstreetmap.org` and draws the 93 markers grouped with Leaflet.markercluster (clusters break apart from zoom level 9). |
| Facility selection | Highlights a facility and all its coverage when the user picks it. |
| Preparation and notices | Shows the progress pill and the temporary messages over the map. |
| Isochrones | `cargarCoberturaNacional()` uses `data/isocronas.js` first; if facilities are missing, it takes whatever is in the browser cache (`iso_<id>`) and computes the rest with OpenRouteService in batches of three, waiting 20 seconds when the API answers 429. `orsKey()` returns the key the user entered (`acv_key`) or an empty string when there is none; when the browser blocks storage, it returns the key typed in the help window field (`inpKey`) during that visit. |
| Step 1 and facility search | Fills the region and commune selectors, frames the map and handles the multiple-choice facility search. |
| Step 3 | `calcularNacional()` weights the thesis tables by population and area, and `actualizarCobertura()` builds the national, regional, commune or highlighted-facility card. `estimarCoberturaComuna()` draws up to 420 random points inside the commune and counts how many fall within any 45 minute isochrone of its region. |
| Step 4 | Searches addresses in Nominatim (Chile, up to five results), uses the browser GPS when the page runs in a secure context and, through `evaluarPunto()`, reports the shortest travel time whose isochrone contains the point (or more than 60 minutes) and the three nearest facilities in a straight line, with route links to Google Maps. |
| Advanced functions | Asks OpenRouteService for the coverage of a hypothetical facility and draws it with dashed lines; the simulation is not saved. |
| Help | Handles the welcome screen (`acv_bienv`), the help window, the personal key field and the "?" pop-overs. |
| Downloads | `descargarIsocronas()` builds a new `isocronas.js` once all 93 coverages are available. `descargarCSV()` downloads `establecimientos_acv_chile.csv` (UTF-8 with BOM) with the columns `id`, `codigo`, `nombre`, `comuna`, `provincia`, `region`, `lat` and `lon`; `id` is the internal identifier and `codigo` is the facility code (`code`). |
| Events, start-up and language | Wires the buttons and, when the language changes, redraws everything dynamic while keeping the current selection. At the end of the file, the start-up sequence computes the national figure, creates the map and starts loading the isochrones. |

### `i18n.js`

The file has 695 lines and defines `window.I18N`. Its `DICT` dictionary has 187 keys per language (`es`, `en` and `pt`) and accepts substitutions written as `{token}`. It exposes these functions:

| Function | What it does |
|---|---|
| `t(key, params)` | Returns the text in the active language; if the key is missing in that language it uses Spanish, and if it is missing there too it returns the key. |
| `applyStatic()` | Translates the `index.html` elements marked with `data-i18n`, `data-i18n-html`, `data-i18n-ph`, `data-i18n-title` and `data-i18n-aria`, plus the page title. |
| `setLang(language)` | Changes the language, stores it in `localStorage` (`acv_lang`) when the browser allows it, translates the page again and notifies the listeners registered with `onChange`. |
| `lang()`, `locale()` | Return the active language and its locale (`es-CL`, `en-US` or `pt-BR`). |
| `syncSwitcher()` | Marks the flag of the active language. |

On start-up the application uses the stored language; if there is none, or if the browser blocks storage, it uses the browser language when it is Spanish, English or Portuguese, and Spanish otherwise. The texts written in `index.html` are only the initial content: `applyStatic()` replaces them with the ones in `DICT`, so any text change must be made in `DICT`, in all three languages.
