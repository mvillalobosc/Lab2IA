"""Dos perfiles derivados del mismo modelo:

- SciELO PS (SPS): JATS Publishing 1.1 mas el Estilo SciELO. Exige UTF-8,
  identificador scielo-v3, specific-use con la version de SPS, sec-type y
  atributos de licencia normalizados.
- Clarivate / xmlwos: el formato heredado con que SciELO alimenta al
  SciELO Citation Index de Web of Science. Solo metadatos, sin body, con
  etiquetas del NLM DTD antiguo (nlm-citation) y el elemento propio <numero>.
"""
from .base import Buffer, esc

SPS_VERSION = "sps-1.10"
DOCTYPE_SPS = ('<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) '
               'Journal Publishing DTD v1.1 20151215//EN" '
               '"https://jats.nlm.nih.gov/publishing/1.1/JATS-journalpublishing1.dtd">')


# ---------------------------------------------------------------- SciELO PS
def emitir_sps(a):
    from .jats import emitir as emitir_jats
    xml = emitir_jats(a)
    xml = xml.replace('dtd-version="1.3"', f'dtd-version="1.1" specific-use="{SPS_VERSION}"')
    xml = xml.replace(
        '<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Publishing '
        'DTD v1.3 20210610//EN" "https://jats.nlm.nih.gov/publishing/1.3/'
        'JATS-journalpublishing1-3.dtd">', DOCTYPE_SPS)
    # el Estilo SciELO exige element-citation, no mixed
    return xml


def alertas_sps(a):
    """Advertencias de revisión para SciELO PS 1.10.

    Se evita presentar como obligatorios campos que el esquema general admite
    como opcionales. Las reglas específicas de una colección pueden ser más
    estrictas y deben comprobarse en la normativa enlazada por la interfaz.
    """
    al = []
    if not a.licencia:
        al.append("SPS 1.10: falta seleccionar una licencia Creative Commons")
    elif not a.licencia_url:
        al.append("SPS 1.10: la licencia no tiene una URL oficial válida (xlink:href)")
    if not (a.issn_electronico or a.issn_impreso):
        al.append("SPS 1.10: falta ISSN de la revista (epub o ppub)")
    if not a.secciones:
        al.append("SPS 1.10: falta el cuerpo del artículo (body)")
    # En SPS 1.10 se exige ORCID para al menos un autor, no para todos.
    if a.autores and not any(getattr(au, "orcid", "") for au in a.autores):
        al.append("SPS 1.10: al menos un autor debe tener ORCID")
    return al


# ------------------------------------------------------------ Clarivate/WoS
def emitir_wos(a):
    b = Buffer()
    b.crudo('<?xml version="1.0" encoding="ISO-8859-1"?>')
    b.abrir("article", **{"xmlns:mml": "http://www.w3.org/1998/Math/MathML",
                          "xmlns:xlink": "http://www.w3.org/1999/xlink",
                          "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance"})
    b.abrir("front")
    b.abrir("journal-meta")
    b.hoja("journal-id", a.issn_electronico or a.issn_impreso)
    b.crudo(f"<journal-title><![CDATA[{a.revista_titulo}]]></journal-title>")
    b.crudo(f"<abbrev-journal-title><![CDATA[{a.revista_abrev}]]></abbrev-journal-title>")
    b.hoja("issn", a.issn_electronico or a.issn_impreso)
    b.abrir("publisher")
    b.crudo(f"<publisher-name><![CDATA[{a.editorial}]]></publisher-name>")
    b.cerrar("publisher")
    b.cerrar("journal-meta")

    b.abrir("article-meta")
    if a.pid_scielo:
        b.hoja("article-id", a.pid_scielo)
    if a.doi:
        b.hoja("article-id", a.doi, **{"pub-id-type": "doi"})
    b.abrir("title-group")
    for lg, t in a.titulos.items():
        b.crudo(f'<article-title xml:lang="{lg}"><![CDATA[{t}]]></article-title>')
    b.cerrar("title-group")

    b.abrir("contrib-group")
    for au in a.autores:
        b.abrir("contrib", **{"contrib-type": "author"})
        b.abrir("name")
        b.crudo(f"<surname><![CDATA[{au.apellidos}]]></surname>")
        b.crudo(f"<given-names><![CDATA[{au.nombres}]]></given-names>")
        b.cerrar("name")
        for rid in au.aff_ids:
            b.hoja("xref", "", vacio_ok=True, **{"ref-type": "aff", "rid": rid})
        b.cerrar("contrib")
    b.cerrar("contrib-group")

    for af in a.afiliaciones:
        b.abrir("aff", id=af.id)
        b.crudo(f"<institution><![CDATA[{af.institucion}]]></institution>")
        if af.ciudad:
            b.crudo(f"<addr-line><![CDATA[{af.ciudad}]]></addr-line>")
        b.hoja("country", af.pais)
        b.cerrar("aff")

    for tipo in ("pub", "epub"):
        b.abrir("pub-date", **{"pub-type": tipo})
        b.hoja("day", a.dia or "00", vacio_ok=True)
        b.hoja("month", a.mes or "00", vacio_ok=True)
        b.hoja("year", a.anio, vacio_ok=True)
        b.cerrar("pub-date")
    b.hoja("volume", a.volumen)
    b.hoja("numero", a.numero)
    b.hoja("fpage", a.fpage)
    b.hoja("lpage", a.lpage)
    b.hoja("copyright-statement", f"© {a.anio} {a.editorial}".strip() if a.anio else "",
           vacio_ok=True)
    b.hoja("copyright-year", a.anio, vacio_ok=True)

    for lg, txt in a.resumenes.items():
        b.crudo(f'<abstract abstract-type="short" xml:lang="{lg}">'
                f"<p><![CDATA[{txt}]]></p></abstract>")
    for lg, kws in a.keywords.items():
        b.abrir("kwd-group", **{"xml:lang": lg})
        for k in kws:
            b.crudo(f"<kwd><![CDATA[{k}]]></kwd>")
        b.cerrar("kwd-group")
    b.cerrar("article-meta")
    b.cerrar("front")

    if a.referencias:
        b.abrir("back")
        b.abrir("ref-list")
        for r in a.referencias:
            b.abrir("ref", id=r.id)
            b.abrir("nlm-citation", **{"citation-type": _tipo_wos(r.tipo)})
            if r.autores:
                b.abrir("person-group", **{"person-group-type": "author"})
                for au in r.autores:
                    b.abrir("name")
                    b.crudo(f"<surname><![CDATA[{au.get('apellidos','')}]]></surname>")
                    b.crudo(f"<given-names><![CDATA[{au.get('nombres','')}]]></given-names>")
                    b.cerrar("name")
                b.cerrar("person-group")
            if r.titulo:
                b.crudo(f'<article-title xml:lang=""><![CDATA[{r.titulo}]]></article-title>')
            if r.fuente:
                b.crudo(f"<source><![CDATA[{r.fuente}]]></source>")
            b.hoja("year", r.anio)
            b.hoja("volume", r.volumen)
            b.hoja("numero", r.numero)
            b.hoja("issue", r.numero)
            b.hoja("page-range", r.paginas)
            if r.doi:
                b.hoja("pub-id", r.doi, **{"pub-id-type": "doi"})
            b.cerrar("nlm-citation")
            b.cerrar("ref")
        b.cerrar("ref-list")
        b.cerrar("back")
    b.cerrar("article")
    return b.texto()


def _tipo_wos(t):
    return {"journal": "journal", "book": "book", "chapter": "book",
            "thesis": "thesis", "webpage": "web"}.get(t, "other")
