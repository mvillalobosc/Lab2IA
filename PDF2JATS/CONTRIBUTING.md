# Contribuir · Contributing

[Español](#español) · [English](#english)

## Español

Las contribuciones deben mantener el objetivo editorial de PDF2JATS: facilitar la corrección humana sin ocultar la incertidumbre de la extracción automática.

### Antes de proponer cambios

1. Mantén separadas la extracción automática y la confirmación editorial.
2. No conviertas datos inferidos en datos confirmados sin una regla verificable.
3. Los enlaces normativos deben concentrarse en la sección **Ayuda** de la interfaz.
4. Evita añadir dependencias si la misma función puede resolverse con la biblioteca estándar o las dependencias existentes.
5. Verifica que la interfaz siga siendo utilizable en escritorio y móvil.

### Validación mínima

```bash
python -m py_compile app.py core/*.py emisores/*.py
```

Esta validación deja carpetas `__pycache__` junto a los módulos; el `.gitignore` de la raíz del repositorio las ignora.

Si modificas `web/index.html`, revisa además que la carga múltiple, las pestañas, las marcas `? → ✓`, el panel Ayuda y la descarga XML continúen funcionando. Para probarlo, corre `python3 app.py` y abre `http://127.0.0.1:5000`.

## English

Contributions must keep the editorial goal of PDF2JATS: make human correction easier without hiding the uncertainty of the automatic extraction.

### Before proposing changes

1. Keep automatic extraction and editorial confirmation separate.
2. Do not turn inferred values into confirmed values without a verifiable rule.
3. Links to the standards must stay in the **Ayuda** (help) section of the interface.
4. Avoid adding dependencies when the standard library or the existing dependencies can do the same job.
5. Check that the interface stays usable on desktop and mobile.

### Minimum check

```bash
python -m py_compile app.py core/*.py emisores/*.py
```

This check leaves `__pycache__` folders next to the modules; the `.gitignore` at the root of the repository ignores them.

If you change `web/index.html`, also check that the multiple upload, the tabs, the `? → ✓` marks, the help panel and the XML download still work. To test it, run `python3 app.py` and open `http://127.0.0.1:5000`.
