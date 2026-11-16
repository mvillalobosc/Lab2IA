# css

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene `estilos.css`, la única hoja de estilos del dashboard. No usa librerías ni fuentes externas: la letra es la del sistema. Para el contexto general, revisa el [README del proyecto](../README.md).

Los colores y las medidas comunes están al comienzo del archivo, como variables de `:root`:

| Variable | Valor | Uso |
|---|---|---|
| `--tinta`, `--tinta-2`, `--tinta-3` | `#25313A`, `#55616A`, `#606C74` | Texto principal, secundario y notas. |
| `--teal`, `--teal-fuerte`, `--teal-suave` | `#00A499`, `#00736B`, `#E2F3F1` | Azul verdoso corporativo de la USACH: barras, selección y fondos. `--teal-fuerte` es el que se usa en texto. |
| `--naranja`, `--naranja-suave` | `#EA7600`, `#FCEEDD` | Naranja corporativo de la USACH: marcas y avisos. No se usa en texto, porque sobre blanco no alcanza el contraste mínimo de lectura. |
| `--papel`, `--tarjeta`, `--linea`, `--pista` | `#F3F5F6`, `#FFFFFF`, `#D5DCE0`, `#ECF0F2` | Fondo de la página, tarjetas, bordes y fondo de las barras. |
| `--foco` | `#00554F` | Borde del elemento que tiene el foco del teclado. |

Los colores de las series de los gráficos no están aquí: los define `COLOR` en `js/graficos.js`, con el mismo azul verdoso, el naranja, un morado para la tercera categoría y rampas de un solo tono para las escalas ordenadas.

El archivo sigue el orden de la página: cabecera, navegación y filtro (quedan pegados arriba al bajar), secciones, cifras destacadas, tarjetas de gráfico, red de enfermedades, territorio, sobre los datos, globo de detalle y pie. Al final están los ajustes para pantallas angostas, con cortes en 1180, 900 y 680 px, y los de impresión. El corte de 680 px es el mismo que usa `js/app.js` para dibujar la red compacta.

## English

This folder holds `estilos.css`, the only style sheet of the dashboard. It uses no libraries or external fonts: the typeface is the system one. For the general context, see the [project README](../README.md).

The shared colours and measures are at the top of the file, as `:root` variables:

| Variable | Value | Use |
|---|---|---|
| `--tinta`, `--tinta-2`, `--tinta-3` | `#25313A`, `#55616A`, `#606C74` | Main text, secondary text and notes. |
| `--teal`, `--teal-fuerte`, `--teal-suave` | `#00A499`, `#00736B`, `#E2F3F1` | USACH corporate teal: bars, selection and backgrounds. `--teal-fuerte` is the one used for text. |
| `--naranja`, `--naranja-suave` | `#EA7600`, `#FCEEDD` | USACH corporate orange: marks and notices. It is not used for text, because on white it does not reach the minimum reading contrast. |
| `--papel`, `--tarjeta`, `--linea`, `--pista` | `#F3F5F6`, `#FFFFFF`, `#D5DCE0`, `#ECF0F2` | Page background, cards, borders and bar track. |
| `--foco` | `#00554F` | Outline of the element that has keyboard focus. |

The colours of the chart series are not here: `COLOR` in `js/graficos.js` defines them, with the same teal, the orange, a purple for the third category and single-hue ramps for ordered scales.

The file follows the order of the page: header, navigation and filter (they stay at the top while scrolling), sections, highlighted figures, chart cards, disease network, regions, about the data, detail tooltip and footer. At the end come the adjustments for narrow screens, with breakpoints at 1180, 900 and 680 px, and the print rules. The 680 px breakpoint is the same one `js/app.js` uses to draw the compact network.
