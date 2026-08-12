"""Consulta y aplica metadatos bibliograficos a partir de un DOI.

La consulta reproduce primero el mecanismo usado por doi2bib: content negotiation
de DOI.org solicitando application/x-bibtex. Luego complementa los huecos con
Crossref, CSL-JSON de DOI.org, DataCite, la pagina editorial y la ficha de revista
por ISSN. Todo fallo es no fatal: la extraccion desde el PDF continua normalmente.
"""
from __future__ import annotations

import html
import json
import os
import re
import unicodedata
from urllib.parse import quote
from urllib.request import Request, urlopen

_CACHE = {}


def normalizar_doi(doi: str) -> str:
    doi = (doi or "").strip().rstrip(".,;:)]}")
    doi = re.sub(r"(?i)^doi\s*:\s*", "", doi)
    doi = re.sub(r"(?i)^(https?://)?(dx\.)?doi\.org/", "", doi)
    return doi


def _limpiar_texto(valor):
    if isinstance(valor, list):
        valor = valor[0] if valor else ""
    valor = html.unescape(str(valor or ""))
    valor = re.sub(r"<[^>]+>", "", valor)
    return re.sub(r"\s+", " ", valor).strip()


def _fecha_desde_partes(partes):
    if not partes or not isinstance(partes, (list, tuple)):
        return ""
    try:
        p = partes[0] if partes and isinstance(partes[0], (list, tuple)) else partes
        if not p:
            return ""
        y = int(p[0])
        if len(p) == 1:
            return f"{y:04d}"
        m = int(p[1])
        if len(p) == 2:
            return f"{y:04d}-{m:02d}"
        d = int(p[2])
        return f"{y:04d}-{m:02d}-{d:02d}"
    except Exception:
        return ""


def _autores_crossref(lista):
    out = []
    for a in lista or []:
        if not isinstance(a, dict):
            continue
        orcid = str(a.get("ORCID") or "")
        orcid = re.sub(r"(?i)^https?://orcid\.org/", "", orcid).strip()
        out.append({
            "nombres": _limpiar_texto(a.get("given")),
            "apellidos": _limpiar_texto(a.get("family")),
            "orcid": orcid,
        })
    return out


def _parsear_crossref(m):
    tipos_issn = m.get("issn-type") or []
    issn_e = issn_i = ""
    for x in tipos_issn:
        if not isinstance(x, dict):
            continue
        val = _limpiar_texto(x.get("value")).upper()
        tipo = str(x.get("type") or "").lower()
        if tipo == "electronic" and val:
            issn_e = issn_e or val
        elif tipo == "print" and val:
            issn_i = issn_i or val
    if not issn_e and not issn_i:
        vals = [_limpiar_texto(x).upper() for x in (m.get("ISSN") or []) if _limpiar_texto(x)]
        if vals:
            issn_e = vals[0]
        if len(vals) > 1:
            issn_i = vals[1]

    fecha = ""
    for clave in ("published-print", "published-online", "published", "issued"):
        obj = m.get(clave) or {}
        fecha = _fecha_desde_partes(obj.get("date-parts") if isinstance(obj, dict) else None)
        if fecha:
            break

    page = _limpiar_texto(m.get("page"))
    fpage = lpage = ""
    mm = re.search(r"(\d+)\s*[-–—]\s*(\d+)", page)
    if mm:
        fpage, lpage = mm.group(1), mm.group(2)
    elif re.fullmatch(r"\d+", page):
        fpage = page

    lic = ""
    licencias = m.get("license") or []
    if licencias and isinstance(licencias[0], dict):
        lic = _limpiar_texto(licencias[0].get("URL"))

    return {
        "doi": normalizar_doi(m.get("DOI") or ""),
        "titulo": _limpiar_texto(m.get("title")),
        "revista_titulo": _limpiar_texto(m.get("container-title")),
        "revista_abrev": _limpiar_texto(m.get("short-container-title")),
        "editorial": _limpiar_texto(m.get("publisher")),
        "issn_electronico": issn_e,
        "issn_impreso": issn_i,
        "volumen": _limpiar_texto(m.get("volume")),
        "numero": _limpiar_texto(m.get("issue")),
        "fpage": fpage,
        "lpage": lpage,
        "fecha_publicado": fecha,
        "idioma": _limpiar_texto(m.get("language")),
        "licencia_url": lic,
        "autores": _autores_crossref(m.get("author")),
    }


