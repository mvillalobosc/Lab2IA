#!/usr/bin/env python3
"""Sella APP_VERSION en todas las referencias cacheables del proyecto.

Poner ?v=NN sólo en el <script> de entrada no sirve: los `import` de un módulo ES se
resuelven como URLs propias y, sin query, el navegador los sirve desde la caché. El
resultado es un app.js nuevo conviviendo con un animation.js viejo, que es exactamente
como aparece "animator.setLanguage is not a function".

Este script reescribe, con la versión que declara js/config.js:
  - los especificadores de import relativos entre módulos
  - las referencias a css/js/assets en los HTML

Todos los módulos quedan con la MISMA query, así que cada uno se instancia una sola vez.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_RE = re.compile(r'APP_VERSION\s*=\s*"([^"]+)"')
# from "./algo.js"  |  from "./algo.js?v=12"
IMPORT_RE = re.compile(r'(from\s+")(\.{1,2}/[^"?]+\.js)(\?v=[^"]*)?(")')
HTML_RE = re.compile(r'((?:href|src)=")([^"?]+\.(?:js|css))(\?v=[^"]*)?(")')
BUILD_RE = re.compile(r'(const BUILD = ")([^"]*)(";)')


def read_version() -> str:
    match = VERSION_RE.search((ROOT / "js" / "config.js").read_text(encoding="utf-8"))
    if not match:
        raise SystemExit("No se encontró APP_VERSION en js/config.js")
    return match.group(1)


def stamp(path: Path, pattern: re.Pattern, version: str) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = pattern.sub(lambda m: f"{m.group(1)}{m.group(2)}?v={version}{m.group(4)}", original)
    if updated == original:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


# Globales del lenguaje y del navegador: no se importan y no son un error.
GLOBALES = {
    "JSON", "URL", "NaN", "Infinity", "Math", "Number", "Object", "Array", "String", "Boolean",
    "Promise", "Map", "Set", "Date", "RegExp", "Error", "Blob", "Image", "ImageData", "Uint8Array",
    "Int32Array", "Float32Array", "AudioContext", "SpeechSynthesisUtterance", "FileReader",
    "DOMParser", "TextEncoder", "TextDecoder", "AbortController",
    # funciones globales
    "fetch", "structuredClone", "requestAnimationFrame", "cancelAnimationFrame",
    "setTimeout", "clearTimeout", "setInterval", "clearInterval", "isNaN", "isFinite",
    "parseInt", "parseFloat", "encodeURIComponent", "decodeURIComponent", "atob", "btoa",
    "alert", "confirm", "prompt", "queueMicrotask", "reportError",
}


def check_undefined():
    """Símbolos en MAYÚSCULA usados pero no importados ni declarados.

    El cruce de imports sólo verifica que lo importado exista. No pilla lo contrario: usar
    algo que nunca se importó. Pasó de verdad — `HABITAT_LABEL` se usaba en facts.js sin
    importar, y sólo reventaba al ejecutar esa rama, no al cargar el módulo.
    """
    import sys

    problemas = []
    for path in sorted((ROOT / "js").rglob("*.js")):
        if "vendor" in path.parts:
            continue
        texto = path.read_text(encoding="utf-8")
        importados = set()
        for m in re.finditer(r"import \{([^}]+)\} from", texto):
            importados |= {x.strip().split(" as ")[-1] for x in m.group(1).split(",") if x.strip()}
        declarados = set(re.findall(r"(?:const|let|var|function|class)\s+(\w+)", texto))

        codigo = re.sub(r"^import[\s\S]*?;$", "", texto, flags=re.M)
        codigo = re.sub(r"/\*[\s\S]*?\*/", "", codigo)          # bloques de comentario
        codigo = re.sub(r"//.*$", "", codigo, flags=re.M)         # comentarios de línea
        codigo = re.sub(r'"[^"\n]*"', '""', codigo)              # cadenas dobles
        codigo = re.sub(r"'[^'\n]*'", "''", codigo)              # cadenas simples
        codigo = re.sub(r"`[^`]*`", "``", codigo)                 # plantillas
        codigo = re.sub(r"\.\s*[A-Za-z_]\w*", ".x", codigo)       # accesos a propiedad
        codigo = re.sub(r"(\w+)\s*:", "x:", codigo)               # claves de objeto

        # Sólo CONSTANTES en mayúsculas, y es a propósito.
        #
        # Se intentó extenderlo a funciones llamadas sin importar —el caso de `idIsValid`
        # copiada a otro módulo, que reventó la portada entera y sólo se veía al ejecutar esa
        # rama—. No se puede: distinguir una función importada de un parámetro, un método o una
        # variable local exige un analizador de ALCANCE, y hacerlo con expresiones regulares da
        # falsos positivos en `resolve`, `fn`, `play`... Un linter que grita en falso se ignora,
        # y entonces no sirve para nada.
        #
        # Lo que cubre esto: las CONSTANTES, que son el 90% de lo que se comparte entre módulos
        # y donde de verdad se cometió el error (HABITAT_LABEL, DISPLAY). Para el resto está
        # el arnés: si una rama no se ejecuta en ninguna prueba, ningún linter la va a salvar.
        for nombre in sorted(set(re.findall(r"\b([A-Z][A-Z0-9_]{2,})\b", codigo))):
            if nombre in importados or nombre in declarados or nombre in GLOBALES:
                continue
            problemas.append(f"{path.relative_to(ROOT)}: usa {nombre} sin importar ni declarar")

    if problemas:
        for p in problemas:
            print(f"  ERROR {p}", file=sys.stderr)
        raise SystemExit(1)
    print("Verificado: ningún símbolo en mayúscula usado sin importar")


def main() -> None:
    version = read_version()
    touched = []
    for path in sorted((ROOT / "js").rglob("*.js")):
        if "vendor" in path.parts:
            continue
        if stamp(path, IMPORT_RE, version):
            touched.append(path.relative_to(ROOT))
    # BUILD queda escrito literalmente en app.js. Si el navegador sirve un app.js nuevo
    # con un config.js de su caché, BUILD y APP_VERSION difieren y la app lo grita en vez
    # de comportarse raro en silencio.
    app = ROOT / "js" / "app.js"
    text = app.read_text(encoding="utf-8")
    updated = BUILD_RE.sub(lambda m: f"{m.group(1)}{version}{m.group(3)}", text)
    if updated != text:
        app.write_text(updated, encoding="utf-8")
        touched.append(app.relative_to(ROOT))

    # Se descubren solos. La lista estaba clavada a mano y textos.html quedó fuera al
    # reemplazar al editor viejo: nunca se sellaba, así que arrastraba la caché del navegador
    # justo como pasó en la v32.
    htmls = sorted(ROOT.glob("*.html"))
    if not htmls:
        raise SystemExit("No se encontró ningún HTML en la raíz del proyecto")
    for path in htmls:
        if stamp(path, HTML_RE, version):
            touched.append(path.relative_to(ROOT))

    print(f"Versión sellada: {version}")
    for item in touched:
        print(f"  actualizado {item}")
    if not touched:
        print("  (ya estaba todo sellado)")

    # Verificación: no puede quedar ningún import relativo sin sellar, ni dos versiones.
    found = set()
    problems = []
    for path in sorted((ROOT / "js").rglob("*.js")):
        if "vendor" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r'from\s+"(\.{1,2}/[^"]+)"', text):
            spec = match.group(1)
            query = re.search(r"\?v=(.+)$", spec)
            if not query:
                problems.append(f"{path.relative_to(ROOT)}: import sin sellar -> {spec}")
            else:
                found.add(query.group(1))
    if len(found) > 1:
        problems.append(f"conviven varias versiones en los imports: {sorted(found)}")
    if problems:
        for problem in problems:
            print(f"  ERROR {problem}", file=sys.stderr)
        raise SystemExit(1)
    print(f"Verificado: todos los imports sellados con ?v={version}")
    check_undefined()


if __name__ == "__main__":
    main()


