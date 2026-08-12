"""Consulta opcional de metadatos publicados en SciELO a partir del DOI.

El PID SciELO no se inventa ni se deriva de ISSN/volumen/pagina: es un
identificador de la coleccion. Si el articulo ya esta publicado en SciELO,
esta capa intenta localizarlo por DOI y recupera su PID y los metadatos
editoriales oficiales. Si aun no esta en SciELO, simplemente no hay PID.
"""
from __future__ import annotations

import html as _html
import re
import urllib.parse
import urllib.request
from typing import Dict, Tuple

from lxml import etree, html as lhtml

_CACHE: Dict[str, dict] = {}


def normalizar_doi(doi: str) -> str:
    s = (doi or "").strip()
    s = re.sub(r"(?i)^https?://(?:dx\.)?doi\.org/", "", s)
    s = re.sub(r"(?i)^doi\s*:\s*", "", s)
    return s.strip().rstrip(".,;)")


def _abrir(url: str, timeout: int = 12, accept: str = "text/html,*/*") -> Tuple[bytes, str]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "PDF2JATS/1.5 (SciELO PID lookup; editorial tool)",
            "Accept": accept,
            "Accept-Language": "es,en;q=0.8,pt;q=0.7",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.geturl()


def _pid_en_url(url: str) -> str:
    try:
        q = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)
        pid = (q.get("pid") or [""])[0]
        return pid if re.fullmatch(r"S[0-9A-Za-z_.-]+", pid or "") else ""
    except Exception:
        return ""


def _candidatos_busqueda(raw: bytes, base_url: str):
    out = []
    texto = raw.decode("utf-8", "ignore")
    try:
        doc = lhtml.fromstring(raw)
        for a in doc.xpath("//a[@href]"):
            href = urllib.parse.urljoin(base_url, a.get("href"))
            if "scielo.php" not in href:
                continue
            pid = _pid_en_url(_html.unescape(href))
            if pid:
                out.append((_html.unescape(href), pid))
    except Exception:
        pass

    # Respaldo para HTML minificado, JS o URLs escapadas dentro de atributos.
    un = _html.unescape(texto).replace("\\/", "/")
    for m in re.finditer(r"https?://[^\s\"'<>]+/scielo\.php\?[^\s\"'<>]*pid=(S[0-9A-Za-z_.-]+)[^\s\"'<>]*", un, re.I):
        out.append((m.group(0), m.group(1)))

    vistos = set()
    limpios = []
    for href, pid in out:
        k = (href, pid)
        if k not in vistos:
            vistos.add(k)
            limpios.append(k)
    return limpios


def localizar_por_doi(doi: str, timeout: int = 12) -> dict:
    doi = normalizar_doi(doi)
    if not doi:
        return {"ok": False, "error": "DOI vacio"}

    # El buscador oficial de SciELO documenta el indice `doi` y devuelve enlaces
    # a la coleccion que aloja el articulo, desde los que se obtiene el PID.
    query = urllib.parse.urlencode({"q": f"doi:{doi}", "lang": "es", "count": 15})
    url = "https://search.scielo.org/?" + query
    try:
        raw, final = _abrir(url, timeout=timeout)
    except Exception as e:
        return {"ok": False, "error": f"SciELO Search: {type(e).__name__}"}

    cands = _candidatos_busqueda(raw, final)
    if not cands:
        return {"ok": False, "error": "DOI no encontrado en SciELO"}

    # La consulta es exacta por DOI. Aun asi, se intenta verificar el DOI en la
    # pagina del articulo antes de aceptar el primer resultado.
    doi_n = doi.lower()
    fallback = None
    for href, pid in cands[:8]:
        dominio = urllib.parse.urlsplit(href).netloc
        if not dominio:
            continue
        art_url = f"https://{dominio}/scielo.php?script=sci_arttext&pid={urllib.parse.quote(pid)}"
        fallback = fallback or {"pid": pid, "dominio": dominio, "url_articulo": art_url}
        try:
            pagina, _ = _abrir(art_url, timeout=min(timeout, 8))
            if doi_n in pagina.decode("utf-8", "ignore").lower():
                return {"ok": True, "pid": pid, "dominio": dominio, "url_articulo": art_url}
        except Exception:
            continue

    if fallback:
        return {"ok": True, **fallback, "advertencia": "PID obtenido de la busqueda DOI sin verificacion secundaria"}
    return {"ok": False, "error": "SciELO devolvio resultados sin PID util"}


