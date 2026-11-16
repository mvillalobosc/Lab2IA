# css

[Español](#español) · [English](#english)

## Español

Esta carpeta tiene `estilos.css`, la única hoja de estilos del dashboard. No usa librerías ni fuentes externas: la letra es la del sistema. Para el contexto general, revisa el [README del proyecto](../README.md).

Los colores y las medidas comunes están al comienzo del archivo, como variables de `:root`:

| Variable | Valor | Uso |
|---|---|---|
| `--tinta`, `--tinta-2`, `--tinta-3` | `#29313A`, `#4E5964`, `#66717C` | Texto principal, secundario y notas. |
| `--teal`, `--teal-p` | `#6FC4BC`, `#8FD3CC` | Azul verdoso de la USACH en pastel: marcas, bordes, selección y botón principal. |
| `--teal-dd`, `--teal-ddd` | `#00655E`, `#00514C` | Azul verdoso oscuro para texto e íconos, que sí alcanza el contraste de lectura. |
| `--teal-l`, `--teal-l2` | `#E6F6F5`, `#CDECEA` | Fondos de la opción elegida y de los íconos. |
| `--naranja`, `--naranja-l` | `#F2AE6B`, `#FFF4E8` | Naranja de la USACH en pastel: región y enfermedad elegidas, filete de la barra superior y avisos. No se usa en texto, porque sobre blanco no alcanza el contraste mínimo de lectura. |
| `--grafito` | `#394049` | Gris corporativo de la USACH: globos de ayuda y avisos. |
| `--papel`, `--papel-2`, `--linea`, `--linea-2`, `--pista` | `#EEF1F3`, `#F6F8F9`, `#DFE4E8`, `#ECEFF1`, `#E9EEF1` | Fondos, bordes y fondo de las barras. |
| `--foco` | `#00554F` | Borde del elemento que tiene el foco del teclado. |
| `--alto-barra` | se mide al cargar | Alto de la barra superior. `js/app.js` lo ajusta para que el panel de selección y la barra de pestañas queden pegados justo debajo. |

Los colores de las series de los gráficos no están aquí: los define `COLOR` en `js/graficos.js`, con el azul verdoso y el naranja en pastel, un gris para "otro" y rampas de un solo tono para las escalas ordenadas.

El archivo sigue el orden de la página: base, botones, barra superior, panel de selección, ficha y pestañas, bloques y tarjetas, gráficos, guía de uso, bienvenida y avisos. Al final están los ajustes para pantallas angostas, con cortes en 1300, 1240, 1120, 1024, 900 y 680 px, y los de impresión. El corte de 680 px es el mismo que usa `js/app.js` para dibujar la red compacta, y bajo 900 px el panel de selección se convierte en una lista desplegable.

## English

This folder holds `estilos.css`, the only style sheet of the dashboard. It uses no libraries or external fonts: the typeface is the system one. For the general context, see the [project README](../README.md).

The shared colours and measures are at the top of the file, as `:root` variables:

| Variable | Value | Use |
|---|---|---|
| `--tinta`, `--tinta-2`, `--tinta-3` | `#29313A`, `#4E5964`, `#66717C` | Main text, secondary text and notes. |
| `--teal`, `--teal-p` | `#6FC4BC`, `#8FD3CC` | USACH teal in pastel: marks, borders, selection and main button. |
| `--teal-dd`, `--teal-ddd` | `#00655E`, `#00514C` | Dark teal for text and icons, which does reach reading contrast. |
| `--teal-l`, `--teal-l2` | `#E6F6F5`, `#CDECEA` | Backgrounds of the chosen option and of the icons. |
| `--naranja`, `--naranja-l` | `#F2AE6B`, `#FFF4E8` | USACH orange in pastel: chosen region and disease, line under the top bar and notices. It is not used for text, because on white it does not reach the minimum reading contrast. |
| `--grafito` | `#394049` | USACH corporate grey: help tooltips and notices. |
| `--papel`, `--papel-2`, `--linea`, `--linea-2`, `--pista` | `#EEF1F3`, `#F6F8F9`, `#DFE4E8`, `#ECEFF1`, `#E9EEF1` | Backgrounds, borders and bar track. |
| `--foco` | `#00554F` | Outline of the element that has keyboard focus. |
| `--alto-barra` | measured on load | Height of the top bar. `js/app.js` sets it so that the selection panel and the tab bar stay right below it. |

The colours of the chart series are not here: `COLOR` in `js/graficos.js` defines them, with pastel teal and orange, a grey for "other" and single-hue ramps for ordered scales.

The file follows the order of the page: base, buttons, top bar, selection panel, profile and tabs, blocks and cards, charts, user guide, welcome and notices. At the end come the adjustments for narrow screens, with breakpoints at 1300, 1240, 1120, 1024, 900 and 680 px, and the print rules. The 680 px breakpoint is the same one `js/app.js` uses to draw the compact network, and below 900 px the selection panel becomes a drop-down list.
