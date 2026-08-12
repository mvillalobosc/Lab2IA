"""Extraccion del front matter. Trabaja sobre las primeras paginas, que es donde
las revistas concentran los metadatos. Cada extractor devuelve tambien una senal
de confianza para que la interfaz sepa que pedirle al humano.
"""
import re
import unicodedata

RE_DOI = re.compile(r"\b10\.\d{4,9}/[^\s\"'<>,;)\]]+", re.I)
RE_ORCID = re.compile(r"\b(\d{4}-\d{4}-\d{4}-\d{3}[\dXx])\b")
RE_EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
RE_ISSN = re.compile(r"ISSN[\s:]*(?:electr[oó]nico|impreso|-e|e-|en l[ií]nea)?[\s:]*(\d{4}-\d{3}[\dXx])", re.I)
RE_ANIO = re.compile(r"\b(19\d{2}|20\d{2})\b")

MESES = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
    "julio": 7, "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10,
    "noviembre": 11, "diciembre": 12,
    "janeiro": 1, "fevereiro": 2, "marco": 3, "março": 3, "abril_pt": 4, "maio": 5,
    "junho": 6, "julho": 7, "agosto_pt": 8, "setembro": 9, "outubro": 10,
    "novembro": 11, "dezembro": 12,
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12,
}

# muchas revistas adornan el marcador: "[ RESUMEN ]", "-> Abstract", "| RESUMO |"
_ADORNO = r"^[\s\[\(\|►→▪•·\-–—*]{0,6}"
_CIERRE = r"[\s\]\)\|:.]{0,6}"
MARCA_RESUMEN = {
    "es": _ADORNO + r"resumen" + _CIERRE,
    "en": _ADORNO + r"abstract" + _CIERRE,
    "pt": _ADORNO + r"resumo" + _CIERRE,
}
MARCA_KW = {
    "es": _ADORNO + r"palabras\s*[- ]?\s*clave[s]?" + _CIERRE,
    "en": _ADORNO + r"key\s*[- ]?\s*words?" + _CIERRE,
    "pt": _ADORNO + r"palavras\s*[- ]?\s*chave[s]?" + _CIERRE,
}
MARCA_REFS = re.compile(
    r"^\s*(?:\d+\s*[.\-)–]*\s*)?"
    r"(referencias?\s*(bibliogr[aá]ficas?)?|bibliograf[ií]a|references?|refer[eê]ncias?|"
    r"obras\s+citadas|fuentes\s+consultadas|lista\s+de\s+referencias|"
    r"referencias?\s+citadas|works\s+cited)\s*:?\s*$", re.I)

PAISES = ["Chile", "España", "Argentina", "Brasil", "Brazil", "México", "Mexico",
          "Colombia", "Perú", "Peru", "Uruguay", "Ecuador", "Bolivia", "Paraguay",
          "Venezuela", "Costa Rica", "Cuba", "Portugal", "Estados Unidos", "USA",
          "Francia", "Italia", "Alemania", "Reino Unido", "Canadá", "Canada"]


def _norm(s):
    return unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower().strip()


def limpiar_doi(d):
    if not d:
        return ""
    d = d.strip().rstrip(".,;:)]}")
    d = re.sub(r"(?i)^(https?://)?(dx\.)?doi\.org/", "", d)
    return d


# --------------------------------------------------------------------------
def extraer_doi(texto):
    m = RE_DOI.findall(texto)
    if not m:
        return "", 0.0
    cands = [limpiar_doi(x) for x in m]
    # el DOI del articulo suele ser el mas repetido en portada
    frec = {}
    for c in cands:
        frec[c] = frec.get(c, 0) + 1
    mejor = max(frec, key=lambda k: (frec[k], -cands.index(k)))
    return mejor, 0.95 if frec[mejor] > 1 else 0.75


def extraer_issn(texto):
    """Devuelve (electronico, impreso). Sin etiqueta explicita asume electronico."""
    e = i = ""
    for m in re.finditer(r"ISSN[^\d]{0,30}(\d{4}-\d{3}[\dXx])", texto, re.I):
        ctx = texto[max(0, m.start() - 40):m.start()].lower() + texto[m.start():m.end()].lower()
        val = m.group(1).upper()
        if re.search(r"impres|print|papel", ctx):
            i = i or val
        elif re.search(r"electr|online|en l[ií]nea|digital|-e\b|e-issn", ctx):
            e = e or val
        else:
            e = e or val
    return e, i


