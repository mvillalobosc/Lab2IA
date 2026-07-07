# Phyli

**Phyli** is a static, browser-based phylogenetic tree viewer for Newick files. It parses tree data directly in the browser, renders the result as SVG, supports rectangular and radial layouts, and exports publication-ready graphics without requiring a backend server.

The current implementation is a self-contained `index.html` application with embedded CSS and JavaScript. It can be published as a GitHub Pages site, hosted on any static web server, or deployed under an Apache subdirectory with optional rewrite support.

![Static app](https://img.shields.io/badge/app-static%20HTML%2FCSS%2FJS-394049)
![Input](https://img.shields.io/badge/input-Newick%20%7C%20JSON-498BCA)
![Renderer](https://img.shields.io/badge/renderer-SVG-EA7600)
![No backend](https://img.shields.io/badge/backend-none-00A499)

## Repository description

> Interactive browser-based phylogenetic tree viewer for Newick files, with SVG rendering, radial and rectangular layouts, clade styling, export tools, and shareable URLs.

Suggested repository name: `Phyli`  
Suggested topics: `phylogenetics`, `newick`, `bioinformatics`, `svg`, `javascript`, `github-pages`, `tree-viewer`

## Demo

After enabling GitHub Pages, the app will be available at:

```text
https://<github-user>.github.io/<repository-name>/
```

For a repository named `Phyli`, the URL would usually be:

```text
https://<github-user>.github.io/Phyli/
```

## Main features

- Load phylogenetic trees from local files (`.nwk`, `.tree`, `.txt`, `.json`).
- Paste a Newick string, a JSON project, or a remote URL directly into the app.
- Open remote Newick or JSON files through HTTP(S), subject to CORS rules.
- Render trees as SVG using rectangular, curved, slanted, radial, and radial-step layouts.
- Switch between phylogram and cladogram views.
- Preserve branch lengths when the Newick file includes them.
- Display internal support values, including bootstrap-like values written as `[95]` or numeric internal labels.
- Search terminal taxa and focus the viewport on matching leaves.
- Collapse or expand clades interactively.
- Apply clade-level colours.
- Adjust branch width, branch colour, node size, node colour, label size, and label colour.
- Toggle guide lines, support markers, and internal clade labels.
- Pan, zoom, fit to screen, and reset the visual state.
- Export the current tree as SVG, PNG, Newick, or a JSON project.
- Create shareable links that encode the tree and, when needed, the visual configuration.

## Screenshots

Add screenshots after the first public deployment:

```text
assets/screenshot-home.png
assets/screenshot-radial.png
assets/screenshot-export.png
```

Suggested Markdown once screenshots are available:

```md
![Phyli home screen](assets/screenshot-home.png)
![Radial tree layout](assets/screenshot-radial.png)
```

## Quick start

Clone or download the repository and open `index.html` in a modern browser:

```bash
git clone https://github.com/<github-user>/Phyli.git
cd Phyli
```

Then open:

```text
index.html
```

No package installation, build step, database, or server-side runtime is required.

## Repository structure

```text
Phyli/
├── index.html              # Complete static application
├── 404.html                # Optional GitHub Pages fallback for path-like shared URLs
├── .htaccess               # Optional Apache rewrite rules for /Phyli/ deployments
├── README.md               # Main technical documentation
├── docs/
│   └── index.md            # GitHub Pages documentation page
└── examples/
    ├── simple.nwk          # Small test tree
    └── vertebrates.nwk     # Example vertebrate tree with branch lengths and support values
```

The ZIP originally used the folder name `Phyli`, while the application interface and page title use `Phyli`. For public release, use one spelling consistently. This documentation uses **Phyli** because that is the name shown in the application.

## Input formats

### Newick

Phyli reads standard Newick-like strings such as:

```newick
(Cat:0.3,(Mouse:0.2,Human:0.2)[95]:0.1);
```

Supported elements include:

| Element | Example | Meaning |
|---|---:|---|
| Parentheses | `(A,B)` | Group descendants into a clade |
| Commas | `A,B` | Separate sister branches |
| Branch length | `A:0.2` | Evolutionary distance or edge length |
| Internal clade name | `(A,B)Mammalia` | Name assigned to an internal node |
| Support value | `(A,B)[95]` | Bootstrap-like support value |
| Numeric internal support | `(A,B)95` | Treated as support and hidden as a label |
| Semicolon | `;` | End of the tree |

### JSON project

The app can reopen exported JSON projects. The internal project format stores the Newick string and the visual state:

```json
{
  "format": "Phyli-project",
  "version": 1,
  "name": "example.nwk",
  "view": {
    "shape": "step",
    "mode": "phylo",
    "aligned": false,
    "ladder": true,
    "angle": 360,
    "leafGap": 24
  },
  "style": {
    "pathW": 1.6,
    "pathC": "#394049",
    "nodeR": 0,
    "nodeC": "#498BCA",
    "labelS": 13,
    "labelC": "#2C3138"
  },
  "show": {
    "guides": true,
    "support": true,
    "internal": false
  },
  "newick": "(A:1,B:1);"
}
```

The app also includes a compatibility path for older JSON objects that store a nested `tree` object.

## URL interface

Phyli can load trees from the browser URL. This is useful for teaching, reproducible examples, and sharing figures.

### Plain Newick in the hash

```text
https://<github-user>.github.io/Phyli/#nwk=(A:1,B:1);
```

### Remote file

```text
https://<github-user>.github.io/Phyli/#src=https://example.org/tree.nwk
```

Remote files must be served through HTTP(S) and must allow browser access through CORS. When using GitHub-hosted tree files, use the raw file URL.

### Compressed project link

When the tree or visual configuration is too large for a readable URL, the app uses an LZ-based compressed payload:

```text
https://<github-user>.github.io/Phyli/#z=<compressed-payload>
```

Users normally do not need to build this URL manually. The **Share link** button creates it automatically.

### Path-style Newick URLs

The Apache deployment supports path-style tree URLs such as:

```text
https://example.org/Phyli/(A:1,B:1);
```

GitHub Pages does not use `.htaccess`, so hash-based URLs are the safest option there. This package includes `404.html` as an optional fallback for path-like URLs, but public links should prefer `#nwk=...` or `#z=...` for predictable behaviour.

## User workflow

1. Open the app.
2. Load a tree from a local Newick file, paste a Newick string, paste a JSON project, or use one of the embedded examples.
3. Choose a visual layout: step, curved, slanted, radial, or radial-step.
4. Select phylogram mode when branch lengths should control horizontal or radial distance.
5. Select cladogram mode when only topology should define the view.
6. Search taxa, collapse clades, colour clades, and adjust the visual style.
7. Export the result as SVG or PNG for figures, or export Newick/JSON for reuse.
8. Use **Share link** to create a URL that rebuilds the same tree in another browser.

## Technical architecture

Phyli is organised around a simple client-side pipeline:

```text
Input file / URL / pasted text
        ↓
Newick or JSON detection
        ↓
Newick parser
        ↓
Node enrichment: branch length, support, IDs
        ↓
Tree annotation: depth, cumulative distance, leaf count, max distance
        ↓
Layout computation: rectangular or radial coordinates
        ↓
SVG rendering
        ↓
Viewport interaction: pan, zoom, focus, export, share
```

### Main state object

The application keeps its state in a single JavaScript object named `S`. It stores:

- the current tree root;
- tree metadata, such as name, title, and description;
- layout mode and shape;
- radial angle and leaf spacing;
- visual style settings;
- visible layers, such as support markers and guide lines;
- viewport transform;
- collapsed clades;
- clade colours;
- highlighted or selected nodes;
- computed statistics and layout information.

### Parser

The parser tokenises Newick text using parentheses, commas, colons, and semicolons. It creates a nested JavaScript tree, then enriches each node with:

- `id`: internal node identifier;
- `name`: terminal or internal label;
- `len`: branch length;
- `support`: support value, when present;
- `children`: descendant nodes.

### Annotation

The annotation step computes values used by layout and interaction:

- number of leaves;
- number of nodes;
- topological depth;
- cumulative branch distance;
- maximum branch distance;
- descendant leaf counts;
- maximum descendant depth and distance.

### Layout engine

The layout engine first assigns an across-axis position to each terminal node. Collapsed clades occupy a compact span based on the square root of their leaf count. The depth axis is then computed in one of two ways:

- **Phylogram**: branch lengths define distance, when branch lengths are present.
- **Cladogram**: topological depth defines distance.

Radial layouts map those rectangular coordinates into polar coordinates.

### Renderer

The renderer builds a new SVG group each time the tree is redrawn. It draws layers in this order:

1. guide lines;
2. branches;
3. collapsed clade wedges;
4. support markers;
5. node markers and hit targets;
6. labels.

The SVG is also used as the basis for SVG and PNG export.

### Interaction model

Phyli uses browser pointer and wheel events for pan, zoom, hover tooltips, and node selection. Internal nodes have invisible hit targets when visible node markers are disabled, so clades remain clickable.

Keyboard shortcuts:

| Shortcut | Action |
|---|---|
| `+` / `=` | Zoom in |
| `-` | Zoom out |
| `F` | Fit tree to viewport |
| `Esc` | Close sheets, popovers, and mobile sidebar |

## Export formats

| Format | Use case | Notes |
|---|---|---|
| SVG | Publication figures, editing in vector tools | Preserves vector paths and text |
| PNG | Slides, quick sharing, image-based documents | Exported at 2× resolution |
| Newick | Reuse in phylogenetic software | Serialises the current tree |
| JSON | Reopen the project in Phyli | Stores Newick plus visual configuration |

## Deployment

### Option A: GitHub Pages

1. Create a repository, for example `Phyli`.
2. Upload the contents of this package to the repository root.
3. Commit the files to the default branch, usually `main`.
4. Go to **Settings → Pages**.
5. Under **Build and deployment**, choose **Deploy from a branch**.
6. Select the default branch and the root folder `/`.
7. Save the configuration.
8. Open the published URL once GitHub finishes the deployment.

Because this app is plain HTML, CSS, and JavaScript, no build workflow is needed.

### Option B: Apache subdirectory

For Apache hosting under `/Phyli/`, place these files in the server directory:

```text
/Phyli/index.html
/Phyli/.htaccess
```

The included `.htaccess` rewrites unknown paths back to `index.html`, which allows URLs where the tree is written directly in the path.

If you deploy under a different path, update:

```apache
RewriteBase /Phyli/
```

For example, if the app is deployed under `/Phyli/`, use:

```apache
RewriteBase /Phyli/
```

### Option C: Any static server

The app can also be served with any static file server:

```bash
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

## Browser compatibility

Phyli uses standard browser APIs:

- SVG;
- FileReader;
- Fetch;
- Canvas export;
- Blob download;
- URL hash parsing;
- Clipboard API when available;
- pointer and wheel events.

A current desktop browser is recommended for large trees.

## Privacy and data handling

Phyli runs in the browser. Local files selected by the user are read by the browser and are not uploaded to a server by this application. Remote URLs are fetched directly by the browser. Share links may encode the tree and visual configuration inside the URL, so do not share those links publicly if the tree data are private.

## Known limitations

- The Newick parser is intentionally lightweight. Labels that contain commas, parentheses, colons, or complex quoting may need to be simplified before loading.
- Very large trees may become slow because the app renders many SVG elements in the browser.
- Remote file loading depends on CORS. If a server blocks cross-origin requests, download the file and load it locally.
- GitHub Pages ignores `.htaccess`; use hash-based links for public GitHub Pages deployments.
- The current app is implemented as one large `index.html`. Future development could split CSS and JavaScript into separate files.

## Development notes

Useful future improvements:

- Split the code into `src/parser.js`, `src/layout.js`, `src/render.js`, and `src/ui.js`.
- Add automated parser tests for Newick edge cases.
- Add a small sample dataset folder.
- Add screenshots and a short video demo.
- Add an explicit open-source license once authorship and reuse conditions are confirmed.
- Add accessibility review for keyboard navigation and colour contrast.
- Add optional support for quoted Newick labels.

## Citation

Current in-app citation:

> Mardones Aguilar, R. I. N., Villalobos Cid, M. J., & Universidad de Santiago de Chile. Facultad de Ingeniería. Departamento de Ingeniería Informática. (2006). *Desarrollo de aplicación en línea para la interacción y visualización de árboles filogenéticos*. Universidad de Santiago de Chile.

Please verify the year, authorship order, and preferred institutional wording before making the repository public.

## Authors

- Rodrigo Mardones Aguilar
- Manuel Villalobos Cid
- Universidad de Santiago de Chile, Facultad de Ingeniería, Departamento de Ingeniería Informática

## License

No license has been selected yet. Before publishing the repository as open source, add a licence file such as `LICENSE` and confirm that all authors agree with the selected reuse terms.

## Acknowledgements

The interface uses the USACH institutional colour palette and includes an embedded LZString implementation for compressed share URLs.
