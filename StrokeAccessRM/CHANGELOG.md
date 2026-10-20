# Changelog

[Español](#español) · [English](#english)

## Español

Este archivo registra los cambios relevantes de StrokeAccessRM. El formato sigue [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) y el proyecto usa versionado semántico.

### [Sin publicar]

#### Cambiado

- La documentación tiene ahora un README bilingüe en cada carpeta (`assets/`, `data/`, `lib/` y `scripts/`).
- La documentación dejó de mencionar flujos de GitHub Actions, plantillas de GitHub y archivos `.gitignore` o `.nojekyll` dentro de esta carpeta, porque no forman parte de ella. La entrada 1.0.0 se corrigió por el mismo motivo.

### [1.0.0] - 2026-07-13

#### Agregado

- Visor estático en Leaflet para 2.371 zonas censales de la Región Metropolitana de Santiago.
- Indicadores de FONASA A/B, diabetes, hipertensión, adulto mayor, tiempo de viaje y clustering.
- Selección de comunas y resúmenes agregados para 52 comunas.
- Red asistencial con 113 hospitales, clínicas e institutos.
- Resaltado de 21 hospitales asociados a la atención de ACV isquémico en los registros GRD analizados.
- Isócronas de tiempo de viaje de 10 a 60 minutos.
- Búsqueda de direcciones, geolocalización del navegador, consultas de punto en polígono y cálculo del establecimiento más cercano.
- Interfaz en español, inglés y portugués.
- Copias locales de Leaflet y Leaflet.markercluster.
- Script de validación de datos (`scripts/validate-data.mjs`), capturas de pantalla y documentación bilingüe.

## English

This file records the notable changes to StrokeAccessRM. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses semantic versioning.

### [Unreleased]

#### Changed

- The documentation now has a bilingual README in each folder (`assets/`, `data/`, `lib/` and `scripts/`).
- The documentation no longer mentions GitHub Actions workflows, GitHub templates or `.gitignore` and `.nojekyll` files inside this folder, because they are not part of it. The 1.0.0 entry was corrected for the same reason.

### [1.0.0] - 2026-07-13

#### Added

- Static Leaflet viewer for 2,371 census zones in the Santiago Metropolitan Region.
- FONASA A/B, diabetes, hypertension, older-adult, travel-time, and clustering indicators.
- Municipality selection and aggregated summaries for 52 municipalities.
- Healthcare network with 113 hospitals, clinics, and institutes.
- Highlighting of 21 hospitals associated with ischaemic stroke care in the analysed DRG records.
- Travel-time isochrones from 10 to 60 minutes.
- Address search, browser geolocation, point-in-polygon queries, and nearest-facility calculations.
- Spanish, English, and Portuguese interface.
- Local copies of Leaflet and Leaflet.markercluster.
- Data validation script (`scripts/validate-data.mjs`), screenshots, and bilingual documentation.