def extraer_orcids(texto):
    return [m.group(1).upper() for m in RE_ORCID.finditer(texto)]


def extraer_volumen_numero(texto):
    vol = num = ""
    pats_v = [r"\bvol(?:umen|ume|\.)?\s*[:.]?\s*([IVXLCDM]+|\d+)",
              r"\bv\.\s*(\d+)"]
    pats_n = [r"\bn[uú]m(?:ero|\.)?\s*[:.]?\s*(\d+)",
              r"\bn[ºo°]\s*[:.]?\s*(\d+)",
              r"\bno?\.\s*(\d+)",
              r"\bissue\s*(\d+)"]
    for p in pats_v:
        m = re.search(p, texto, re.I)
        if m:
            vol = m.group(1)
            break
    for p in pats_n:
        m = re.search(p, texto, re.I)
        if m:
            num = m.group(1)
            break
    # forma compacta 12(37) o 6(1)
    if not vol or not num:
        m = re.search(r"\b(\d{1,3})\s*\(\s*(\d{1,3})\s*\)", texto)
        if m:
            vol = vol or m.group(1)
            num = num or m.group(2)
    return _roman_a_int(vol), num


def _roman_a_int(s):
    if not s or not re.fullmatch(r"[IVXLCDM]+", s or "", re.I):
        return s
    vals = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000}
    s = s.upper()
    tot = 0
    for k, c in enumerate(s):
        v = vals[c]
        if k + 1 < len(s) and vals[s[k + 1]] > v:
            tot -= v
        else:
            tot += v
    return str(tot)


def extraer_paginas(texto):
    """Rango de paginas del articulo. Se limpian antes ORCID, ISSN, DOI y fechas,
    que son las fuentes clasicas de falsos positivos con guion.
    """
    t = RE_ORCID.sub(" ", texto)
    t = re.sub(r"ISSN[^\n]{0,20}", " ", t, flags=re.I)
    t = RE_DOI.sub(" ", t)
    t = re.sub(r"\b\d{4}-\d{2}-\d{2}\b", " ", t)
    t = re.sub(r"\b(19|20)\d{2}\s*[-–—]\s*(19|20)\d{2}\b", " ", t)

    prioridad = [
        r"(?:p[páa]g(?:ina)?s?\.?|pp?\.)\s*(\d{1,4})\s*[-–—]\s*(\d{1,4})",
        r"\d{1,3}\s*\(\s*\d{1,3}\s*\)\s*[,:]?\s*(\d{1,4})\s*[-–—]\s*(\d{1,4})",
        r"(?:vol|n[uú]m|n[ºo°])[^\n]{0,40}?(\d{1,4})\s*[-–—]\s*(\d{1,4})",
    ]
    for p in prioridad:
        for m in re.finditer(p, t, re.I):
            a, b = int(m.group(1)), int(m.group(2))
            if 0 < a <= b < 3000 and (b - a) < 200:
                return str(a), str(b)
    for m in re.finditer(r"\b(\d{1,4})\s*[-–—]\s*(\d{1,4})\b", t):
        a, b = int(m.group(1)), int(m.group(2))
        if 0 < a <= b < 3000 and 0 < (b - a) < 200:
            return str(a), str(b)
    return "", ""


def extraer_fechas(texto):
    """Recibido / aceptado / publicado en es, en, pt."""
    out = {"recibido": "", "aceptado": "", "publicado": ""}
    claves = {
        "recibido": r"(?:recibid[oa]|recepci[oó]n|received|recebido|submitted)",
        "aceptado": r"(?:aceptad[oa]|aceptaci[oó]n|accepted|aceito|aprobad[oa])",
        "publicado": r"(?:publicad[oa]|published|publicac[ií][oó]n|publicado em)",
    }
    for k, pat in claves.items():
        m = re.search(pat + r"\s*:?\s*[\n→\-]*\s*(.{0,40})", texto, re.I)
        if m:
            out[k] = _parse_fecha(m.group(1))
    return out


