"""Servidor de la mesa de corrección.

    pip install -r requirements.txt
    python3 app.py
    http://127.0.0.1:5000

La sesión vive en memoria del proceso. Para producción hay que persistirla.
"""
import io
import json
import os
import shutil
import tempfile
import uuid
import zipfile

from flask import Flask, Response, jsonify, request, send_file

from core.extractor import extraer
from core import doi_metadata, reference_metadata, scielo_metadata
from core.model import Articulo, Autor, Afiliacion, Referencia, Seccion
from core.revision import evaluar, pendientes, resumen
from emisores.jats import emitir as emitir_jats
from emisores.scielo import alertas_sps, emitir_sps, emitir_wos

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 120 * 1024 * 1024

SESION = {}
ORDEN = []
PDFS = os.path.join(tempfile.gettempdir(), "pdf2jats_pdfs")
os.makedirs(PDFS, exist_ok=True)

PERFILES = {
    "jats": ("NISO JATS 1.3 Journal Publishing", emitir_jats, "utf-8"),
    "sps": ("SciELO PS 1.10", emitir_sps, "utf-8"),
    "wos": ("Clarivate / SciELO Citation Index", emitir_wos, "iso-8859-1"),
}

AQUI = os.path.dirname(os.path.abspath(__file__))


LICENCIAS_CC = {
    "CC BY 4.0": "https://creativecommons.org/licenses/by/4.0/",
    "CC BY-NC 4.0": "https://creativecommons.org/licenses/by-nc/4.0/",
    "CC BY-NC-ND 4.0": "https://creativecommons.org/licenses/by-nc-nd/4.0/",
    "CC BY 3.0": "https://creativecommons.org/licenses/by/3.0/",
    "CC BY-NC 3.0": "https://creativecommons.org/licenses/by-nc/3.0/",
    "CC BY-NC-ND 3.0": "https://creativecommons.org/licenses/by-nc-nd/3.0/",
}


def _licencia_canonica(licencia="", url=""):
    """Devuelve (nombre, URL) para licencias Creative Commons aceptadas por la UI.

    La URL nunca se toma de texto libre del editor: se deriva del tipo de licencia.
    """
    u = str(url or "").strip().lower().replace("http://", "https://")
    for nombre, href in LICENCIAS_CC.items():
        if u.rstrip("/") == href.rstrip("/"):
            return nombre, href
    t = " ".join(str(licencia or "").upper().replace("_", "-").split())
    version = "3.0" if "3.0" in t else "4.0"
    if ("BY-NC-ND" in t or ("NONCOMMERCIAL" in t and "NODERIV" in t)):
        nombre = f"CC BY-NC-ND {version}"
    elif ("BY-NC" in t or "NONCOMMERCIAL" in t):
        nombre = f"CC BY-NC {version}"
    elif ("CC BY" in t or "CREATIVE COMMONS ATTRIBUTION" in t):
        nombre = f"CC BY {version}"
    else:
        return "", ""
    return (nombre, LICENCIAS_CC.get(nombre, ""))


def _normalizar_licencia_obj(a):
    nombre, href = _licencia_canonica(getattr(a, "licencia", ""), getattr(a, "licencia_url", ""))
    a.licencia = nombre
    a.licencia_url = href
    return a


def _normalizar_licencia_dict(d):
    nombre, href = _licencia_canonica(d.get("licencia", ""), d.get("licencia_url", ""))
    d["licencia"] = nombre
    d["licencia_url"] = href
    return d



def rehidratar(d):
    a = Articulo(**{k: v for k, v in d.items()
                    if k not in ("autores", "afiliaciones", "referencias", "secciones")})
    a.autores = [Autor(**x) for x in d.get("autores", [])]
    a.afiliaciones = [Afiliacion(**x) for x in d.get("afiliaciones", [])]
    a.referencias = [Referencia(**x) for x in d.get("referencias", [])]
    a.secciones = [Seccion(**x) for x in d.get("secciones", [])]
    return a


def ficha(sid, perfil):
    d = SESION[sid]
    f = evaluar(d, perfil)
    return {"sid": sid, "archivo": d.get("archivo"), "estados": f,
            "resumen": resumen(f), "pendientes": pendientes(f)}


@app.route("/")
def index():
    with open(os.path.join(AQUI, "web", "index.html"), encoding="utf-8") as fh:
        return Response(fh.read(), mimetype="text/html")


@app.route("/web/<path:archivo>")
def estatico(archivo):
    """Sirve recursos de la interfaz, incluidos archivos binarios como el logo."""
    ruta = os.path.join(AQUI, "web", archivo)
    if not os.path.isfile(ruta):
        return "no encontrado", 404
    return send_file(ruta)


