# emisores/

[Español](#español) · [English](#english)

## Español

Esta carpeta es el paquete Python que escribe el XML a partir del modelo neutro del artículo (`core/model.py`). Los emisores nunca leen el PDF: todo lo que escriben sale de la ficha que el editor revisó. `app.py` los llama desde las rutas `/api/xml`, `/api/descargar` y `/api/lote`; los perfiles se describen en el [README del proyecto](../README.md#perfiles-de-salida).

| Archivo | Qué hace |
|---|---|
| `__init__.py` | Marca la carpeta como paquete; está vacío. |
| `base.py` | Reúne las utilidades comunes: `esc` y `attr` escapan texto y atributos, y la clase `Buffer` arma el XML con sangría (abrir, cerrar, hoja y texto crudo). |
| `jats.py` | Escribe NISO JATS 1.3 Journal Publishing con `front` (revista, identificadores DOI y PID, títulos, autores con ORCID, afiliaciones, fechas, licencia, resúmenes y palabras clave), `body` (secciones con `sec-type`) y `back` (lista de referencias con `element-citation`). Es la base de los otros dos perfiles. |
| `scielo.py` | Deriva dos perfiles. `emitir_sps` toma el XML JATS y lo declara como JATS Publishing 1.1 con `specific-use="sps-1.10"`, como pide SciELO PS 1.10; `alertas_sps` agrega los avisos de revisión de ese perfil (licencia y su URL, ISSN, cuerpo y ORCID). `emitir_wos` escribe el formato heredado con que SciELO alimenta SciELO Citation Index de Web of Science: solo metadatos, sin cuerpo, en ISO-8859-1, con citas `nlm-citation`. |

## English

This folder is the Python package that writes the XML from the neutral article model (`core/model.py`). The emitters never read the PDF: everything they write comes from the record the editor reviewed. `app.py` calls them from the `/api/xml`, `/api/descargar` and `/api/lote` routes; the profiles are described in the [project README](../README.md#output-profiles).

| File | What it does |
|---|---|
| `__init__.py` | Marks the folder as a package; it is empty. |
| `base.py` | Holds the shared utilities: `esc` and `attr` escape text and attributes, and the `Buffer` class builds indented XML (open, close, leaf and raw text). |
| `jats.py` | Writes NISO JATS 1.3 Journal Publishing with `front` (journal, DOI and PID identifiers, titles, authors with ORCID, affiliations, dates, licence, abstracts and keywords), `body` (sections with `sec-type`) and `back` (reference list with `element-citation`). It is the base of the other two profiles. |
| `scielo.py` | Derives two profiles. `emitir_sps` takes the JATS XML and declares it as JATS Publishing 1.1 with `specific-use="sps-1.10"`, as SciELO PS 1.10 requires; `alertas_sps` adds the review warnings of that profile (licence and its URL, ISSN, body and ORCID). `emitir_wos` writes the legacy format SciELO uses to feed the SciELO Citation Index of Web of Science: metadata only, no body, in ISO-8859-1, with `nlm-citation` references. |
