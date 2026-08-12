"""Lectura del PDF conservando tamano de fuente, peso y posicion.
La tipografia es la senal mas util para distinguir titulo, autores y encabezados
de seccion. Sin ella la extraccion se vuelve adivinanza sobre texto plano.
"""
import re
import pymupdf


class Linea:
    __slots__ = ("texto", "size", "font", "bold", "italic", "x0", "y0", "x1", "y1", "pagina")

    def __init__(self, texto, size, font, x0, y0, x1, y1, pagina):
        self.texto = texto
        self.size = round(size, 1)
        self.font = font
        f = font.lower()
        self.bold = ("bold" in f or "black" in f or "semibold" in f or "heavy" in f)
        self.italic = ("italic" in f or f.endswith("it") or "oblique" in f)
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.pagina = pagina

    def __repr__(self):
        return f"<L p{self.pagina} {self.size} {'B' if self.bold else ''}{'I' if self.italic else ''} {self.texto[:50]!r}>"


class Documento:
    def __init__(self, ruta):
        self.ruta = ruta
        self.doc = pymupdf.open(ruta)
        self.n_paginas = len(self.doc)
        self.lineas = []
        self._cargar()
        self.texto = "\n".join(l.texto for l in self.lineas)
        from .layout import Maqueta
        self.maqueta = Maqueta(self)
        self.size_cuerpo = self.maqueta.size_cuerpo
        # orden de lectura corregido segun el numero de columnas detectado
        self.lineas = self.maqueta.orden_lectura(self.lineas)

    def utiles(self, hasta_pagina=None):
        """Lineas de contenido: sin cornisas, folios ni pies de revista."""
        m = self.maqueta
        return [l for l in self.lineas
                if not m.es_recurrente(l) and not m.es_folio(l)
                and (hasta_pagina is None or l.pagina < hasta_pagina)]

    def _cargar(self):
        for i, pg in enumerate(self.doc):
            d = pg.get_text("dict", sort=True)
            for b in d["blocks"]:
                if b.get("type") != 0:
                    continue
                for l in b["lines"]:
                    spans = [s for s in l["spans"] if s["text"].strip()]
                    if not spans:
                        continue
                    # algunos PDF (tipico de LaTeX) no codifican el espacio entre
                    # spans: se reconstruye midiendo el hueco horizontal
                    partes = [spans[0]["text"]]
                    for a, b in zip(spans, spans[1:]):
                        hueco = b["bbox"][0] - a["bbox"][2]
                        umbral = max(1.0, b["size"] * 0.12)
                        if hueco > umbral and not partes[-1].endswith(" ") \
                           and not b["text"].startswith(" "):
                            partes.append(" ")
                        partes.append(b["text"])
                    txt = "".join(partes)
                    txt = re.sub(r"[ \t]+", " ", txt).strip()
                    if not txt:
                        continue
                    big = max(spans, key=lambda s: s["size"])
                    bb = l["bbox"]
                    self.lineas.append(Linea(txt, big["size"], big["font"],
                                             bb[0], bb[1], bb[2], bb[3], i))

    def _size_dominante(self):
        """Tamano de fuente del cuerpo del texto: el que acumula mas caracteres."""
        acc = {}
        for l in self.lineas:
            acc[l.size] = acc.get(l.size, 0) + len(l.texto)
        return max(acc, key=acc.get) if acc else 10.0

    def pagina(self, i):
        return [l for l in self.lineas if l.pagina == i]

    def texto_pagina(self, i):
        return "\n".join(l.texto for l in self.pagina(i))

    def texto_paginas(self, ini, fin=None):
        fin = self.n_paginas if fin is None else fin
        return "\n".join(l.texto for l in self.lineas if ini <= l.pagina < fin)

    def close(self):
        self.doc.close()
