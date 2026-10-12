# -*- coding: utf-8 -*-
"""
Empaqueta los CSV de la carpeta data/ dentro de data/data.js para que la app
funcione con doble clic en index.html, sin servidor, sin .bat y sin internet.

Uso:  python regenerar_datos.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
OUT  = os.path.join(DATA, "data.js")

FILES = {
    "MEMORIAS_CSV":  "memorias.csv",
    "ACADEMICOS_CSV": "academicos.csv",
}

def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

with open(OUT, "w", encoding="utf-8") as out:
    out.write("/* Datos empaquetados automáticamente. NO editar a mano.\n")
    out.write("   Edita los CSV en data/ y ejecuta: python regenerar_datos.py */\n")
    for var, fname in FILES.items():
        raw = read(os.path.join(DATA, fname))
        out.write("window.%s = %s;\n" % (var, json.dumps(raw)))

print("OK: data/data.js regenerado (%s)" % ", ".join(FILES.values()))
