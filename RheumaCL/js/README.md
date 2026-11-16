# js

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el código que corre en el navegador. Son tres scripts clásicos, sin módulos ni librerías, que `index.html` carga en este orden después de las bases de datos de [data/](../data/README.md): `textos.js`, `graficos.js` y `app.js`. Para el contexto general, revisa el [README del proyecto](../README.md).

| Archivo | Variable global | Qué hace |
|---|---|---|
| `textos.js` | `window.RCL_TEXTOS`, `window.RCL_REGIONES` | Trae todos los textos de la interfaz en castellano (`es`), inglés (`en`) y portugués (`pt`), con los mismos 470 textos en cada idioma, y el nombre corto y largo de cada región. |
| `graficos.js` | `window.RCL_GRAFICOS` | Dibuja las piezas: `icono()`, `botonAyuda()` (el "?" con su explicación), `barras()`, `segmentada()`, `leyenda()`, `tabla()`, `red()` (enfermedades combinadas, en SVG) y `mapa()` (regiones, en SVG). No conoce los datos ni los textos: recibe filas ya armadas. |
| `app.js` | ninguna | Guarda el estado, lo lee y lo escribe en la dirección de la página, arma el panel de selección, la ficha y sus pestañas con los datos de `window.BD_ENCUESTA`, y maneja la bienvenida, la guía de uso y los avisos. |

### `textos.js`

Cada idioma tiene 19 grupos:

| Grupos | Contenido |
|---|---|
| `codigo`, `numero` | Código del idioma y separadores de miles y decimales. |
| `app`, `modo`, `nav`, `selector`, `ficha`, `comun` | La estructura de la página: barra superior, vistas, pestañas, panel de selección, ficha y textos comunes. |
| `resumen`, `combinadas`, `perfil`, `territorio`, `tratamientos`, `acceso` | Títulos de cada pestaña y de la vista por región. |
| `ayuda` | La explicación de cada "?". |
| `bienvenida`, `guia` | La presentación de la primera visita y la guía de uso, con su glosario. |
| `enf`, `cat` | Nombre y descripción de cada enfermedad y texto de cada respuesta de la encuesta. |

Los textos aceptan reemplazos con la forma `{nombre}`. `data/bd_encuesta.js` guarda las respuestas con códigos, no con textos; el código de cada respuesta es la clave con que `cat` la traduce, así que un código nuevo en la base necesita su texto en los tres idiomas.

Para agregar un idioma hay que copiar un bloque completo de `RCL_TEXTOS` y traducirlo, agregar su código a `IDIOMAS` en `app.js` y agregar su botón en `index.html` con el atributo `data-idioma`.

### `app.js`

Estos son sus bloques, en el orden del archivo:

| Bloque | Qué hace |
|---|---|
| Constantes | `MODOS`, `SECCIONES`, `GRUPO_CHICO` (30 personas), `CLASES_MAPA` (cortes del mapa), `COBERTURA` (GES, guía clínica y Ley Ricarte Soto de cada enfermedad) y `CATEGORIA_FARMACO`. |
| Textos, números y almacenamiento | `t()` busca un texto en el idioma activo; `num()`, `pct()` y `fecha()` dan formato según el idioma; `leerGuardado()` y `guardar()` usan el almacenamiento del navegador y siguen funcionando si está bloqueado. |
| Estado en la dirección | `leerDireccion()` y `escribirDireccion()` mantienen la vista, la pestaña, la enfermedad, la región y el idioma en `#modo=...&seccion=...&enf=...&reg=...&lang=...`. Los valores que no existen se ignoran. |
| Acciones | `cambiar()` actualiza el estado, vuelve a pintar y devuelve el foco al control que se usó. |
| Piezas comunes | `cifra()`, `tarjeta()` (con su "?", su tabla y su descarga), `tarjetaBarras()`, `bloque()` y `grupo()`, el grupo que se abre y se cierra. |
| Descargas, enlace y avisos | `descargarCsv()` arma un CSV en UTF-8 con los números sin formato; `copiarEnlace()` copia la dirección de la vista; `avisar()` muestra el aviso breve. |
| Ficha y pestañas | La ficha del grupo elegido y la barra de pestañas, que se recorre con las flechas, Inicio y Fin. |
| Pestañas y vista por región | Una función por pestaña, de `seccionResumen()` a `seccionAcceso()`, y `vistaRegion()`. |
| Panel de selección | La lista de enfermedades, o el mapa y la lista de regiones, con la lista desplegable que los reemplaza en pantallas angostas. |
| Guía de uso y bienvenida | Arman los dos diálogos, retienen el foco mientras están abiertos y lo devuelven al cerrarse. |
| Pintado e inicio | `pintar()` vuelve a dibujar la página cuando cambia el estado; el inicio elige la enfermedad y la región con más encuestados, lee la dirección y abre la bienvenida si corresponde. |

