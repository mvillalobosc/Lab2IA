# Security Policy

## Supported version

The latest version on the `main` branch receives security and maintenance updates.

## Reporting a vulnerability

Please report security issues privately to:

- Manuel Villalobos Cid: manuel.villalobos.c@usach.cl

Include a clear description, affected files or functions, reproduction steps, and the potential impact. Do not disclose sensitive details in a public issue before the maintainers have reviewed the report.

## Scope

StrokeAccessRM is a static client-side application. Relevant security concerns include:

- unsafe changes to remote service URLs;
- cross-site scripting through newly introduced untrusted data;
- accidental publication of personal or confidential health data;
- exposed credentials or API keys;
- dependency vulnerabilities in bundled third-party libraries.

The current repository should not contain secrets or individual-level clinical records.
