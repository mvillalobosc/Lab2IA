"""Búsqueda asistida de DOI para referencias bibliográficas.

Usa la API REST pública de Crossref con ``query.bibliographic``. No asigna un
DOI por el mero orden del resultado: calcula una similitud local entre los
metadatos ya extraídos de la referencia y cada candidato. De este modo la
interfaz puede mostrar sugerencias y el modo por lote solo completa coincidencias
con confianza alta.
"""
from __future__ import annotations

import json
import os
import re
import threading
import time
import unicodedata
from difflib import SequenceMatcher
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .doi_metadata import normalizar_doi

_CACHE = {}
_LOCK = threading.Lock()
_ULTIMA_LISTA = 0.0


def _texto(v):
    if isinstance(v, list):
        return _texto(v[0]) if v else ""
    if v is None:
        return ""
    return re.sub(r"\s+", " ", str(v)).strip()


def _norm(s):
    s = unicodedata.normalize("NFKD", _texto(s)).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"https?://(?:dx\.)?doi\.org/\S+", " ", s)
    s = re.sub(r"\bdoi\s*:\s*\S+", " ", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _sim(a, b):
    a, b = _norm(a), _norm(b)
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


def _anio(m):
    for k in ("published-print", "published-online", "published", "issued", "created"):
        o = m.get(k) or {}
        try:
            p = o.get("date-parts") or []
            if p and p[0]:
                return str(p[0][0])
        except Exception:
            pass
    return ""


def _autores(m):
    out = []
    for a in m.get("author") or []:
        if not isinstance(a, dict):
            continue
        out.append({
            "nombres": _texto(a.get("given")),
            "apellidos": _texto(a.get("family")),
        })
    return out[:30]


def _tipo(t):
    return {
        "journal-article": "journal",
        "book-chapter": "chapter",
        "proceedings-article": "confproc",
        "dissertation": "thesis",
        "posted-content": "webpage",
        "book": "book",
        "monograph": "book",
        "reference-entry": "chapter",
    }.get(t or "", "other")


def _candidato(m):
    fuente = _texto(m.get("container-title")) or _texto(m.get("publisher"))
    return {
        "doi": normalizar_doi(m.get("DOI") or ""),
        "titulo": _texto(m.get("title")),
        "fuente": fuente,
        "anio": _anio(m),
        "volumen": _texto(m.get("volume")),
        "numero": _texto(m.get("issue")),
        "paginas": _texto(m.get("page")),
        "tipo": _tipo(_texto(m.get("type"))),
        "url": _texto(m.get("URL")),
        "autores": _autores(m),
        "score_crossref": float(m.get("score") or 0.0),
    }


def _apellidos_ref(ref):
    out = []
    for a in (ref.get("autores") if isinstance(ref, dict) else getattr(ref, "autores", [])) or []:
        ap = a.get("apellidos", "") if isinstance(a, dict) else getattr(a, "apellidos", "")
        if ap:
            out.append(_norm(ap))
    return set(filter(None, out))


def puntuar(ref, cand):
    """Puntaje 0..1 para decidir si un candidato corresponde a una referencia."""
    get = ref.get if isinstance(ref, dict) else lambda k, d="": getattr(ref, k, d)
    titulo_ref = get("titulo", "")
    fuente_ref = get("fuente", "")
    anio_ref = str(get("anio", "") or "")
    texto_ref = get("texto_plano", "")

    # El título es la evidencia principal. Cuando el parser no lo obtuvo, la
    # cita completa sirve como respaldo, pero con menor peso.
    st = _sim(titulo_ref, cand.get("titulo", "")) if titulo_ref else 0.0
    sf = _sim(fuente_ref, cand.get("fuente", "")) if fuente_ref else 0.0
    sr = _sim(texto_ref, " ".join([
        " ".join(a.get("apellidos", "") for a in cand.get("autores", [])),
        cand.get("anio", ""), cand.get("titulo", ""), cand.get("fuente", ""),
        cand.get("volumen", ""), cand.get("numero", ""), cand.get("paginas", ""),
    ])) if texto_ref else 0.0

    ay = 1.0 if anio_ref and cand.get("anio") == anio_ref else (0.0 if anio_ref else 0.5)
    ar = _apellidos_ref(ref)
    ac = {_norm(a.get("apellidos", "")) for a in cand.get("autores", []) if a.get("apellidos")}
    aa = (len(ar & ac) / max(1, len(ar))) if ar else 0.5

    if titulo_ref:
        score = 0.68 * st + 0.12 * ay + 0.10 * sf + 0.10 * aa
    else:
        score = 0.66 * sr + 0.14 * ay + 0.10 * sf + 0.10 * aa

    # Un año explícito en conflicto es una señal fuerte en contra.
    if anio_ref and cand.get("anio") and anio_ref != cand.get("anio"):
        score -= 0.12
    return max(0.0, min(1.0, score))


def _esperar_lista():
    """Respeta el límite actual de la lista pública de Crossref.

    Con mailto se usa el polite pool; sin mailto se deja >1 s entre consultas.
    """
    global _ULTIMA_LISTA
    mailto = os.getenv("PDF2JATS_CROSSREF_MAILTO", "").strip()
    minimo = 0.36 if mailto else 1.05
    with _LOCK:
        ahora = time.monotonic()
        espera = minimo - (ahora - _ULTIMA_LISTA)
        if espera > 0:
            time.sleep(espera)
        _ULTIMA_LISTA = time.monotonic()


def buscar(ref, limite=3):
    get = ref.get if isinstance(ref, dict) else lambda k, d="": getattr(ref, k, d)
    texto = _texto(get("texto_plano", ""))
    if not texto:
        partes = [get("titulo", ""), get("fuente", ""), get("anio", ""), get("volumen", ""), get("paginas", "")]
        texto = ". ".join(_texto(x) for x in partes if _texto(x))
    if len(texto) < 12:
        return {"ok": False, "error": "referencia demasiado breve para buscar", "candidatos": []}

    clave = _norm(texto)
    if clave in _CACHE:
        return {"ok": True, "fuente": "Crossref", "candidatos": [dict(x) for x in _CACHE[clave]]}

    params = {"query.bibliographic": texto, "rows": max(1, min(5, int(limite)))}
    mailto = os.getenv("PDF2JATS_CROSSREF_MAILTO", "").strip()
    if mailto:
        params["mailto"] = mailto
    url = "https://api.crossref.org/works?" + urlencode(params)
    ua = os.getenv("PDF2JATS_USER_AGENT", "PDF2JATS/1.3 (reference DOI lookup)")
    timeout = float(os.getenv("PDF2JATS_DOI_TIMEOUT", "5.5"))

    try:
        _esperar_lista()
        req = Request(url, headers={"User-Agent": ua, "Accept": "application/json"})
        with urlopen(req, timeout=timeout) as r:
            j = json.loads(r.read().decode("utf-8", errors="replace"))
        items = ((j or {}).get("message") or {}).get("items") or []
    except Exception as e:
        return {"ok": False, "error": f"Crossref: {type(e).__name__}", "candidatos": []}

    cands = []
    for m in items:
        if not isinstance(m, dict):
            continue
        c = _candidato(m)
        if not c["doi"]:
            continue
        c["confianza"] = round(puntuar(ref, c), 3)
        cands.append(c)
    cands.sort(key=lambda x: (-x["confianza"], -x.get("score_crossref", 0.0)))
    _CACHE[clave] = [dict(x) for x in cands]
    return {"ok": True, "fuente": "Crossref", "candidatos": cands}


def aplicar(ref, cand, sobrescribir=False):
    """Aplica metadatos de un candidato a una Referencia o dict."""
    es_dict = isinstance(ref, dict)
    get = ref.get if es_dict else lambda k, d="": getattr(ref, k, d)
    cambios = []

    def setv(campo, valor, siempre=False):
        if valor and (siempre or sobrescribir or not get(campo, "")):
            actual = get(campo, "")
            if actual != valor:
                if es_dict:
                    ref[campo] = valor
                else:
                    setattr(ref, campo, valor)
                cambios.append(campo)

    setv("doi", normalizar_doi(cand.get("doi", "")), siempre=True)
    setv("titulo", cand.get("titulo", ""))
    setv("fuente", cand.get("fuente", ""))
    setv("anio", cand.get("anio", ""))
    setv("volumen", cand.get("volumen", ""))
    setv("numero", cand.get("numero", ""))
    setv("paginas", cand.get("paginas", ""))
    setv("tipo", cand.get("tipo", ""))
    if cand.get("autores") and (sobrescribir or not get("autores", [])):
        if es_dict:
            ref["autores"] = cand["autores"]
        else:
            ref.autores = cand["autores"]
        cambios.append("autores")
    # DOI es preferible al URL de landing de Crossref; conserva URL externa ya extraída.
    return cambios
