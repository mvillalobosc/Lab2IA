# js

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el código que corre en el navegador. Son tres scripts clásicos, sin módulos ni librerías, que `index.html` carga en este orden después de las bases de datos de [data/](../data/README.md): `textos.js`, `graficos.js` y `app.js`. Para el contexto general, revisa el [README del proyecto](../README.md).

| Archivo | Variable global | Qué hace |
|---|---|---|
| `textos.js` | `window.RCL_TEXTOS`, `window.RCL_REGIONES` | Trae todos los textos de la interfaz en castellano (`es`), inglés (`en`) y portugués (`pt`), con las mismas 341 claves en cada idioma, y el nombre corto y largo de cada región. |
| `graficos.js` | `window.RCL_GRAFICOS` | Dibuja las piezas: `barras()`, `segmentada()`, `leyenda()`, `tabla()`, `red()` (enfermedades combinadas, en SVG) y `mapa()` (regiones, en SVG). No conoce los datos ni los textos: recibe filas ya armadas. |
| `app.js` | ninguna | Guarda el estado (sección, enfermedad, región e idioma), lo lee y lo escribe en la dirección de la página, arma cada sección con los datos de `window.BD_ENCUESTA` y dibuja el filtro. |

### `textos.js`

Cada idioma tiene 15 grupos: `codigo`, `numero` (separadores de miles y decimales), `app`, `nav`, `filtro`, `comun`, uno por sección (`resumen`, `combinadas`, `perfil`, `territorio`, `tratamientos`, `acceso`, `datos`), `enf` (nombre y descripción de cada enfermedad) y `cat` (el texto de cada respuesta de la encuesta). Los textos aceptan reemplazos con la forma `{nombre}`.

`data/bd_encuesta.js` guarda las respuestas con códigos, no con textos. El código de cada respuesta es la clave con que `cat` la traduce, así que un código nuevo en la base necesita su texto en los tres idiomas.

Para agregar un idioma hay que copiar un bloque completo de `RCL_TEXTOS` y traducirlo, agregar su código a `IDIOMAS` en `app.js` y agregar su botón en `index.html` con el atributo `data-idioma`.

### `app.js`

Estos son sus bloques, en el orden del archivo:

| Bloque | Qué hace |
|---|---|
| Constantes | `SECCIONES`, `IDIOMAS`, `GRUPO_CHICO` (30 personas), `CLASES_MAPA` (cortes del mapa), `COBERTURA` (GES, guía clínica y Ley Ricarte Soto de cada enfermedad) y `CATEGORIA_FARMACO`. |
| Textos y formatos | `t()` busca un texto en el idioma activo; `num()`, `pct()` y `fecha()` dan formato según el idioma. |
| Estado y dirección | `leerDireccion()` y `escribirDireccion()` mantienen la sección, la enfermedad, la región y el idioma en `#seccion=...&enf=...&reg=...&lang=...`. El idioma inicial es el guardado en el navegador (`rheumacl_idioma`) o el del navegador. |
| Piezas | `tarjeta()`, `tarjetaBarras()`, `cifra()` y `grupo()` arman las tarjetas, con su base, su nota y su botón de tabla. |
| Secciones | Una función por sección, de `seccionResumen()` a `seccionDatos()`. |
| Filtro y pintado | `filtro()` dibuja el selector de enfermedad o de región, y `pintar()` vuelve a dibujar la página cuando cambia el estado. |

## English

This folder holds the code that runs in the browser. It consists of three classic scripts, without modules or libraries, which `index.html` loads in this order after the databases in [data/](../data/README.md): `textos.js`, `graficos.js` and `app.js`. For the general context, see the [project README](../README.md).

| File | Global variable | What it does |
|---|---|---|
| `textos.js` | `window.RCL_TEXTOS`, `window.RCL_REGIONES` | Holds every interface text in Spanish (`es`), English (`en`) and Portuguese (`pt`), with the same 341 keys per language, and the short and long name of each region. |
| `graficos.js` | `window.RCL_GRAFICOS` | Draws the building blocks: `barras()` (bars), `segmentada()` (segmented bar), `leyenda()` (legend), `tabla()` (table), `red()` (network of combined diseases, SVG) and `mapa()` (regions, SVG). It knows nothing about the data or the texts: it receives rows that are ready to draw. |
| `app.js` | none | Keeps the state (section, disease, region and language), reads it from and writes it to the page address, builds each section with the data in `window.BD_ENCUESTA` and draws the filter. |

### `textos.js`

Each language has 15 groups: `codigo`, `numero` (thousands and decimal separators), `app`, `nav`, `filtro`, `comun`, one per section (`resumen`, `combinadas`, `perfil`, `territorio`, `tratamientos`, `acceso`, `datos`), `enf` (name and description of each disease) and `cat` (the text of each survey answer). Texts accept substitutions written as `{name}`.

`data/bd_encuesta.js` stores the answers as codes, not as texts. The code of each answer is the key that `cat` uses to translate it, so a new code in the database needs its text in the three languages.

To add a language, copy a whole block of `RCL_TEXTOS` and translate it, add its code to `IDIOMAS` in `app.js` and add its button to `index.html` with the `data-idioma` attribute.

### `app.js`

These are its blocks, in file order:

| Block | What it does |
|---|---|
| Constants | `SECCIONES`, `IDIOMAS`, `GRUPO_CHICO` (30 people), `CLASES_MAPA` (map class breaks), `COBERTURA` (GES, clinical guideline and Ricarte Soto Law for each disease) and `CATEGORIA_FARMACO`. |
| Texts and formats | `t()` looks up a text in the active language; `num()`, `pct()` and `fecha()` format values for that language. |
| State and address | `leerDireccion()` and `escribirDireccion()` keep the section, disease, region and language in `#seccion=...&enf=...&reg=...&lang=...`. The initial language is the one stored in the browser (`rheumacl_idioma`) or the browser language. |
| Building blocks | `tarjeta()`, `tarjetaBarras()`, `cifra()` and `grupo()` build the cards, with their base, note and table button. |
| Sections | One function per section, from `seccionResumen()` to `seccionDatos()`. |
| Filter and rendering | `filtro()` draws the disease or region selector, and `pintar()` redraws the page when the state changes. |
