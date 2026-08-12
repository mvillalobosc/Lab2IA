# Arquitectura

PDF2JATS es una aplicación Flask con una interfaz web autocontenida y módulos Python separados por responsabilidad.

## Componentes

### `app.py`

Expone la interfaz y la API HTTP. Gestiona la sesión de artículos cargados, la actualización de campos, la revisión, las consultas DOI/SciELO y la generación/descarga XML.

### `core/`

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

### `emisores/`

Transforma el modelo neutral a los perfiles XML soportados.

- `jats.py`: salida JATS.
- `scielo.py`: ajustes del perfil SciELO.
- `base.py`: utilidades comunes.

### `web/index.html`

Interfaz HTML/CSS/JavaScript autocontenida. Contiene la mesa de trabajo, visor del PDF, pestañas de edición, estados de revisión, ayudas, carga múltiple y previsualización de XML.

## Flujo de datos

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
 ├── JATS
 └── SciELO PS
 │
 ▼
XML
```

## Principio de diseño

La extracción automática puede sugerir datos, pero la aplicación mantiene visible qué elementos requieren revisión humana. Un dato inferido no se presenta como confirmado hasta que el usuario lo valida o lo corrige.
