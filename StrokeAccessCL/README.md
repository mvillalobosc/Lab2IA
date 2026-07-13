# StrokeAccessCL

<p align="center">
  <img src="assets/logo.svg" width="86" alt="StrokeAccessCL logo">
</p>

<p align="center">
  <b>Mapa interactivo de accesibilidad hospitalaria para atención de ataque cerebrovascular en Chile</b><br>
  <b>Interactive web map for stroke-care hospital accessibility in Chile</b><br>
  <b>Mapa interativo de acessibilidade hospitalar para atendimento de AVC no Chile</b>
</p>

<p align="center">
  <a href="#español">Español</a> ·
  <a href="#english">English</a> ·
  <a href="#português">Português</a> ·
  <a href="https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/">Aplicación web / Web application / Aplicação web</a>
</p>

<p align="center">
  <img src="assets/screenshot-main.png" alt="StrokeAccessCL main interface" width="920">
</p>

---

## Español

### 1. ¿Qué es StrokeAccessCL?

**StrokeAccessCL** es una aplicación web estática para visualizar la accesibilidad geográfica a los establecimientos que atienden el ataque cerebrovascular (ACV) en Chile. La interfaz permite explorar establecimientos, regiones, comunas, coberturas según el tiempo de traslado e información contextual a través de un mapa interactivo.

La aplicación está implementada como un sitio web del lado del cliente. No requiere un backend propio para visualizar los datos ya incluidos en el repositorio. El navegador carga archivos JavaScript locales con establecimientos, límites administrativos e isócronas precalculadas, y usa Leaflet para dibujar el mapa.

Despliegue público actual: [https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/](https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/)

### 2. Funcionalidades principales

- Visualiza **93 establecimientos** con atención ACV georreferenciados en Chile.
- Permite filtrar por **región**, **comuna con establecimiento** o **establecimiento específico**.
- Muestra coberturas de viaje en auto para **30, 45 y 60 minutos**.
- Usa isócronas precalculadas desde `data/isocronas.js` cuando estén disponibles.
- Permite consultar un punto mediante clic en el mapa, la búsqueda de direcciones o la geolocalización del navegador.
- Informa de hospitales cercanos al punto consultado y entrega enlaces de ruta en Google Maps.
- Incluye una función avanzada para simular un nuevo establecimiento con OpenRouteService.
- Permite descargar los establecimientos en formato CSV y las coberturas en formato `isocronas.js`.
- Soporta las interfaces en **español**, **inglés** y **portugués** mediante `js/i18n.js`.

### 3. Estructura del repositorio

```text
.
├── index.html
├── README.md
├── CITATION.cff
├── LICENSE
├── package.json
├── .nojekyll
├── .gitignore
├── generar_isocronas.mjs
├── assets/
│   ├── screenshot-main.png
│   ├── screenshot-region.png
│   ├── screenshot-help.png
│   ├── architecture-code.png
│   ├── pipeline-code.png
│   └── logo.svg
├── css/
│   └── estilos.css
├── js/
│   ├── app.js
│   └── i18n.js
├── data/
│   ├── establecimientos.js
│   ├── regiones.js
│   ├── comunas.js
│   └── isocronas.js
└── vendor/
    ├── leaflet.css
    ├── leaflet.js
    ├── MarkerCluster.css
    └── leaflet.markercluster.js
```

| Archivo o carpeta | Rol |
|---|---|
| `index.html` | Define la estructura de la interfaz: encabezado, panel lateral, mapa, bienvenida y ayuda. |
| `css/estilos.css` | Contiene el diseño visual, los colores, las tarjetas, el panel lateral, los modales y la respuesta móvil. |
| `js/app.js` | Contiene la lógica principal: estado, mapa Leaflet, filtros, isócronas, consulta de puntos, simulación y descargas. |
| `js/i18n.js` | Diccionario multilingüe usado por la interfaz. |
| `data/establecimientos.js` | Lista de establecimientos con coordenadas, región, comuna, código e identificador interno. |
| `data/regiones.js` | Capa GeoJSON de regiones usada para filtros y encuadre del mapa. |
| `data/comunas.js` | Capa GeoJSON de comunas usada para filtros y consulta territorial. |
| `data/isocronas.js` | Coberturas precalculadas para 30, 45 y 60 minutos por establecimiento. |
| `vendor/` | Dependencias locales de Leaflet y MarkerCluster. |
| `generar_isocronas.mjs` | Script auxiliar para generar o regenerar isócronas. |
| `assets/` | Imágenes usadas por este README. |

### 4. Capturas / Screenshots / Capturas

| Vista principal | Región con isócronas |
|---|---|
| ![Vista principal](assets/screenshot-main.png) | ![Región seleccionada](assets/screenshot-region.png) |

| Ayuda de la aplicación | Flujo de ejecución |
|---|---|
| ![Ayuda y metodología](assets/screenshot-help.png) | ![Pipeline de ejecución](assets/pipeline-code.png) |

Las imágenes de este README se prepararon desde los archivos reales de la aplicación entregada: `index.html`, `css/`, `js/` y `data/`. No se usaron capturas ni figuras de la memoria escrita.

### 5. Manual de uso

#### 5.1 Elegir territorio

El panel lateral permite trabajar en dos modos:

| Modo | Uso |
|---|---|
| **Por región / comuna** | Filtra el mapa por región y luego por comuna que contiene al menos un establecimiento. |
| **Por establecimiento** | Permite buscar establecimientos por nombre o comuna y mostrar solo los seleccionados. |

Al elegir una región, la aplicación centra el mapa sobre el territorio correspondiente y actualiza el panel de cobertura.

#### 5.2 Activar tiempos de traslado

Los botones **30 min**, **45 min** y **60 min** activan o desactivan las capas de isócronas. Cada isócrona representa el área desde la cual se alcanza un establecimiento con atención ACV en ese tiempo de viaje en auto.

