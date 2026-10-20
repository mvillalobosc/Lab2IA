# assets/characters/

[Español](#español) · [English](#english)

## Español

Esta carpeta guarda el catálogo de personajes de [PaleoColor CL](../../README.md). Cada personaje vive en un solo archivo JSON, el manifiesto, que trae sus datos, su arte y su animación. Las plantillas imprimibles no se guardan como imagen: `js/plantillas.js` las dibuja desde el manifiesto, de modo que el QR, las marcas y el dibujo siempre calzan con lo que espera el visor.

### Archivos

| Archivo | Contenido |
|---|---|
| `index.json` | Lista de 50 entradas, una por personaje, con `id`, `number` (1 a 50), `name` (nombre científico), `habitat` (`tierra` 29, `agua` 19, `aire` 2), `epoch` (Neógeno 17, Cretácico 14, Cuaternario 11, Jurásico 6, Paleógeno 2) y `group` (grupo en lenguaje común, por ejemplo `Foca`). La función `listCharacters` de `js/characters.js` la lee para la portada y la galería. |
| `<id>.json` | Manifiesto de cada personaje. Hay 50 (de 160 a 325 KB cada uno, unos 12 MB en total) y el nombre del archivo es el `id` del personaje. Los leen `js/characters.js` (visor y galería) y `js/textos.js` (editor). |

### Campos del manifiesto

| Campo | Qué guarda |
|---|---|
| `id` | Identificador corto con minúsculas, dígitos o guion, de hasta 9 caracteres. Debe coincidir con el nombre del archivo, y el QR de la plantilla lleva el texto `clr2:<id>`. |
| `number`, `name`, `habitat`, `epoch` | Los mismos datos de `index.json`. |
| `frame` | Marco del personaje en la hoja: `vertical`, `apaisado` o `cuadrado`, según `FRAMES` en `js/config.js`. Hoy hay 40 apaisados, 7 verticales y 3 cuadrados. |
| `animation` | Coreografía definida en `js/rig.js`. Los manifiestos usan `nada`, `desfile`, `camina`, `correteo`, `alzada` y `vuela`; si el campo falta, el código usa `parada`. |
| `groundY` | Altura del suelo dentro de la textura, en píxeles. Si falta, el código la calcula desde el borde inferior de la silueta. |
| `voice` | Parámetros de la voz que `js/voice.js` sintetiza con WebAudio: `type` (los 50 usan `gruñido`), `f0` (frecuencia fundamental), `vibrato`, `vibratoDepth`, `contour`, `noise`, `duration`, `gain` y `bubble` (texto del globo de diálogo). Ningún manifiesto trae audio grabado. |
| `facts` | Ficha de la tarjeta de datos: `pronunciation`, `meaning`, `group`, `sizeM` (largo en metros), `age` (texto en millones de años, por ejemplo `80-66`) e `items`, una lista de pares `label` y `text` (307 en total) donde el texto marca las negritas con `**`. |
| `lineart` | Dibujo de línea que se imprime en la plantilla y sobre el cual el visor proyecta los colores, como data URL PNG. |
| `silhouette` | Silueta del personaje como data URL PNG. La portada la dibuja y el visor la usa para calcular el área que ocupa el dibujo. |
| `parts` | Entre 4 y 9 partes articuladas por personaje (320 en total). Cada parte trae `id` (por ejemplo `cuerpo`, `cabeza-1`, `pata-1`, `cola`), `mask` (máscara PNG en data URL), `pivot` (punto de giro `[x, y]`), `motion`, `amount` (amplitud), `phase` (desfase) y `z` (orden de dibujo, de atrás hacia adelante). `motion` toma los valores `pendulo` (extremidades, aletas y alas), `cabeceo` (cabeza o cuello), `arrastre` (colas) y `respira` (cuerpo). La parte con `anchor: true` sostiene al resto; en los 50 manifiestos es `cuerpo`. |

`js/characters.js` valida al cargar que el `id` coincida con el archivo, que existan `lineart`, `silhouette` y al menos una parte, que cada parte tenga `id` único, `mask` y un `pivot` de dos números, y que `motion` sea uno de los movimientos de `js/rig.js`. El código también acepta un campo opcional `rear` (con `pivot` y `angle`) para alzarse sobre las patas traseras, que hoy no trae ningún manifiesto. Los campos de imagen admiten un data URL o una ruta relativa a esta carpeta.

### Cómo se modifica

Para cambiar textos, abre `textos.html`, elige el personaje, edita la ficha y descarga el JSON; después reemplaza aquí el archivo con el mismo nombre. Un personaje nuevo necesita un manifiesto completo (dibujo, silueta, máscaras y pivotes) más su entrada en `index.json`. El repositorio no trae una herramienta que produzca el dibujo y las máscaras desde cero.

## English

This folder stores the character catalogue of [PaleoColor CL](../../README.md). Each character lives in a single JSON file, the manifest, which carries its facts, its artwork and its animation. Printable templates are not stored as images: `js/plantillas.js` draws them from the manifest, so the QR code, the markers and the drawing always match what the viewer expects.

### Files

| File | Contents |
|---|---|
| `index.json` | List of 50 entries, one per character, with `id`, `number` (1 to 50), `name` (scientific name), `habitat` (`tierra` 29, `agua` 19, `aire` 2, that is land, water and air), `epoch` (Neogene 17, Cretaceous 14, Quaternary 11, Jurassic 6, Palaeogene 2, stored in Spanish) and `group` (common group name, for example `Foca`). The `listCharacters` function in `js/characters.js` reads it for the start screen and the gallery. |
| `<id>.json` | Manifest of each character. There are 50 (160 to 325 KB each, about 12 MB in total) and the file name is the character `id`. `js/characters.js` (viewer and gallery) and `js/textos.js` (editor) read them. |

### Manifest fields

| Field | What it stores |
|---|---|
| `id` | Short identifier made of lowercase letters, digits or hyphens, up to 9 characters. It must match the file name, and the template QR code carries the text `clr2:<id>`. |
| `number`, `name`, `habitat`, `epoch` | The same data as `index.json`. |
| `frame` | Frame of the character on the sheet: `vertical`, `apaisado` (landscape) or `cuadrado` (square), as defined by `FRAMES` in `js/config.js`. Today there are 40 landscape, 7 vertical and 3 square frames. |
| `animation` | Choreography defined in `js/rig.js`. The manifests use `nada`, `desfile`, `camina`, `correteo`, `alzada` and `vuela`; when the field is missing, the code uses `parada`. |
| `groundY` | Ground height inside the texture, in pixels. When it is missing, the code computes it from the bottom edge of the silhouette. |
| `voice` | Parameters of the voice that `js/voice.js` synthesises with WebAudio: `type` (all 50 use `gruñido`, a growl), `f0` (fundamental frequency), `vibrato`, `vibratoDepth`, `contour`, `noise`, `duration`, `gain` and `bubble` (text of the speech bubble). No manifest carries recorded audio. |
| `facts` | Content of the fact card: `pronunciation`, `meaning`, `group`, `sizeM` (length in metres), `age` (text in millions of years, for example `80-66`) and `items`, a list of `label` and `text` pairs (307 in total) where the text marks bold with `**`. |
| `lineart` | Line drawing printed on the template, onto which the viewer projects the colours, as a PNG data URL. |
| `silhouette` | Character silhouette as a PNG data URL. The start screen draws it and the viewer uses it to compute the area that the drawing occupies. |
| `parts` | Between 4 and 9 articulated parts per character (320 in total). Each part has `id` (for example `cuerpo`, `cabeza-1`, `pata-1`, `cola`), `mask` (PNG mask as a data URL), `pivot` (rotation point `[x, y]`), `motion`, `amount` (amplitude), `phase` (offset) and `z` (drawing order, back to front). `motion` takes the values `pendulo` (limbs, flippers and wings), `cabeceo` (head or neck), `arrastre` (tails) and `respira` (body). The part with `anchor: true` holds the rest; in all 50 manifests it is `cuerpo`. |

When it loads a manifest, `js/characters.js` checks that the `id` matches the file, that `lineart`, `silhouette` and at least one part exist, that every part has a unique `id`, a `mask` and a two-number `pivot`, and that `motion` is one of the movements in `js/rig.js`. The code also accepts an optional `rear` field (with `pivot` and `angle`) for rearing up on the hind legs, which no manifest uses today. Image fields accept a data URL or a path relative to this folder.

### How to change it

To edit texts, open `textos.html`, choose the character, edit the fact card and download the JSON, then replace the file with the same name here. A new character needs a complete manifest (drawing, silhouette, masks and pivots) plus its entry in `index.json`. The repository has no tool that produces the drawing and the masks from scratch.
