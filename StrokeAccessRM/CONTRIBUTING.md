# Contributing to StrokeAccessRM

[Español](#español) · [English](#english)

## Español

Gracias por contribuir a StrokeAccessRM.

### Flujo de desarrollo

1. Haz un fork del repositorio y crea una rama desde `main`.
2. Levanta un servidor estático local desde la carpeta `StrokeAccessRM/`:

   ```bash
   python -m http.server 8000
   ```

3. Abre `http://localhost:8000/`.
4. Haz cambios acotados y conserva el esquema de datos existente.
5. Corre el script de validación, que necesita Node.js 20.11 o superior:

   ```bash
   node scripts/validate-data.mjs
   ```

6. Prueba los tres idiomas de la interfaz, todos los indicadores, los resúmenes comunales, los establecimientos, las isócronas y las consultas de puntos.
7. Actualiza las capturas y la documentación cuando cambie la interfaz o la estructura de los datos.
8. Abre un pull request que describa el cambio y las pruebas que hiciste.

### Estilo de código

- Mantén la aplicación con pocas dependencias y apta para hosting estático.
- Usa rutas relativas para los recursos del repositorio.
- Conserva la convención de carga de datos `window.DATA_*`, salvo que documentes la migración.
- Agrega las traducciones al español, inglés y portugués cuando sumes texto visible en la interfaz.
- No subas datos personales, confidenciales ni datos de salud a nivel individual.

### Contribuciones de datos

Las contribuciones públicas deben usar datos agregados o anonimizados de forma adecuada. Documenta la fuente, el año, la resolución geográfica, los pasos de procesamiento, la licencia y las limitaciones conocidas.

### Reportar problemas

Abre un issue en GitHub para informar errores o proponer funciones; el repositorio no tiene plantillas de issues. No incluyas en un issue información de salud privada, ubicaciones personales precisas, tokens de acceso ni credenciales.

## English

Thank you for contributing to StrokeAccessRM.

### Development workflow

1. Fork the repository and create a branch from `main`.
2. Run a local static server from the `StrokeAccessRM/` folder:

   ```bash
   python -m http.server 8000
   ```

3. Open `http://localhost:8000/`.
4. Make focused changes and preserve the existing data schema.
5. Run the validation script, which needs Node.js 20.11 or newer:

   ```bash
   node scripts/validate-data.mjs
   ```

6. Test the three interface languages, all indicators, municipality summaries, facilities, isochrones, and point queries.
7. Update screenshots and documentation when the interface or data structure changes.
8. Open a pull request describing the change and the tests performed.

### Code style

- Keep the application dependency-light and suitable for static hosting.
- Use relative paths for repository assets.
- Preserve the `window.DATA_*` data-loading convention unless the migration is documented.
- Add translations to Spanish, English, and Portuguese when adding visible interface text.
- Avoid committing personal, confidential, or individual-level health data.

### Data contributions

Public contributions should use aggregated or appropriately anonymised data. Document the source, year, geographic resolution, processing steps, licence, and known limitations.

### Reporting problems

Open a GitHub issue to report bugs or request features; the repository has no issue templates. Do not include private health information, precise personal locations, access tokens, or credentials in an issue.