| Tiempo | Color usado por la app | Uso principal |
|---|---|---|
| 30 minutos | Verde azulado `#00A499` | Cobertura cercana. |
| 45 minutos | Amarillo `#EAAA00` | Tiempo de referencia principal usado en el panel. |
| 60 minutos | Naranjo `#EA7600` | Cobertura ampliada. |

#### 5.3 Ver cobertura del área

El paso 3 del panel muestra tarjetas de cobertura. El contenido cambia según el contexto:

- Si no hay región seleccionada, muestra el resumen nacional.
- Si hay región seleccionada, muestra cobertura regional.
- Si hay comuna seleccionada, estima cobertura comunal con las geometrías disponibles.
- Si hay un establecimiento destacado, muestra información del establecimiento, comuna, región y cobertura asociada.

#### 5.4 Consultar un punto

La aplicación permite consultar un punto de tres formas:

1. Escribir una dirección en el buscador.
2. Usar el botón **Mi ubicación**.
3. Usar **Marcar en el mapa** y hacer clic sobre el punto de interés.

Luego, la aplicación revisa si el punto cae dentro de alguna isócrona activa o cargada y lista los hospitales más cercanos usando distancia en línea recta. Para navegación práctica, entrega enlaces a Google Maps.

#### 5.5 Simular un establecimiento nuevo

En **Funciones avanzadas**, el usuario puede marcar un punto como si ahí existiera un nuevo establecimiento con atención ACV. La aplicación consulta OpenRouteService y dibuja coberturas temporales para 30, 45 y 60 minutos.

Esta simulación:

- No se guarda en `data/establecimientos.js`.
- No modifica las isócronas reales.
- Usa línea punteada y colores por tiempo.
- Requiere clave de OpenRouteService si se ejecuta desde la versión pública de GitHub.

### 6. Arquitectura técnica / Technical architecture / Arquitetura técnica

<p align="center">
  <img src="assets/architecture-code.png" alt="Technical architecture" width="900">
</p>

StrokeAccessCL es una aplicación web estática. Su ejecución ocurre en el navegador:

```text
Browser
  │
  ├── index.html
  │     ├── header
  │     ├── sidebar controls
  │     ├── Leaflet map container
  │     ├── welcome overlay
  │     └── help/methodology overlay
  │
  ├── css/estilos.css
  │     ├── layout
  │     ├── responsive rules
  │     ├── buttons/cards/modals
  │     └── colour system
  │
  ├── js/i18n.js
  │     └── ES / EN / PT interface strings
  │
  ├── data/*.js
  │     ├── establishments
  │     ├── regions
  │     ├── comunas
  │     └── precomputed isochrones
  │
  └── js/app.js
        ├── application state
        ├── Leaflet map setup
        ├── marker clustering
        ├── isochrone drawing
        ├── region/comuna/facility filters
        ├── point evaluation
        ├── simulated facility mode
        └── CSV / isochrone downloads
```

### 7. Estado central de ejecución

La aplicación usa un objeto de estado en `js/app.js`. La estructura conceptual es:

```javascript
const S = {
  region: '',
  comuna: '',
  filtroHosp: new Set(),
  activos: {30: false, 45: false, 60: false},
  iso: {},
  capas: {},
  sel: null,
  cargando: null,
  puntoModo: false,
  simModo: false,
  sim: null,
  nacional: null,
  nacionalSalud: null
};
```

Este estado separa filtros territoriales, tiempos activos, geometrías de isócronas, capas dibujadas, establecimiento destacado, modo de consulta por punto y modo de simulación.

### 8. Flujo de datos

<p align="center">
  <img src="assets/pipeline-code.png" alt="Data and runtime pipeline" width="900">
</p>

El flujo principal es:

```text
Abrir index.html
  ↓
Cargar Leaflet, MarkerCluster, i18n y data/*.js
  ↓
Inicializar mapa y marcadores
  ↓
Leer isócronas precalculadas desde data/isocronas.js
  ↓
Aplicar filtros por región, comuna o establecimiento
  ↓
Activar capas de 30, 45 o 60 minutos
  ↓
Consultar punto, geolocalización o simulación
```

Si `data/isocronas.js` no existe o está incompleto, la aplicación intenta completar las coberturas usando OpenRouteService. Los resultados pueden guardarse en `localStorage` y descargarse como un nuevo `isocronas.js`.

### 9. APIs y dependencias externas

| Servicio | Uso en la app | Archivo donde aparece |
|---|---|---|
| Leaflet | Renderizado del mapa y capas GeoJSON. | `vendor/leaflet.js`, `js/app.js` |
| Leaflet MarkerCluster | Agrupación visual de marcadores. | `vendor/leaflet.markercluster.js` |
| CARTO / OpenStreetMap | Teselas del mapa base. | `js/app.js` |
| OpenRouteService | Cálculo de isócronas para coberturas y simulaciones. | `js/app.js`, `generar_isocronas.mjs` |
| Nominatim / OpenStreetMap | Búsqueda de direcciones en Chile. | `js/app.js` |
| Google Maps | Enlaces externos de ruta. | `js/app.js` |

### 10. Clave de OpenRouteService

La versión preparada para GitHub no publica una clave de OpenRouteService dentro de `js/app.js`. Esto evita subir una credencial a un repositorio público.

La visualización normal funciona con `data/isocronas.js`. Para recalcular coberturas o usar simulación de establecimientos, ingresa una clave propia en:

```text
Ayuda y metodología → OpenRouteService key
```

La clave se guarda solo en el navegador mediante `localStorage`.

### 11. Ejecución local

No se necesita instalar dependencias para ver la app. Basta con servir la carpeta como sitio estático.

Con Python 3:

```bash
python3 -m http.server 8000
```

