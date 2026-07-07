# Phyli

<p align="center">
  <img src="assets/screenshot-home.png" alt="Phyli home screen" width="92%">
</p>

<p align="center">
  <strong>Interactive phylogenetic tree visualisation in the browser</strong><br>
  <strong>Visualización interactiva de árboles filogenéticos en el navegador</strong>
</p>

<p align="center">
  <a href="#english">English</a> · <a href="#español">Español</a> · <a href="#screenshots--capturas">Screenshots / Capturas</a> · <a href="#citation--citación">Citation / Citación</a>
</p>

---

## Screenshots / Capturas

| Main interface / Interfaz principal | Radial layout / Trazado radial |
|---|---|
| ![Phyli home screen](assets/screenshot-home.png) | ![Radial tree layout](assets/screenshot-radial.png) |

| Export tools / Herramientas de exportación |
|---|
| ![Phyli export options](assets/screenshot-export.png) |

---

# English

## 1. Overview

**Phyli** is a standalone web application for loading, visualising, editing, rooting, exploring, and exporting phylogenetic trees. It is designed for teaching, research support, and quick inspection of trees in **Newick** format.

The application runs entirely in the browser. It does not require a backend, database, user account, installation process, or server-side processing. A static web server is enough to publish it.

**Live deployment:**  
<https://mvillalobosc.diinf.usach.cl/Phyli/>

## 2. Main features

- Load phylogenetic trees from local files or from a URL.
- Read trees in **Newick** format and project data in **JSON** format.
- Explore built-in examples, including vertebrates, a simple tree, and a tree-of-life example.
- Switch the application interface between **Spanish**, **English**, and **Portuguese**.
- Visualise trees as step, curved, straight, radial, or radial-step layouts.
- Use phylogram mode when branch lengths represent evolutionary distance.
- Use cladogram mode when only topology should be shown.
- Root trees by a selected species/taxon or by midpoint.
- Search taxa and centre the canvas on a selected tip.
- Collapse, focus, and colour clades.
- Display internal support values as coloured node markers.
- Export publication-ready figures as **SVG** or high-resolution **PNG**.
- Export the edited tree as **Newick** or the full project as **JSON**.
- Generate shareable links that encode the tree and visual state in the URL.

## 3. Repository structure

A clean GitHub repository for Phyli can use this structure:

```text
.
├── index.html
├── README.md
├── LICENSE.md
├── CITATION.cff
├── .nojekyll
├── assets/
│   ├── screenshot-home.png
│   ├── screenshot-radial.png
│   ├── screenshot-export.png
│   └── flags/
│       ├── cl.svg
│       ├── gb.svg
│       └── br.svg
└── examples/
    ├── simple.nwk
    ├── vertebrates.nwk
    └── tree-of-life.nwk
```

### Required files

| File or folder | Purpose |
|---|---|
| `index.html` | Main application. It contains the interface, styles, and JavaScript logic. |
| `examples/` | Example Newick trees loaded from the interface. |
| `assets/` | Screenshots and visual assets used by the README or the interface. |
| `README.md` | Technical and user documentation for the GitHub repository. |

### Recommended files

| File | Purpose |
|---|---|
| `LICENSE.md` | Defines how other people may use, modify, and redistribute the software. |
| `CITATION.cff` | Allows GitHub to show a **Cite this repository** button. |
| `.nojekyll` | Prevents GitHub Pages from processing the site with Jekyll. Useful for static apps. |

## 4. Input formats

### 4.1 Newick trees

Phyli reads trees written in Newick notation. Newick uses parentheses to describe nested clades, commas to separate sister branches, colons to represent branch lengths, and a semicolon to close the tree.

Example:

```newick
(Cat:0.3,(Mouse:0.2,Human:0.2)[95]:0.1);
```

Meaning:

| Element | Meaning |
|---|---|
| `(Mouse:0.2,Human:0.2)` | A clade containing Mouse and Human. |
| `:0.2` | Branch length. |
| `[95]` | Support value, such as bootstrap support. |
| `;` | End of the Newick tree. |

### 4.2 JSON projects

Phyli can export and reopen project files in JSON format. A JSON project stores the tree plus visual settings such as layout, colours, collapsed clades, and view state.

Use JSON when you want to continue editing the same visualisation later.

## 5. User manual

### 5.1 Load a tree

You can start in three ways:

1. Drag a `.nwk`, `.tree`, or `.json` file into the upload area.
2. Select one of the built-in examples.
3. Paste or load a remote URL pointing to a Newick or JSON file.

After loading, Phyli shows the number of taxa, nodes, and tree depth in the sidebar.

### 5.2 Search a taxon

