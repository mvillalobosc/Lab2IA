# publicaciones/data/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda la base del módulo Publicaciones de [ResearchAnalyser](../../README.md). La página lee `data.js`; `BD_papers.csv` es la fuente que se edita y desde la que se regenera ese archivo.

| Archivo | Qué es |
|---|---|
| `BD_papers.csv` | La base de publicaciones: 1.285 registros y 45 columnas separadas por `|`, en UTF-8. La arma `../../herramientas/procesador.html` a partir de las exportaciones de Scopus y Web of Science y de la base SJR de Scimago. |
| `data.js` | Empaqueta el CSV completo en `window.PAPERS_CSV = "...";` para que la app funcione con doble clic, sin servidor. Hoy su contenido es idéntico a `BD_papers.csv`. |
| `Conversor_Papers_BD_JS_v2.R` | Regenera `data.js` desde `BD_papers.csv` con R base: `Rscript Conversor_Papers_BD_JS_v2.R` dentro de esta carpeta. Normaliza los saltos de línea y escribe `<` y `>` como `\u003C` y `\u003E`. |

La otra forma de regenerar `data.js` es `python regenerar_datos.py` dentro de `publicaciones/`. Cualquiera de las dos sobrescribe `data.js`.

### Qué es un registro

Cada fila une una publicación con un académico de la unidad (`NOMBRE_AUTOR`), así que una publicación firmada por varios académicos aparece una vez por cada uno. Los 1.285 registros corresponden a 1.034 títulos distintos y 41 académicos. `SESION` distingue la unidad: el Departamento de Ingeniería Informática tiene 1.160 registros e Ingeniería Civil Biomédica, 125. Los años (`ANO`) van de 1976 a 2027.

### Columnas

| Grupo | Columnas |
|---|---|
| Unidad y académico | `UNIVERSIDAD`, `SESION`, `NOMBRE_AUTOR`, `SCOPUS_ID`, `WOS_ID` (nombre e identificador de Web of Science), `FIALIACION_SESION` (`SI` o `NO`, si el año de la publicación cae dentro de los años en que el académico estaba registrado en la unidad; lo usa el filtro Filiación), `URL_FOTO_ACADEMICO`, `URL_FOTO_DEPARTAMENTO` |
| Publicación | `AUTORES`, `AUTORES_ID`, `TITULO`, `ANO`, `FUENTE`, `VOLUMEN`, `PAG_COMIENZO`, `PAG_FINAL`, `DOI`, `LINK`, `ISSN`, `IDIOMA`, `TIPO_DOCUMENTO`, `RESUMEN`, `AUTOR_PALABRAS_CLAVES`, `INDEX_PALABRAS_CLAVES` |
| Afiliaciones y países | `AFILIACIÓN_AUTOR`, `AFILIACIÓN_AUTORES`, `PAISES_AUTORES` |
| Indexación e impacto | `WOS` (`SI` o `NO`), `WOS_Science_Index`, `WOS_COLECCION`, `SJR`, `QUARTILE` (`Q1` a `Q4` o `Sin clasificación`), `CITADO_POR`, `CATEGORIAS`, `AREAS` |
| Clasificaciones | `AREA_COMPUTACION`, `CODIGO_AREA_COMPUTACION`, `NOMBRE_AREA_COMPUTACION` (áreas de computación), `AREA_OCDE`, `CODIGO_OCDE`, `DISCIPLINA_OCDE`, `SUBDISCIPLINA_OCDE` (áreas OCDE), `AREA_ODS_ANID`, `CODIGO_ODS_ANID`, `NOMBRE_ODS_ANID` (Objetivos de Desarrollo Sostenible) |

Las listas dentro de una celda (autores, identificadores, palabras clave) van separadas por `; `. El nombre `FIALIACION_SESION` se escribe así en la base, en la app y en `procesador.html`.

Las columnas de fotos traen URL de otros sitios y la base incluye nombres de personas, así que conviene revisar la licencia y los datos personales descritos en el [README del proyecto](../../README.md) antes de publicarla.

## English

This folder holds the database of the Publications module of [ResearchAnalyser](../../README.md). The page reads `data.js`; `BD_papers.csv` is the source that gets edited and from which that file is regenerated.

| File | What it is |
|---|---|
| `BD_papers.csv` | The publications database: 1,285 records and 45 columns separated by `|`, in UTF-8. `../../herramientas/procesador.html` builds it from the Scopus and Web of Science exports and the Scimago SJR database. |
| `data.js` | Packs the whole CSV into `window.PAPERS_CSV = "...";` so that the app works with a double click, without a server. Its content is currently identical to `BD_papers.csv`. |
| `Conversor_Papers_BD_JS_v2.R` | Regenerates `data.js` from `BD_papers.csv` with base R: `Rscript Conversor_Papers_BD_JS_v2.R` inside this folder. It normalises line breaks and writes `<` and `>` as `\u003C` and `\u003E`. |

The other way to regenerate `data.js` is `python regenerar_datos.py` inside `publicaciones/`. Either one overwrites `data.js`.

### What a record is

Each row links a publication to one academic of the unit (`NOMBRE_AUTOR`), so a publication signed by several academics appears once for each of them. The 1,285 records correspond to 1,034 distinct titles and 41 academics. `SESION` identifies the unit: the Departamento de Ingeniería Informática has 1,160 records and Ingeniería Civil Biomédica has 125. Years (`ANO`) range from 1976 to 2027.

### Columns

| Group | Columns |
|---|---|
| Unit and academic | `UNIVERSIDAD`, `SESION`, `NOMBRE_AUTOR`, `SCOPUS_ID`, `WOS_ID` (Web of Science name and identifier), `FIALIACION_SESION` (`SI` or `NO`, whether the publication year falls within the years in which the academic was registered in the unit; the Affiliation filter uses it), `URL_FOTO_ACADEMICO`, `URL_FOTO_DEPARTAMENTO` |
| Publication | `AUTORES`, `AUTORES_ID`, `TITULO`, `ANO`, `FUENTE`, `VOLUMEN`, `PAG_COMIENZO`, `PAG_FINAL`, `DOI`, `LINK`, `ISSN`, `IDIOMA`, `TIPO_DOCUMENTO`, `RESUMEN`, `AUTOR_PALABRAS_CLAVES`, `INDEX_PALABRAS_CLAVES` |
| Affiliations and countries | `AFILIACIÓN_AUTOR`, `AFILIACIÓN_AUTORES`, `PAISES_AUTORES` |
| Indexing and impact | `WOS` (`SI` or `NO`), `WOS_Science_Index`, `WOS_COLECCION`, `SJR`, `QUARTILE` (`Q1` to `Q4` or `Sin clasificación`), `CITADO_POR`, `CATEGORIAS`, `AREAS` |
| Classifications | `AREA_COMPUTACION`, `CODIGO_AREA_COMPUTACION`, `NOMBRE_AREA_COMPUTACION` (computing areas), `AREA_OCDE`, `CODIGO_OCDE`, `DISCIPLINA_OCDE`, `SUBDISCIPLINA_OCDE` (OECD fields), `AREA_ODS_ANID`, `CODIGO_ODS_ANID`, `NOMBRE_ODS_ANID` (Sustainable Development Goals) |

Lists inside a cell (authors, identifiers, keywords) are separated by `; `. The name `FIALIACION_SESION` is spelled this way in the database, in the app and in `procesador.html`.

The photo columns hold URLs on other sites and the database includes people's names, so check the licence and the personal data notes in the [project README](../../README.md) before publishing it.