def _parsear_csl(m):
    issn = m.get("ISSN") or []
    if isinstance(issn, str):
        issn = [issn]
    issn = [_limpiar_texto(x).upper() for x in issn if _limpiar_texto(x)]
    page = _limpiar_texto(m.get("page"))
    fpage = lpage = ""
    mm = re.search(r"(\d+)\s*[-–—]\s*(\d+)", page)
    if mm:
        fpage, lpage = mm.group(1), mm.group(2)
    elif re.fullmatch(r"\d+", page):
        fpage = page

    fecha = ""
    for k in ("issued", "published-print", "published-online"):
        o = m.get(k) or {}
        fecha = _fecha_desde_partes(o.get("date-parts") if isinstance(o, dict) else None)
        if fecha:
            break

    autores = []
    for a in m.get("author") or []:
        if not isinstance(a, dict):
            continue
        orcid = re.sub(r"(?i)^https?://orcid\.org/", "", str(a.get("ORCID") or "")).strip()
        autores.append({
            "nombres": _limpiar_texto(a.get("given")),
            "apellidos": _limpiar_texto(a.get("family")),
            "orcid": orcid,
        })

    return {
        "doi": normalizar_doi(m.get("DOI") or ""),
        "titulo": _limpiar_texto(m.get("title")),
        "revista_titulo": _limpiar_texto(m.get("container-title")),
        "revista_abrev": _limpiar_texto(m.get("container-title-short")),
        "editorial": _limpiar_texto(m.get("publisher")),
        "issn_electronico": issn[0] if issn else "",
        "issn_impreso": issn[1] if len(issn) > 1 else "",
        "volumen": _limpiar_texto(m.get("volume")),
        "numero": _limpiar_texto(m.get("issue")),
        "fpage": fpage,
        "lpage": lpage,
        "fecha_publicado": fecha,
        "idioma": _limpiar_texto(m.get("language")),
        "licencia_url": _limpiar_texto(m.get("URL")) if "creativecommons.org/licenses" in str(m.get("URL") or "") else "",
        "autores": autores,
    }



def _abrir_texto(url, headers, timeout, max_bytes=2_000_000):
    req = Request(url, headers=headers)
    with urlopen(req, timeout=timeout) as r:
        if getattr(r, "status", 200) >= 400:
            return ""
        raw = r.read(max_bytes)
        # DOI.org devuelve normalmente UTF-8; respetar charset si viene declarado.
        ctype = str(r.headers.get("Content-Type") or "")
        m = re.search(r"charset=([^;\s]+)", ctype, re.I)
        enc = (m.group(1).strip('"\'') if m else "utf-8") or "utf-8"
        try:
            return raw.decode(enc, errors="replace")
        except LookupError:
            return raw.decode("utf-8", errors="replace")


def _deslatex_minimo(s):
    """Limpieza conservadora de valores BibTeX sin depender de bibtexparser."""
    s = _limpiar_texto(s)
    # Quitar llaves de proteccion tipicas, manteniendo el contenido.
    s = s.replace("{", "").replace("}", "")
    reemplazos = {
        r"\\&": "&", r"\\%": "%", r"\\_": "_", r"\\#": "#",
        r"\\textendash": "–", r"\\textemdash": "—", r"~": " ",
        r"\\'a": "á", r"\\'e": "é", r"\\'i": "í", r"\\'o": "ó", r"\\'u": "ú",
        r"\\'A": "Á", r"\\'E": "É", r"\\'I": "Í", r"\\'O": "Ó", r"\\'U": "Ú",
        r'\\"a': "ä", r'\\"e': "ë", r'\\"i': "ï", r'\\"o': "ö", r'\\"u': "ü",
        r"\\~n": "ñ", r"\\~N": "Ñ",
    }
    for a, b in reemplazos.items():
        s = s.replace(a, b)
    s = re.sub(r"\\[a-zA-Z]+\s*", "", s)
    return re.sub(r"\s+", " ", s).strip()


