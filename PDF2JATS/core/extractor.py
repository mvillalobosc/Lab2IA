"""Une lectura, front matter, cuerpo y referencias en un objeto Articulo."""
import os
import re
from collections import Counter
from .pdf_reader import Documento
from .model import Articulo, Autor, Afiliacion, Referencia, Seccion
from . import front_matter as fm
from . import cuerpo_refs as cr
from . import autoria
from . import doi_metadata
from . import scielo_metadata

# Cache opcional: si una revista ya fue revisada por un editor, su ficha manda
# sobre lo inferido. Empieza vacio a proposito; se llena desde la interfaz.
REVISTAS = {}


def registrar_revista(issn, codigo, titulo, editorial):
    REVISTAS[issn] = (codigo, titulo, editorial)


def extraer(ruta):
    doc = Documento(ruta)
    art = Articulo(archivo=os.path.basename(ruta))
    p1 = doc.texto_pagina(0)
    p12 = doc.texto_paginas(0, min(3, doc.n_paginas))

    art.doi, c_doi = fm.extraer_doi(p12)
    art.confianza["doi"] = c_doi

    art.issn_electronico, art.issn_impreso = fm.extraer_issn(p12)

    art.volumen, art.numero = fm.extraer_volumen_numero(p1)
    art.fpage, art.lpage = fm.extraer_paginas(p1)
    art.mes, art.anio = fm.extraer_mes_anio_portada(p1)

    f = fm.extraer_fechas(p12)
    art.fecha_recibido, art.fecha_aceptado, art.fecha_publicado = (
        f["recibido"], f["aceptado"], f["publicado"])
    if art.fecha_publicado and len(art.fecha_publicado) >= 10:
        art.anio, art.mes, art.dia = art.fecha_publicado.split("-")
    elif not art.anio and art.fecha_aceptado:
        art.anio = art.fecha_aceptado[:4]

    art.titulos, c_tit = fm.extraer_titulos(doc)
    art.confianza["titulo"] = c_tit
    art.idioma = min(art.titulos, key=lambda k: 0) if art.titulos else "es"
    if art.titulos:
        art.idioma = list(art.titulos.keys())[0]

    art.resumenes, art.keywords = fm.extraer_resumenes_kw(doc)
    if art.resumenes and art.idioma not in art.resumenes:
        art.idioma = list(art.resumenes.keys())[0]

    autores_raw, affs, alertas = autoria.extraer(doc)
    art.alertas.extend(alertas)
    art.afiliaciones = [Afiliacion(**a) for a in affs]
    for a in autores_raw:
        art.autores.append(Autor(nombres=a["nombres"], apellidos=a["apellidos"],
                                 orcid=a.get("orcid", ""), email=a.get("email", ""),
                                 aff_ids=a.get("aff_ids", []),
                                 correspondencia=bool(a.get("email"))))

    art.licencia, art.licencia_url = _licencia(p12)

    # Si hay DOI, consulta primero sus metadatos bibliograficos. La consulta no
    # bloquea la extraccion: ante timeout o falta de red se conserva lo obtenido
    # directamente desde el PDF y luego se aplican las heuristicas locales.
    doi_info = {"ok": False, "cambios": []}
    scielo_info = {"ok": False, "cambios": []}
    if art.doi:
        doi_info = doi_metadata.enriquecer_desde_doi(art)
        if doi_info.get("ok"):
            art.confianza["doi_metadata"] = 0.98
        # El PID no se fabrica. Si el DOI ya existe en SciELO, se recupera del
        # buscador oficial y se aprovechan los metadatos publicados para evitar
        # errores de OCR en revista, resumenes y palabras clave.
        scielo_info = scielo_metadata.enriquecer_desde_scielo(art)
        if scielo_info.get("ok"):
            art.confianza["scielo_metadata"] = 0.99

    issn = art.issn_electronico or art.issn_impreso
    if issn in REVISTAS:
        # Una ficha ya confirmada por el editor siempre tiene prioridad.
        cod, tit, ed = REVISTAS[issn]
        art.revista_codigo, art.revista_titulo, art.editorial = cod, tit, ed
        art.revista_abrev = tit
    else:
        # DOI > heuristica del PDF para revista y editorial.
        if not art.revista_titulo:
            art.revista_titulo = _adivinar_revista(doc, art.autores)
        if not art.revista_abrev:
            art.revista_abrev = art.revista_titulo
        if not art.editorial:
            art.editorial = _adivinar_editorial(doc)
        if not art.revista_titulo:
            art.alertas.append("no se pudo inferir el titulo de la revista")
        if art.doi and not doi_info.get("ok") and (not art.revista_titulo or not art.editorial):
            art.alertas.append("DOI detectado, pero no fue posible consultar sus metadatos")
    art.confianza["autores"] = 0.9 if all(x.orcid for x in art.autores) and art.autores else 0.5

    art.secciones = [Seccion(**s) for s in cr.extraer_secciones(doc)]
    refs, al = cr.extraer_referencias(doc)
    art.alertas.extend(al)
    art.referencias = [Referencia(**r) for r in refs]
    art.confianza["referencias"] = 0.8 if len(refs) > 5 else 0.3
    art.confianza["cuerpo"] = 0.8 if len(art.secciones) > 2 else 0.4

    doc.close()
    return art


