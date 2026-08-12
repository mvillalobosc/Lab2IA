"""Utilidades comunes a todos los emisores."""
from xml.sax.saxutils import escape, quoteattr


def esc(t):
    return escape(t or "", {'"': "&quot;"})


def attr(v):
    return quoteattr(v or "")


def tag(nombre, contenido="", cierre=True, **atributos):
    at = "".join(f' {k.replace("_", "-")}={attr(str(v))}' for k, v in atributos.items() if v)
    if contenido == "" and cierre is False:
        return f"<{nombre}{at}/>"
    return f"<{nombre}{at}>{contenido}</{nombre}>"


class Buffer:
    def __init__(self):
        self.lin = []
        self.niv = 0

    def abrir(self, nombre, **at):
        a = "".join(f' {k.replace("_", "-")}={attr(str(v))}' for k, v in at.items() if v)
        self.lin.append("  " * self.niv + f"<{nombre}{a}>")
        self.niv += 1

    def cerrar(self, nombre):
        self.niv = max(0, self.niv - 1)
        self.lin.append("  " * self.niv + f"</{nombre}>")

    def hoja(self, nombre, contenido="", vacio_ok=False, **at):
        if not contenido and not vacio_ok:
            return
        a = "".join(f' {k.replace("_", "-")}={attr(str(v))}' for k, v in at.items() if v)
        if not contenido:
            self.lin.append("  " * self.niv + f"<{nombre}{a}/>")
        else:
            self.lin.append("  " * self.niv + f"<{nombre}{a}>{esc(str(contenido))}</{nombre}>")

    def crudo(self, s):
        self.lin.append("  " * self.niv + s)

    def texto(self):
        return "\n".join(self.lin)