@app.route("/api/extraer", methods=["POST"])
def api_extraer():
    salida = []
    for f in request.files.getlist("pdfs"):
        if not f.filename.lower().endswith(".pdf"):
            salida.append({"archivo": f.filename,
                           "error": "solo se aceptan archivos PDF"})
            continue
        sid = uuid.uuid4().hex[:12]
        destino = os.path.join(PDFS, f"{sid}.pdf")
        f.save(destino)
        try:
            a = extraer(destino)
            _normalizar_licencia_obj(a)
            a.archivo = f.filename
            SESION[sid] = json.loads(a.to_json())
            ORDEN.append(sid)
            salida.append({**ficha(sid, "sps"), "datos": SESION[sid],
                           "alertas": a.alertas + alertas_sps(a)})
        except Exception as e:
            salida.append({"archivo": f.filename,
                           "error": f"no se pudo leer el PDF: {str(e)[:140]}"})
    return jsonify(salida)


@app.route("/api/doi/<sid>", methods=["POST"])
def api_doi(sid):
    """Reconsulta los metadatos del DOI y completa la ficha actual.

    Sirve tanto para reintentar una consulta que fallo durante la carga como para
    usar un DOI corregido manualmente por el editor.
    """
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    payload = request.get_json() or {}
    doi = doi_metadata.normalizar_doi(payload.get("doi") or SESION[sid].get("doi", ""))
    if not doi:
        return jsonify({"error": "ingresa un DOI antes de consultar"}), 400

    a = rehidratar(SESION[sid])
    a.doi = doi
    res = doi_metadata.enriquecer_desde_doi(a, forzar=True)
    sci = scielo_metadata.enriquecer_desde_scielo(a, forzar=True)
    if not res.get("ok") and not sci.get("ok"):
        return jsonify({"error": "no fue posible obtener metadatos para ese DOI",
                        "detalle": "; ".join(x for x in [res.get("error", ""), sci.get("error", "")] if x)}), 502

    if res.get("ok"):
        a.confianza["doi_metadata"] = 0.98
    if sci.get("ok"):
        a.confianza["scielo_metadata"] = 0.99
    _normalizar_licencia_obj(a)
    SESION[sid] = json.loads(a.to_json())
    perfil = payload.get("perfil", "sps")
    fuentes = [x for x in [res.get("fuente", "") if res.get("ok") else "",
                            sci.get("fuente", "") if sci.get("ok") else ""] if x]
    cambios = sorted(set((res.get("cambios") or []) + (sci.get("cambios") or [])))
    return jsonify({**ficha(sid, perfil), "datos": SESION[sid],
                    "alertas": a.alertas + alertas_sps(a),
                    "fuente": " + ".join(fuentes) or "DOI",
                    "cambios": cambios,
                    "scielo": {"encontrado": bool(sci.get("ok")),
                               "pid": getattr(a, "pid_scielo", ""),
                               "url": sci.get("url_articulo", ""),
                               "error": sci.get("error", "")}})


@app.route("/api/scielo/<sid>", methods=["POST"])
def api_scielo(sid):
    """Busca el PID en SciELO usando el DOI. No genera PIDs artificiales."""
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    payload = request.get_json(silent=True) or {}
    doi = doi_metadata.normalizar_doi(payload.get("doi") or SESION[sid].get("doi", ""))
    if not doi:
        return jsonify({"error": "ingresa un DOI antes de buscar en SciELO"}), 400
    a = rehidratar(SESION[sid])
    a.doi = doi
    sci = scielo_metadata.enriquecer_desde_scielo(a, forzar=True)
    if not sci.get("ok"):
        return jsonify({"error": "Ese DOI no aparece publicado en SciELO. El PID se deja vacio.",
                        "detalle": sci.get("error", "")}), 404
    a.confianza["scielo_metadata"] = 0.99
    _normalizar_licencia_obj(a)
    SESION[sid] = json.loads(a.to_json())
    perfil = payload.get("perfil", "sps")
    return jsonify({**ficha(sid, perfil), "datos": SESION[sid],
                    "alertas": a.alertas + alertas_sps(a),
                    "fuente": sci.get("fuente", "SciELO"),
                    "cambios": sci.get("cambios", []),
                    "pid": a.pid_scielo, "url": sci.get("url_articulo", "")})


