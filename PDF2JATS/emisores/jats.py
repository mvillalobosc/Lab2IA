"""Emisor NISO JATS 1.3 Journal Publishing (el sabor 'Blue').
Este es el punto de partida: SciELO PS y el perfil Clarivate se derivan de aca.
"""
from .base import Buffer, esc

DOCTYPE = ('<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) '
           'Journal Publishing DTD v1.3 20210610//EN" '
           '"https://jats.nlm.nih.gov/publishing/1.3/JATS-journalpublishing1-3.dtd">')


def emitir(a, perfil="jats"):
    b = Buffer()
    b.crudo('<?xml version="1.0" encoding="UTF-8"?>')
    b.crudo(DOCTYPE)
    b.abrir("article",
            **{"xmlns:xlink": "http://www.w3.org/1999/xlink",
               "xmlns:mml": "http://www.w3.org/1998/Math/MathML",
               "dtd-version": "1.3",
               "article-type": a.tipo_articulo,
               "xml:lang": a.idioma})
    _front(b, a)
    _body(b, a)
    _back(b, a)
    b.cerrar("article")
    return b.texto()


def _front(b, a):
    b.abrir("front")
    b.abrir("journal-meta")
    b.hoja("journal-id", a.revista_codigo or a.revista_abrev, **{"journal-id-type": "publisher-id"})
    b.abrir("journal-title-group")
    b.hoja("journal-title", a.revista_titulo)
    b.hoja("abbrev-journal-title", a.revista_abrev, **{"abbrev-type": "publisher"})
    b.cerrar("journal-title-group")
    if a.issn_electronico:
        b.hoja("issn", a.issn_electronico, **{"pub-type": "epub"})
    if a.issn_impreso:
        b.hoja("issn", a.issn_impreso, **{"pub-type": "ppub"})
    b.abrir("publisher")
    b.hoja("publisher-name", a.editorial)
    b.cerrar("publisher")
    b.cerrar("journal-meta")

    b.abrir("article-meta")
    if a.pid_scielo:
        b.hoja("article-id", a.pid_scielo, **{"pub-id-type": "publisher-id"})
    if a.doi:
        b.hoja("article-id", a.doi, **{"pub-id-type": "doi"})

    b.abrir("title-group")
    princ = a.idioma if a.idioma in a.titulos else (list(a.titulos)[0] if a.titulos else "es")
    b.hoja("article-title", a.titulos.get(princ, ""), **{"xml:lang": princ})
    otros = [k for k in a.titulos if k != princ]
    if otros:
        b.abrir("trans-title-group") if False else None
        for lg in otros:
            b.crudo(f'<trans-title-group xml:lang="{lg}">')
            b.niv += 1
            b.hoja("trans-title", a.titulos[lg])
            b.niv -= 1
            b.crudo("</trans-title-group>")
    b.cerrar("title-group")

    if a.autores:
        b.abrir("contrib-group")
        for au in a.autores:
            b.abrir("contrib", **{"contrib-type": "author",
                                  "corresp": "yes" if au.correspondencia else ""})
            if au.orcid:
                b.hoja("contrib-id", au.orcid.replace("https://orcid.org/", "").replace("http://orcid.org/", ""),
                       **{"contrib-id-type": "orcid"})
            b.abrir("name")
            b.hoja("surname", au.apellidos)
            b.hoja("given-names", au.nombres)
            b.cerrar("name")
            for rid in au.aff_ids:
                b.hoja("xref", "", vacio_ok=True, **{"ref-type": "aff", "rid": rid})
            if au.email:
                b.hoja("email", au.email)
            b.cerrar("contrib")
        b.cerrar("contrib-group")

    for af in a.afiliaciones:
        b.abrir("aff", id=af.id)
        b.hoja("institution", af.institucion, **{"content-type": "orgname"})
        if af.ror:
            b.hoja("institution-id", af.ror, **{"institution-id-type": "ror"})
        b.hoja("addr-line", af.ciudad) if af.ciudad else None
        b.hoja("country", af.pais)
        b.cerrar("aff")

    if a.fecha_recibido or a.fecha_aceptado:
        b.abrir("history")
        for tipo, f in (("received", a.fecha_recibido), ("accepted", a.fecha_aceptado)):
            if f:
                _fecha(b, "date", f, **{"date-type": tipo})
        b.cerrar("history")

    if a.licencia:
        b.abrir("permissions")
        b.hoja("copyright-statement", f"© {a.anio} {a.editorial}".strip())
        b.hoja("copyright-year", a.anio)
        b.abrir("license", **{"license-type": "open-access",
                              "xlink:href": a.licencia_url,
                              "xml:lang": a.idioma})
        b.abrir("license-p")
        b.crudo(esc(a.licencia))
        b.cerrar("license-p")
        b.cerrar("license")
        b.cerrar("permissions")

    if a.fecha_publicado or a.anio:
        _fecha(b, "pub-date", a.fecha_publicado or a.anio,
               **{"date-type": "pub", "publication-format": "electronic"})
    b.hoja("volume", a.volumen)
    b.hoja("issue", a.numero)
    b.hoja("fpage", a.fpage)
    b.hoja("lpage", a.lpage)

    for lg, txt in a.resumenes.items():
        etq = "abstract" if lg == a.idioma else "trans-abstract"
        b.crudo(f'<{etq} xml:lang="{lg}">')
        b.niv += 1
        b.hoja("p", txt)
        b.niv -= 1
        b.crudo(f"</{etq}>")

    for lg, kws in a.keywords.items():
        b.abrir("kwd-group", **{"xml:lang": lg})
        for k in kws:
            b.hoja("kwd", k)
        b.cerrar("kwd-group")

    if a.financiamiento:
        b.abrir("funding-group")
        for f in a.financiamiento:
            b.abrir("funding-statement") if False else None
            b.hoja("funding-statement", f)
        b.cerrar("funding-group")

    b.cerrar("article-meta")
    b.cerrar("front")


