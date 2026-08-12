"""Estado de cada campo para el margen de correccion.

Tres estados y nada mas, porque el editor tiene que poder decidir de un vistazo:

    ok     el dato vino del PDF sin ambiguedad
    duda   se infirio, se emparejo por posicion o el perfil lo exige y falta algo
    falta  no hay dato y el perfil de salida lo necesita

Un campo pasa a "ok" tambien cuando el editor lo confirma o lo corrige a mano.
"""

# campo -> (etiqueta visible, obligatorio en, ruta en el modelo)
CAMPOS = [
    ("revista_titulo", "Revista", ("jats", "sps", "wos")),
    ("issn_electronico", "ISSN electrónico", ()),
    ("issn_impreso", "ISSN impreso", ()),
    ("editorial", "Editorial", ("sps", "wos")),
    ("doi", "DOI", ("jats", "sps", "wos")),
    ("pid_scielo", "PID SciELO", ()),
    ("volumen", "Volumen", ("sps", "wos")),
    ("numero", "Número", ()),
    ("fpage", "Página inicial", ("sps",)),
    ("lpage", "Página final", ("sps",)),
    ("anio", "Año", ("jats", "sps", "wos")),
    ("fecha_recibido", "Recibido", ()),
    ("fecha_aceptado", "Aceptado", ()),
    ("fecha_publicado", "Publicado", ("sps",)),
    ("licencia", "Licencia", ("sps",)),
    # La URL la deriva automáticamente la aplicación a partir de la licencia CC elegida.
    ("licencia_url", "URL de licencia", ()),
]

GRUPOS = [
    ("titulos", "Títulos", ("jats", "sps", "wos")),
    ("autores", "Autores", ("jats", "sps", "wos")),
    ("afiliaciones", "Afiliaciones", ("sps", "wos")),
    ("resumenes", "Resúmenes", ("sps",)),
    ("keywords", "Palabras clave", ("sps",)),
    ("secciones", "Cuerpo", ("sps",)),
    ("referencias", "Referencias", ()),
]


def _estado(tiene, obligatorio, dudoso):
    if dudoso:
        return "duda"
    if tiene:
        return "ok"
    return "falta" if obligatorio else "vacio"


def evaluar(art, perfil="sps"):
    """Devuelve la ficha de estados que dibuja el margen."""
    d = art if isinstance(art, dict) else art.__dict__
    revisado = d.get("revisado") or {}
    alertas = " ".join(d.get("alertas") or []).lower()
    out = {}

    for campo, etiqueta, perfiles in CAMPOS:
        valor = d.get(campo) or ""
        obligatorio = perfil in perfiles
        est = _estado(bool(valor), obligatorio, False)
        if revisado.get(campo):
            est = "ok"
        out[campo] = {"etiqueta": etiqueta, "estado": est, "obligatorio": obligatorio}

    for campo, etiqueta, perfiles in GRUPOS:
        valor = d.get(campo) or []
        obligatorio = perfil in perfiles
        n = len(valor)
        dudoso = False
        if campo == "autores":
            dudoso = any("orden de aparicion" in a or "posicion" in a
                         for a in (d.get("alertas") or []))
            if perfil == "sps" and valor:
                tiene_orcid = any((x.get("orcid") if isinstance(x, dict) else x.orcid) for x in valor)
                if not tiene_orcid:
                    dudoso = True
        if campo == "afiliaciones":
            dudoso = "nota" in alertas and "afiliacion" in alertas
        if campo == "referencias":
            dudoso = "segmentadas por patron" in alertas
        if campo == "resumenes":
            textos = list(valor.values()) if isinstance(valor, dict) else []
            dudoso = any("[REVISAR" in t for t in textos)
        est = _estado(n > 0, obligatorio, dudoso and n > 0)
        if revisado.get(campo):
            est = "ok"
        out[campo] = {"etiqueta": etiqueta, "estado": est,
                      "obligatorio": obligatorio, "n": n}
    return out


def pendientes(ficha):
    return [k for k, v in ficha.items() if v["estado"] in ("duda", "falta")]


def resumen(ficha):
    c = {"ok": 0, "duda": 0, "falta": 0, "vacio": 0}
    for v in ficha.values():
        c[v["estado"]] += 1
    total = sum(c.values()) - c["vacio"]
    listo = c["ok"]
    return {"conteo": c, "listo": listo, "total": max(1, total),
            "porcentaje": round(100 * listo / max(1, total))}