Luego abre:

```text
http://localhost:8000/
```

También puedes usar el script definido en `package.json`:

```bash
npm run start
```

### 12. Despliegue manual en GitHub Pages

1. Crea un repositorio vacío en GitHub.
2. Descomprime este ZIP.
3. Sube el contenido completo a la raíz del repositorio, no el ZIP.
4. Verifica que `index.html` y `README.md` queden en la raíz.
5. En GitHub, entra a:

```text
Settings → Pages → Build and deployment
```

6. Configura:

```text
Source: Deploy from a branch
Branch: main
Folder: /root
```

7. Guarda la configuración.

GitHub Pages publicará la app usando `index.html`. El README se verá automáticamente en la página principal del repositorio.

### 13. Mantención de datos

#### 13.1 Actualizar establecimientos

Edita `data/establecimientos.js`. Cada registro debe mantener esta estructura:

```javascript
{
  code: 101100,
  name: "Hospital Dr Juan Noé Crevanni (Arica)",
  lat: -18.482478,
  lon: -70.312948,
  comuna: "Arica",
  provincia: "Arica",
  region: "Región de Arica y Parinacota",
  cod_comuna: 15101,
  codregion: 15,
  id: 1
}
```

Reglas prácticas:

- `id` debe ser único.
- `lat` y `lon` deben estar en WGS84.
- `codregion` debe coincidir con `data/regiones.js`.
- `cod_comuna` debe coincidir con `data/comunas.js`.
- Si agregas un establecimiento, también debes generar sus isócronas.

#### 13.2 Actualizar límites territoriales

Los archivos `data/regiones.js` y `data/comunas.js` deben exponer objetos GeoJSON en variables globales:

```javascript
window.REGIONES = {...};
window.COMUNAS = {...};
```

La app usa estos polígonos para encuadrar el mapa, filtrar comunas y determinar en qué comuna cae un punto consultado.

#### 13.3 Regenerar isócronas

Las coberturas se guardan en:

```text
data/isocronas.js
```

Formato esperado:

```javascript
window.ISOCRONAS = {
  "1": {
    "30": { "type": "Polygon", "coordinates": [...] },
    "45": { "type": "Polygon", "coordinates": [...] },
    "60": { "type": "Polygon", "coordinates": [...] }
  }
};
```

Para regenerarlas puedes usar la app o el script `generar_isocronas.mjs`. Si usas la app, al terminar la preparación descarga `isocronas.js` desde la ventana de ayuda y súbelo a `data/`.

### 14. Checklist antes de publicar

- [ ] `index.html` abre correctamente.
- [ ] `README.md` se ve en GitHub con las imágenes de `assets/`.
- [ ] No hay claves privadas publicadas en `js/app.js`.
- [ ] `data/establecimientos.js` carga 93 establecimientos o el número actualizado esperado.
- [ ] `data/isocronas.js` contiene coberturas para los establecimientos vigentes.
- [ ] Los filtros de región y comuna funcionan.
- [ ] Los botones 30/45/60 dibujan coberturas.
- [ ] El buscador de dirección responde con conexión a internet.
- [ ] La geolocalización se prueba desde `https` o `localhost`.
- [ ] GitHub Pages está configurado en `main / root`.

### 15. Limitaciones conocidas

- Las isócronas dependen de la red vial y del servicio OpenRouteService cuando se recalculan.
- El GPS del navegador requiere `https` o `localhost`.
- La búsqueda de direcciones depende de Nominatim y de conexión a internet.
- La cobertura comunal en línea se estima con muestreo de puntos, no reemplaza una estimación censal completa.
- Si se agregan nuevos establecimientos, deben actualizarse también las coberturas.
- En árboles de datos muy pesados o muchas geometrías activas, el navegador puede tardar más en renderizar.

### 16. Cita sugerida

Guajardo Arias, I. A., Villalobos Cid, M. J., & Giglio Gutiérrez, J. (2025). *Implementación de un sistema de visualización para el análisis espacio-temporal de la cobertura hospitalaria y la accesibilidad de los servicios de atención para el ataque cerebrovascular a nivel nacional en Chile*. Universidad de Santiago de Chile, Facultad de Ingeniería, Departamento de Ingeniería Informática.

La metadata para GitHub también está disponible en `CITATION.cff`.

### 17. Créditos

Trabajo asociado a la Universidad de Santiago de Chile, Facultad de Ingeniería, Departamento de Ingeniería Informática.

Autores reconocidos en la cita del proyecto:

| Autor | Rol |
|---|---|
| Iván Alejandro Guajardo Arias | Desarrollo original de la herramienta y memoria asociada. |
| Manuel José Villalobos Cid | Profesor guía / colaboración académica. |
| Juan Giglio Gutiérrez | Profesor co-guía / colaboración académica. |

Nota de preparación del repositorio: este paquete fue organizado con apoyo de ChatGPT para dejar una estructura publicable en GitHub, concentrando la documentación en un único `README.md`, sin generar documentación separada en múltiples archivos Markdown.

---

## English

### 1. What is StrokeAccessCL?

**StrokeAccessCL** is a static web application for visualising geographic accessibility to facilities that provide stroke care in Chile. Its interface allows users to explore facilities, regions, communes, travel-time coverage and contextual information through an interactive map.

The application is implemented as a client-side website. It does not require a dedicated backend to display the data already included in the repository. The browser loads local JavaScript files containing facilities, administrative boundaries and precomputed isochrones, and uses Leaflet to render the map.

Current public deployment: [https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/](https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/)

### 2. Main features