@app.route("/api/referencia/buscar/<sid>/<int:indice>", methods=["POST"])
def api_referencia_buscar(sid, indice):
    """Busca candidatos DOI para una referencia sin modificarla."""
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    refs = SESION[sid].get("referencias") or []
    if not (0 <= indice < len(refs)):
        return jsonify({"error": "referencia fuera de rango"}), 404
    payload = request.get_json(silent=True) or {}
    # Permite buscar usando el texto recién editado sin exigir un guardado previo.
    ref = dict(refs[indice])
    for k in ("texto_plano", "titulo", "fuente", "anio", "autores"):
        if k in payload:
            ref[k] = payload[k]
    res = reference_metadata.buscar(ref, limite=3)
    codigo = 200 if res.get("ok") else 502
    return jsonify(res), codigo


@app.route("/api/referencia/aplicar/<sid>/<int:indice>", methods=["POST"])
def api_referencia_aplicar(sid, indice):
    """Aplica a una referencia el candidato DOI elegido por el editor."""
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    refs = SESION[sid].get("referencias") or []
    if not (0 <= indice < len(refs)):
        return jsonify({"error": "referencia fuera de rango"}), 404
    payload = request.get_json() or {}
    candidato = payload.get("candidato") or {}
    if not candidato.get("doi"):
        return jsonify({"error": "candidato sin DOI"}), 400
    cambios = reference_metadata.aplicar(refs[indice], candidato, sobrescribir=bool(payload.get("sobrescribir")))
    SESION[sid].setdefault("revisado", {})["referencias"] = True
    perfil = payload.get("perfil", "sps")
    return jsonify({**ficha(sid, perfil), "datos": SESION[sid], "cambios": cambios})


@app.route("/api/referencias/buscar/<sid>", methods=["POST"])
def api_referencias_buscar(sid):
    """Completa DOI faltantes cuando la coincidencia bibliográfica es alta.

    Las coincidencias dudosas no se escriben automáticamente; quedan disponibles
    para búsqueda individual desde la pestaña Referencias.
    """
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    payload = request.get_json(silent=True) or {}
    umbral = float(payload.get("umbral", 0.86))
    refs = SESION[sid].get("referencias") or []
    max_busquedas = max(1, min(80, int(payload.get("max", 60))))
    buscadas = encontradas = aplicadas = 0
    dudosas = []
    errores = []
    for i, ref in enumerate(refs):
        if buscadas >= max_busquedas:
            break
        if ref.get("doi"):
            continue
        buscadas += 1
        res = reference_metadata.buscar(ref, limite=3)
        if not res.get("ok"):
            errores.append({"indice": i, "error": res.get("error", "sin respuesta")})
            continue
        cands = res.get("candidatos") or []
        if not cands:
            continue
        mejor = cands[0]
        encontradas += 1
        if float(mejor.get("confianza") or 0) >= umbral:
            reference_metadata.aplicar(ref, mejor, sobrescribir=float(mejor.get("confianza") or 0) >= 0.90)
            aplicadas += 1
        else:
            dudosas.append({"indice": i, "doi": mejor.get("doi", ""),
                            "titulo": mejor.get("titulo", ""),
                            "confianza": mejor.get("confianza", 0)})
    if aplicadas:
        SESION[sid].setdefault("revisado", {})["referencias"] = True
    perfil = payload.get("perfil", "sps")
    return jsonify({**ficha(sid, perfil), "datos": SESION[sid],
                    "buscadas": buscadas, "encontradas": encontradas,
                    "aplicadas": aplicadas, "dudosas": dudosas,
                    "errores": errores[:10]})


@app.route("/api/pdf/<sid>")
def api_pdf(sid):
    ruta = os.path.join(PDFS, f"{sid}.pdf")
    if not os.path.isfile(ruta):
        return "no encontrado", 404
    return send_file(ruta, mimetype="application/pdf")


@app.route("/api/pagina/<sid>/<int:n>")
def api_pagina(sid, n):
    """Pagina renderizada como imagen. Es mas confiable que incrustar el PDF:
    funciona en cualquier navegador y no obliga a bajar el archivo completo."""
    import pymupdf
    ruta = os.path.join(PDFS, f"{sid}.pdf")
    if not os.path.isfile(ruta):
        return "no encontrado", 404
    doc = pymupdf.open(ruta)
    if not (0 <= n < len(doc)):
        doc.close()
        return "página fuera de rango", 404
    escala = min(3.0, max(1.0, float(request.args.get("escala", 1.6))))
    pix = doc[n].get_pixmap(matrix=pymupdf.Matrix(escala, escala))
    datos = pix.tobytes("png")
    total = len(doc)
    doc.close()
    resp = send_file(io.BytesIO(datos), mimetype="image/png")
    resp.headers["X-Total-Paginas"] = str(total)
    resp.headers["Cache-Control"] = "public, max-age=3600"
    return resp