def _parse_fecha(frag):
    frag = frag.strip()
    m = re.search(r"(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4})", frag)
    if m:
        return f"{m.group(3)}-{int(m.group(2)):02d}-{int(m.group(1)):02d}"
    m = re.search(r"(\d{4})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{1,2})", frag)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    m = re.search(r"(\d{1,2})\s+de\s+(\w+)\s+de\s+(\d{4})", frag, re.I)
    if m:
        mes = MESES.get(_norm(m.group(2)), 0)
        if mes:
            return f"{m.group(3)}-{mes:02d}-{int(m.group(1)):02d}"
    m = re.search(r"(\w+)\s+(\d{1,2}),?\s+(\d{4})", frag)
    if m and _norm(m.group(1)) in MESES:
        return f"{m.group(3)}-{MESES[_norm(m.group(1))]:02d}-{int(m.group(2)):02d}"
    m = re.search(r"\b(19\d{2}|20\d{2})\b", frag)
    return m.group(1) if m else ""


def extraer_mes_anio_portada(texto):
    """Mes y anio de publicacion desde la linea de fasciculo."""
    for m in re.finditer(r"(\w+)\s+(?:de\s+)?(19\d{2}|20\d{2})", texto):
        mes = MESES.get(_norm(m.group(1)))
        if mes:
            return str(mes), m.group(2)
    m = RE_ANIO.search(texto)
    return "", (m.group(1) if m else "")


# --------------------------------------------------------------------------
def extraer_titulos(doc):
    """El titulo principal es el bloque de mayor tamano tipografico de la p1.
    Los titulos traducidos suelen ir inmediatamente abajo, en cursiva o menor.
    """
    p1 = [l for l in doc.pagina(0) if len(l.texto) > 3]
    if not p1:
        return {}, 0.0
    ruido = re.compile(r"(?i)^(art[ií]culo|articles?|dossier|ensayo|rese[nñ]a|editorial|"
                       r"issn|doi|vol|revista|universidad|recibido|aceptado|publicado|"
                       r"c[oó]mo citar|how to cite)")
    cands = [l for l in p1 if not ruido.match(l.texto)]
    if not cands:
        cands = p1
    smax = max(l.size for l in cands)
    princ = [l for l in cands if abs(l.size - smax) < 0.6]
    princ.sort(key=lambda l: (l.pagina, l.y0, l.x0))
    titulo = _unir(princ)

    titulos = {}
    idioma = _detectar_idioma(titulo)
    titulos[idioma] = titulo

    # traducciones: lineas por debajo del titulo, tamano intermedio
    ymax = max(l.y1 for l in princ)
    body = doc.size_cuerpo
    sub = [l for l in cands if l.y0 > ymax - 1 and body < l.size < smax - 0.5
           and l.y0 < ymax + 200 and len(l.texto) > 8]
    sub.sort(key=lambda l: (l.y0, l.x0))
    grupos, actual, prev = [], [], None
    for l in sub:
        alto = max(1.0, l.y1 - l.y0)
        salto = (l.y0 - prev.y1) if prev is not None else 0
        cambio_idioma = bool(actual) and len(_unir(actual)) > 18 and \
            _detectar_idioma(l.texto) != _detectar_idioma(_unir(actual))
        if prev is not None and (salto > alto * 0.55 or cambio_idioma):
            grupos.append(actual)
            actual = []
        actual.append(l)
        prev = l
    if actual:
        grupos.append(actual)
    for g in grupos[:4]:
        t = _unir(g)
        if len(t) < 10 or RE_DOI.search(t) or re.search(r"ISSN|@|orcid", t, re.I):
            continue
        lg = _detectar_idioma(t)
        if lg not in titulos:
            titulos[lg] = t
    conf = 0.9 if smax > doc.size_cuerpo * 1.3 else 0.55
    return titulos, conf


def _unir(lineas):
    txt = " ".join(l.texto.strip() for l in lineas)
    txt = re.sub(r"-\s+(?=[a-záéíóúñ])", "", txt)
    txt = re.sub(r"\s{2,}", " ", txt).strip(" .,;")
    if txt.isupper() and len(txt) > 12:
        txt = _capitalizar(txt)
    return txt


def _capitalizar(t):
    minus = {"de", "del", "la", "las", "el", "los", "y", "e", "o", "u", "en", "a",
             "por", "para", "con", "sin", "un", "una", "al", "que", "su", "sus"}
    palabras = t.lower().split()
    out = []
    for i, p in enumerate(palabras):
        out.append(p if (i > 0 and p in minus) else p[:1].upper() + p[1:])
    return " ".join(out)


