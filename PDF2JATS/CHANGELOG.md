# Changelog

[Español](#español) · [English](#english)

## Español

### Cambios sin versión (octubre de 2026)

- La ruta `/web/` ya no entrega archivos de fuera de la carpeta `web/`: una ruta que intenta salir de ella, como `/web/../app.py`, recibe 404.
- Cada navegador tiene su propia sesión de trabajo, identificada por la cookie firmada `pdf2jats_sesion`. La clave de firma sale de la variable de entorno `PDF2JATS_SECRET_KEY` o, si no está definida, se genera al arrancar.
- Una sesión sin actividad por más de 6 horas se borra junto con sus PDF.
- Los PDF cargados se guardan en una subcarpeta por sesión dentro de `pdf2jats_pdfs`.
- `/api/limpiar` borra solo la sesión y los PDF de quien la llama; antes vaciaba la sesión común y toda la carpeta temporal. `/api/quitar`, `/api/propagar`, `/api/lote` y `/api/cola` también trabajan solo con la sesión propia.
- Las páginas que el visor recibe como PNG llevan `Cache-Control: private`, para que ningún caché compartido las guarde.
- Las cabeceras `User-Agent` de las consultas a DOI.org, Crossref, DataCite y SciELO dicen `PDF2JATS/1.10`; antes decían 1.3, 1.4 o 1.5 según el módulo.
- El código se distribuye con licencia MIT (`LICENSE`), y `CITATION.cff` declara la licencia y apunta a la carpeta del proyecto en el repositorio.
- La documentación quedó en castellano y en inglés: el README explica la ejecución local, las rutas de la API, las variables de entorno, los tres perfiles de salida y los límites de operación; `docs/INSTALACION.md` usa un solo worker de Gunicorn en sus ejemplos, y `core/`, `emisores/`, `web/` y `docs/` tienen su propio README.

### 1.10 (2026-08-12)

- La ayuda explica explícitamente que un bloque `?` se confirma haciendo clic y pasa a `✓`.
- Se añadió una indicación visible dentro de la ficha cuando existen campos pendientes.
- Los enlaces a normativa se concentran en el panel **Ayuda**.
- Se retiraron enlaces normativos repetidos de avisos amarillos, información y encabezados de bloques.
- Se mantiene la URL oficial de Creative Commons como dato derivado de la licencia, no como campo manual.
- Se mantiene la carga múltiple de PDF con ventana de progreso.

## English

### Unreleased changes (October 2026)

- The `/web/` route no longer serves files outside the `web/` folder: a path that tries to leave it, such as `/web/../app.py`, gets 404.
- Each browser has its own working session, identified by the signed cookie `pdf2jats_sesion`. The signing key comes from the `PDF2JATS_SECRET_KEY` environment variable or, when it is not set, is generated at startup.
- A session with no activity for more than 6 hours is deleted together with its PDFs.
- Uploaded PDFs are stored in one subfolder per session inside `pdf2jats_pdfs`.
- `/api/limpiar` deletes only the session and the PDFs of the caller; before, it emptied the shared session and the whole temporary folder. `/api/quitar`, `/api/propagar`, `/api/lote` and `/api/cola` also work only on the caller's session.
- The pages that the viewer receives as PNG carry `Cache-Control: private`, so that no shared cache stores them.
- The `User-Agent` headers of the queries to DOI.org, Crossref, DataCite and SciELO say `PDF2JATS/1.10`; before, they said 1.3, 1.4 or 1.5 depending on the module.
- The code is distributed under the MIT licence (`LICENSE`), and `CITATION.cff` declares the licence and points to the project folder in the repository.
- The documentation is now in Spanish and English: the README explains the local run, the API routes, the environment variables, the three output profiles and the operating limits; `docs/INSTALACION.md` uses a single Gunicorn worker in its examples, and `core/`, `emisores/`, `web/` and `docs/` have their own README.

### 1.10 (2026-08-12)

- The help states explicitly that a `?` block is confirmed with a click and turns into `✓`.
- A visible notice was added inside the record when there are pending fields.
- Links to the standards are gathered in the **Ayuda** (help) panel.
- Repeated links to the standards were removed from the yellow warnings, the information notes and the block headers.
- The official Creative Commons URL is still derived from the licence instead of being a manual field.
- The multiple PDF upload with a progress window is kept.