def _adivinar_revista(doc, autores=()):
    """El titulo de la revista aparece en la cornisa de casi todas las paginas.
    Se buscan las lineas recurrentes detectadas por la maqueta y se elige la mas
    corta que no sea el titulo del articulo ni un dato de fasciculo.
    """
    m = doc.maqueta
    cands = []
    for l in doc.lineas:
        if not m.es_recurrente(l):
            continue
        t = re.split(r"\s+(?:Vol|vol\.|N[uú]m|N[ºo°]|ISSN|\d{4}|pp?\.)", l.texto)[0]
        t = t.strip(" ,.-–|")
        if not (4 < len(t) < 70):
            continue
        if re.search(r"(?i)issn|doi|https?://|@|p[aá]g\b", t):
            continue
        # descartes tipicos de cornisa: la cita del propio articulo, el dato de
        # fasciculo y el nombre de la institucion editora
        if re.search(r"\(\d{4}\)", t):
            continue
        if re.match(r"(?i)^(volumen|vol\b|n[uú]mero|n[ºo°]|universidad|facultad|"
                    r"departamento|instituto|escuela)\b", t):
            continue
        if any(_mismo_nombre(t, a) for a in autores):
            continue
        cands.append(t)
    if cands:
        # la mas frecuente entre las recurrentes, desempatando por la mas corta
        frec = Counter(cands)
        tope = max(frec.values())
        return min((c for c, n in frec.items() if n == tope), key=len)
    # sin cornisa: primera linea de la portada que nombre una publicacion
    for l in doc.utiles()[:20]:
        t = l.texto.strip()
        if re.search(r"(?i)^(revista|cuadernos|anales|estudios|bolet[ií]n|journal)", t):
            return re.split(r"(?i)\s+(?:vol|n[ºo°]|issn)", t)[0].strip(" ,")
    return ""


def _mismo_nombre(texto, autor):
    from .autoria import _norm
    a = _norm(f"{autor.nombres} {autor.apellidos}")
    b = _norm(texto)
    if not a or not b:
        return False
    pa, pb = set(a.split()), set(b.split())
    return len(pa & pb) >= 2


def _adivinar_editorial(doc):
    """Solo desde la cornisa recurrente. En la portada la institucion editora es
    indistinguible de la afiliacion del autor, y confundirlas produce un dato
    peor que un campo vacio.
    """
    from .autoria import MARCA_INST
    for l in doc.lineas:
        if not doc.maqueta.es_recurrente(l):
            continue
        t = l.texto.strip(" ,.-|")
        if 8 < len(t) < 120 and MARCA_INST.search(t) and not re.search(
                r"(?i)issn|doi|https?://|@|orcid|\(\d{4}\)", t):
            return re.split(r"(?i)\s+(?:vol\b|n[ºo°]|issn|\d{4})", t)[0].strip(" ,.•|")
    return ""


def _licencia(texto):
    m = re.search(r"CC\s*[- ]?\s*(BY(?:[- ](?:NC|ND|SA)){0,2})\s*[- ]?\s*(\d\.\d)?", texto, re.I)
    if not m:
        return "", ""
    partes = m.group(1).upper().replace(" ", "-")
    ver = m.group(2) or "4.0"
    return f"CC {partes} {ver}", f"https://creativecommons.org/licenses/{partes.lower()}/{ver}/"