STOP = {
    "es": set("el la los las de del y en que un una por para con este esta como se su".split()),
    "en": set("the of and in to a an for with this that is are as by from on".split()),
    "pt": set("o a os as de do da dos das e em que um uma por para com este esta como".split()),
}


def _detectar_idioma(t):
    w = set(_norm(t).split())
    sc = {k: len(w & v) for k, v in STOP.items()}
    if max(sc.values()) == 0:
        if re.search(r"[ãõçêô]", t or "", re.I):
            return "pt"
        if re.search(r"[áéíóúñ¿¡]", t or "", re.I):
            return "es"
        return "en"
    return max(sc, key=sc.get)


# --------------------------------------------------------------------------
def extraer_resumenes_kw(doc, max_pag=4):
    """Resumen y palabras clave por idioma.

    El delimitador natural es el marcador siguiente, pero en PDF generados desde
    Word el orden de lectura intercala cajas y el marcador de palabras clave cae
    en medio del resumen. Por eso, si el bloque delimitado sale demasiado corto,
    se extiende hasta el proximo marcador del mismo tipo omitiendo los del otro.
    """
    lineas = [l for l in doc.lineas if l.pagina < max_pag]
    resumenes, keywords = {}, {}
    marcas = []
    for i, l in enumerate(lineas):
        for lg, pat in MARCA_RESUMEN.items():
            if re.match(pat, l.texto, re.I) and len(l.texto) < 220:
                marcas.append((i, lg, "res", re.sub(pat, "", l.texto, flags=re.I).strip()))
        for lg, pat in MARCA_KW.items():
            if re.match(pat, l.texto, re.I):
                marcas.append((i, lg, "kw", re.sub(pat, "", l.texto, flags=re.I).strip()))
    marcas.sort()
    corte_cuerpo = re.compile(
        r"^\s*(?:\d+\s*[.\-)]?\s*)?(introducci[oó]n|introduction|introdu[cç][aã]o|"
        r"antecedentes|presentaci[oó]n|referencias|bibliograf[ií]a)\b", re.I)
    todas_marcas = [p for p in list(MARCA_RESUMEN.values()) + list(MARCA_KW.values())]

    def bloque(i, fin, saltar_marcas):
        """Acumula el texto del bloque quedandose en la columna del marcador.

        Varias portadas ponen el resumen y las palabras clave en columnas
        paralelas. Ordenadas por altura quedan intercaladas, asi que se descarta
        toda linea que no solape horizontalmente con la del marcador.
        """
        ref = lineas[i]
        out = []
        for l in lineas[i + 1:fin]:
            t = l.texto
            if MARCA_REFS.match(t) or corte_cuerpo.match(t):
                break
            es_marca = any(re.match(pt, t, re.I) for pt in todas_marcas)
            if es_marca and not saltar_marcas:
                break
            if es_marca:
                continue
            solape = min(l.x1, ref.x1) - max(l.x0, ref.x0)
            ancho = max(1.0, min(l.x1 - l.x0, ref.x1 - ref.x0))
            if solape < ancho * 0.35:
                continue
            out.append(t)
        return out

    for k, (i, lg, tipo, resto) in enumerate(marcas):
        fin = marcas[k + 1][0] if k + 1 < len(marcas) else min(len(lineas), i + 80)
        txt = _parrafo(" ".join(([resto] if resto else []) + bloque(i, fin, False)))
        if tipo == "res" and len(txt) < 600:
            # un resumen academico rara vez baja de 600 caracteres: si salio mas
            # corto, el marcador que corto el bloque venia de una columna vecina.
            # Se extiende hasta el proximo marcador del mismo tipo, filtrando por
            # columna, y se conserva la version mas larga.
            sig = next((m[0] for m in marcas[k + 1:] if m[2] == "res"),
                       min(len(lineas), i + 80))
            largo = _parrafo(" ".join(([resto] if resto else []) + bloque(i, sig, True)))
            if len(largo) > len(txt):
                txt = largo
        if tipo == "res":
            if len(txt) > 80 and lg not in resumenes:
                if len(txt) > 2500:
                    corte = txt.rfind(". ", 0, 2500)
                    txt = txt[:corte + 1] if corte > 500 else txt[:2500]
                    txt += "  [REVISAR: sin marcador de cierre, posible arrastre del cuerpo]"
                resumenes[lg] = txt
        else:
            if len(txt) < 8:
                # el filtro por columna dejo el bloque vacio: las palabras clave
                # suelen ir en una sola linea y a veces arrancan fuera de columna
                txt = _parrafo(" ".join(([resto] if resto else [])
                                        + [l.texto for l in lineas[i + 1:min(fin, i + 4)]]))
            kws = [x.strip(" .;") for x in re.split(r"[;,·|]|\s{3,}", txt)
                   if 2 < len(x.strip()) < 80]
            if kws and lg not in keywords:
                keywords[lg] = kws[:12]
    return resumenes, keywords


