# demo/

[Español](#español) · [English](#english)

## Español

`genera_corpus_demo.R` arma un corpus sintético para comprobar que el pipeline corre de punta a cabo sin los libros reales. Se ejecuta desde la raíz del proyecto:

```bash
Rscript demo/genera_corpus_demo.R
```

El script fija la semilla 4242, crea `demo/textos/` con 36 libros en txt (3 por cada nivel del 1 al 12, con nombres como `01_el_perro_saltarin.txt`) y escribe `demo/catalogo_demo.xlsx` con las columnas `Titulo`, `Archivo` y `Curso` (por ejemplo "5° Básico" o "2° Medio"). La complejidad del léxico, el largo de las oraciones y la carga afectiva crecen con el nivel, de modo que las pruebas por nivel tienen una señal que detectar. El corpus trae tres casos a propósito para ejercitar los controles: "La cenicienta" aparece en los niveles 2 y 4 con el mismo texto (duplicado por título y contenido), "El tesoro del rio" tiene unas 180 palabras y queda bajo `min_palabras`, y la fila "Libro fantasma" apunta a `no_existe.txt` para que el módulo 01 la excluya con motivo.

El `config.R` versionado ya apunta a estos archivos, así que después basta con `Rscript run_all.R`, que corre en unos 5 minutos. El script usa writexl y la tubería nativa `|>` de R 4.1 o superior. `demo/textos/` y `demo/catalogo_demo.xlsx` no se versionan: los ignora el `.gitignore` de la raíz del repositorio. Vuelve al [README del proyecto](../README.md).

## English

`genera_corpus_demo.R` builds a synthetic corpus to check that the pipeline runs end to end without the real books. Run it from the project root:

```bash
Rscript demo/genera_corpus_demo.R
```

The script sets seed 4242, creates `demo/textos/` with 36 txt books (3 for each grade from 1 to 12, with names such as `01_el_perro_saltarin.txt`) and writes `demo/catalogo_demo.xlsx` with the columns `Titulo`, `Archivo` and `Curso` (for example "5° Básico" or "2° Medio"). Vocabulary complexity, sentence length and affective load grow with the grade, so the per-grade tests have a signal to find. The corpus includes three deliberate cases that exercise the checks: "La cenicienta" appears in grades 2 and 4 with the same text (a duplicate by title and content), "El tesoro del rio" has about 180 words and falls below `min_palabras`, and the row "Libro fantasma" points to `no_existe.txt` so that module 01 excludes it with a reason.

The versioned `config.R` already points to these files, so `Rscript run_all.R` is all that follows, and it takes about 5 minutes. The script uses writexl and R's native `|>` pipe, which needs R 4.1 or later. `demo/textos/` and `demo/catalogo_demo.xlsx` are not versioned: the `.gitignore` at the repository root ignores them. Back to the [project README](../README.md).
