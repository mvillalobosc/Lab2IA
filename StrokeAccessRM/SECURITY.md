# Security Policy

[Español](#español) · [English](#english)

## Español

### Versión con soporte

La última versión de la rama `main` recibe las actualizaciones de seguridad y mantenimiento.

### Reportar una vulnerabilidad

Reporta los problemas de seguridad en forma privada a:

- Manuel Villalobos Cid: manuel.villalobos.c@usach.cl

Incluye una descripción clara, los archivos o funciones afectados, los pasos para reproducir el problema y su posible impacto. No publiques detalles sensibles en un issue público antes de que los mantenedores revisen el reporte.

### Alcance

StrokeAccessRM es una aplicación estática que corre en el navegador. Los temas de seguridad relevantes son:

- cambios inseguros en las direcciones de servicios remotos;
- cross-site scripting a través de datos nuevos no confiables;
- publicación accidental de datos de salud personales o confidenciales;
- credenciales o claves de API expuestas;
- vulnerabilidades en las bibliotecas de terceros incluidas.

El repositorio no debe contener secretos ni registros clínicos individuales.

## English

### Supported version

The latest version on the `main` branch receives security and maintenance updates.

### Reporting a vulnerability

Please report security issues privately to:

- Manuel Villalobos Cid: manuel.villalobos.c@usach.cl

Include a clear description, affected files or functions, reproduction steps, and the potential impact. Do not disclose sensitive details in a public issue before the maintainers have reviewed the report.

### Scope

StrokeAccessRM is a static client-side application. Relevant security concerns include:

- unsafe changes to remote service URLs;
- cross-site scripting through newly introduced untrusted data;
- accidental publication of personal or confidential health data;
- exposed credentials or API keys;
- dependency vulnerabilities in bundled third-party libraries.

The repository should not contain secrets or individual-level clinical records.
