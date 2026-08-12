"""Segmentacion del cuerpo y de la lista de referencias.

El criterio no es una lista de titulos conocidos sino la maqueta del propio
documento: que tamanos usa para encabezar, como separa bloques y donde estan
las notas al pie. La lista de nombres de seccion se usa solo para clasificar
un titulo ya detectado, nunca para detectarlo.
"""
import re
from collections import Counter
from .front_matter import (MARCA_REFS, RE_DOI, RE_ANIO, limpiar_doi, _parrafo,
                           MARCA_RESUMEN, MARCA_KW)

RE_URL = re.compile(r"https?://[^\s<>\"')\]]+")
RE_CAPTION = re.compile(r"^\s*(figura|figure|tabla|table|cuadro|gr[aá]fico|grafico|"
                        r"imagen|foto|ilustraci[oó]n|anexo|ap[eé]ndice|fuente|source|"
                        r"nota|note|elaboraci[oó]n)\s*[\dIVXa-z]{0,4}\s*[.:\-–]", re.I)

RE_ECUACION = re.compile(r"[=≈≠≤≥±×÷∑∫√∞∂∆∇^_{}]|(?:\b(?:sin|cos|tan|log|ln|exp)\s*\()", re.I)

# Las declaraciones CRediT suelen poner el nombre de cada autor en negrita y
# continuar con una lista de roles. Tipograficamente se parecen mucho a un
# encabezado, pero son contenido de la seccion "Declaracion de autoria".
RE_CREDIT_ROL = re.compile(
    r"(?:conceptualizaci[oó]n|conceitua[cç][aã]o|curaci[oó]n de datos|curadoria de dados|data curation|an[aá]lisis formal|an[aá]lise formal|"
    r"formal analysis|captaci[oó]n|adquisici[oó]n de fondos|aquisi[cç][aã]o de financiamento|funding acquisition|"
    r"investigaci[oó]n|investiga[cç][aã]o|investigation|metodolog[ií]a|metodologia|methodology|administraci[oó]n del proyecto|administra[cç][aã]o do projeto|"
    r"project administration|recursos|resources|software|supervisi[oó]n|supervis[aã]o|supervision|"
    r"validaci[oó]n|valida[cç][aã]o|validation|visualizaci[oó]n|visualiza[cç][aã]o|visualization|redacci[oó]n|reda[cç][aã]o|writing|"
    r"borrador original|rascunho original|revisi[oó]n y edici[oó]n|revis[aã]o e edi[cç][aã]o|review(?:\s*&| and)?\s*editing)", re.I)

def parece_credit_autoria(t):
    t = (t or "").strip()
    if not t or ":" not in t:
        return False
    izquierda, derecha = t.split(":", 1)
    # Un nombre de persona seguido de uno o mas roles CRediT.
    if 1 < len(izquierda.split()) <= 8 and RE_CREDIT_ROL.search(derecha):
        return True
    # Algunas maquetas cortan la linea justo despues del primer rol.
    return bool(RE_CREDIT_ROL.search(t) and re.search(r"[,;]", derecha))

def parece_ecuacion(t):
    """Descarta fórmulas que por tipografía se parecen a un encabezado."""
    t = (t or "").strip()
    if not t:
        return False
    letras = sum(ch.isalpha() for ch in t)
    visibles = sum(not ch.isspace() for ch in t) or 1
    operadores = sum(ch in "=<>±×÷∑∫√∞∂∆∇^_{}[]*/+−" for ch in t)
    if RE_ECUACION.search(t) and (operadores >= 1 or re.search(r"\d", t)):
        if letras / visibles < 0.68 or operadores >= 2:
            return True
    if re.match(r"^\(?\d+\)?\s*[=:]", t):
        return True
    if re.search(r"\([0-9]+\)\s*$", t) and RE_ECUACION.search(t):
        return True
    return False

SEC_TYPE = [
    (r"introducci|introduction|introdu[cç]|presentaci[oó]n|antecedentes", "intro"),
    (r"m[eé]todo|metodolog|methods|methodolog|materiales", "methods"),
    (r"resultado|results|hallazgos|findings", "results"),
    (r"discusi|discussion|discuss[aã]o|an[aá]lisis", "discussion"),
    (r"conclusi|conclus|consideraciones finales|reflexiones finales", "conclusions"),
    (r"agradec|acknowledg|reconocimiento", "acknowledgments"),
    (r"financiamiento|funding|apoyo", "funding-information"),
]