def _parsear_bibtex_campos(texto):
    """Parsea una entrada BibTeX con llaves/comillas balanceadas.

    DOI.org devuelve una sola entrada para content negotiation. Este parser evita
    dependencias nuevas y soporta valores multilínea, llaves anidadas y comillas.
    """
    if not texto or "@" not in texto:
        return {}
    ini = texto.find("{")
    if ini < 0:
        ini = texto.find("(")
    if ini < 0:
        return {}
    # Saltar la citation key hasta la primera coma de nivel superior.
    i = ini + 1
    profundidad = 0
    comillas = False
    escape = False
    while i < len(texto):
        c = texto[i]
        if escape:
            escape = False
        elif c == "\\":
            escape = True
        elif c == '"':
            comillas = not comillas
        elif not comillas:
            if c == "{": profundidad += 1
            elif c == "}": profundidad = max(0, profundidad - 1)
            elif c == "," and profundidad == 0:
                i += 1
                break
        i += 1

    campos = {}
    n = len(texto)
    while i < n:
        while i < n and (texto[i].isspace() or texto[i] == ','):
            i += 1
        if i >= n or texto[i] in "})":
            break
        m = re.match(r"([A-Za-z][A-Za-z0-9_:\-]*)\s*=\s*", texto[i:])
        if not m:
            i += 1
            continue
        clave = m.group(1).lower()
        i += m.end()
        if i >= n:
            break
        if texto[i] == "{":
            i += 1; start = i; depth = 1; quote = False; esc = False
            while i < n and depth:
                c = texto[i]
                if esc: esc = False
                elif c == "\\": esc = True
                elif c == '"': quote = not quote
                elif not quote:
                    if c == "{": depth += 1
                    elif c == "}":
                        depth -= 1
                        if depth == 0: break
                i += 1
            valor = texto[start:i]
            i += 1
        elif texto[i] == '"':
            i += 1; start = i; esc = False
            while i < n:
                c = texto[i]
                if esc: esc = False
                elif c == "\\": esc = True
                elif c == '"': break
                i += 1
            valor = texto[start:i]
            i += 1
        else:
            start = i
            while i < n and texto[i] not in ",}\n\r": i += 1
            valor = texto[start:i]
        campos[clave] = _deslatex_minimo(valor.strip())
    return campos


def _autores_bibtex(valor):
    autores = []
    for raw in re.split(r"\s+and\s+", valor or "", flags=re.I):
        raw = raw.strip()
        if not raw:
            continue
        if "," in raw:
            ap, no = [x.strip() for x in raw.split(",", 1)]
        else:
            partes = raw.split()
            ap, no = (partes[-1], " ".join(partes[:-1])) if len(partes) > 1 else (raw, "")
        autores.append({"nombres": no, "apellidos": ap, "orcid": ""})
    return autores