El navegador guarda dos datos: el idioma elegido (`rheumacl_idioma`) y la marca de no volver a mostrar la bienvenida (`rheumacl_sin_bienvenida`).

## English

This folder holds the code that runs in the browser. It consists of three classic scripts, without modules or libraries, which `index.html` loads in this order after the databases in [data/](../data/README.md): `textos.js`, `graficos.js` and `app.js`. For the general context, see the [project README](../README.md).

| File | Global variable | What it does |
|---|---|---|
| `textos.js` | `window.RCL_TEXTOS`, `window.RCL_REGIONES` | Holds every interface text in Spanish (`es`), English (`en`) and Portuguese (`pt`), with the same 470 texts per language, and the short and long name of each region. |
| `graficos.js` | `window.RCL_GRAFICOS` | Draws the building blocks: `icono()` (icons), `botonAyuda()` (the "?" with its explanation), `barras()` (bars), `segmentada()` (segmented bar), `leyenda()` (legend), `tabla()` (table), `red()` (network of combined diseases, SVG) and `mapa()` (regions, SVG). It knows nothing about the data or the texts: it receives rows that are ready to draw. |
| `app.js` | none | Keeps the state, reads it from and writes it to the page address, builds the selection panel, the profile and its tabs with the data in `window.BD_ENCUESTA`, and handles the welcome, the user guide and the notices. |

### `textos.js`

Each language has 19 groups:

| Groups | Content |
|---|---|
| `codigo`, `numero` | Language code and thousands and decimal separators. |
| `app`, `modo`, `nav`, `selector`, `ficha`, `comun` | The page structure: top bar, views, tabs, selection panel, profile and shared texts. |
| `resumen`, `combinadas`, `perfil`, `territorio`, `tratamientos`, `acceso` | Titles of each tab and of the region view. |
| `ayuda` | The explanation behind each "?". |
| `bienvenida`, `guia` | The first-visit introduction and the user guide, with its glossary. |
| `enf`, `cat` | Name and description of each disease and the text of each survey answer. |

Texts accept substitutions written as `{name}`. `data/bd_encuesta.js` stores the answers as codes, not as texts; the code of each answer is the key that `cat` uses to translate it, so a new code in the database needs its text in the three languages.

To add a language, copy a whole block of `RCL_TEXTOS` and translate it, add its code to `IDIOMAS` in `app.js` and add its button to `index.html` with the `data-idioma` attribute.

### `app.js`

These are its blocks, in file order:

| Block | What it does |
|---|---|
| Constants | `MODOS` (views), `SECCIONES` (tabs), `GRUPO_CHICO` (30 people), `CLASES_MAPA` (map class breaks), `COBERTURA` (GES, clinical guideline and Ricarte Soto Law for each disease) and `CATEGORIA_FARMACO`. |
| Texts, numbers and storage | `t()` looks up a text in the active language; `num()`, `pct()` and `fecha()` format values for that language; `leerGuardado()` and `guardar()` use the browser storage and keep working when it is blocked. |
| State in the address | `leerDireccion()` and `escribirDireccion()` keep the view, tab, disease, region and language in `#modo=...&seccion=...&enf=...&reg=...&lang=...`. Values that do not exist are ignored. |
| Actions | `cambiar()` updates the state, redraws and returns the focus to the control that was used. |
| Building blocks | `cifra()` (figure), `tarjeta()` (card, with its "?", table and download), `tarjetaBarras()`, `bloque()` and `grupo()`, the group that opens and closes. |
| Downloads, link and notices | `descargarCsv()` builds a UTF-8 CSV with unformatted numbers; `copiarEnlace()` copies the address of the view; `avisar()` shows the short notice. |
| Profile and tabs | The profile of the chosen group and the tab bar, which is browsed with the arrow, Home and End keys. |
| Tabs and region view | One function per tab, from `seccionResumen()` to `seccionAcceso()`, and `vistaRegion()`. |
| Selection panel | The list of diseases, or the map and list of regions, with the drop-down list that replaces them on narrow screens. |
| User guide and welcome | Build both dialogs, keep the focus inside while they are open and return it when they close. |
| Rendering and start-up | `pintar()` redraws the page when the state changes; start-up picks the disease and the region with the most respondents, reads the address and opens the welcome when needed. |

The browser stores two values: the chosen language (`rheumacl_idioma`) and the flag that hides the welcome (`rheumacl_sin_bienvenida`).