- Displays **93 georeferenced stroke-care facilities** in Chile.
- Allows filtering by **region**, **commune with at least one facility**, or **specific facility**.
- Shows car travel-time coverage for **30, 45 and 60 minutes**.
- Uses precomputed isochrones from `data/isocronas.js` when available.
- Allows users to query a point by clicking on the map, searching for an address or using browser geolocation.
- Reports hospitals near the queried point and provides route links in Google Maps.
- Includes an advanced function for simulating a new facility with OpenRouteService.
- Allows facilities to be downloaded in CSV format and coverage data in `isocronas.js` format.
- Supports **Spanish**, **English** and **Portuguese** interfaces through `js/i18n.js`.

### 3. Repository structure

```text
.
├── index.html
├── README.md
├── CITATION.cff
├── LICENSE
├── package.json
├── .nojekyll
├── .gitignore
├── generar_isocronas.mjs
├── assets/
│   ├── screenshot-main.png
│   ├── screenshot-region.png
│   ├── screenshot-help.png
│   ├── architecture-code.png
│   ├── pipeline-code.png
│   └── logo.svg
├── css/
│   └── estilos.css
├── js/
│   ├── app.js
│   └── i18n.js
├── data/
│   ├── establecimientos.js
│   ├── regiones.js
│   ├── comunas.js
│   └── isocronas.js
└── vendor/
    ├── leaflet.css
    ├── leaflet.js
    ├── MarkerCluster.css
    └── leaflet.markercluster.js
```

| File or directory | Role |
|---|---|
| `index.html` | Defines the interface structure: header, sidebar, map, welcome screen and help panel. |
| `css/estilos.css` | Contains the visual design, colours, cards, sidebar, modals and responsive behaviour. |
| `js/app.js` | Contains the main logic: state, Leaflet map, filters, isochrones, point queries, simulation and downloads. |
| `js/i18n.js` | Multilingual dictionary used by the interface. |
| `data/establecimientos.js` | List of facilities with coordinates, region, commune, code and internal identifier. |
| `data/regiones.js` | GeoJSON region layer used for filtering and map framing. |
| `data/comunas.js` | GeoJSON commune layer used for filtering and territorial queries. |
| `data/isocronas.js` | Precomputed 30, 45 and 60 minute coverage for each facility. |
| `vendor/` | Local Leaflet and MarkerCluster dependencies. |
| `generar_isocronas.mjs` | Auxiliary script for generating or regenerating isochrones. |
| `assets/` | Images used by this README. |

### 4. Screenshots

| Main view | Region with isochrones |
|---|---|
| ![Main view](assets/screenshot-main.png) | ![Selected region](assets/screenshot-region.png) |

| Application help | Runtime flow |
|---|---|
| ![Help and methodology](assets/screenshot-help.png) | ![Runtime pipeline](assets/pipeline-code.png) |

The images in this README were prepared from the actual application files provided: `index.html`, `css/`, `js/` and `data/`. No screenshots or figures from the written thesis were used.

### 5. User guide

#### 5.1 Select a territory

The sidebar supports two working modes:

| Mode | Use |
|---|---|
| **By region / commune** | Filters the map first by region and then by a commune containing at least one facility. |
| **By facility** | Allows facilities to be searched by name or commune and displays only the selected facilities. |

When a region is selected, the application centres the map on the corresponding territory and updates the coverage panel.

#### 5.2 Activate travel times

The **30 min**, **45 min** and **60 min** buttons enable or disable the isochrone layers. Each isochrone represents the area from which a stroke-care facility can be reached within that car travel time.

| Time | Colour used by the app | Main use |
|---|---|---|
| 30 minutes | Teal `#00A499` | Nearby coverage. |
| 45 minutes | Yellow `#EAAA00` | Main reference time used in the panel. |
| 60 minutes | Orange `#EA7600` | Extended coverage. |

#### 5.3 View area coverage

Step 3 of the sidebar displays coverage cards. Their content changes according to the current context:

- If no region is selected, it displays the national summary.
- If a region is selected, it displays regional coverage.
- If a commune is selected, it estimates commune-level coverage using the available geometries.
- If a facility is highlighted, it displays information about the facility, commune, region and associated coverage.

#### 5.4 Query a point

The application allows a point to be queried in three ways:

1. Enter an address in the search box.
2. Use the **My location** button.
3. Use **Mark on map** and click the point of interest.

The application then checks whether the point falls inside any active or loaded isochrone and lists the nearest hospitals using straight-line distance. For practical navigation, it provides links to Google Maps.

#### 5.5 Simulate a new facility

Under **Advanced functions**, the user can mark a point as though a new stroke-care facility existed at that location. The application queries OpenRouteService and draws temporary 30, 45 and 60 minute coverage areas.

This simulation:

- Is not saved in `data/establecimientos.js`.
- Does not modify the real isochrones.
- Uses dashed lines and time-specific colours.
- Requires an OpenRouteService key when run from the public GitHub version.

### 6. Technical architecture

<p align="center">
  <img src="assets/architecture-code.png" alt="Technical architecture" width="900">
</p>

StrokeAccessCL is a static web application. It runs entirely in the browser:

```text
Browser
  │
  ├── index.html
  │     ├── header
  │     ├── sidebar controls
  │     ├── Leaflet map container
  │     ├── welcome overlay
  │     └── help/methodology overlay
  │
  ├── css/estilos.css
  │     ├── layout
  │     ├── responsive rules
  │     ├── buttons/cards/modals
  │     └── colour system
  │
  ├── js/i18n.js
  │     └── ES / EN / PT interface strings
  │
  ├── data/*.js
  │     ├── establishments
  │     ├── regions
  │     ├── communes
  │     └── precomputed isochrones
  │
  └── js/app.js
        ├── application state
        ├── Leaflet map setup
        ├── marker clustering
        ├── isochrone drawing
        ├── region/commune/facility filters
        ├── point evaluation
        ├── simulated facility mode
        └── CSV / isochrone downloads
```

### 7. Central runtime state

The application uses a state object in `js/app.js`. Its conceptual structure is:

