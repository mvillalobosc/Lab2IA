# Arquitectura · Architecture

[Español](#español) · [English](#english)

## Español

PDF2JATS es una aplicación Flask con una interfaz web autocontenida y módulos Python separados por responsabilidad.

### Componentes

#### `app.py`

Expone la interfaz y la API HTTP. Gestiona una sesión de artículos cargados por navegador, identificada por una cookie firmada, la actualización de campos, la revisión, las consultas DOI/SciELO y la generación/descarga XML. La lista de rutas está en el [README del proyecto](../README.md#rutas-de-la-api).

#### `core/`

- `pdf_reader.py`: lectura del PDF y representación de páginas.
- `layout.py`: apoyo a la lectura de estructura y bloques.
- `front_matter.py`: extracción inicial de metadatos editoriales.
- `autoria.py`: extracción y normalización de autoría/filiaciones.
- `cuerpo_refs.py`: cuerpo del artículo y referencias.
- `doi_metadata.py`: enriquecimiento desde DOI y fuentes bibliográficas.
- `reference_metadata.py`: búsqueda de DOI para referencias.
- `scielo_metadata.py`: recuperación de metadatos públicos de SciELO cuando existe una coincidencia por DOI.
- `revision.py`: estados de revisión y campos pendientes.
- `model.py`: modelo neutral del artículo.
- `extractor.py`: coordina el pipeline de extracción.

El detalle de cada módulo está en [core/README.md](../core/README.md).

#### `emisores/`

Transforma el modelo neutral a los perfiles XML soportados.

- `jats.py`: salida JATS 1.3.
- `scielo.py`: perfil SciELO PS 1.10 y perfil heredado Clarivate / SciELO Citation Index.
- `base.py`: utilidades comunes.

El detalle está en [emisores/README.md](../emisores/README.md).

#### `web/index.html`

Interfaz HTML/CSS/JavaScript autocontenida. Contiene la mesa de trabajo, visor del PDF, pestañas de edición, estados de revisión, ayudas, carga múltiple y previsualización de XML.

### Flujo de datos

```text
PDF
 │
 ▼
Extractor
 │
 ├── front matter
 ├── autoría
 ├── cuerpo
 └── referencias
 │
 ▼
Modelo neutral
 │
 ├── enriquecimiento DOI
 ├── enriquecimiento SciELO
 └── revisión humana
 │
 ▼
Emisor
 │
 ├── JATS 1.3
 ├── SciELO PS 1.10
 └── Clarivate / SciELO CI
 │
 ▼
XML
```

### Principio de diseño

La extracción automática puede sugerir datos, pero la aplicación mantiene visible qué elementos requieren revisión humana. Un dato inferido no se presenta como confirmado hasta que el usuario lo valida o lo corrige.

## English

PDF2JATS is a Flask application with a self-contained web interface and Python modules split by responsibility.

### Components

#### `app.py`

Exposes the interface and the HTTP API. It manages one session of uploaded articles per browser, identified by a signed cookie, field updates, review, DOI/SciELO queries and XML generation and download. The list of routes is in the [project README](../README.md#api-routes).

#### `core/`

- `pdf_reader.py`: reads the PDF and represents its pages.
- `layout.py`: supports the reading of structure and blocks.
- `front_matter.py`: first extraction of editorial metadata.
- `autoria.py`: extraction and normalisation of authorship and affiliations.
- `cuerpo_refs.py`: article body and references.
- `doi_metadata.py`: enrichment from the DOI and bibliographic sources.
- `reference_metadata.py`: DOI search for references.
- `scielo_metadata.py`: retrieval of public SciELO metadata when there is a match by DOI.
- `revision.py`: review states and pending fields.
- `model.py`: neutral article model.
- `extractor.py`: coordinates the extraction pipeline.

Each module is described in [core/README.md](../core/README.md).

#### `emisores/`

Turns the neutral model into the supported XML profiles.

- `jats.py`: JATS 1.3 output.
- `scielo.py`: SciELO PS 1.10 profile and the legacy Clarivate / SciELO Citation Index profile.
- `base.py`: shared utilities.

Details are in [emisores/README.md](../emisores/README.md).

#### `web/index.html`

Self-contained HTML/CSS/JavaScript interface. It holds the workbench, the PDF viewer, the editing tabs, the review states, the help, the multiple upload and the XML preview.

### Data flow

```text
PDF
 │
 ▼
Extractor
 │
 ├── front matter
 ├── authorship
 ├── body
 └── references
 │
 ▼
Neutral model
 │
 ├── DOI enrichment
 ├── SciELO enrichment
 └── human review
 │
 ▼
Emitter
 │
 ├── JATS 1.3
 ├── SciELO PS 1.10
 └── Clarivate / SciELO CI
 │
 ▼
XML
```

### Design principle

Automatic extraction can suggest values, but the application keeps visible which elements need human review. An inferred value is not shown as confirmed until the user validates or corrects it.
