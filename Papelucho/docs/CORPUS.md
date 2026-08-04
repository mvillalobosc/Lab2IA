# Corpus / Corpus

> ## ⚠️ Copyright / Derechos de autor
>
> **EN.** The corpus contains 63 commercially published novels (Stephen King,
> J. K. Rowling, Stephenie Meyer, R. A. Salvatore, Umberto Eco and others) and
> the 12 Papelucho titles. All 75 are under copyright. Marcela Paz died in 1985,
> so the Papelucho books are protected in Chile until 2055.
>
> Publishing `data/raw/corpus.tar.gz` in a **public** repository redistributes
> them in full and is copyright infringement, exposed to a DMCA takedown against
> the repository and its owner.
>
> Safe options, in order of preference:
>
> 1. **Publish without the texts.** Uncomment the `data/raw/corpus.tar.gz` line
>    in `.gitignore`. `data/metadata/corpus_checksums.csv` still lets anyone
>    verify byte-for-byte that they have assembled the identical corpus, so
>    reproducibility is preserved. This is standard practice in corpus
>    linguistics and is what the field expects.
> 2. **Keep the repository private** and share access with reviewers and
>    collaborators only.
> 3. **Publish only derived data**: the frequency tables and counts already in
>    `outputs/tables/`, which are not the original text.
>
> The archive is included by default because it was requested. Decide before
> making the repository public.
>
> **ES.** El corpus contiene 63 novelas publicadas comercialmente (Stephen King,
> J. K. Rowling, Stephenie Meyer, R. A. Salvatore, Umberto Eco y otros) y los 12
> títulos de Papelucho. Los 75 están protegidos por derechos de autor. Marcela
> Paz murió en 1985, así que los Papelucho están protegidos en Chile hasta 2055.
>
> Publicar `data/raw/corpus.tar.gz` en un repositorio **público** los
> redistribuye completos y es infracción de derechos de autor, expuesta a un
> takedown DMCA contra el repositorio y su dueño.
>
> Opciones seguras, en orden de preferencia:
>
> 1. **Publicar sin los textos.** Descomentar la línea
>    `data/raw/corpus.tar.gz` en `.gitignore`. El archivo
>    `data/metadata/corpus_checksums.csv` igual permite verificar byte a byte que
>    se armó el corpus idéntico, así que la reproducibilidad se conserva. Es la
>    práctica estándar en lingüística de corpus y es lo que el área espera.
> 2. **Mantener el repositorio privado** y dar acceso solo a revisores y
>    colaboradores.
> 3. **Publicar solo datos derivados**: las tablas de frecuencias y conteos que
>    ya están en `outputs/tables/`, que no son el texto original.
>
> El archivo va incluido por defecto porque así se pidió. Decidir antes de hacer
> público el repositorio.

**EN.** The book texts analysed in this project are under copyright and are not
distributed with this repository. This document explains how to reconstruct the
corpus so the pipeline can be re-run.

**ES.** Los textos de los libros analizados en este proyecto están protegidos por
derechos de autor y no se distribuyen con este repositorio. Este documento
explica cómo reconstruir el corpus para poder volver a correr el pipeline.

---

## 1. Layout and packing / Estructura y empaquetado

```
data/raw/corpus.tar.gz          the 75 texts as ONE tracked file
data/raw/papelucho/             12 .txt files, UTF-8   (unpacked, gitignored)
data/raw/comparison/            63 .txt files, UTF-8   (unpacked, gitignored)
data/metadata/corpus_checksums.csv   MD5 and byte size for all 75
```

**EN.** The texts are tracked as a single archive rather than 75 loose files.
That is what keeps the repository under the 100-file limit of the GitHub web
uploader; 75 loose texts plus the code alone would be 94 files with no room for
anything else.

```bash
Rscript scripts/unpack_corpus.R      # unpack and verify every checksum
tar -czf data/raw/corpus.tar.gz -C data/raw papelucho comparison   # repack
```

`unpack_corpus.R` also runs without the archive: it verifies whichever files are
already in place and names the missing ones. A checksum mismatch means the file
is not byte-identical to the one the published results were computed on, usually
through a re-encoding or a line-ending conversion.

**ES.** Los textos se versionan como un solo archivo comprimido y no como 75
sueltos. Eso es lo que mantiene el repositorio bajo el límite de 100 archivos del
uploader web de GitHub; 75 textos sueltos más el código serían 94 archivos sin
espacio para nada más.