```javascript
const S = {
  region: '',
  comuna: '',
  filtroHosp: new Set(),
  activos: {30: false, 45: false, 60: false},
  iso: {},
  capas: {},
  sel: null,
  cargando: null,
  puntoModo: false,
  simModo: false,
  sim: null,
  nacional: null,
  nacionalSalud: null
};
```

This state separates territorial filters, active travel times, isochrone geometries, rendered layers, the highlighted facility, point-query mode and simulation mode.

### 8. Data flow

<p align="center">
  <img src="assets/pipeline-code.png" alt="Data and runtime pipeline" width="900">
</p>

The main flow is:

```text
Open index.html
  ↓
Load Leaflet, MarkerCluster, i18n and data/*.js
  ↓
Initialise the map and markers
  ↓
Read precomputed isochrones from data/isocronas.js
  ↓
Apply filters by region, commune or facility
  ↓
Activate 30, 45 or 60 minute layers
  ↓
Query a point, use geolocation or run a simulation
```

If `data/isocronas.js` does not exist or is incomplete, the application attempts to complete the coverage data using OpenRouteService. Results can be stored in `localStorage` and downloaded as a new `isocronas.js` file.

### 9. APIs and external dependencies

| Service | Use in the app | File where it appears |
|---|---|---|
| Leaflet | Rendering the map and GeoJSON layers. | `vendor/leaflet.js`, `js/app.js` |
| Leaflet MarkerCluster | Visual grouping of markers. | `vendor/leaflet.markercluster.js` |
| CARTO / OpenStreetMap | Base-map tiles. | `js/app.js` |
| OpenRouteService | Isochrone calculation for coverage and simulations. | `js/app.js`, `generar_isocronas.mjs` |
| Nominatim / OpenStreetMap | Address search in Chile. | `js/app.js` |
| Google Maps | External route links. | `js/app.js` |

### 10. OpenRouteService key

The GitHub-ready version does not publish an OpenRouteService key inside `js/app.js`. This prevents a private credential from being uploaded to a public repository.

Normal visualisation works with `data/isocronas.js`. To recalculate coverage or use facility simulation, enter your own key under:

```text
Help and methodology → OpenRouteService key
```

The key is stored only in the browser through `localStorage`.

### 11. Local execution

No dependencies need to be installed to view the application. The directory only needs to be served as a static website.

With Python 3:

```bash
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

You can also use the script defined in `package.json`:

```bash
npm run start
```

### 12. Manual deployment to GitHub Pages

1. Create an empty repository on GitHub.
2. Extract this ZIP file.
3. Upload the complete contents to the repository root, not the ZIP file itself.
4. Check that `index.html` and `README.md` are in the root directory.
5. In GitHub, open:

```text
Settings → Pages → Build and deployment
```

6. Configure:

```text
Source: Deploy from a branch
Branch: main
Folder: /root
```

7. Save the configuration.

GitHub Pages will publish the application using `index.html`. The README will appear automatically on the repository landing page.

### 13. Data maintenance

#### 13.1 Update facilities

Edit `data/establecimientos.js`. Each record must keep the following structure:

```javascript
{
  code: 101100,
  name: "Hospital Dr Juan Noé Crevanni (Arica)",
  lat: -18.482478,
  lon: -70.312948,
  comuna: "Arica",
  provincia: "Arica",
  region: "Región de Arica y Parinacota",
  cod_comuna: 15101,
  codregion: 15,
  id: 1
}
```

Practical rules:

- `id` must be unique.
- `lat` and `lon` must use WGS84 coordinates.
- `codregion` must match `data/regiones.js`.
- `cod_comuna` must match `data/comunas.js`.
- When a facility is added, its isochrones must also be generated.

#### 13.2 Update territorial boundaries

The `data/regiones.js` and `data/comunas.js` files must expose GeoJSON objects as global variables:

```javascript
window.REGIONES = {...};
window.COMUNAS = {...};
```

The application uses these polygons to frame the map, filter communes and determine which commune contains a queried point.

#### 13.3 Regenerate isochrones

Coverage data are stored in:

```text
data/isocronas.js
```

Expected format:

```javascript
window.ISOCRONAS = {
  "1": {
    "30": { "type": "Polygon", "coordinates": [...] },
    "45": { "type": "Polygon", "coordinates": [...] },
    "60": { "type": "Polygon", "coordinates": [...] }
  }
};
```

Isochrones can be regenerated using the application or the `generar_isocronas.mjs` script. When using the application, download `isocronas.js` from the help window after preparation is complete and upload it to `data/`.

### 14. Checklist before publication

- [ ] `index.html` opens correctly.
- [ ] `README.md` is displayed on GitHub with the images from `assets/`.
- [ ] No private keys are published in `js/app.js`.
- [ ] `data/establecimientos.js` loads 93 facilities or the expected updated number.
- [ ] `data/isocronas.js` contains coverage for all current facilities.
- [ ] Region and commune filters work correctly.
- [ ] The 30/45/60 buttons draw the coverage layers.
- [ ] The address search works when an internet connection is available.
- [ ] Geolocation is tested through `https` or `localhost`.
- [ ] GitHub Pages is configured to use `main / root`.

### 15. Known limitations

- Isochrones depend on the road network and on OpenRouteService when recalculated.
- Browser GPS requires `https` or `localhost`.
- Address search depends on Nominatim and an internet connection.
- Online commune-level coverage is estimated by point sampling and does not replace a complete census-based estimate.
- When new facilities are added, their coverage data must also be updated.
- With very large data trees or many active geometries, the browser may take longer to render the map.

### 16. Suggested citation

Guajardo Arias, I. A., Villalobos Cid, M. J., & Giglio Gutiérrez, J. (2025). *Implementación de un sistema de visualización para el análisis espacio-temporal de la cobertura hospitalaria y la accesibilidad de los servicios de atención para el ataque cerebrovascular a nivel nacional en Chile*. Universidad de Santiago de Chile, Facultad de Ingeniería, Departamento de Ingeniería Informática.

GitHub citation metadata are also available in `CITATION.cff`.

### 17. Credits

Work associated with the Universidad de Santiago de Chile, Faculty of Engineering, Department of Computer Science.

Authors acknowledged in the project citation:

| Author | Role |
|---|---|
| Iván Alejandro Guajardo Arias | Original development of the tool and associated thesis. |
| Manuel José Villalobos Cid | Supervisor / academic collaboration. |
| Juan Giglio Gutiérrez | Co-supervisor / academic collaboration. |

Repository preparation note: this package was organised with support from ChatGPT to provide a GitHub-ready structure, concentrating all documentation in a single `README.md` instead of creating multiple separate Markdown files.

---

## Português

### 1. O que é o StrokeAccessCL?

**StrokeAccessCL** é uma aplicação web estática para visualizar a acessibilidade geográfica aos estabelecimentos que oferecem atendimento ao acidente vascular cerebral (AVC) no Chile. A interface permite explorar estabelecimentos, regiões, comunas, coberturas conforme o tempo de deslocamento e informações contextuais por meio de um mapa interativo.

A aplicação foi implementada como um site do lado do cliente. Ela não requer um backend próprio para visualizar os dados já incluídos no repositório. O navegador carrega arquivos JavaScript locais com estabelecimentos, limites administrativos e isócronas pré-calculadas, e utiliza o Leaflet para desenhar o mapa.

Implantação pública atual: [https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/](https://mvillalobosc.diinf.usach.cl/StrokeAccessCL/)

### 2. Funcionalidades principais

- Exibe **93 estabelecimentos georreferenciados** com atendimento ao AVC no Chile.
- Permite filtrar por **região**, **comuna com estabelecimento** ou **estabelecimento específico**.
- Mostra coberturas de viagem de carro para **30, 45 e 60 minutos**.
- Utiliza isócronas pré-calculadas de `data/isocronas.js` quando disponíveis.
- Permite consultar um ponto por clique no mapa, busca de endereço ou geolocalização do navegador.
- Informa os hospitais próximos ao ponto consultado e fornece links de rota no Google Maps.
- Inclui uma função avançada para simular um novo estabelecimento com o OpenRouteService.
- Permite baixar os estabelecimentos em formato CSV e as coberturas no formato `isocronas.js`.
- Oferece interfaces em **espanhol**, **inglês** e **português** por meio de `js/i18n.js`.

### 3. Estrutura do repositório

```text
.
├── index.html
├── README.md
├── CITATION.cff
├── LICENSE
├── package.json
├── .nojekyll
├── .gitignore
├── generar_isocronas.mjs
├── assets/
│   ├── screenshot-main.png
│   ├── screenshot-region.png
│   ├── screenshot-help.png
│   ├── architecture-code.png
│   ├── pipeline-code.png
│   └── logo.svg
├── css/
│   └── estilos.css
├── js/
│   ├── app.js
│   └── i18n.js
├── data/
│   ├── establecimientos.js
│   ├── regiones.js
│   ├── comunas.js
│   └── isocronas.js
└── vendor/
    ├── leaflet.css
    ├── leaflet.js
    ├── MarkerCluster.css
    └── leaflet.markercluster.js
