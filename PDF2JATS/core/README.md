# core/

[Español](#español) · [English](#english)

## Español

Esta carpeta es el paquete Python que convierte un PDF en el modelo neutro del artículo, lo completa con fuentes abiertas y calcula qué campos falta revisar. `app.py` importa estos módulos; ninguno se ejecuta por sí solo. La visión general está en el [README del proyecto](../README.md) y en [docs/ARQUITECTURA.md](../docs/ARQUITECTURA.md).

### Orden en que trabajan

`extractor.extraer(ruta)` abre el PDF con `pdf_reader`, que a su vez usa `layout` para medir la maqueta. Después saca el front matter con `front_matter`, los autores y afiliaciones con `autoria` y el cuerpo y las referencias con `cuerpo_refs`. Si encontró un DOI, completa los metadatos con `doi_metadata` y `scielo_metadata`. El resultado es un objeto `Articulo` de `model`, que `revision` evalúa para pintar el margen de estados. La búsqueda de DOI de cada referencia (`reference_metadata`) no corre durante la extracción: la pide el editor desde la pestaña Referencias.

### Archivos

| Archivo | Qué hace |
|---|---|
| `__init__.py` | Marca la carpeta como paquete; está vacío. |
| `pdf_reader.py` | Lee el PDF con PyMuPDF y guarda cada línea con su texto, tamaño de letra, peso, posición y página (clases `Linea` y `Documento`), porque la tipografía es la señal que separa título, autores y encabezados. |
| `layout.py` | Mide la maqueta del propio documento (clase `Maqueta`): encabezados y pies que se repiten entre páginas, número y límites de columnas, tamaños del cuerpo, de los títulos y de las notas, zona de notas al pie y orden de lectura. No asume ninguna revista en particular. |
| `front_matter.py` | Extrae de las primeras páginas el DOI, los ISSN, el volumen y número, las páginas, las fechas de recepción, aceptación y publicación (en español, inglés y portugués), los títulos, los resúmenes y las palabras clave, cada uno con una señal de confianza. |
| `autoria.py` | Delimita la zona de autoría, la corta en bloques por columna y distancia vertical, clasifica cada línea (nombre, institución, lugar, correo, ORCID) y liga autores con afiliaciones; si la zona no trae nada, lo intenta en las notas al pie de la portada. |
| `cuerpo_refs.py` | Segmenta el cuerpo en secciones a partir de los tamaños y pesos que el documento usa para sus encabezados, y separa la lista de referencias probando tres estrategias (sangría francesa, primera línea y patrón) para quedarse con la más consistente. |
| `doi_metadata.py` | Consulta el DOI en DOI.org (BibTeX y CSL-JSON), Crossref, DataCite, la página editorial a la que resuelve el DOI y la ficha de la revista por ISSN, fusiona lo que obtiene sin borrar lo que ya venía del PDF y guarda las respuestas en memoria. Ningún fallo detiene la extracción. Lo controlan `PDF2JATS_DOI_LOOKUP`, `PDF2JATS_DOI_TIMEOUT` y `PDF2JATS_USER_AGENT`. |
| `reference_metadata.py` | Busca candidatos DOI para una referencia en la API de Crossref (`query.bibliographic`), les asigna un puntaje de 0 a 1 comparando título, autores, año y fuente con lo extraído, y aplica el candidato elegido. Espera entre consultas para respetar el límite de Crossref; lo controlan `PDF2JATS_CROSSREF_MAILTO`, `PDF2JATS_DOI_TIMEOUT` y `PDF2JATS_USER_AGENT`. |
| `scielo_metadata.py` | Busca el DOI en el buscador público de SciELO (`search.scielo.org`), confirma el artículo, obtiene su PID y lee el XML publicado por la colección para tomar los metadatos que SciELO conoce con autoridad. Nunca fabrica un PID: si el artículo no está en SciELO, el campo queda vacío. |
| `model.py` | Define el modelo neutro con dataclasses: `Afiliacion`, `Autor`, `Referencia`, `Seccion` y `Articulo` (con `to_json`). Todo emisor XML parte de este modelo y nunca del PDF. |
| `revision.py` | Tiene la tabla de campos (`CAMPOS` y `GRUPOS`) con los perfiles que exigen cada uno y calcula el estado de cada campo: `ok`, `duda`, `falta` o `vacio` (vacío y no exigido). Un campo pasa a `ok` cuando el editor lo confirma o lo corrige. |
| `extractor.py` | Coordina todo lo anterior en `extraer(ruta)` y devuelve un `Articulo` con sus alertas y señales de confianza. También infiere el título de la revista y la editorial desde la cornisa repetida y la licencia Creative Commons desde el texto. |

### Notas

- Los módulos que consultan servicios externos usan solo la biblioteca estándar (`urllib`); `scielo_metadata.py` además usa `lxml` para leer HTML y XML.
- Las cachés de `doi_metadata.py` y `reference_metadata.py` viven en la memoria del proceso y se pierden al reiniciar.

## English

This folder is the Python package that turns a PDF into the neutral article model, completes it from open sources and works out which fields still need review. `app.py` imports these modules; none of them runs on its own. The overview is in the [project README](../README.md) and in [docs/ARQUITECTURA.md](../docs/ARQUITECTURA.md).

### Order of work

`extractor.extraer(ruta)` opens the PDF with `pdf_reader`, which in turn uses `layout` to measure the page layout. It then takes the front matter with `front_matter`, the authors and affiliations with `autoria`, and the body and references with `cuerpo_refs`. When it found a DOI, it completes the metadata with `doi_metadata` and `scielo_metadata`. The result is an `Articulo` object from `model`, which `revision` evaluates to draw the margin of review states. The DOI search for each reference (`reference_metadata`) does not run during extraction: the editor requests it from the Referencias (references) tab.

### Files

| File | What it does |
|---|---|
| `__init__.py` | Marks the folder as a package; it is empty. |
| `pdf_reader.py` | Reads the PDF with PyMuPDF and stores each line with its text, font size, weight, position and page (classes `Linea` and `Documento`), because typography is the signal that separates title, authors and headings. |
| `layout.py` | Measures the layout of the document itself (class `Maqueta`): headers and footers repeated across pages, number and limits of columns, sizes of the body text, headings and notes, the footnote area and the reading order. It assumes no particular journal. |
| `front_matter.py` | Extracts from the first pages the DOI, the ISSNs, volume and issue, pages, the received, accepted and published dates (in Spanish, English and Portuguese), titles, abstracts and keywords, each with a confidence signal. |
| `autoria.py` | Finds the authorship area, cuts it into blocks by column and vertical gap, classifies each line (name, institution, place, e-mail, ORCID) and links authors to affiliations; when the area is empty, it tries the footnotes of the first page. |
| `cuerpo_refs.py` | Splits the body into sections from the sizes and weights the document uses for its headings, and separates the reference list by trying three strategies (hanging indent, first line and pattern) and keeping the most consistent one. |
| `doi_metadata.py` | Queries the DOI at DOI.org (BibTeX and CSL-JSON), Crossref, DataCite, the publisher page the DOI resolves to and the journal record by ISSN, merges what it gets without erasing what came from the PDF and keeps the answers in memory. No failure stops the extraction. It is controlled by `PDF2JATS_DOI_LOOKUP`, `PDF2JATS_DOI_TIMEOUT` and `PDF2JATS_USER_AGENT`. |
| `reference_metadata.py` | Searches the Crossref API (`query.bibliographic`) for DOI candidates for a reference, scores each from 0 to 1 by comparing title, authors, year and source with the extracted values, and applies the chosen candidate. It waits between queries to respect the Crossref limit; it is controlled by `PDF2JATS_CROSSREF_MAILTO`, `PDF2JATS_DOI_TIMEOUT` and `PDF2JATS_USER_AGENT`. |
| `scielo_metadata.py` | Looks the DOI up in the public SciELO search (`search.scielo.org`), confirms the article, gets its PID and reads the XML published by the collection to take the metadata SciELO knows authoritatively. It never makes up a PID: when the article is not in SciELO, the field stays empty. |
| `model.py` | Defines the neutral model with dataclasses: `Afiliacion`, `Autor`, `Referencia`, `Seccion` and `Articulo` (with `to_json`). Every XML emitter starts from this model, never from the PDF. |
| `revision.py` | Holds the table of fields (`CAMPOS` and `GRUPOS`) with the profiles that require each one and computes the state of every field: `ok`, `duda` (doubt), `falta` (missing) or `vacio` (empty and not required). A field becomes `ok` when the editor confirms or corrects it. |
| `extractor.py` | Coordinates all of the above in `extraer(ruta)` and returns an `Articulo` with its warnings and confidence signals. It also infers the journal title and the publisher from the repeated running header, and the Creative Commons licence from the text. |

### Notes

- The modules that query external services use only the standard library (`urllib`); `scielo_metadata.py` also uses `lxml` to read HTML and XML.
- The caches of `doi_metadata.py` and `reference_metadata.py` live in the process memory and are lost on restart.