def _parsear_bibtex(texto):
    c = _parsear_bibtex_campos(texto)
    if not c:
        return {}
    pages = c.get("pages", "")
    fpage = lpage = ""
    mm = re.search(r"(\d+)\s*(?:--+|[-–—])\s*(\d+)", pages)
    if mm:
        fpage, lpage = mm.group(1), mm.group(2)
    elif re.fullmatch(r"\d+", pages):
        fpage = pages

    copyright_txt = c.get("copyright", "")
    licencia = ""
    if re.search(r"creative\s+commons\s+attribution\s+4(?:\.0)?", copyright_txt, re.I):
        licencia = "CC BY 4.0"
    elif copyright_txt:
        licencia = copyright_txt

    return {
        "doi": normalizar_doi(c.get("doi", "")),
        "titulo": c.get("title", ""),
        "revista_titulo": c.get("journal", "") or c.get("journaltitle", ""),
        "revista_abrev": c.get("shortjournal", ""),
        "editorial": c.get("publisher", ""),
        "issn_electronico": c.get("eissn", ""),
        "issn_impreso": c.get("issn", ""),
        "volumen": c.get("volume", ""),
        "numero": c.get("issue", "") or c.get("number", ""),
        "fpage": fpage,
        "lpage": lpage,
        "fecha_publicado": c.get("year", ""),
        "idioma": c.get("language", ""),
        "licencia_url": c.get("license", "") if "creativecommons.org" in c.get("license", "").lower() else "",
        "licencia": licencia,
        "autores": _autores_bibtex(c.get("author", "")),
        "url_articulo": c.get("url", ""),
        "keywords_bibtex": [x.strip() for x in re.split(r"[,;]", c.get("keywords", "")) if x.strip()],
        "_bibtex": texto.strip(),
    }


def _consultar_bibtex_doi(doi, ua, timeout):
    """Replica exactamente la estrategia de doi2bib para DOI -> BibTeX."""
    url = "https://doi.org/" + quote(doi, safe="/")
    texto = _abrir_texto(url, {
        "User-Agent": ua,
        "Accept": "application/x-bibtex; charset=utf-8",
    }, timeout)
    return _parsear_bibtex(texto)


def _abrir_json(url, headers, timeout):
    req = Request(url, headers=headers)
    with urlopen(req, timeout=timeout) as r:
        if getattr(r, "status", 200) >= 400:
            return None
        return json.loads(r.read().decode("utf-8", errors="replace"))


def _merge_metadata(base, nuevo, fuente, proveniencia):
    """Combina fuentes sin borrar valores ya recuperados.

    La estrategia es deliberadamente conservadora: una fuente posterior solo
    rellena huecos. Así se pueden consultar varias bases aunque una de ellas
    entregue una ficha parcial, que es frecuente en revistas pequeñas/OJS.
    """
    if not isinstance(nuevo, dict):
        return
    aporto = False
    for k, v in nuevo.items():
        if k == "autores":
            if v and not base.get(k):
                base[k] = v
                aporto = True
            continue
        if v not in (None, "", [], {}) and not base.get(k):
            base[k] = v
            aporto = True
    if aporto and fuente not in proveniencia:
        proveniencia.append(fuente)


def _tiene_datos(datos):
    claves = ("revista_titulo", "editorial", "titulo", "issn_electronico",
              "issn_impreso", "volumen", "numero", "fpage", "lpage")
    return any(datos.get(k) for k in claves)