Use **Search taxon** to find a tip by name. The viewer highlights the selected taxon and centres the canvas on it. This is useful for large trees where names are difficult to locate manually.

### 5.3 Root the tree

Phyli provides two rooting options:

| Option | Use case |
|---|---|
| Root by species/taxon | Select a tip to use as the reference group or outgroup. |
| Root by midpoint | Place the root at the midpoint between the two most distant tips. |

Rooting changes the tree topology shown in the viewer and is reflected in the exported Newick file.

### 5.4 Choose a layout

| Layout | Description |
|---|---|
| Step | Rectangular tree with right-angle branches. Good for standard publication figures. |
| Curved | Smooth branch transitions. Useful for presentation figures. |
| Straight | Direct diagonal branches between nodes. |
| Radial | Circular or fan-like layout for compact exploration. |
| Radial step | Radial layout with stepped branches. |

### 5.5 Choose the branch scale

| Mode | Description |
|---|---|
| Phylogram | Branch lengths are proportional to evolutionary distance. A scale bar is shown. |
| Cladogram | Branch lengths are ignored. The tree shows topology only. |

### 5.6 Interact with the tree

| Action | Result |
|---|---|
| Mouse wheel | Zoom in or out. |
| Drag canvas | Move the tree view. |
| Hover node or branch | Show contextual information. |
| Click a node | Open node actions such as focus, collapse, or colour clade. |
| Collapse clade | Replace a large clade with a compact triangular marker. |
| Focus clade | Centre the selected clade in the viewer. |

### 5.7 Export and share

| Export option | Recommended use |
|---|---|
| SVG | Vector figure for manuscripts, Illustrator, Inkscape, or further editing. |
| PNG | High-resolution image for slides, reports, and teaching material. |
| Newick | Tree topology and branch lengths as `.nwk`. |
| JSON | Full Phyli project with tree and visual settings. |
| Share link | URL containing the tree and visual state. Useful for sending an interactive view to someone else. |

## 6. Technical manual

### 6.1 Application type

Phyli is a static single-page web application. The main software components are contained in `index.html`:

- HTML structure for the interface.
- CSS styles for the sidebar, canvas, controls, and responsive layout.
- JavaScript logic for parsing, drawing, interaction, rooting, export, and language switching.

### 6.2 Runtime requirements

Phyli only needs a modern web browser. Recommended browsers are current versions of Chrome, Edge, Firefox, or Safari.

No Node.js, Python, R, database, or web framework is required to run the app.

### 6.3 Local execution

You can open `index.html` directly in a browser. For more reliable testing, especially when loading local examples, start a small static server:

```bash
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

### 6.4 GitHub Pages deployment

To publish Phyli with GitHub Pages:

1. Create or open the target GitHub repository.
2. Upload `index.html`, `README.md`, `assets/`, `examples/`, `LICENSE.md`, `CITATION.cff`, and `.nojekyll` to the repository root.
3. Go to **Settings → Pages**.
4. Select **Deploy from a branch**.
5. Select branch `main` and folder `/root`.
6. Save the configuration.

The application will be available at:

```text
https://YOUR_USER.github.io/YOUR_REPOSITORY/
```

If Phyli is stored inside a subfolder such as `Phyli/` in another repository, the URL will be:

```text
https://YOUR_USER.github.io/YOUR_REPOSITORY/Phyli/
```

## 7. Credits

Phyli recognises the original work and the current web reconstruction by:

- Rodrigo Mardones Aguilar
- Manuel Villalobos Cid
- Eduardo Kessi-Pérez

The application is associated with the Department of Computer Engineering, Faculty of Engineering, Universidad de Santiago de Chile.

---

# Español

## 1. Descripción general

**Phyli** es una aplicación web autónoma para cargar, visualizar, editar, enraizar, explorar y exportar árboles filogenéticos. Está pensada para docencia, apoyo a investigación e inspección rápida de árboles en formato **Newick**.

La aplicación funciona completamente en el navegador. No requiere backend, base de datos, cuenta de usuario, instalación ni procesamiento del lado del servidor. Basta con un servidor web estático para publicarla.

**Despliegue público:**  
<https://mvillalobosc.diinf.usach.cl/Phyli/>

## 2. Funcionalidades principales

- Cargar árboles filogenéticos desde archivos locales o desde una URL.
- Leer árboles en formato **Newick** y proyectos en formato **JSON**.
- Explorar ejemplos integrados, como vertebrados, un árbol simple y un árbol de la vida.
- Cambiar la interfaz entre **español**, **inglés** y **portugués**.
- Visualizar árboles con trazado escalonado, curvo, recto, radial o radial escalonado.
- Usar modo filograma cuando los largos de rama representan distancia evolutiva.
- Usar modo cladograma cuando se quiere mostrar solo la topología.
- Enraizar árboles por una especie/taxón seleccionado o por midpoint.
- Buscar taxones y centrar la vista en una punta seleccionada.
- Colapsar, enfocar y colorear clados.
- Mostrar valores de soporte interno como marcadores de color en los nodos.
- Exportar figuras listas para publicación como **SVG** o **PNG** de alta resolución.
- Exportar el árbol editado como **Newick** o el proyecto completo como **JSON**.
- Generar enlaces compartibles que codifican el árbol y el estado visual en la URL.

## 3. Estructura del repositorio

Una estructura limpia para publicar Phyli en GitHub puede ser:

```text
.
├── index.html
├── README.md
├── LICENSE.md
├── CITATION.cff
├── .nojekyll
├── assets/
│   ├── screenshot-home.png
│   ├── screenshot-radial.png
│   ├── screenshot-export.png
│   └── flags/
│       ├── cl.svg
│       ├── gb.svg
│       └── br.svg
└── examples/
    ├── simple.nwk
    ├── vertebrates.nwk
    └── tree-of-life.nwk