`unpack_corpus.R` también corre sin el archivo: verifica los que ya estén en su
lugar y nombra los que faltan. Una discrepancia de checksum significa que el
archivo no es idéntico byte a byte al que produjo los resultados publicados,
normalmente por una recodificación o una conversión de fin de línea.

**EN.** Filenames must match the `filename` column of
`data/metadata/corpus_metadata.csv` exactly, including spaces and the absence of
accents. Step 01 stops with an error if a listed file is missing from disk or if
a file on disk is not listed in the metadata, so a mismatch cannot pass silently.

**ES.** Los nombres de archivo deben coincidir exactamente con la columna
`filename` de `data/metadata/corpus_metadata.csv`, incluidos los espacios y la
ausencia de acentos. El paso 01 se detiene con error si un archivo listado falta
en el disco o si un archivo del disco no está listado en el metadata, así que una
discrepancia no puede pasar en silencio.

---

## 2. Metadata columns / Columnas del metadata

| Column | EN | ES |
|---|---|---|
| `book_id` | Stable identifier (`PAP01`–`PAP12`, `CMP01`–`CMP63`) | Identificador estable |
| `group` | `Papelucho` or `Comparison` | `Papelucho` o `Comparison` |
| `filename` | Exact filename on disk | Nombre exacto del archivo en disco |
| `title_es` / `title_en` | Title in Spanish / English | Título en español / inglés |
| `author` | Author as credited | Autor tal como se acredita |
| `series` / `series_position` | Series name and volume number | Nombre de la serie y número de volumen |
| `year_first_edition` | Year of first publication | Año de primera publicación |
| `audience` | `children`, `young_adult`, `adult` | `children`, `young_adult`, `adult` |
| `original_language` | ISO code of the language it was written in | Código ISO del idioma en que se escribió |
| `translated` | `TRUE` if the text is a translation into Spanish | `TRUE` si el texto es una traducción al español |
| `notes` | Edition caveats, ambiguous titles | Salvedades de edición, títulos ambiguos |

**EN.** The `audience`, `original_language` and `translated` columns are not
decorative. Step 09 uses them to build the restricted corpus designs that test
whether each finding survives the imbalances in the comparison group. If you
extend the corpus, these columns must be filled in correctly or the sensitivity
analysis becomes meaningless.

**ES.** Las columnas `audience`, `original_language` y `translated` no son
decorativas. El paso 09 las usa para armar los diseños restringidos de corpus que
prueban si cada hallazgo sobrevive a los desbalances del grupo de comparación. Si
extiendes el corpus, estas columnas deben llenarse correctamente o el análisis de
sensibilidad pierde sentido.

---

## 3. Composition of the current corpus / Composición del corpus actual

### Papelucho (12 books, 1947–1974)

The complete series by Marcela Paz (Esther Huneeus Salas), in publication order.
The two posthumous 2017 volumes are **not** included, since they were assembled
from unpublished drafts and did not go through the same editorial process.

La serie completa de Marcela Paz (Esther Huneeus Salas), en orden de publicación.
Los dos volúmenes póstumos de 2017 **no** se incluyen, ya que se armaron a partir
de borradores inéditos y no pasaron por el mismo proceso editorial.

### Comparison (63 books)

| Author | Books | % |
|---|---|---|
| R. A. Salvatore | 16 | 25.4 |
| J. K. Rowling | 7 | 11.1 |
| L. J. Smith | 5 | 7.9 |
| Stephen King | 5 | 7.9 |
| Stephenie Meyer | 5 | 7.9 |
| Justin Somper | 4 | 6.3 |
| Rick Riordan | 4 | 6.3 |
| Others (17 authors) | 17 | 27.0 |

| Property | Value |
|---|---|
| Translated into Spanish / Traducidos al español | 60 of 63 |
| Originally Spanish / Originalmente en español | 3 of 63 |
| Adult fiction / Ficción adulta | 30 of 63 |
| Children or young adult / Infantil o juvenil | 33 of 63 |

**EN.** This composition is a known limitation, documented in the README and
tested in step 09. It was inherited from the earlier version of the study rather
than designed. A corpus assembled specifically for this comparison would balance
target audience, translation status and authorship, and would ideally include
Chilean and Latin American children's literature from a comparable period.

