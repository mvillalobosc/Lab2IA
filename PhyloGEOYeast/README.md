# PhyloGEOYeast

Interactive explorer of the phylogeographic analyses of *Saccharomyces eubayanus* and *S. cerevisiae*. The app brings together geographic sampling, genetic diversity and structure, admixture, trees, and checks used to evaluate origin inference.

The interface is available in Spanish, English, and Portuguese. It is a static web app: the repository currently contains a single self-contained `index.html` with the interface, bundled analysis results, and its JavaScript libraries.

## Run locally

No package installation or build step is required.

1. Clone or download this repository.
2. From the repository directory, start a local web server:

   ```bash
   python3 -m http.server 8000
   ```

3. Open <http://localhost:8000> in a modern browser.

You can also open `index.html` directly in a browser. A local server is recommended for consistent browser behavior. Internet access is needed to load the OpenStreetMap basemap; the app and its analysis results are bundled in the HTML file.

## Publish with GitHub Pages

1. Push `index.html` and this `README.md` to the repository's default branch.
2. In the repository settings, open **Pages**.
3. Select deployment from a branch, choose the default branch and the repository root, and save.
4. Open the Pages URL shown by GitHub.

The entry point must remain named `index.html` in the published directory.

## Explore the app

- Choose a species and analysis scale: locality, locality × lineage, or lineage (the available scales can depend on the species).
- Search for a strain, place, or gene to locate it on the map and in the linked views.
- Explore geographic sampling, diversity, population structure, admixture, genetic distances, trees, and methodological checks.
- Use the help controls in each view for definitions and interpretation.
- Download the JSON data exposed by the app when you need to inspect the displayed data.

## Reading results carefully

The map combines observations and estimates at different geographic resolutions. Some origins are reported only when the validation checks support them. If the evidence does not identify an origin, the app says so; the location of highest observed diversity may appear as a descriptive reference and must not be read as an inferred ancestral location.

A point may represent a locality, region, or country, and some geographic assignments are approximate. Missing origins inferred from a lineage's most frequent location are marked separately and are excluded from calculations. Tree rooting and temporal displays also have stated assumptions; a visual root does not by itself establish direction or calendar dates. Consult the in-app **Method & reproducibility** tab and the explanatory notes before interpreting or reusing a result.

## Data and attribution

The *S. eubayanus* data and analyses in this project were generated and curated by the project team. The *S. cerevisiae* comparison dataset was prepared and analysed by the same team using the team's data associated with the 1,011-isolate study by Peter et al. (2018). The publication remains cited as the source of that study and its underlying resource:

> Peter, J. et al. (2018). Genome evolution across 1,011 *Saccharomyces cerevisiae* isolates. *Nature*, 556(7701), 339–344. <https://doi.org/10.1038/s41586-018-0030-5>

Please cite the associated manuscript and the original references listed in its bibliography when reusing analyses or figures. The app's **Method & reproducibility** tab documents the data processing, analytical procedures, assumptions, and code represented in the interface.

## Repository contents

```text
.
├── index.html   # Self-contained app, bundled data, and client-side code
└── README.md    # Setup, deployment, and interpretation notes
```

## License

No software license is declared here. Add the license selected by the project owners as a separate `LICENSE` file before distributing or reusing the code under license terms.