def _parrafo(t):
    t = re.sub(r"-\s+(?=[a-záéíóúñ])", "", t)
    return re.sub(r"\s{2,}", " ", t).strip()


# --------------------------------------------------------------------------
def extraer_autores(doc, texto_p1):
    """Autores: se anclan en ORCID y correo, que son las senales duras.
    Como respaldo se usa la linea de 'Como citar' o la tipografia destacada.
    """
    lineas = [l for l in doc.lineas if l.pagina == 0]
    autores, alertas, huerfanos = [], [], []
    idx_orcid = [i for i, l in enumerate(lineas) if RE_ORCID.search(l.texto)]

    if idx_orcid:
        for i in idx_orcid:
            ref = lineas[i]
            orcid = RE_ORCID.search(ref.texto).group(1).upper()
            nombre, email, aff_txt = "", "", []
            for j in range(i - 1, max(-1, i - 16), -1):
                lin = lineas[j]
                t = lin.texto.strip()
                if RE_ORCID.search(t):
                    break
                # misma columna que el ORCID: se compara solapamiento horizontal,
                # no x0, porque muchas portadas centran el nombre del autor
                solape = min(lin.x1, ref.x1) - max(lin.x0, ref.x0)
                if solape < min(20, (lin.x1 - lin.x0) * 0.25):
                    continue
                if RE_EMAIL.search(t):
                    email = email or RE_EMAIL.search(t).group(0)
                    continue
                if _parece_nombre(t):
                    nombre = t
                    break
                if len(t) > 3 and not re.search(r"(?i)volumen|n[uú]mero|ISSN|doi|"
                                                r"recibido|aceptado|publicado|art[ií]culo", t):
                    aff_txt.insert(0, t)
            for j in range(i, min(len(lineas), i + 4)):
                m = RE_EMAIL.search(lineas[j].texto)
                if m:
                    email = email or m.group(0)
                    break
            if not nombre:
                huerfanos.append(orcid)
                continue
            n, a = _partir_nombre(nombre)
            autores.append({"nombres": n, "apellidos": a, "orcid": orcid,
                            "email": email, "aff_txt": " ".join(aff_txt),
                            "aff_lineas": list(aff_txt)})

    if huerfanos:
        # el ORCID venia en nota al pie o lejos del nombre: se emparejan los
        # candidatos tipograficos de la portada en orden de aparicion
        cands = _candidatos_nombre(lineas, doc.size_cuerpo)
        usados = {(x["nombres"], x["apellidos"]) for x in autores}
        libres = [c for c in cands if (_partir_nombre(c)[0], _partir_nombre(c)[1]) not in usados]
        for k, orcid in enumerate(huerfanos):
            if k < len(libres):
                n, ap = _partir_nombre(libres[k])
                autores.append({"nombres": n, "apellidos": ap, "orcid": orcid,
                                "email": "", "aff_txt": "", "aff_lineas": []})
                alertas.append(f"ORCID {orcid} emparejado por posicion, verificar")
            else:
                alertas.append(f"ORCID {orcid} sin nombre asociado")

    if not autores:
        alertas.append("sin ORCID en portada, autores inferidos por tipografia")
        cuerpo = doc.size_cuerpo
        for l in lineas:
            t = l.texto.strip()
            if _parece_nombre(t) and (l.bold or l.size > cuerpo) and len(t) < 70:
                if not re.search(r"(?i)universidad|instituto|revista|facultad|depto|ISSN", t):
                    n, a = _partir_nombre(t)
                    if not any(x["apellidos"] == a and x["nombres"] == n for x in autores):
                        autores.append({"nombres": n, "apellidos": a, "orcid": "",
                                        "email": "", "aff_txt": "", "aff_lineas": []})
        autores = autores[:8]
    return autores, alertas