```

### Archivos necesarios

| Archivo o carpeta | Propósito |
|---|---|
| `index.html` | Aplicación principal. Contiene la interfaz, los estilos y la lógica JavaScript. |
| `examples/` | Árboles Newick de ejemplo cargados desde la interfaz. |
| `assets/` | Capturas e imágenes usadas por el README o por la interfaz. |
| `README.md` | Documentación técnica y de uso del repositorio. |

### Archivos recomendados

| Archivo | Propósito |
|---|---|
| `LICENSE.md` | Define cómo otras personas pueden usar, modificar y redistribuir el software. |
| `CITATION.cff` | Permite que GitHub muestre el botón **Cite this repository**. |
| `.nojekyll` | Evita que GitHub Pages procese el sitio con Jekyll. Es útil para apps estáticas. |

## 4. Formatos de entrada

### 4.1 Árboles Newick

Phyli lee árboles escritos en notación Newick. Newick usa paréntesis para describir clados anidados, comas para separar ramas hermanas, dos puntos para representar largos de rama y punto y coma para cerrar el árbol.

Ejemplo:

```newick
(Gato:0.3,(Ratón:0.2,Humano:0.2)[95]:0.1);
```

Significado:

| Elemento | Significado |
|---|---|
| `(Ratón:0.2,Humano:0.2)` | Clado que contiene Ratón y Humano. |
| `:0.2` | Largo de rama. |
| `[95]` | Valor de soporte, por ejemplo bootstrap. |
| `;` | Fin del árbol Newick. |

### 4.2 Proyectos JSON

Phyli puede exportar y reabrir proyectos en formato JSON. Un proyecto JSON guarda el árbol junto con la configuración visual, como trazado, colores, clados colapsados y estado de la vista.

Usa JSON cuando quieras continuar editando la misma visualización más adelante.

## 5. Manual de uso

### 5.1 Cargar un árbol

Puedes comenzar de tres maneras:

1. Arrastrando un archivo `.nwk`, `.tree` o `.json` al área de carga.
2. Seleccionando uno de los ejemplos integrados.
3. Pegando o cargando una URL remota que apunte a un archivo Newick o JSON.

Después de cargar, Phyli muestra el número de taxones, nodos y profundidad del árbol en el panel lateral.

### 5.2 Buscar un taxón

Usa **Buscar taxón** para encontrar una punta por nombre. El visor resalta el taxón seleccionado y centra el lienzo sobre él. Esto ayuda en árboles grandes donde los nombres son difíciles de ubicar manualmente.

### 5.3 Enraizar el árbol

Phyli ofrece dos opciones de enraizamiento:

| Opción | Uso recomendado |
|---|---|
| Enraizar por especie/taxón | Selecciona una punta para usarla como referencia o grupo externo. |
| Enraizar por midpoint | Ubica la raíz en el punto medio entre las dos puntas más distantes. |

El enraizamiento cambia la topología mostrada en el visor y queda reflejado en el archivo Newick exportado.

### 5.4 Elegir un trazado

| Trazado | Descripción |
|---|---|
| Escalón | Árbol rectangular con ramas en ángulo recto. Útil para figuras estándar. |
| Curvo | Transiciones suaves entre ramas. Útil para presentaciones. |
| Recto | Ramas diagonales directas entre nodos. |
| Radial | Distribución circular o en abanico para exploración compacta. |
| Radial escalonado | Trazado radial con ramas escalonadas. |

### 5.5 Elegir la escala de ramas

| Modo | Descripción |
|---|---|
| Filograma | Los largos de rama son proporcionales a la distancia evolutiva. Se muestra una barra de escala. |
| Cladograma | Ignora los largos de rama. Muestra solo la topología. |

### 5.6 Interactuar con el árbol

| Acción | Resultado |
|---|---|
| Rueda del mouse | Acercar o alejar. |
| Arrastrar el lienzo | Mover la vista del árbol. |
| Pasar el cursor sobre nodos o ramas | Mostrar información contextual. |
| Hacer clic en un nodo | Abrir acciones como enfocar, colapsar o colorear clado. |
| Colapsar clado | Reemplazar un clado grande por un marcador triangular compacto. |
| Enfocar clado | Centrar el clado seleccionado en el visor. |

### 5.7 Exportar y compartir

| Opción de exportación | Uso recomendado |
|---|---|
| SVG | Figura vectorial para manuscritos, Illustrator, Inkscape o edición posterior. |
| PNG | Imagen de alta resolución para diapositivas, informes y material docente. |
| Newick | Topología y largos de rama como archivo `.nwk`. |
| JSON | Proyecto completo de Phyli con árbol y configuración visual. |
| Enlace compartible | URL que contiene el árbol y el estado visual. Útil para enviar una vista interactiva a otra persona. |

## 6. Manual técnico

### 6.1 Tipo de aplicación

Phyli es una aplicación web estática de una sola página. Los componentes principales del software están contenidos en `index.html`:

- Estructura HTML para la interfaz.
- Estilos CSS para el panel lateral, lienzo, controles y diseño responsivo.
- Lógica JavaScript para parseo, dibujo, interacción, enraizamiento, exportación y cambio de idioma.

### 6.2 Requisitos de ejecución

Phyli solo necesita un navegador web moderno. Se recomiendan versiones actuales de Chrome, Edge, Firefox o Safari.

No se requiere Node.js, Python, R, base de datos ni framework web para ejecutar la aplicación.

### 6.3 Ejecución local

Puedes abrir `index.html` directamente en el navegador. Para pruebas más confiables, especialmente al cargar ejemplos locales, inicia un servidor estático pequeño:

```bash
python -m http.server 8000
```

Luego abre:

```text
http://localhost:8000/
```

### 6.4 Publicación con GitHub Pages

Para publicar Phyli con GitHub Pages:

1. Crea o abre el repositorio de GitHub.
2. Sube `index.html`, `README.md`, `assets/`, `examples/`, `LICENSE.md`, `CITATION.cff` y `.nojekyll` a la raíz del repositorio.
3. Entra a **Settings → Pages**.
4. Selecciona **Deploy from a branch**.
5. Selecciona la rama `main` y la carpeta `/root`.
6. Guarda la configuración.

La aplicación quedará disponible en:

```text
https://TU_USUARIO.github.io/TU_REPOSITORIO/
```

Si Phyli está dentro de una subcarpeta como `Phyli/` en otro repositorio, la URL será:

```text
https://TU_USUARIO.github.io/TU_REPOSITORIO/Phyli/
```

## 7. Créditos

Phyli reconoce el trabajo original y la reconstrucción web actual de:

- Rodrigo Mardones Aguilar
- Manuel Villalobos Cid
- Eduardo Kessi-Pérez

La aplicación se asocia al Departamento de Ingeniería Informática, Facultad de Ingeniería, Universidad de Santiago de Chile.

---

## Citation / Citación

If you use Phyli in teaching, research, or software development, cite the original work and this web reconstruction.

Si usas Phyli en docencia, investigación o desarrollo de software, cita el trabajo original y esta reconstrucción web.

```text
Mardones Aguilar, R. I. N., Villalobos Cid, M. J., & Universidad de Santiago de Chile. Facultad de Ingeniería. Departamento de Ingeniería Informática. (2006). Desarrollo de aplicación en línea para la interacción y visualización de árboles filogenéticos. Universidad de Santiago de Chile.
```

For GitHub, keep `CITATION.cff` in the repository so users can copy a citation directly from the **Cite this repository** button.

Para GitHub, conserva `CITATION.cff` en el repositorio para que las personas puedan copiar la cita desde el botón **Cite this repository**.

## Licence / Licencia

The base project follows **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. Keep attribution to the original authors and share derivative versions under compatible terms.

El proyecto base sigue **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. Mantén la atribución a los autores originales y comparte versiones derivadas bajo términos compatibles.

## Contact / Contacto

- Manuel Villalobos Cid — `manuel.villalobos@usach.cl`
- Rodrigo Mardones Aguilar — `rodrigo.mardones.a@usach.cl`
- Eduardo Kessi-Pérez