def sec_type(titulo):
    t = (titulo or "").lower()
    for p, v in SEC_TYPE:
        if re.search(p, t):
            return v
    return ""


class DetectorTitulos:
    """Aprende del documento que combinaciones de tamano y peso se usan para
    encabezar, y descarta las que aparecen demasiado o cubren texto largo.
    """

    def __init__(self, doc, lineas):
        self.m = doc.maqueta
        self.estilos = self._estilos(lineas)

    def _estilos(self, lineas):
        cuerpo = self.m.size_cuerpo
        cuenta, largo = Counter(), Counter()
        for l in lineas:
            t = l.texto.strip()
            if not (2 < len(t) < 140) or self.m.es_nota(l):
                continue
            if not (l.size > cuerpo + 0.3 or l.bold):
                continue
            k = (round(l.size, 1), l.bold)
            cuenta[k] += 1
            largo[k] += len(t)
        n = max(1, len(lineas))
        buenos = set()
        for k, c in cuenta.items():
            if (largo[k] / c) < 70 and (c / n) < 0.25:
                buenos.add(k)
        return buenos

    def es_titulo(self, linea):
        t = linea.texto.strip()
        if not (2 < len(t) < 140):
            return False
        if RE_CAPTION.match(t) or parece_ecuacion(t) or parece_credit_autoria(t) or self.m.es_nota(linea):
            return False
        if re.search(r"[.;,]$", t) and not re.match(r"^\d+[.)]\s", t):
            return False
        if len(t.split()) > 14:
            return False
        if (round(linea.size, 1), linea.bold) not in self.estilos:
            return False
        return not t[0].islower()

    def nivel(self, linea):
        mayores = sorted({k[0] for k in self.estilos}, reverse=True)
        try:
            return min(3, mayores.index(round(linea.size, 1)) + 1)
        except ValueError:
            return 1


def _fin_front(doc, lineas):
    ult = -1
    pats = list(MARCA_RESUMEN.values()) + list(MARCA_KW.values())
    for i, l in enumerate(lineas[:min(len(lineas), 260)]):
        for pat in pats:
            if re.match(pat, l.texto, re.I) and len(l.texto) < 260:
                ult = max(ult, i)
    return ult


def indice_refs(doc, lineas):
    cands = [i for i, l in enumerate(lineas) if MARCA_REFS.match(l.texto)]
    if not cands:
        return -1
    validos = [i for i in cands if i > len(lineas) * 0.25]
    return max(validos) if validos else max(cands)


def extraer_secciones(doc):
    lineas = doc.utiles()
    ini = _fin_front(doc, lineas)
    fin = indice_refs(doc, lineas)
    fin = fin if fin > 0 else len(lineas)
    trozo = [l for l in lineas[ini + 1:fin] if not doc.maqueta.es_nota(l)]
    det = DetectorTitulos(doc, trozo)

    secciones = []
    actual = {"titulo": "", "nivel": 1, "parrafos": []}
    buf, prev = [], None

    def cerrar():
        if buf:
            t = _parrafo(" ".join(buf))
            if len(t) > 40 and not RE_CAPTION.match(t):
                actual["parrafos"].append(t)
            buf.clear()

    for l in trozo:
        t = l.texto.strip()
        if len(t) < 2:
            continue
        if det.es_titulo(l):
            cerrar()
            if actual["parrafos"] or actual["titulo"]:
                secciones.append(actual)
            actual = {"titulo": re.sub(r"^\s*\d+(\.\d+)*[.)\-–]?\s*", "", t).strip(),
                      "nivel": det.nivel(l), "parrafos": []}
            prev = l
            continue
        if RE_CAPTION.match(t):
            cerrar()
            prev = l
            continue
        if prev is not None:
            alto = max(1.0, prev.y1 - prev.y0)
            salto = l.y0 - prev.y1
            cambio = (l.pagina != prev.pagina
                      or doc.maqueta.columna_de(l) != doc.maqueta.columna_de(prev))
            if not cambio and salto > alto * 0.9:
                cerrar()
        buf.append(t)
        prev = l
    cerrar()
    if actual["parrafos"] or actual["titulo"]:
        secciones.append(actual)
    return [s for s in secciones if s["parrafos"] or s["titulo"]]