```

| Arquivo ou pasta | Função |
|---|---|
| `index.html` | Define a estrutura da interface: cabeçalho, painel lateral, mapa, boas-vindas e ajuda. |
| `css/estilos.css` | Contém o design visual, as cores, os cartões, o painel lateral, os modais e o comportamento responsivo. |
| `js/app.js` | Contém a lógica principal: estado, mapa Leaflet, filtros, isócronas, consulta de pontos, simulação e downloads. |
| `js/i18n.js` | Dicionário multilíngue utilizado pela interface. |
| `data/establecimientos.js` | Lista de estabelecimentos com coordenadas, região, comuna, código e identificador interno. |
| `data/regiones.js` | Camada GeoJSON de regiões utilizada para filtros e enquadramento do mapa. |
| `data/comunas.js` | Camada GeoJSON de comunas utilizada para filtros e consultas territoriais. |
| `data/isocronas.js` | Coberturas pré-calculadas de 30, 45 e 60 minutos para cada estabelecimento. |
| `vendor/` | Dependências locais do Leaflet e do MarkerCluster. |
| `generar_isocronas.mjs` | Script auxiliar para gerar ou regenerar isócronas. |
| `assets/` | Imagens utilizadas neste README. |

### 4. Capturas de tela

| Visão principal | Região com isócronas |
|---|---|
| ![Visão principal](assets/screenshot-main.png) | ![Região selecionada](assets/screenshot-region.png) |

| Ajuda da aplicação | Fluxo de execução |
|---|---|
| ![Ajuda e metodologia](assets/screenshot-help.png) | ![Pipeline de execução](assets/pipeline-code.png) |

As imagens deste README foram preparadas a partir dos arquivos reais da aplicação fornecida: `index.html`, `css/`, `js/` e `data/`. Não foram utilizadas capturas nem figuras da dissertação escrita.

### 5. Manual de uso

#### 5.1 Selecionar um território

O painel lateral permite trabalhar em dois modos:

| Modo | Uso |
|---|---|
| **Por região / comuna** | Filtra o mapa por região e depois por uma comuna que contenha pelo menos um estabelecimento. |
| **Por estabelecimento** | Permite buscar estabelecimentos por nome ou comuna e mostrar apenas os selecionados. |

Ao selecionar uma região, a aplicação centraliza o mapa no território correspondente e atualiza o painel de cobertura.

#### 5.2 Ativar tempos de deslocamento

Os botões **30 min**, **45 min** e **60 min** ativam ou desativam as camadas de isócronas. Cada isócrona representa a área a partir da qual é possível chegar a um estabelecimento com atendimento ao AVC dentro daquele tempo de viagem de carro.

| Tempo | Cor utilizada pela aplicação | Uso principal |
|---|---|---|
| 30 minutos | Verde-azulado `#00A499` | Cobertura próxima. |
| 45 minutos | Amarelo `#EAAA00` | Principal tempo de referência utilizado no painel. |
| 60 minutos | Laranja `#EA7600` | Cobertura ampliada. |