def _texto(root, xpath: str) -> str:
    try:
        s = root.xpath(f"string({xpath})")
    except Exception:
        return ""
    return re.sub(r"\s+", " ", s or "").strip(" ,;\n\t")


def _limpiar_prefijo_resumen(s: str) -> str:
    return re.sub(r"^\s*(?:Resumen|Abstract|Resumo)\s*[:.-]?\s*", "", s or "", flags=re.I).strip()


def parsear_xml_scielo(raw: bytes, pid_hint: str = "", dominio: str = "") -> dict:
    """Extrae un subconjunto neutral tanto del XML legado como de JATS/SPS."""
    parser = etree.XMLParser(recover=True, huge_tree=True, resolve_entities=False)
    try:
        root = etree.fromstring(raw, parser=parser)
    except Exception as e:
        return {"ok": False, "error": f"XML SciELO invalido: {type(e).__name__}"}

    ns_xml = "{http://www.w3.org/XML/1998/namespace}lang"
    datos = {
        "pid_scielo": pid_hint or "",
        "doi": "",
        "revista_titulo": _texto(root, ".//journal-meta/journal-title-group/journal-title") or _texto(root, ".//journal-meta/journal-title"),
        "revista_abrev": _texto(root, ".//journal-meta/journal-title-group/abbrev-journal-title") or _texto(root, ".//journal-meta/abbrev-journal-title"),
        "editorial": _texto(root, ".//journal-meta/publisher/publisher-name"),
        "issn_electronico": "",
        "issn_impreso": "",
        "volumen": _texto(root, ".//article-meta/volume"),
        "numero": _texto(root, ".//article-meta/issue") or _texto(root, ".//article-meta/numero"),
        "fpage": _texto(root, ".//article-meta/fpage"),
        "lpage": _texto(root, ".//article-meta/lpage"),
        "titulos": {},
        "resumenes": {},
        "keywords": {},
        "url_scielo": "",
        "dominio_scielo": dominio,
    }

    for e in root.xpath(".//article-meta/article-id"):
        valor = re.sub(r"\s+", "", "".join(e.itertext()))
        tipo = (e.get("pub-id-type") or "").lower()
        if tipo == "doi":
            datos["doi"] = normalizar_doi(valor)
        elif (tipo == "publisher-id" or not tipo) and re.fullmatch(r"S[0-9A-Za-z_.-]+", valor or ""):
            datos["pid_scielo"] = valor

    issns = root.xpath(".//journal-meta/issn")
    for e in issns:
        val = re.sub(r"\s+", "", "".join(e.itertext()))
        tipo = (e.get("pub-type") or "").lower()
        if tipo == "ppub":
            datos["issn_impreso"] = val
        elif tipo in ("epub", "electronic"):
            datos["issn_electronico"] = val
        elif val and not datos["issn_electronico"]:
            # Las colecciones antiguas suelen publicar un solo ISSN online sin atributo.
            datos["issn_electronico"] = val

    # Titulos: XML legado usa varios article-title; SPS moderno usa trans-title.
    for e in root.xpath(".//article-meta/title-group/article-title"):
        lg = (e.get(ns_xml) or "es").lower().split("-")[0]
        val = re.sub(r"\s+", " ", "".join(e.itertext())).strip()
        if val:
            datos["titulos"][lg] = val
    for e in root.xpath(".//article-meta/title-group//trans-title"):
        parent = e.getparent()
        lg = ((parent.get(ns_xml) if parent is not None else "") or e.get(ns_xml) or "").lower().split("-")[0]
        val = re.sub(r"\s+", " ", "".join(e.itertext())).strip()
        if lg and val:
            datos["titulos"][lg] = val

    for e in root.xpath(".//article-meta/abstract | .//article-meta/trans-abstract"):
        lg = (e.get(ns_xml) or "es").lower().split("-")[0]
        val = _limpiar_prefijo_resumen(re.sub(r"\s+", " ", " ".join(e.itertext())).strip())
        if val:
            datos["resumenes"][lg] = val

    kws = {}
    for kg in root.xpath(".//article-meta/kwd-group"):
        lg_grupo = (kg.get(ns_xml) or "").lower().split("-")[0]
        for e in kg.xpath("./kwd"):
            lg = ((e.get("lng") or lg_grupo or "es")).lower().split("-")[0]
            val = re.sub(r"\s+", " ", "".join(e.itertext())).strip(" .;,\n\t")
            if val:
                kws.setdefault(lg, []).append(val)
    datos["keywords"] = {lg: vals for lg, vals in kws.items() if vals}

    # El XML legado expone self-uri con el mismo PID. Se conserva solo para ayuda.
    uri = root.xpath("string(.//article-meta/self-uri[1]/@xlink:href)", namespaces={"xlink": "http://www.w3.org/1999/xlink"})
    if uri:
        datos["url_scielo"] = uri.strip()
    elif dominio and datos["pid_scielo"]:
        datos["url_scielo"] = f"https://{dominio}/scielo.php?script=sci_arttext&pid={datos['pid_scielo']}"

    return {"ok": True, "datos": datos}


