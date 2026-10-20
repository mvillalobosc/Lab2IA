# web/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la interfaz de PDF2JATS en un solo archivo, `index.html` (unas 3.000 líneas), que `app.py` entrega en la ruta `/`. La interfaz está en castellano y no carga nada desde internet: el CSS, el JavaScript y el logo del DIINF (como imagen en base64) van dentro del archivo. El uso se explica en la [guía de uso](../docs/GUIA_USO.md) y la API que llama, en el [README del proyecto](../README.md#rutas-de-la-api).

### Cómo está organizado `index.html`

| Parte | Contenido |
|---|---|
| Bloque `<style>` (inicio del archivo) | Estilos con la paleta USACH (turquesa `#00A499`, naranjo `#EA7600` y gris `#394049`), diseño de escritorio y móvil. |
| Cuerpo HTML | Cabecera con el logo, el selector **Estándar de salida** y los botones Ayuda, Siguiente pendiente, + Agregar PDFs y Descargar todos; la cola de artículos; el visor de páginas del PDF; la ficha con las pestañas Metadatos, Autoría, Contenido, Referencias y Salida XML; el panel Ayuda con la normativa, los estados y los atajos; y la ventana de progreso de la carga. |
| Bloque `<script>` (final del archivo) | La lógica: estado de la sesión en el navegador, carga de los PDF uno por uno contra `/api/extraer`, dibujo de la ficha y del margen de estados, edición y guardado, búsqueda de DOI, vista previa y descarga del XML. |

### Detalles útiles para editarla

- Las llamadas a la API usan una base calculada desde la URL de la página (`APP_BASE`), así que la misma interfaz funciona en `/` y bajo un prefijo como `/PDF2JATS/`. Por eso no sirve abrir el archivo con doble clic: necesita que `app.py` responda las rutas `/api/...`.
- El perfil elegido en el selector (`sps` al empezar) viaja en las consultas para que el servidor evalúe los campos con ese perfil.
- `CONTRIBUTING.md` lista lo que conviene probar después de modificar este archivo.

## English

This folder holds the PDF2JATS interface in a single file, `index.html` (about 3,000 lines), which `app.py` serves at `/`. The interface is in Spanish and loads nothing from the internet: the CSS, the JavaScript and the DIINF logo (as a base64 image) are inside the file. Usage is explained in the [user guide](../docs/GUIA_USO.md), and the API it calls in the [project README](../README.md#api-routes).

### How `index.html` is organised

| Part | Content |
|---|---|
| `<style>` block (start of the file) | Styles with the USACH palette (teal `#00A499`, orange `#EA7600` and grey `#394049`), desktop and mobile layout. |
| HTML body | Header with the logo, the **Estándar de salida** (output standard) selector and the Ayuda (help), Siguiente pendiente (next pending), + Agregar PDFs (add PDFs) and Descargar todos (download all) buttons; the article queue; the PDF page viewer; the record with the Metadatos, Autoría, Contenido, Referencias and Salida XML tabs; the help panel with the standards, the states and the shortcuts; and the upload progress window. |
| `<script>` block (end of the file) | The logic: session state in the browser, upload of the PDFs one at a time to `/api/extraer`, drawing of the record and the margin of states, editing and saving, DOI search, XML preview and download. |

### Useful details for editing it

- API calls use a base derived from the page URL (`APP_BASE`), so the same interface works at `/` and under a prefix such as `/PDF2JATS/`. That is why opening the file with a double click does not work: it needs `app.py` to answer the `/api/...` routes.
- The profile chosen in the selector (`sps` at start) travels with the requests so that the server evaluates the fields with that profile.
- `CONTRIBUTING.md` lists what to test after changing this file.