#### 5.3 Visualizar a cobertura da área

A etapa 3 do painel mostra cartões de cobertura. O conteúdo muda conforme o contexto:

- Se nenhuma região estiver selecionada, mostra o resumo nacional.
- Se uma região estiver selecionada, mostra a cobertura regional.
- Se uma comuna estiver selecionada, estima a cobertura comunal com as geometrias disponíveis.
- Se um estabelecimento estiver destacado, mostra informações sobre o estabelecimento, a comuna, a região e a cobertura associada.

#### 5.4 Consultar um ponto

A aplicação permite consultar um ponto de três formas:

1. Digitar um endereço no campo de busca.
2. Utilizar o botão **Minha localização**.
3. Utilizar **Marcar no mapa** e clicar no ponto de interesse.

Em seguida, a aplicação verifica se o ponto está dentro de alguma isócrona ativa ou carregada e lista os hospitais mais próximos utilizando distância em linha reta. Para navegação prática, fornece links para o Google Maps.

#### 5.5 Simular um novo estabelecimento

Em **Funções avançadas**, o usuário pode marcar um ponto como se houvesse ali um novo estabelecimento com atendimento ao AVC. A aplicação consulta o OpenRouteService e desenha coberturas temporárias de 30, 45 e 60 minutos.

Essa simulação:

- Não é salva em `data/establecimientos.js`.
- Não modifica as isócronas reais.
- Utiliza linha tracejada e cores específicas para cada tempo.
- Requer uma chave do OpenRouteService quando executada a partir da versão pública no GitHub.

### 6. Arquitetura técnica

<p align="center">
  <img src="assets/architecture-code.png" alt="Arquitetura técnica" width="900">
</p>

O StrokeAccessCL é uma aplicação web estática. Sua execução ocorre inteiramente no navegador:

```text
Navegador
  │
  ├── index.html
  │     ├── cabeçalho
  │     ├── controles do painel lateral
  │     ├── contêiner do mapa Leaflet
  │     ├── camada de boas-vindas
  │     └── camada de ajuda/metodologia
  │
  ├── css/estilos.css
  │     ├── layout
  │     ├── regras responsivas
  │     ├── botões/cartões/modais
  │     └── sistema de cores
  │
  ├── js/i18n.js
  │     └── textos da interface em ES / EN / PT
  │
  ├── data/*.js
  │     ├── estabelecimentos
  │     ├── regiões
  │     ├── comunas
  │     └── isócronas pré-calculadas
  │
  └── js/app.js
        ├── estado da aplicação
        ├── configuração do mapa Leaflet
        ├── agrupamento de marcadores
        ├── desenho das isócronas
        ├── filtros de região/comuna/estabelecimento
        ├── avaliação de pontos
        ├── modo de estabelecimento simulado
        └── downloads de CSV / isócronas
```

### 7. Estado central de execução

A aplicação utiliza um objeto de estado em `js/app.js`. A estrutura conceitual é:

```javascript
const S = {
  region: '',
  comuna: '',
  filtroHosp: new Set(),
  activos: {30: false, 45: false, 60: false},
  iso: {},
  capas: {},
  sel: null,
  cargando: null,
  puntoModo: false,
  simModo: false,
  sim: null,
  nacional: null,
  nacionalSalud: null
};
```

Esse estado separa os filtros territoriais, os tempos ativos, as geometrias das isócronas, as camadas desenhadas, o estabelecimento destacado, o modo de consulta por ponto e o modo de simulação.

### 8. Fluxo de dados

<p align="center">
  <img src="assets/pipeline-code.png" alt="Pipeline de dados e execução" width="900">
</p>

O fluxo principal é:

```text
Abrir index.html
  ↓
Carregar Leaflet, MarkerCluster, i18n e data/*.js
  ↓
Inicializar o mapa e os marcadores
  ↓
Ler as isócronas pré-calculadas de data/isocronas.js
  ↓
Aplicar filtros por região, comuna ou estabelecimento
  ↓
Ativar camadas de 30, 45 ou 60 minutos
  ↓
Consultar um ponto, usar geolocalização ou executar uma simulação
```

Se `data/isocronas.js` não existir ou estiver incompleto, a aplicação tenta completar as coberturas utilizando o OpenRouteService. Os resultados podem ser armazenados em `localStorage` e baixados como um novo arquivo `isocronas.js`.

### 9. APIs e dependências externas

| Serviço | Uso na aplicação | Arquivo em que aparece |
|---|---|---|
| Leaflet | Renderização do mapa e das camadas GeoJSON. | `vendor/leaflet.js`, `js/app.js` |
| Leaflet MarkerCluster | Agrupamento visual dos marcadores. | `vendor/leaflet.markercluster.js` |
| CARTO / OpenStreetMap | Blocos do mapa-base. | `js/app.js` |
| OpenRouteService | Cálculo de isócronas para coberturas e simulações. | `js/app.js`, `generar_isocronas.mjs` |
| Nominatim / OpenStreetMap | Busca de endereços no Chile. | `js/app.js` |
| Google Maps | Links externos de rota. | `js/app.js` |

### 10. Chave do OpenRouteService

