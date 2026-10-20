# scripts

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene el único script de desarrollo del proyecto. No forma parte de la aplicación que ve el usuario: sirve para revisar los datos antes de publicar un cambio. Para el contexto general, revisa el [README del proyecto](../README.md).

### `validate-data.mjs`

El script solo lee archivos y no escribe nada. Necesita Node.js 20.11 o superior, porque ubica la carpeta del proyecto con `import.meta.dirname`, y usa únicamente módulos de Node (`node:fs`, `node:path` y `node:process`), así que no hay que instalar paquetes. Se puede correr desde cualquier carpeta:

```bash
node scripts/validate-data.mjs
```

El script hace estas comprobaciones:

1. Revisa que `index.html` nombre los cinco archivos de [lib/](../lib/README.md) y los cuatro de [data/](../data/README.md), y que todos existan.
2. Lee cada archivo de datos, exige que empiece con `window.DATA_<NOMBRE>=` y termine con punto y coma, y comprueba que el contenido sea un GeoJSON `FeatureCollection` válido.
3. Exige 2.371 zonas censales, 52 comunas, 6 isócronas y 113 establecimientos.
4. Revisa que cada elemento tenga geometría, propiedades y los campos obligatorios de su capa, y que los establecimientos con `acv` verdadero traigan `f2019`, `f2020`, `f2021` y `fprom`.
5. Exige que las isócronas sean exactamente las de 10, 20, 30, 40, 50 y 60 minutos, que existan los tres tipos de establecimiento (`Hospital`, `Clínica` e `Instituto`) y que haya 21 hospitales con `acv` verdadero.

Si los datos calzan, imprime «Validation passed» con los conteos y termina con código 0; si algo falla, imprime cada error y termina con código 1. Las cantidades esperadas están escritas en el script, de modo que un cambio intencional en los datos obliga a actualizarlas aquí.

## English

This folder holds the project's only development script. It is not part of the application that users see: it checks the data before a change is published. For the general context, see the [project README](../README.md).

### `validate-data.mjs`

The script only reads files and writes nothing. It needs Node.js 20.11 or newer, because it finds the project folder through `import.meta.dirname`, and it uses only Node modules (`node:fs`, `node:path` and `node:process`), so no packages need to be installed. It can run from any folder:

```bash
node scripts/validate-data.mjs
```

The script performs these checks:

1. It verifies that `index.html` names the five files in [lib/](../lib/README.md) and the four in [data/](../data/README.md), and that all of them exist.
2. It reads each data file, requires it to start with `window.DATA_<NAME>=` and end with a semicolon, and checks that the content is a valid GeoJSON `FeatureCollection`.
3. It requires 2,371 census zones, 52 municipalities, 6 isochrones and 113 facilities.
4. It checks that each feature has a geometry, properties and the required fields of its layer, and that facilities whose `acv` is true carry `f2019`, `f2020`, `f2021` and `fprom`.
5. It requires the isochrones to be exactly the 10, 20, 30, 40, 50 and 60 minute ones, the three facility types (`Hospital`, `Clínica` and `Instituto`) to be present, and 21 hospitals to have `acv` set to true.

When everything matches, it prints "Validation passed" with the counts and exits with code 0; when something fails, it prints each error and exits with code 1. The expected counts are written in the script, so an intentional change in the data requires updating them here.
