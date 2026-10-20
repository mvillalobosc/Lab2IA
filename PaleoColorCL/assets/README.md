# assets/

[Español](#español) · [English](#english)

## Español

Esta carpeta reúne los recursos estáticos que cargan las tres páginas de [PaleoColor CL](../README.md): las hojas de estilo, el logo institucional y el catálogo de personajes.

| Archivo o carpeta | Qué es y quién lo usa |
|---|---|
| `styles.css` | Hoja de estilos del visor de realidad aumentada. La carga `index.html` y define la paleta USACH (teal `#00A499`, naranjo `#EA7600`, pizarra `#394049`), el escenario de la cámara, el menú y la pantalla de inicio. No tiene `url()` ni `@import`. |
| `shell.css` | Hoja común de las dos herramientas de escritorio, `plantillas.html` y `textos.html`. Su cabecera explica que vive aparte porque esos diez selectores estaban copiados en las dos páginas. El visor no la usa. Tampoco tiene `url()` ni `@import`. |
| `brand/diinf.png` | Logo del Departamento de Ingeniería Informática (PNG de 329 x 110 px). `js/credits.js` lo declara en `BRAND.logo`; el visor lo muestra en la portada y en la barra superior, y `js/template.js` lo dibuja en el pie de cada plantilla imprimible y en el editor. |
| [`characters/`](characters/README.md) | Catálogo `index.json` y los 50 manifiestos JSON de los personajes. Tiene su propio README con el formato de cada archivo. |

Las tres páginas piden las hojas de estilo con el sufijo `?v=<versión>` (por ejemplo `assets/styles.css?v=100`). `tools/sellar_version.py` actualiza ese sufijo cuando cambia `APP_VERSION` en `js/config.js`, así que si se agrega otra hoja conviene enlazarla de la misma forma.

## English

This folder holds the static resources that the three pages of [PaleoColor CL](../README.md) load: the stylesheets, the institutional logo and the character catalogue.

| File or folder | What it is and who uses it |
|---|---|
| `styles.css` | Stylesheet of the augmented-reality viewer. `index.html` loads it, and it defines the USACH palette (teal `#00A499`, orange `#EA7600`, slate `#394049`), the camera stage, the menu and the start screen. It contains no `url()` or `@import`. |
| `shell.css` | Shared sheet of the two desktop tools, `plantillas.html` and `textos.html`. Its header explains that it lives apart because those ten selectors used to be copied in both pages. The viewer does not use it. It contains no `url()` or `@import` either. |
| `brand/diinf.png` | Logo of the Department of Informatics Engineering (PNG, 329 x 110 px). `js/credits.js` declares it in `BRAND.logo`; the viewer shows it on the start screen and in the top bar, and `js/template.js` draws it in the footer of every printable template and in the editor. |
| [`characters/`](characters/README.md) | The `index.json` catalogue and the 50 JSON character manifests. It has its own README that describes the format of each file. |

The three pages request the stylesheets with a `?v=<version>` suffix (for example `assets/styles.css?v=100`). `tools/sellar_version.py` updates that suffix when `APP_VERSION` changes in `js/config.js`, so any new stylesheet should be linked the same way.