A versão preparada para o GitHub não publica uma chave do OpenRouteService dentro de `js/app.js`. Isso evita o envio de uma credencial privada para um repositório público.

A visualização normal funciona com `data/isocronas.js`. Para recalcular coberturas ou utilizar a simulação de estabelecimentos, informe sua própria chave em:

```text
Ajuda e metodologia → OpenRouteService key
```

A chave é armazenada somente no navegador por meio de `localStorage`.

### 11. Execução local

Não é necessário instalar dependências para visualizar a aplicação. Basta servir a pasta como um site estático.

Com Python 3:

```bash
python3 -m http.server 8000
```

Depois, abra:

```text
http://localhost:8000/
```

Também é possível utilizar o script definido em `package.json`:

```bash
npm run start
```

### 12. Implantação manual no GitHub Pages

1. Crie um repositório vazio no GitHub.
2. Descompacte este arquivo ZIP.
3. Envie todo o conteúdo para a raiz do repositório, e não o arquivo ZIP.
4. Verifique se `index.html` e `README.md` estão na raiz.
5. No GitHub, acesse:

```text
Settings → Pages → Build and deployment
```

6. Configure:

```text
Source: Deploy from a branch
Branch: main
Folder: /root
```

7. Salve a configuração.

O GitHub Pages publicará a aplicação utilizando `index.html`. O README será exibido automaticamente na página inicial do repositório.

### 13. Manutenção dos dados

#### 13.1 Atualizar estabelecimentos

Edite `data/establecimientos.js`. Cada registro deve manter a seguinte estrutura:

```javascript
{
  code: 101100,
  name: "Hospital Dr Juan Noé Crevanni (Arica)",
  lat: -18.482478,
  lon: -70.312948,
  comuna: "Arica",
  provincia: "Arica",
  region: "Región de Arica y Parinacota",
  cod_comuna: 15101,
  codregion: 15,
  id: 1
}
```

Regras práticas:

- `id` deve ser único.
- `lat` e `lon` devem estar em WGS84.
- `codregion` deve coincidir com `data/regiones.js`.
- `cod_comuna` deve coincidir com `data/comunas.js`.
- Ao adicionar um estabelecimento, também é necessário gerar suas isócronas.

#### 13.2 Atualizar limites territoriais

Os arquivos `data/regiones.js` e `data/comunas.js` devem expor objetos GeoJSON em variáveis globais:

```javascript
window.REGIONES = {...};
window.COMUNAS = {...};
```

A aplicação utiliza esses polígonos para enquadrar o mapa, filtrar comunas e determinar em qual comuna está localizado um ponto consultado.

#### 13.3 Regenerar isócronas

As coberturas são armazenadas em:

```text
data/isocronas.js
```

Formato esperado:

```javascript
window.ISOCRONAS = {
  "1": {
    "30": { "type": "Polygon", "coordinates": [...] },
    "45": { "type": "Polygon", "coordinates": [...] },
    "60": { "type": "Polygon", "coordinates": [...] }
  }
};
```

Para regenerá-las, é possível utilizar a aplicação ou o script `generar_isocronas.mjs`. Ao utilizar a aplicação, depois que a preparação for concluída, baixe `isocronas.js` na janela de ajuda e envie o arquivo para `data/`.

### 14. Checklist antes da publicação

- [ ] `index.html` abre corretamente.
- [ ] `README.md` é exibido no GitHub com as imagens de `assets/`.
- [ ] Não há chaves privadas publicadas em `js/app.js`.
- [ ] `data/establecimientos.js` carrega 93 estabelecimentos ou o número atualizado esperado.
- [ ] `data/isocronas.js` contém coberturas para todos os estabelecimentos vigentes.
- [ ] Os filtros de região e comuna funcionam corretamente.
- [ ] Os botões 30/45/60 desenham as camadas de cobertura.
- [ ] A busca de endereço funciona com conexão à internet.
- [ ] A geolocalização é testada por meio de `https` ou `localhost`.
- [ ] O GitHub Pages está configurado para utilizar `main / root`.

### 15. Limitações conhecidas

- As isócronas dependem da rede viária e do serviço OpenRouteService quando são recalculadas.
- O GPS do navegador requer `https` ou `localhost`.
- A busca de endereços depende do Nominatim e de conexão à internet.
- A cobertura comunal on-line é estimada por amostragem de pontos e não substitui uma estimativa censitária completa.
- Ao adicionar novos estabelecimentos, também é necessário atualizar suas coberturas.
- Com árvores de dados muito grandes ou muitas geometrias ativas, o navegador pode levar mais tempo para renderizar o mapa.

### 16. Citação sugerida

Guajardo Arias, I. A., Villalobos Cid, M. J., & Giglio Gutiérrez, J. (2025). *Implementación de un sistema de visualización para el análisis espacio-temporal de la cobertura hospitalaria y la accesibilidad de los servicios de atención para el ataque cerebrovascular a nivel nacional en Chile*. Universidad de Santiago de Chile, Facultad de Ingeniería, Departamento de Ingeniería Informática.

Os metadados de citação para o GitHub também estão disponíveis em `CITATION.cff`.

### 17. Créditos

Trabalho associado à Universidad de Santiago de Chile, Faculdade de Engenharia, Departamento de Engenharia Informática.

Autores reconhecidos na citação do projeto:

| Autor | Função |
|---|---|
| Iván Alejandro Guajardo Arias | Desenvolvimento original da ferramenta e dissertação associada. |
| Manuel José Villalobos Cid | Professor orientador / colaboração acadêmica. |
| Juan Giglio Gutiérrez | Professor coorientador / colaboração acadêmica. |

Nota de preparação do repositório: este pacote foi organizado com apoio do ChatGPT para oferecer uma estrutura pronta para publicação no GitHub, concentrando toda a documentação em um único `README.md`, sem gerar documentos separados em vários arquivos Markdown.
