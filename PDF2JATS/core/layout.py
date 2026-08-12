"""Analisis de maqueta. Nada de esto asume una revista concreta: todo se infiere
midiendo el propio PDF.

Detecta:
  - encabezados y pies recurrentes (se repiten entre paginas y hay que borrarlos)
  - numero de columnas y sus limites
  - tamano tipografico del cuerpo, de los titulos y de las notas al pie
  - zona de notas al pie
  - si el documento usa sangria francesa o linea en blanco para separar bloques
"""
import re
from collections import Counter, defaultdict


def _firma(texto):
    """Normaliza una linea para detectar repeticion entre paginas: los numeros
    cambian de pagina en pagina, el resto no."""
    t = re.sub(r"\d+", "#", texto.lower())
    return re.sub(r"\s+", " ", t).strip()


class Maqueta:
    def __init__(self, doc):
        self.doc = doc
        self.ancho, self.alto = self._dimensiones()
        self.recurrentes = self._detectar_recurrentes()
        self.size_cuerpo = self._size_cuerpo()
        self.size_nota = self._size_nota()
        self.columnas = self._detectar_columnas()
        self.escala_titulo = self._escala_titulos()

    # ------------------------------------------------------------------
    def _dimensiones(self):
        if not self.doc.lineas:
            return 612.0, 792.0
        return (max(l.x1 for l in self.doc.lineas),
                max(l.y1 for l in self.doc.lineas))

    def _detectar_recurrentes(self):
        """Lineas que reaparecen en muchas paginas siempre a la misma altura.
        Son cornisas, folios y pies de revista, y contaminan cualquier heuristica.
        """
        if self.doc.n_paginas < 3:
            return set()
        vistos = defaultdict(set)
        alturas = defaultdict(list)
        for l in self.doc.lineas:
            f = _firma(l.texto)
            if not f or len(f) > 160:
                continue
            vistos[f].add(l.pagina)
            alturas[f].append(l.y0)
        umbral = max(2, int(self.doc.n_paginas * 0.4))
        out = set()
        for f, pags in vistos.items():
            if len(pags) < umbral:
                continue
            ys = alturas[f]
            # misma posicion vertical en todas las apariciones
            if max(ys) - min(ys) < 12:
                out.add(f)
        return out

    def es_recurrente(self, linea):
        return _firma(linea.texto) in self.recurrentes

    def es_folio(self, linea):
        t = linea.texto.strip()
        if not re.fullmatch(r"[\d\s|/.,;·–—-]{1,14}", t):
            return False
        return linea.y0 < self.alto * 0.12 or linea.y0 > self.alto * 0.88

    # ------------------------------------------------------------------
    def _utiles(self):
        return [l for l in self.doc.lineas
                if not self.es_recurrente(l) and not self.es_folio(l)]

    def _size_cuerpo(self):
        acc = Counter()
        for l in self._utiles():
            if len(l.texto) > 30:
                acc[l.size] += len(l.texto)
        return acc.most_common(1)[0][0] if acc else 10.0

    def _size_nota(self):
        """Las notas al pie usan un tamano menor al cuerpo y aparecen abajo."""
        acc = Counter()
        for l in self._utiles():
            if l.size < self.size_cuerpo - 0.4 and l.y0 > self.alto * 0.72:
                acc[l.size] += len(l.texto)
        if not acc:
            return None
        s, n = acc.most_common(1)[0]
        return s if n > 120 else None

    def es_nota(self, linea):
        """Nota al pie: tamano menor al cuerpo y ubicada en el tramo final de la
        pagina. El umbral es alto a proposito: muchas portadas ponen los datos
        del autor en tamano reducido a media pagina y no son notas.
        """
        return (self.size_nota is not None
                and abs(linea.size - self.size_nota) < 0.35
                and linea.y0 > self.alto * 0.76)

    # ------------------------------------------------------------------
    def _detectar_columnas(self):
        """Agrupa los inicios de linea del cuerpo. Dos modas separadas por mas
        de un tercio del ancho significan doble columna.
        """
        xs = [l.x0 for l in self._utiles()
              if abs(l.size - self.size_cuerpo) < 0.5 and len(l.texto) > 25]
        if len(xs) < 20:
            return [(0, self.ancho)]
        bins = Counter(round(x / 10) * 10 for x in xs)
        modas = [x for x, n in bins.most_common(6) if n >= len(xs) * 0.08]
        modas.sort()
        if not modas:
            return [(0, self.ancho)]
        grupos, actual = [], [modas[0]]
        for a, b in zip(modas, modas[1:]):
            if b - a > self.ancho * 0.25:
                grupos.append(actual)
                actual = []
            actual.append(b)
        grupos.append(actual)
        if len(grupos) < 2:
            return [(0, self.ancho)]
        cols = []
        for i, g in enumerate(grupos):
            ini = min(g) - 5
            fin = (min(grupos[i + 1]) - 5) if i + 1 < len(grupos) else self.ancho
            cols.append((ini, fin))
        return cols

    def columna_de(self, linea):
        for i, (a, b) in enumerate(self.columnas):
            if a <= linea.x0 < b:
                return i
        return 0

    def orden_lectura(self, lineas):
        """En doble columna el orden por y0 mezcla ambas. Se lee columna a
        columna dentro de cada pagina."""
        if len(self.columnas) < 2:
            return sorted(lineas, key=lambda l: (l.pagina, l.y0, l.x0))
        return sorted(lineas, key=lambda l: (l.pagina, self.columna_de(l), l.y0, l.x0))

    # ------------------------------------------------------------------
    def _escala_titulos(self):
        """Tamanos por encima del cuerpo, ordenados. Sirve para decidir niveles
        de encabezado sin fijar numeros a mano."""
        acc = Counter()
        for l in self._utiles():
            if l.size > self.size_cuerpo + 0.3:
                acc[l.size] += 1
        return sorted(acc, reverse=True)

    def nivel_titulo(self, linea):
        """0 es el titulo del articulo, 1 y 2 son secciones."""
        if linea.size <= self.size_cuerpo + 0.3:
            return 3 if linea.bold else None
        for i, s in enumerate(self.escala_titulo):
            if abs(linea.size - s) < 0.35:
                return i
        return None

    def resumen(self):
        return {
            "paginas": self.doc.n_paginas,
            "ancho": round(self.ancho), "alto": round(self.alto),
            "columnas": len(self.columnas),
            "size_cuerpo": self.size_cuerpo,
            "size_nota": self.size_nota,
            "escala_titulo": self.escala_titulo[:5],
            "lineas_recurrentes": len(self.recurrentes),
        }