def consultar_doi(doi: str, forzar: bool = False, timeout: int = 12) -> dict:
    doi = normalizar_doi(doi)
    if not doi:
        return {"ok": False, "error": "DOI vacio", "datos": {}}
    if doi in _CACHE and not forzar:
        return dict(_CACHE[doi])

    loc = localizar_por_doi(doi, timeout=timeout)
    if not loc.get("ok"):
        return {**loc, "datos": {}}

    pid = loc["pid"]
    dominio = loc["dominio"]
    xml_url = f"https://{dominio}/scieloOrg/php/articleXML.php?lang=es&pid={urllib.parse.quote(pid)}"
    errores = []
    try:
        raw, _ = _abrir(xml_url, timeout=timeout, accept="application/xml,text/xml,*/*")
        res = parsear_xml_scielo(raw, pid_hint=pid, dominio=dominio)
        if res.get("ok"):
            out = {"ok": True, "fuente": "SciELO", "datos": res["datos"],
                   "pid": pid, "url_articulo": loc.get("url_articulo", ""), "url_xml": xml_url}
            _CACHE[doi] = dict(out)
            return out
        errores.append(res.get("error", "XML no legible"))
    except Exception as e:
        errores.append(f"SciELO XML: {type(e).__name__}")

    # Aunque el XML no este disponible, el PID localizado sigue siendo util.
    out = {"ok": True, "fuente": "SciELO Search", "pid": pid,
           "datos": {"pid_scielo": pid, "doi": doi, "dominio_scielo": dominio,
                     "url_scielo": loc.get("url_articulo", "")},
           "error": "; ".join(errores)}
    _CACHE[doi] = dict(out)
    return out


def aplicar_al_articulo(art, datos: dict):
    """Aplica solo metadatos que SciELO puede conocer de forma autoritativa.

    Si existe un registro exacto por DOI, los datos de identidad de la revista,
    titulos, resumenes y palabras clave publicados en SciELO sustituyen la
    inferencia del PDF. No se reemplazan fechas editoriales ni afiliaciones.
    """
    cambios = []

    def setv(campo, valor, sobrescribir=True):
        if not valor:
            return
        actual = getattr(art, campo, "")
        if sobrescribir or not actual:
            if actual != valor:
                setattr(art, campo, valor)
                cambios.append(campo)

    setv("pid_scielo", datos.get("pid_scielo", ""), True)
    setv("revista_titulo", datos.get("revista_titulo", ""), True)
    setv("revista_abrev", datos.get("revista_abrev", "") or datos.get("revista_titulo", ""), True)
    setv("editorial", datos.get("editorial", ""), True)
    setv("issn_electronico", datos.get("issn_electronico", ""), False)
    setv("issn_impreso", datos.get("issn_impreso", ""), False)
    for campo in ("volumen", "numero", "fpage", "lpage"):
        setv(campo, datos.get(campo, ""), False)

    if datos.get("titulos"):
        nuevos = dict(getattr(art, "titulos", {}) or {})
        antes = dict(nuevos)
        nuevos.update(datos["titulos"])
        if nuevos != antes:
            art.titulos = nuevos
            cambios.append("titulos")
    if datos.get("resumenes"):
        if getattr(art, "resumenes", {}) != datos["resumenes"]:
            art.resumenes = dict(datos["resumenes"])
            cambios.append("resumenes")
    if datos.get("keywords"):
        if getattr(art, "keywords", {}) != datos["keywords"]:
            art.keywords = {k: list(v) for k, v in datos["keywords"].items()}
            cambios.append("keywords")

    return sorted(set(cambios))


def enriquecer_desde_scielo(art, forzar: bool = False):
    res = consultar_doi(getattr(art, "doi", ""), forzar=forzar)
    if not res.get("ok"):
        return {**res, "cambios": []}
    cambios = aplicar_al_articulo(art, res.get("datos") or {})
    return {**res, "cambios": cambios}
