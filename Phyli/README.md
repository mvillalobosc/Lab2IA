# Phyli

**Phyli** is a standalone web application for visualising and interacting with phylogenetic trees in Newick format.

It runs entirely in the browser: no backend, build step, database, or server-side processing is required.

## Features


- Compact accordion-based sidebar to reduce visual clutter.
- Rooting controls by reference taxon or midpoint.
- Trilingual interface: Spanish, English, and Portuguese.

- Inline SVG flag language selector for Spanish, English, and Portuguese.
- Load phylogenetic trees from `.nwk`, `.tree`, `.txt`, or `.json` files.
- Paste a Newick/JSON tree directly into the app.
- Load remote Newick/JSON files by URL when CORS is enabled.
- Explore built-in examples.
- Switch the interface between Spanish, English, and Portuguese using the flag buttons.
- Visualise trees as step, curved, straight, radial, or radial-step layouts.
- Switch between phylogram and cladogram modes.
- Root trees by a selected species/taxon or by midpoint.
- Align tips, ladderise branches, collapse clades, colour clades, and focus nodes.
- Search taxa and centre the view on a selected tip.
- Export figures as SVG or high-resolution PNG.
- Export the tree as Newick or the full project as JSON.
- Generate shareable URLs that encode the tree and view state.

## Live deployment

The current public deployment is available at:

<https://mvillalobosc.diinf.usach.cl/Phyli/>

## Screenshots

Add or replace screenshots in `assets/` after deploying your GitHub Pages version.

```markdown
![Phyli home screen](assets/screenshot-home.png)
![Radial tree layout](assets/screenshot-radial.png)
![Export options](assets/screenshot-export.png)
```

## Repository structure

```text
.
├── index.html
├── README.md
├── LICENSE.md
├── CITATION.cff
├── 404.html
├── .nojekyll
├── examples/
│   ├── simple.nwk
│   ├── vertebrates.nwk
│   └── tree-of-life.nwk
├── assets/
│   ├── screenshot-home.png
│   ├── screenshot-radial.png
│   ├── screenshot-export.png
│   └── flags/
│       ├── cl.svg
│       ├── gb.svg
│       └── br.svg
└── docs/
    └── index.md
```

## Running locally

Because Phyli is static, you can open `index.html` directly in a browser. For URL loading and local testing, a small static server is recommended:

```bash
python -m http.server 8000
```

Then open:

<http://localhost:8000/>

## Publishing with GitHub Pages

1. Create a GitHub repository named `Phyli`.
2. Upload the contents of this folder to the repository root.
3. Go to **Settings → Pages**.
4. Select **Deploy from a branch**.
5. Choose `main` and `/root`.
6. Save.

Your app will be published at:

```text
https://YOUR_USER.github.io/Phyli/
```

## Development credits

Current web version, documentation, and repository preparation:

- Rodrigo Mardones Aguilar
- Manuel Villalobos Cid
- Eduardo Kessi-Pérez

## Citation

If you use Phyli in teaching or research, please cite the original work:

> Mardones Aguilar, R. I. N., Villalobos Cid, M. J., & Universidad de Santiago de Chile. Facultad de Ingeniería. Departamento de Ingeniería Informática. (2006). *Desarrollo de aplicación en línea para la interacción y visualización de árboles filogenéticos*. Universidad de Santiago de Chile.

## Licence

This reconstruction follows the attribution spirit of the original project and is distributed under **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. See `LICENSE.md`.
