# Bosque Filogenético: uso

Descomprime la carpeta completa y abre index.html. También puedes ejecutar python servir.py para abrirla mediante un servidor local.

1. Elige la especie.
2. Busca un gen por ORF, nombre o descripción, o selecciona un punto del bosque.
3. Consulta el árbol y su ficha. En móvil, usa Explorar, Árbol y Ficha y vecinos.
4. Busca otro gen en Comparar para ver sus biparticiones compartidas y métricas.
5. Usa Descargar para exportar el árbol o los vecinos.

Las opciones de color, grupos, ramas y nombres están en secciones desplegables. Ampliar árbol dedica el espacio al árbol; el mismo botón devuelve los paneles. La tecla / lleva a la búsqueda. Escape cierra la ayuda, comparación o filtro.

Las ayudas junto a los paneles explican las proyecciones, RF, concordancia, resolución y respaldo. Guía técnica abre las fórmulas. El respaldo del bosque no es bootstrap. Las posiciones en el bosque no son coordenadas geográficas ni tiempo evolutivo.

Validación: carga, renderizado de árboles, comparación y ayudas con datos de ambas especies mediante DOM automatizado; sintaxis JavaScript verificada. La apariencia y los gestos táctiles requieren una comprobación en un navegador real.

## Metadata de S. cerevisiae
La sección Cepas y metadata consulta las 1.011 cepas e incluye aislado, población de origen, continente, país, sitio, ecología, sustrato, ploidía, coordenadas y precisión geográfica. Hay 943 cepas con coordenadas registradas. Los CSV originales se incluyen completos. La población que ya utilizaba la app se mantiene y la población del CSV se conserva como campo separado.

En la barra de grupos de cepas selecciona la variable para colorear el anillo. Haz clic en una cepa de la tabla para abrir su ficha en Referencia. El CSV exportado respeta la búsqueda activa. El TSV y preparar_app.R conservan la metadata en futuras regeneraciones. El cambio en R no se ha ejecutado en este entorno, que no dispone de R.

## Idiomas
Los botones superiores 🇨🇱 ES, 🇬🇧 EN y 🇧🇷 BR alternan la interfaz, fichas, mensajes, búsquedas, tablas y ayudas técnicas entre español, inglés y portugués de Brasil. La elección se recuerda en el navegador. Las traducciones están incluidas en el paquete y funcionan sin un servicio de traducción externo. Los identificadores científicos y los valores originales de la metadata se conservan.