def extraer_referencias(doc):
    lineas = doc.utiles()
    i = indice_refs(doc, lineas)
    if i < 0:
        return [], ["no se encontro encabezado de referencias"]
    resto = [l for l in lineas[i + 1:] if l.texto.strip()]
    if not resto:
        return [], ["seccion de referencias vacia"]

    tam = Counter()
    for l in resto:
        if len(l.texto) > 25:
            tam[l.size] += len(l.texto)
    if not tam:
        return [], ["seccion de referencias sin texto util"]
    smod = tam.most_common(1)[0][0]
    resto = [l for l in resto if abs(l.size - smod) < 0.6]

    entradas, metodo = _segmentar(resto, doc)
    refs = []
    for e in entradas:
        e = _parrafo(e)
        if len(e) < 25 or not RE_ANIO.search(e):
            continue
        refs.append(parsear_referencia(e, len(refs) + 1))
    if not refs:
        return [], ["no se pudo segmentar la lista de referencias"]

    # En estilos autor-fecha es frecuente usar una raya/serie de guiones bajos
    # para repetir el autor de la referencia anterior. El PDF suele convertir
    # esa raya en "____"; no debe terminar como apellido literal en el XML.
    anteriores = []
    for ref in refs:
        autores = ref.get("autores") or []
        repite = bool(re.match(r"^\s*[_—–-]{3,}", ref.get("texto_plano", ""))) or any(
            re.fullmatch(r"[_—–-]{3,}", (a.get("apellidos") or "").strip()) for a in autores
        )
        if repite and anteriores:
            ref["autores"] = [dict(a) for a in anteriores]
            autores = ref["autores"]
        if autores and not repite:
            anteriores = [dict(a) for a in autores]

    return refs, ([f"referencias segmentadas por {metodo}"] if metodo != "francesa" else [])


def _segmentar(lineas, doc):
    """Tres estrategias en paralelo; gana la particion mas consistente."""
    cands = []
    for nombre, fn in (("francesa", _por_francesa),
                       ("sangria de primera linea", _por_primera_linea),
                       ("patron autor-anio", _por_patron)):
        try:
            e = fn(lineas, doc)
        except Exception:
            e = []
        if e:
            cands.append((_puntaje(e), nombre, e))
    if not cands:
        return [], "ninguna"
    cands.sort(key=lambda x: -x[0])
    return cands[0][2], cands[0][1]


def _puntaje(entradas):
    if len(entradas) < 2:
        return 0.0
    largos = [len(e) for e in entradas]
    prom = sum(largos) / len(largos)
    if prom < 30 or prom > 900:
        return 0.0
    disp = sum(abs(x - prom) for x in largos) / len(largos) / prom
    con_anio = sum(1 for e in entradas if RE_ANIO.search(e)) / len(entradas)
    may = sum(1 for e in entradas
              if re.match(r"^[A-ZÁÉÍÓÚÑÜ\[\d_“\"]", e.strip())) / len(entradas)
    return (con_anio * 2.2) + may + max(0.0, 1.4 - disp)


def _columnas_x(lineas):
    h = Counter(round(l.x0) for l in lineas)
    return [x for x, n in h.most_common(2)]


def _por_francesa(lineas, doc):
    top = _columnas_x(lineas)
    if len(top) < 2 or abs(top[0] - top[1]) < 6:
        return []
    xini = min(top)
    return _agrupar(lineas, lambda l: l.x0 <= xini + 3)


def _por_primera_linea(lineas, doc):
    top = _columnas_x(lineas)
    if len(top) < 2 or abs(top[0] - top[1]) < 6:
        return []
    xsang = max(top)
    return _agrupar(lineas, lambda l: l.x0 >= xsang - 3)


def _por_patron(lineas, doc):
    ent, buf, prev = [], [], None
    for l in lineas:
        t = l.texto.strip()
        alto = max(1.0, l.y1 - l.y0)
        salto = (l.y0 - prev.y1) if (prev is not None and l.pagina == prev.pagina) else 0
        arranca = bool(re.match(r"^[A-ZÁÉÍÓÚÑÜ_\[][\wáéíóúñ'’.\-]*[,.]?\s", t)) and \
            bool(re.search(r"\(?\b(19|20)\d{2}[a-z]?\)?", t[:120]))
        if buf and (arranca or salto > alto * 0.85):
            ent.append(" ".join(buf))
            buf = []
        buf.append(t)
        prev = l
    if buf:
        ent.append(" ".join(buf))
    return ent