def _candidatos_nombre(lineas, cuerpo):
    """Lineas de la portada que parecen un nombre propio destacado."""
    out = []
    for l in lineas:
        t = l.texto.strip()
        if not _parece_nombre(t) or len(t) > 70:
            continue
        if ":" in t or "|" in t or "/" in t:
            continue
        if re.search(r"(?i)universidad|instituto|revista|facultad|departamento|"
                     r"ISSN|resumen|abstract|palabras|keywords|edici[oó]n|"
                     r"resultados|investigaci[oó]n|gesti[oó]n|art[ií]culo|"
                     r"recibido|aprobado|publicado|autor|c[oó]mo citar", t):
            continue
        alto = (l.pagina == 0 and l.y0 < 340 and len(t) < 60)
        if l.bold or l.italic or l.size > cuerpo + 0.3 or t.isupper() or alto:
            if t not in out:
                out.append(t)
    return out


def _parece_nombre(t):
    t = t.strip().strip(",")
    if not (4 < len(t) < 70):
        return False
    if RE_EMAIL.search(t) or RE_DOI.search(t) or re.search(r"\d{3}", t):
        return False
    if re.search(r"(?i)\b(universidad|university|instituto|institute|facultad|"
                 r"departamento|centro|consejo|revista|issn|doi|orcid|chile|españa|"
                 r"recibido|aceptado|resumen|abstract|c[oó]mo citar)\b", t):
        return False
    pal = t.replace(".", "").split()
    if not (2 <= len(pal) <= 6):
        return False
    cap = sum(1 for p in pal if p[:1].isupper())
    return cap >= max(2, len(pal) - 1)


def _partir_nombre(t):
    """Heuristica es-LA: los dos ultimos tokens suelen ser apellidos.
    Si hay coma, el formato es 'Apellidos, Nombres'.
    """
    t = re.sub(r"\d|\*|†|‡|§|¹|²|³", "", t).strip(" ,")
    if "," in t:
        a, _, n = t.partition(",")
        return n.strip(), a.strip()
    pal = t.split()
    if len(pal) <= 2:
        return " ".join(pal[:-1]), pal[-1]
    if len(pal) == 3:
        return pal[0], " ".join(pal[1:])
    return " ".join(pal[:-2]), " ".join(pal[-2:])


RE_INST = re.compile(r"(?i)universi|institut|facultad|departamento|centro|consejo|"
                     r"escuela|laboratorio|programa|unidad|hospital|colegio|"
                     r"fundaci[oó]n|ministerio|academia|college|school|agency")


def extraer_afiliaciones(autores_raw, texto_p1):
    """Construye afiliaciones unicas y las liga a cada autor.
    Las lineas de la portada se tratan como unidades: la ultima suele traer
    'ciudad, pais' y las previas el nombre de la institucion.
    """
    affs, mapa = [], {}
    for a in autores_raw:
        lineas = [x.strip(" ,;") for x in (a.get("aff_lineas") or []) if x.strip()]
        raw = " ".join(lineas) if lineas else (a.get("aff_txt") or "").strip()
        if not raw:
            continue
        clave = _norm(raw)[:70]
        if clave not in mapa:
            aid = f"aff{len(affs) + 1}"
            pais, ciudad, lin_geo = "", "", None
            for k in range(len(lineas) - 1, -1, -1):
                for p in PAISES:
                    if re.search(rf"\b{re.escape(p)}\b", lineas[k], re.I):
                        pais, lin_geo = p, k
                        break
                if pais:
                    break
            if lin_geo is not None:
                geo = lineas[lin_geo]
                idx = geo.lower().rfind(pais.lower())
                antes = geo[:idx].strip(" ,;")
                if antes and not RE_INST.search(antes) and len(antes.split()) <= 6:
                    ciudad = antes
                    inst_lineas = lineas[:lin_geo]
                else:
                    inst_lineas = lineas[:lin_geo] + ([antes] if antes else [])
            else:
                inst_lineas = lineas
            inst = re.sub(r"\s{2,}", " ", " ".join(inst_lineas)).strip(" ,;.")
            mapa[clave] = aid
            affs.append({"id": aid, "institucion": inst, "ciudad": ciudad,
                         "pais": pais, "texto_original": raw})
        a["aff_ids"] = [mapa[clave]]
    return affs