@app.route("/api/paginas/<sid>")
def api_paginas(sid):
    import pymupdf
    ruta = os.path.join(PDFS, f"{sid}.pdf")
    if not os.path.isfile(ruta):
        return jsonify({"error": "no encontrado"}), 404
    doc = pymupdf.open(ruta)
    n = len(doc)
    doc.close()
    return jsonify({"total": n})


@app.route("/api/articulo/<sid>")
def api_articulo(sid):
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    perfil = request.args.get("perfil", "sps")
    a = rehidratar(SESION[sid])
    return jsonify({**ficha(sid, perfil), "datos": SESION[sid],
                    "alertas": a.alertas + alertas_sps(a)})


@app.route("/api/guardar/<sid>", methods=["POST"])
def api_guardar(sid):
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    cambios = request.get_json() or {}
    perfil = cambios.pop("_perfil", "sps")
    SESION[sid].update(cambios)
    _normalizar_licencia_dict(SESION[sid])
    return jsonify(ficha(sid, perfil))


@app.route("/api/revisar/<sid>/<campo>", methods=["POST"])
def api_revisar(sid, campo):
    """Marca un campo como verificado por el editor."""
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    estado = (request.get_json() or {}).get("valor", True)
    SESION[sid].setdefault("revisado", {})[campo] = bool(estado)
    return jsonify(ficha(sid, request.args.get("perfil", "sps")))


@app.route("/api/propagar/<sid>", methods=["POST"])
def api_propagar(sid):
    """Copia los datos de revista de un articulo al resto del lote.
    Evita reescribir la misma ficha veinte veces en un numero completo."""
    if sid not in SESION:
        return jsonify({"error": "no encontrado"}), 404
    campos = (request.get_json() or {}).get(
        "campos", ["revista_titulo", "revista_abrev", "issn_electronico",
                   "issn_impreso", "editorial", "volumen", "numero", "anio"])
    origen = SESION[sid]
    n = 0
    for otro, d in SESION.items():
        if otro == sid:
            continue
        for c in campos:
            if origen.get(c):
                d[c] = origen[c]
        n += 1
    return jsonify({"actualizados": n, "campos": campos})


@app.route("/api/xml/<sid>/<perfil>")
def api_xml(sid, perfil):
    if sid not in SESION or perfil not in PERFILES:
        return jsonify({"error": "no encontrado"}), 404
    a = rehidratar(SESION[sid])
    return jsonify({"xml": PERFILES[perfil][1](a)})


@app.route("/api/descargar/<sid>/<perfil>")
def api_descargar(sid, perfil):
    if sid not in SESION or perfil not in PERFILES:
        return jsonify({"error": "no encontrado"}), 404
    a = rehidratar(SESION[sid])
    _, fn, enc = PERFILES[perfil]
    nombre = os.path.splitext(a.archivo or "articulo")[0].replace(" ", "_")
    buf = io.BytesIO(fn(a).encode(enc, errors="xmlcharrefreplace"))
    return send_file(buf, mimetype="application/xml", as_attachment=True,
                     download_name=f"{nombre}.{perfil}.xml")


@app.route("/api/lote/<perfil>")
def api_lote(perfil):
    if perfil not in PERFILES:
        return jsonify({"error": "perfil no válido"}), 404
    _, fn, enc = PERFILES[perfil]
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for sid in ORDEN:
            if sid not in SESION:
                continue
            a = rehidratar(SESION[sid])
            nombre = os.path.splitext(a.archivo or sid)[0].replace(" ", "_")
            z.writestr(f"{nombre}.{perfil}.xml",
                       fn(a).encode(enc, errors="xmlcharrefreplace"))
    buf.seek(0)
    return send_file(buf, mimetype="application/zip", as_attachment=True,
                     download_name=f"xml_{perfil}.zip")


@app.route("/api/cola")
def api_cola():
    perfil = request.args.get("perfil", "sps")
    return jsonify([ficha(s, perfil) for s in ORDEN if s in SESION])


@app.route("/api/quitar/<sid>", methods=["POST"])
def api_quitar(sid):
    SESION.pop(sid, None)
    if sid in ORDEN:
        ORDEN.remove(sid)
    ruta = os.path.join(PDFS, f"{sid}.pdf")
    if os.path.isfile(ruta):
        os.remove(ruta)
    return jsonify({"ok": True})


@app.route("/api/limpiar", methods=["POST"])
def api_limpiar():
    SESION.clear()
    ORDEN.clear()
    shutil.rmtree(PDFS, ignore_errors=True)
    os.makedirs(PDFS, exist_ok=True)
    return jsonify({"ok": True})


if __name__ == "__main__":
    app.run(debug=False, port=5000)
