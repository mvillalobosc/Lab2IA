# Contribuir

Las contribuciones deben mantener el objetivo editorial de PDF2JATS: facilitar la corrección humana sin ocultar la incertidumbre de la extracción automática.

## Antes de proponer cambios

1. Mantén separadas la extracción automática y la confirmación editorial.
2. No conviertas datos inferidos en datos confirmados sin una regla verificable.
3. Los enlaces normativos deben concentrarse en la sección **Ayuda** de la interfaz.
4. Evita añadir dependencias si la misma función puede resolverse con la biblioteca estándar o las dependencias existentes.
5. Verifica que la interfaz siga siendo utilizable en escritorio y móvil.

## Validación mínima

```bash
python -m py_compile app.py core/*.py emisores/*.py
```

Si modificas `web/index.html`, revisa además que la carga múltiple, las pestañas, las marcas `? → ✓`, el panel Ayuda y la descarga XML continúen funcionando.
