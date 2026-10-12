# ResearchAnalyser · DIINF USACH

App web estática para explorar la producción científica y los trabajos de título del Departamento de Ingeniería Informática. Funciona con doble clic en `index.html`, sin servidor ni internet (solo el mapa de colaboración y las fotos de los académicos se cargan desde la web). Interfaz en español, portugués e inglés (selector arriba a la derecha).

## Abrir

- `index.html` es la portada: desde ahí se elige Publicaciones o Tesis y memorias (y "Inicio" en la barra lateral vuelve a ella).
- `publicaciones/index.html` y `tesis/index.html` son los dos módulos; la cabecera permite pasar de uno a otro.

## Carpetas

| Carpeta | Contenido |
|---|---|
| `publicaciones/` | Módulo de publicaciones (4.989 registros, 43 campos). Datos en `data/BD_papers.csv`; la app lee `data/data.js`. |
| `tesis/` | Módulo de tesis y memorias (898 registros, 20 campos). Datos en `data/memorias.csv` y `data/academicos.csv`; la app lee `data/data.js`. Los Excel de origen están en la misma carpeta. |
| `publicaciones/lib/`, `fonts/`, `webfonts/` | Librerías y tipografías locales, compartidas por los dos módulos. |
| `herramientas/` | `procesador.html` (de los CSV de Scopus y WoS al `BD_papers.csv`) y `gestor_tesis.html` (completar enlaces y áreas de las memorias). Se abren con doble clic. |
| `warmup/` | Precarga del asistente IA en Ollama (`warmup.sh` y servicio systemd). |
| `theme.css`, `theme.js`, `portal.css` | Capa visual común (paleta USACH, tipografía, gráficos). No contienen cálculos. |
| `asistente.js` | Motor del asistente local, compartido por los dos módulos. Cada módulo lo configura en su `app_chat.js`. |

## Actualizar los datos

Publicaciones: edita `publicaciones/data/BD_papers.csv` (separador `|`) y ejecuta `python regenerar_datos.py` dentro de `publicaciones/`, o `Rscript Conversor_Papers_BD_JS_v2.R` dentro de `publicaciones/data/`.

Tesis: edita `tesis/data/memorias.csv` o `academicos.csv` y ejecuta `python regenerar_datos.py` dentro de `tesis/`, o `Rscript Conversor_tesis_v2.R` dentro de `tesis/data/` (requiere `readxl`).

## Asistente

Responde en el navegador, sin API ni servidor, sobre las filas del filtro activo. Entiende la pregunta como una intención (contar, listar, ranking, comparar, coautores, temas, evolución por año, revistas, países, cuartiles, métricas, definir un área) más condiciones que se combinan en una misma frase: persona, años ("desde 2020", "entre 2018 y 2022", "últimos 5 años"), cuartil, WoS o Scopus, tipo de documento, tema, país, programa, rol de guía o co-guía y con o sin enlace. Cada respuesta parte con "Entendí: …" para que se pueda verificar qué condiciones aplicó. Funciona en español, inglés y portugués.

Las reglas comunes están en `asistente.js`; los campos de cada base, los sinónimos propios y el formato de cada respuesta están en `publicaciones/app_chat.js` y `tesis/app_chat.js`. Para agregar equivalencias de términos (por ejemplo, un nuevo tema en dos idiomas) basta con añadirlas al mapa `SINONIMOS` del motor o al `CHAT_BILINGUAL_TERMS` del módulo.

`warmup/` y `herramientas/configurar_ollama.bat` son para las herramientas que usan Ollama (`procesador.html` y `gestor_tesis.html`), no para el asistente de la app.

## Descarga de la base completa

El botón "Base completa" pide una contraseña. La clave no está en el código; solo su hash SHA-256 en `app_clave.js` de cada módulo, con instrucciones para cambiarla.

Desarrollado por Manuel Villalobos-Cid y Valentina Cares Cárdenas · DIINF · Universidad de Santiago de Chile.