def _parsear_datacite(j):
    data = (j or {}).get("data") if isinstance(j, dict) else None
    a = data.get("attributes") if isinstance(data, dict) else None
    if not isinstance(a, dict):
        return {}

    titles = a.get("titles") or []
    titulo = ""
    if titles and isinstance(titles[0], dict):
        titulo = _limpiar_texto(titles[0].get("title"))

    cont = a.get("container") or {}
    if not isinstance(cont, dict):
        cont = {}

    creators = []
    for x in a.get("creators") or []:
        if not isinstance(x, dict):
            continue
        name_ids = x.get("nameIdentifiers") or []
        orcid = ""
        for ni in name_ids:
            if isinstance(ni, dict) and "orcid" in str(ni.get("nameIdentifierScheme") or ni.get("schemeUri") or "").lower():
                orcid = re.sub(r"(?i)^https?://orcid\.org/", "", str(ni.get("nameIdentifier") or "")).strip()
                break
        creators.append({
            "nombres": _limpiar_texto(x.get("givenName")),
            "apellidos": _limpiar_texto(x.get("familyName")),
            "orcid": orcid,
        })

    issn_e = issn_i = ""
    ident = _limpiar_texto(cont.get("identifier")).upper()
    if re.fullmatch(r"\d{4}-?\d{3}[\dX]", ident):
        issn_e = ident

    fecha = ""
    for d in a.get("dates") or []:
        if isinstance(d, dict) and str(d.get("dateType") or "").lower() in {"issued", "available", "created"}:
            fecha = _limpiar_texto(d.get("date"))[:10]
            if fecha:
                break
    if not fecha and a.get("publicationYear"):
        fecha = str(a.get("publicationYear"))

    return {
        "doi": normalizar_doi(a.get("doi") or (data or {}).get("id") or ""),
        "titulo": titulo,
        "revista_titulo": _limpiar_texto(cont.get("title")),
        "revista_abrev": "",
        "editorial": _limpiar_texto(a.get("publisher")),
        "issn_electronico": issn_e,
        "issn_impreso": issn_i,
        "volumen": _limpiar_texto(cont.get("volume")),
        "numero": _limpiar_texto(cont.get("issue")),
        "fpage": _limpiar_texto(cont.get("firstPage")),
        "lpage": _limpiar_texto(cont.get("lastPage")),
        "fecha_publicado": fecha,
        "idioma": _limpiar_texto(a.get("language")),
        "licencia_url": "",
        "autores": creators,
    }


def _parsear_crossref_journal(m):
    if not isinstance(m, dict):
        return {}
    tipos = m.get("issn-type") or []
    issn_e = issn_i = ""
    for x in tipos:
        if not isinstance(x, dict):
            continue
        val = _limpiar_texto(x.get("value")).upper()
        typ = str(x.get("type") or "").lower()
        if typ == "electronic" and val:
            issn_e = issn_e or val
        elif typ == "print" and val:
            issn_i = issn_i or val
    vals = [_limpiar_texto(x).upper() for x in (m.get("ISSN") or []) if _limpiar_texto(x)]
    if not issn_e and vals:
        issn_e = vals[0]
    if not issn_i and len(vals) > 1:
        issn_i = vals[1]
    return {
        "revista_titulo": _limpiar_texto(m.get("title")),
        "revista_abrev": _limpiar_texto(m.get("short-title")) or _limpiar_texto(m.get("title")),
        "editorial": _limpiar_texto(m.get("publisher")),
        "issn_electronico": issn_e,
        "issn_impreso": issn_i,
    }