def _fecha(b, etq, valor, **at):
    partes = (valor or "").split("-")
    b.abrir(etq, **at)
    if len(partes) == 3:
        b.hoja("day", partes[2])
        b.hoja("month", partes[1])
        b.hoja("year", partes[0])
    else:
        b.hoja("year", partes[0])
    b.cerrar(etq)


def _body(b, a):
    if not a.secciones:
        return
    b.abrir("body")
    n = 0
    for s in a.secciones:
        n += 1
        b.abrir("sec", id=f"sec{n}", **{"sec-type": _sec_type(s.titulo)})
        if s.titulo:
            b.hoja("title", s.titulo)
        for p in s.parrafos:
            b.hoja("p", p)
        b.cerrar("sec")
    b.cerrar("body")


def _sec_type(t):
    import re
    t = (t or "").lower()
    mapa = [(r"introducci|introduction|introdu", "intro"),
            (r"m[eé]todo|metodolog|methods|methodolog", "methods"),
            (r"resultado|results", "results"),
            (r"discusi|discussion|discuss", "discussion"),
            (r"conclusi|conclus", "conclusions"),
            (r"agradec|acknowledg", "acknowledgments")]
    for p, v in mapa:
        if re.search(p, t):
            return v
    return ""


def _back(b, a):
    if not a.referencias:
        return
    b.abrir("back")
    b.abrir("ref-list")
    b.hoja("title", "Referencias")
    for r in a.referencias:
        b.abrir("ref", id=r.id)
        b.hoja("label", str(r.orden))
        b.abrir("element-citation", **{"publication-type": r.tipo})
        if r.autores:
            b.abrir("person-group", **{"person-group-type": "author"})
            for au in r.autores:
                b.abrir("name")
                b.hoja("surname", au.get("apellidos", ""))
                b.hoja("given-names", au.get("nombres", ""))
                b.cerrar("name")
            b.cerrar("person-group")
        b.hoja("article-title", r.titulo)
        b.hoja("source", r.fuente)
        b.hoja("year", r.anio)
        b.hoja("volume", r.volumen)
        b.hoja("issue", r.numero)
        if r.paginas and "-" in r.paginas:
            fp, _, lp = r.paginas.partition("-")
            b.hoja("fpage", fp)
            b.hoja("lpage", lp)
        if r.doi:
            b.hoja("pub-id", r.doi, **{"pub-id-type": "doi"})
        if r.url:
            b.hoja("ext-link", r.url, **{"ext-link-type": "uri", "xlink:href": r.url})
        b.cerrar("element-citation")
        b.cerrar("ref")
    b.cerrar("ref-list")
    b.cerrar("back")