def _agrupar(lineas, es_inicio):
    ent, buf = [], []
    for l in lineas:
        t = l.texto.strip()
        if not t:
            continue
        if es_inicio(l) and buf and re.match(r"^[A-ZÁÉÍÓÚÑÜ\[\d_“\"]", t):
            ent.append(" ".join(buf))
            buf = []
        buf.append(t)
    if buf:
        ent.append(" ".join(buf))
    return ent


def parsear_referencia(texto, orden):
    r = {"id": f"B{orden}", "orden": orden, "texto_plano": texto, "tipo": "other",
         "autores": [], "anio": "", "titulo": "", "fuente": "", "volumen": "",
         "numero": "", "paginas": "", "doi": "", "url": ""}

    m = RE_DOI.search(texto)
    if m:
        r["doi"] = limpiar_doi(m.group(0))
    m = RE_URL.search(texto)
    if m and "doi.org" not in m.group(0):
        r["url"] = m.group(0).rstrip(".,;")

    m = re.search(r"\((\d{4})[a-z]?(?:,[^)]*)?\)", texto)
    if m:
        r["anio"] = m.group(1)
        r["autores"] = _autores_ref(texto[:m.start()])
        resto = texto[m.end():].strip(" .,")
    else:
        m2 = RE_ANIO.search(texto)
        r["anio"] = m2.group(0) if m2 else ""
        resto = texto

    m = re.search(r"(\d{1,4})\s*[-–—]\s*(\d{1,4})", resto)
    if m and int(m.group(1)) <= int(m.group(2)):
        r["paginas"] = f"{m.group(1)}-{m.group(2)}"
    m = re.search(r"(\d{1,3})\s*\(\s*(\d{1,4})\s*\)", resto)
    if m:
        r["volumen"], r["numero"] = m.group(1), m.group(2)
    else:
        mv = re.search(r"(?i)\bvol\.?\s*(\d+)", resto)
        if mv:
            r["volumen"] = mv.group(1)

    partes = [p.strip() for p in re.split(r"\.\s+(?=[A-ZÁÉÍÓÚÑ¿“\"])", resto) if p.strip()]
    if partes:
        r["titulo"] = re.sub(r"\s*\[.*?\]\s*$", "", partes[0]).strip(" .")
    if len(partes) > 1:
        f = re.sub(r"\d+\s*\(\s*\d+\s*\).*$", "", partes[1])
        f = re.sub(r",\s*\d.*$", "", f)
        f = re.sub(r"https?://.*$", "", f)
        r["fuente"] = f.strip(" ,.;")

    if r["volumen"] or re.search(r"(?i)revista|journal|review|cuadernos|anales|"
                                 r"bolet[ií]n|revue|zeitschrift", r["fuente"]):
        r["tipo"] = "journal"
    elif re.search(r"(?i)\b(en|in)\b[:.]?\s+[A-ZÁÉÍÓÚÑ]", resto) and r["paginas"]:
        r["tipo"] = "chapter"
    elif re.search(r"(?i)tesis|thesis|disserta|memoria de t[ií]tulo", texto):
        r["tipo"] = "thesis"
    elif re.search(r"(?i)\b(actas|proceedings|congreso|conference|simposio)\b", texto):
        r["tipo"] = "confproc"
    elif r["url"]:
        r["tipo"] = "webpage"
    elif r["fuente"]:
        r["tipo"] = "book"
    return r


def _autores_ref(frag):
    frag = re.sub(r"\s*(?:\by\b|\band\b|\be\b|&)\s*", "; ", frag.strip(" .,;"))
    out = []
    for p in re.split(r";", frag):
        p = p.strip(" .,")
        if not p or len(p) < 3 or p.startswith("("):
            continue
        if "," in p:
            ap, _, no = p.partition(",")
            out.append({"apellidos": ap.strip(), "nombres": no.strip(" .")})
        else:
            tok = p.split()
            if len(tok) >= 2 and len(tok[-1]) <= 4 and tok[-1].replace(".", "").isupper():
                out.append({"apellidos": " ".join(tok[:-1]), "nombres": tok[-1]})
            elif len(tok) >= 2:
                out.append({"apellidos": tok[-1], "nombres": " ".join(tok[:-1])})
            else:
                out.append({"apellidos": p, "nombres": ""})
    return out[:25]