class _MetaHTMLParser(__import__('html.parser', fromlist=['HTMLParser']).HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = {}

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "meta":
            return
        d = {str(k).lower(): v for k, v in attrs}
        key = (d.get("name") or d.get("property") or "").strip().lower()
        val = (d.get("content") or "").strip()
        if key and val:
            self.meta.setdefault(key, []).append(val)


def _primero(meta, *nombres):
    for n in nombres:
        vals = meta.get(n.lower()) or []
        if vals:
            return _limpiar_texto(vals[0])
    return ""


def _parsear_meta_html(raw):
    try:
        parser = _MetaHTMLParser()
        parser.feed(raw.decode("utf-8", errors="replace"))
        m = parser.meta
    except Exception:
        return {}

    page = _primero(m, "citation_firstpage", "prism.startingpage")
    lpage = _primero(m, "citation_lastpage", "prism.endingpage")
    issn_vals = []
    for k in ("citation_issn", "prism.issn", "dc.identifier.issn"):
        for v in m.get(k, []):
            v = _limpiar_texto(v).upper()
            if v and v not in issn_vals:
                issn_vals.append(v)

    return {
        "doi": normalizar_doi(_primero(m, "citation_doi", "dc.identifier")),
        "titulo": _primero(m, "citation_title", "dc.title", "og:title"),
        "revista_titulo": _primero(m, "citation_journal_title", "prism.publicationname", "dc.source"),
        "revista_abrev": "",
        "editorial": _primero(m, "citation_publisher", "dc.publisher", "prism.publisher"),
        "issn_electronico": issn_vals[0] if issn_vals else "",
        "issn_impreso": issn_vals[1] if len(issn_vals) > 1 else "",
        "volumen": _primero(m, "citation_volume", "prism.volume"),
        "numero": _primero(m, "citation_issue", "prism.number"),
        "fpage": page,
        "lpage": lpage,
        "fecha_publicado": _primero(m, "citation_publication_date", "citation_date", "dc.date", "prism.publicationdate")[:10],
        "idioma": _primero(m, "citation_language", "dc.language"),
        "licencia_url": _primero(m, "dc.rights", "dc.rights.uri") if "creativecommons.org" in str(m).lower() else "",
        "autores": [],
    }


def _consultar_landing_doi(doi, ua, timeout):
    """Lee meta-tags bibliograficos de la pagina a la que resuelve el DOI.

    Es un ultimo respaldo, especialmente util en OJS, que suele exponer
    citation_journal_title/citation_publisher aunque el deposito DOI sea parcial.
    """
    req = Request("https://doi.org/" + quote(doi, safe="/"), headers={
        "User-Agent": ua,
        "Accept": "text/html,application/xhtml+xml",
    })
    with urlopen(req, timeout=timeout) as r:
        ctype = str(r.headers.get("Content-Type") or "").lower()
        if "html" not in ctype:
            return {}
        raw = r.read(1_500_000)
    return _parsear_meta_html(raw)


def consultar_doi(doi: str, forzar: bool = False, issn_hint: str = ""):
    """Recupera y fusiona metadatos desde varias fuentes abiertas.

    A diferencia de versiones anteriores, no se detiene en la primera respuesta:
    una ficha Crossref parcial se complementa con DOI.org, DataCite, la pagina
    editorial y, si hay ISSN, la ficha de revista de Crossref.
    """
    doi = normalizar_doi(doi)
    issn_hint = _limpiar_texto(issn_hint).upper()
    if not doi:
        return {"ok": False, "fuente": "", "fuentes": [], "datos": {}, "error": "DOI vacío"}
    if not re.match(r"^10\.\d{4,9}/\S+$", doi, re.I):
        return {"ok": False, "fuente": "", "fuentes": [], "datos": {}, "error": "formato DOI no válido"}
    if not forzar and doi in _CACHE:
        fuente, datos, fuentes = _CACHE[doi]
        return {"ok": True, "fuente": fuente, "fuentes": list(fuentes), "datos": dict(datos), "error": ""}

    if str(os.getenv("PDF2JATS_DOI_LOOKUP", "1")).lower() in {"0", "false", "no", "off"}:
        return {"ok": False, "fuente": "", "fuentes": [], "datos": {}, "error": "consulta DOI desactivada"}

    timeout = float(os.getenv("PDF2JATS_DOI_TIMEOUT", "4.5"))
    ua = os.getenv("PDF2JATS_USER_AGENT", "PDF2JATS/1.4 (doi2bib-compatible DOI metadata lookup)")
    errores = []
    datos = {"doi": doi}
    fuentes = []

    # 0) Misma estrategia que doi2bib: DOI.org -> application/x-bibtex.
    # Es importante porque algunos depositos exponen journal/publisher en BibTeX
    # aunque esos campos lleguen vacios en CSL-JSON o en otras representaciones.
    try:
        bib = _consultar_bibtex_doi(doi, ua, timeout)
        if isinstance(bib, dict):
            _merge_metadata(datos, bib, "DOI.org BibTeX (doi2bib)", fuentes)
    except Exception as e:
        errores.append(f"DOI.org BibTeX: {type(e).__name__}")

    # 1) Registro del trabajo en Crossref.
    try:
        url = "https://api.crossref.org/works/" + quote(doi, safe="")
        j = _abrir_json(url, {"User-Agent": ua, "Accept": "application/json"}, timeout)
        msg = (j or {}).get("message") if isinstance(j, dict) else None
        if isinstance(msg, dict):
            _merge_metadata(datos, _parsear_crossref(msg), "Crossref", fuentes)
    except Exception as e:
        errores.append(f"Crossref: {type(e).__name__}")

    # 2) Content negotiation del DOI. La DOI Foundation deriva la consulta a la
    # agencia registradora correspondiente y puede aportar una representacion CSL.
    try:
        url = "https://doi.org/" + quote(doi, safe="/")
        j = _abrir_json(url, {
            "User-Agent": ua,
            "Accept": "application/vnd.citationstyles.csl+json",
        }, timeout)
        if isinstance(j, dict):
            _merge_metadata(datos, _parsear_csl(j), "DOI.org", fuentes)
    except Exception as e:
        errores.append(f"DOI.org: {type(e).__name__}")

    # 3) DataCite: respaldo para DOI registrados alli o registros enriquecidos.
    try:
        url = "https://api.datacite.org/dois/" + quote(doi, safe="/")
        j = _abrir_json(url, {"User-Agent": ua, "Accept": "application/vnd.api+json"}, timeout)
        _merge_metadata(datos, _parsear_datacite(j), "DataCite", fuentes)
    except Exception as e:
        errores.append(f"DataCite: {type(e).__name__}")

    # 4) Pagina del editor: muchos OJS exponen Highwire/DC/PRISM completos aunque
    # el deposito del DOI no incluya revista o publisher.
    if not datos.get("revista_titulo") or not datos.get("editorial"):
        try:
            _merge_metadata(datos, _consultar_landing_doi(doi, ua, timeout), "Página editorial", fuentes)
        except Exception as e:
            errores.append(f"Página editorial: {type(e).__name__}")

    # 5) Ficha de revista por ISSN en Crossref. Usa primero el ISSN detectado en
    # el propio PDF, y si no, alguno recuperado por las fuentes anteriores.
    issn = issn_hint or datos.get("issn_electronico") or datos.get("issn_impreso") or ""
    if issn and (not datos.get("revista_titulo") or not datos.get("editorial")):
        try:
            url = "https://api.crossref.org/journals/" + quote(issn, safe="")
            j = _abrir_json(url, {"User-Agent": ua, "Accept": "application/json"}, timeout)
            msg = (j or {}).get("message") if isinstance(j, dict) else None
            if isinstance(msg, dict):
                _merge_metadata(datos, _parsear_crossref_journal(msg), "Crossref Journal", fuentes)
        except Exception as e:
            errores.append(f"Crossref Journal: {type(e).__name__}")

    if _tiene_datos(datos):
        fuente = " + ".join(fuentes) if fuentes else "DOI"
        _CACHE[doi] = (fuente, dict(datos), tuple(fuentes))
        return {"ok": True, "fuente": fuente, "fuentes": fuentes, "datos": datos, "error": "; ".join(errores)}

    return {"ok": False, "fuente": "", "fuentes": fuentes, "datos": {}, "error": "; ".join(errores) or "sin metadatos"}

def _norm_nombre(s):
    return unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower().strip()


def _enriquecer_autores(art, autores_doi):
    cambios = []
    if not autores_doi:
        return cambios
    if not getattr(art, "autores", None):
        # Se evita fabricar afiliaciones. Si el PDF no detecto autores, el DOI al
        # menos permite recuperar nombres y ORCID.
        from .model import Autor
        art.autores = [Autor(nombres=a.get("nombres", ""), apellidos=a.get("apellidos", ""),
                             orcid=a.get("orcid", "")) for a in autores_doi]
        return ["autores"]

    usados = set()
    for autor in art.autores:
        if getattr(autor, "orcid", ""):
            continue
        an = _norm_nombre(f"{autor.nombres} {autor.apellidos}")
        ap = set(an.split())
        mejor = None
        for i, d in enumerate(autores_doi):
            if i in usados:
                continue
            dn = _norm_nombre(f"{d.get('nombres','')} {d.get('apellidos','')}")
            dp = set(dn.split())
            score = len(ap & dp)
            if score >= 1 and (mejor is None or score > mejor[0]):
                mejor = (score, i, d)
        if mejor and mejor[2].get("orcid"):
            autor.orcid = mejor[2]["orcid"]
            usados.add(mejor[1])
            cambios.append("orcid")
    return cambios


def aplicar_al_articulo(art, datos: dict, preferir_doi_revista: bool = True):
    """Aplica metadatos DOI sin destruir informacion editorial fina del PDF.

    Revista/editorial se consideran autoritativas cuando vienen del registro DOI.
    El resto de los campos bibliograficos completa vacios; autores solo se crean si
    faltaban o se enriquecen con ORCID.
    """
    cambios = []

    if datos.get("doi"):
        art.doi = datos["doi"]

    for campo in ("revista_titulo", "editorial"):
        val = datos.get(campo, "")
        if val and (preferir_doi_revista or not getattr(art, campo, "")):
            if getattr(art, campo, "") != val:
                setattr(art, campo, val)
                cambios.append(campo)

    ab = datos.get("revista_abrev") or datos.get("revista_titulo")
    if ab and (preferir_doi_revista or not getattr(art, "revista_abrev", "")):
        if getattr(art, "revista_abrev", "") != ab:
            art.revista_abrev = ab
            cambios.append("revista_abrev")

    for campo in ("issn_electronico", "issn_impreso", "volumen", "numero", "fpage", "lpage"):
        val = datos.get(campo, "")
        if val and not getattr(art, campo, ""):
            setattr(art, campo, val)
            cambios.append(campo)

    fecha = datos.get("fecha_publicado", "")
    if fecha and not getattr(art, "fecha_publicado", ""):
        art.fecha_publicado = fecha
        p = fecha.split("-")
        if p and not getattr(art, "anio", ""):
            art.anio = p[0]
        if len(p) > 1 and not getattr(art, "mes", ""):
            art.mes = str(int(p[1]))
        if len(p) > 2 and not getattr(art, "dia", ""):
            art.dia = str(int(p[2]))
        cambios.append("fecha_publicado")

    lg = (datos.get("idioma") or getattr(art, "idioma", "") or "es").lower().split("-")[0]
    titulo = datos.get("titulo", "")
    if titulo:
        if not getattr(art, "titulos", None):
            art.titulos = {lg: titulo}
            art.idioma = lg
            cambios.append("titulos")
        elif lg not in art.titulos:
            art.titulos[lg] = titulo
            cambios.append("titulos")

    if datos.get("licencia_url") and not getattr(art, "licencia_url", ""):
        art.licencia_url = datos["licencia_url"]
        cambios.append("licencia_url")
    if datos.get("licencia") and not getattr(art, "licencia", ""):
        art.licencia = datos["licencia"]
        cambios.append("licencia")

    # Keywords del BibTeX solo completan cuando el PDF no produjo ninguna lista.
    kws = datos.get("keywords_bibtex") or []
    if kws and not getattr(art, "keywords", None):
        lgkw = (datos.get("idioma") or getattr(art, "idioma", "") or "es").lower().split("-")[0]
        art.keywords = {lgkw: kws}
        cambios.append("keywords")

    cambios.extend(_enriquecer_autores(art, datos.get("autores") or []))
    return sorted(set(cambios))


def enriquecer_desde_doi(art, forzar=False):
    res = consultar_doi(getattr(art, "doi", ""), forzar=forzar,
                       issn_hint=getattr(art, "issn_electronico", "") or getattr(art, "issn_impreso", ""))
    if not res["ok"]:
        return {**res, "cambios": []}
    cambios = aplicar_al_articulo(art, res["datos"])
    return {**res, "cambios": cambios}
