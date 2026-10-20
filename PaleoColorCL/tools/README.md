# tools/

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene las dos herramientas de mantenimiento de [PaleoColor CL](../README.md). Las dos son scripts de Python 3 que usan solo la biblioteca estándar y ubican el proyecto a partir de su propia ruta, así que se pueden ejecutar desde cualquier directorio.

### `sellar_version.py`

```bash
python tools/sellar_version.py
```

El script lee `APP_VERSION` en `js/config.js` y escribe esa versión como sufijo `?v=<versión>` en tres lugares: los `import` relativos de todos los módulos de `js/` (salvo `js/vendor/`), la constante `BUILD` de `js/app.js` y los `href` y `src` que apuntan a `.js` o `.css` en los HTML de la raíz del proyecto, que descubre solo. Modifica esos archivos en el mismo repositorio. Después verifica que ningún `import` relativo quede sin sellar, que no convivan dos versiones y que ningún símbolo en mayúsculas se use sin importarlo ni declararlo; si algo falla, termina con código 1. Hay que correrlo cada vez que cambia `APP_VERSION`. Cuando no queda nada por sellar, lo informa y no cambia ningún archivo.

### `reempacar_proyecto.py`

```bash
python tools/reempacar_proyecto.py [salida.zip] [--no-stamp] [--include-tests]
```

El script corre primero `sellar_version.py` (salvo con `--no-stamp`) y luego empaqueta el proyecto completo en un zip con compresión máxima, dentro de una carpeta `PaleoColorCL/`. Deja fuera `__pycache__`, `.git` y `.DS_Store`. Sin argumento de salida escribe `ColoreaEnRA_v<versión>.zip` en la carpeta que contiene a `PaleoColorCL/`; en este monorepo esa carpeta es la raíz del repositorio y el `.gitignore` ignora ese zip. La opción `--include-tests` incluiría una carpeta `tests/`, que el proyecto no tiene.

## English

This folder holds the two maintenance tools of [PaleoColor CL](../README.md). Both are Python 3 scripts that use only the standard library and locate the project from their own path, so they can run from any directory.

### `sellar_version.py`

```bash
python tools/sellar_version.py
```

The script reads `APP_VERSION` from `js/config.js` and writes that version as a `?v=<version>` suffix in three places: the relative `import` statements of every module in `js/` (except `js/vendor/`), the `BUILD` constant in `js/app.js` and the `href` and `src` attributes that point to `.js` or `.css` files in the HTML pages at the project root, which it finds on its own. It modifies those files in the repository. It then checks that no relative `import` is left unstamped, that no two versions coexist and that no uppercase symbol is used without being imported or declared; when a check fails, it exits with code 1. Run it every time `APP_VERSION` changes. When nothing is left to stamp, it says so and changes no file.

### `reempacar_proyecto.py`

```bash
python tools/reempacar_proyecto.py [output.zip] [--no-stamp] [--include-tests]
```

The script first runs `sellar_version.py` (unless it receives `--no-stamp`) and then packs the whole project into a zip with maximum compression, inside a `PaleoColorCL/` folder. It leaves out `__pycache__`, `.git` and `.DS_Store`. Without an output argument it writes `ColoreaEnRA_v<version>.zip` to the folder that contains `PaleoColorCL/`; in this monorepo that folder is the repository root, and `.gitignore` ignores that zip. The `--include-tests` option would include a `tests/` folder, which the project does not have.