**ES.** Esta composición es una limitación conocida, documentada en el README y
puesta a prueba en el paso 09. Se heredó de la versión anterior del estudio, no se
diseñó. Un corpus armado específicamente para esta comparación balancearía público
objetivo, condición de traducción y autoría, e idealmente incluiría literatura
infantil chilena y latinoamericana de un período comparable.

---

## 4. Text file requirements / Requisitos de los archivos de texto

**EN.**

1. **Encoding: UTF-8.** Files in Latin-1 will produce corrupted accented
   characters. Convert with `iconv -f ISO-8859-1 -t UTF-8 in.txt > out.txt`.
2. **Plain text, one book per file.** No markup, no page images.
3. **Editorial front matter may be left in.** Step 01 detects and removes it, and
   records exactly what was removed in `outputs/tables/01_corpus_qa.csv`.
4. **Ebook scraper footers may be left in.** Lines such as
   `www.lectulandia.com - Página 5` are removed throughout the file in step 01.
5. **Hard-wrapped lines are fine.** Several files in the current corpus are
   wrapped at roughly 50 characters; the pipeline rejoins them.

**ES.**

1. **Codificación: UTF-8.** Los archivos en Latin-1 producirán acentos corruptos.
   Convertir con `iconv -f ISO-8859-1 -t UTF-8 in.txt > out.txt`.
2. **Texto plano, un libro por archivo.** Sin marcado, sin imágenes de página.
3. **El paratexto editorial puede dejarse.** El paso 01 lo detecta y elimina, y
   registra exactamente qué se eliminó en `outputs/tables/01_corpus_qa.csv`.
4. **Los pies de scraper de ebooks pueden dejarse.** Líneas como
   `www.lectulandia.com - Página 5` se eliminan en todo el archivo en el paso 01.
5. **Las líneas cortadas duro no son problema.** Varios archivos del corpus actual
   están cortados a unos 50 caracteres; el pipeline los vuelve a unir.

---

## 5. Verifying the corpus / Verificar el corpus

```bash
Rscript run_all.R 01
```

**EN.** Then inspect:

- `outputs/tables/01_corpus_descriptives.csv` — token, type and sentence counts
  per book. A book with an implausible count usually means an encoding problem.
- `outputs/tables/01_corpus_qa.csv` — how much front matter and scraper
  boilerplate was removed from each file, with a preview of the removed text.
  **Read the preview column.** If narrative text appears there, the cleaning was
  too aggressive for that file and should be reported as a bug.
- `outputs/tables/01_balance_*.csv` — length, authorship, audience and
  translation balance across the two groups.

**ES.** Después inspeccionar:

- `outputs/tables/01_corpus_descriptives.csv` — conteos de tokens, tipos y
  oraciones por libro. Un libro con un conteo inverosímil suele indicar un
  problema de codificación.
- `outputs/tables/01_corpus_qa.csv` — cuánto paratexto y boilerplate de scraper se
  eliminó de cada archivo, con una vista previa del texto eliminado.
  **Leer la columna de vista previa.** Si ahí aparece texto narrativo, la limpieza
  fue demasiado agresiva para ese archivo y debe reportarse como bug.
- `outputs/tables/01_balance_*.csv` — balance de largo, autoría, público y
  traducción entre los dos grupos.

---

## 6. Adding books / Agregar libros

**EN.**

1. Place the `.txt` file in the appropriate `data/raw/` subdirectory.
2. Add a row to `data/metadata/corpus_metadata.csv` with every column filled.
   Use the next free `book_id`.
3. Re-run the full pipeline. Do not re-run only the later steps: all derived
   objects depend on step 01.

Note that adding books to the comparison group changes the multiple-testing
family size and therefore every adjusted p-value in the project.

**ES.**

1. Poner el archivo `.txt` en el subdirectorio correspondiente de `data/raw/`.
2. Agregar una fila a `data/metadata/corpus_metadata.csv` con todas las columnas
   llenas. Usar el siguiente `book_id` libre.
3. Volver a correr el pipeline completo. No correr solo los pasos posteriores:
   todos los objetos derivados dependen del paso 01.

Notar que agregar libros al grupo de comparación cambia el tamaño de la familia de
pruebas múltiples y por lo tanto todo valor p ajustado del proyecto.
