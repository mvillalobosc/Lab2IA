# Contributing to StrokeAccessRM

Thank you for contributing to StrokeAccessRM.

## Development workflow

1. Fork the repository and create a branch from `main`.
2. Run a local static server:

   ```bash
   python -m http.server 8000
   ```

3. Open `http://localhost:8000/`.
4. Make focused changes and preserve the existing data schema.
5. Run the validation script:

   ```bash
   node scripts/validate-data.mjs
   ```

6. Test the three interface languages, all indicators, municipality summaries, facilities, isochrones, and point queries.
7. Update screenshots and documentation when the interface or data structure changes.
8. Open a pull request describing the change and the tests performed.

## Code style

- Keep the application dependency-light and suitable for static hosting.
- Use relative paths for repository assets.
- Preserve the `window.DATA_*` data-loading convention unless the migration is documented.
- Add translations to Spanish, English, and Portuguese when adding visible interface text.
- Avoid committing personal, confidential, or individual-level health data.

## Data contributions

Public contributions should use aggregated or appropriately anonymised data. Document the source, year, geographic resolution, processing steps, licence, and known limitations.

## Reporting problems

Use the GitHub issue templates for bugs and feature requests. Do not include private health information, precise personal locations, access tokens, or credentials in an issue.
