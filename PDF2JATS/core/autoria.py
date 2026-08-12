"""Autores y afiliaciones sin reglas por revista.

Procedimiento:
  1. delimitar la zona de autoria (entre el titulo y el resumen o el cuerpo)
  2. agrupar sus lineas en bloques por proximidad vertical y por columna
  3. clasificar cada linea del bloque: nombre, institucion, lugar, correo, orcid
  4. si la zona no trae nada, reintentar sobre las notas al pie de la portada
  5. ligar autor y afiliacion por indice de llamada (superindice) si existe

Se aceptan cuatro maquetas frecuentes sin tratarlas como casos especiales:
bloque por autor, lista de nombres seguida de lista de afiliaciones, todo en
una linea separado por comas, y datos en nota al pie.
"""
import re
import unicodedata

RE_ORCID = re.compile(r"\b(\d{4}-\d{4}-\d{4}-\d{3}[\dXx])\b")
RE_EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
RE_LLAMADA = re.compile(r"[\d*†‡§¹²³⁴⁵]+$")

MARCA_INST = re.compile(
    r"(?i)universi|institut|facultad|faculty|departamento|department|centro|center|"
    r"centre|consejo|escuela|school|college|laboratori|programa|unidad|hospital|"
    r"cl[ií]nica|fundaci[oó]n|ministerio|academia|agencia|agency|corporaci[oó]n|"
    r"observatori|museo|c[aá]tedra|servicio|conicet|csic|cnrs|inta|inia|"
    r"investigador independiente|independent researcher")

PAISES = ["Chile", "España", "Espanha", "Spain", "Argentina", "Brasil", "Brazil",
          "México", "Mexico", "Colombia", "Perú", "Peru", "Uruguay", "Ecuador",
          "Bolivia", "Paraguay", "Venezuela", "Costa Rica", "Panamá", "Guatemala",
          "Cuba", "República Dominicana", "Portugal", "Estados Unidos", "USA",
          "United States", "Francia", "France", "Italia", "Italy", "Alemania",
          "Germany", "Reino Unido", "United Kingdom", "Canadá", "Canada",
          "Australia", "China", "Japón", "India", "Sudáfrica", "Países Bajos",
          "Bélgica", "Suiza", "Suecia", "Noruega", "Dinamarca", "Polonia"]

GRADOS = re.compile(r"(?i)^(dr|dra|doctor|doctora|mg|mag|mgtr|magister|magíster|"
                    r"lic|licenciad|prof|profesor|profesora|ing|ph\.?d|m\.?sc|"
                    r"candidat|becari|investigador|estudiante|acad[eé]mic)\b")

RUIDO = re.compile(r"(?i)\b(issn|doi|orcid|recibido|aceptado|publicado|received|"
                   r"accepted|revista|journal|volumen|volume|n[uú]mero|number|"
                   r"c[oó]mo citar|how to cite|copyright|licencia|resumen|abstract|"
                   r"resumo|palabras|keywords|palavras|art[ií]culo|article|"
                   r"correspondencia|autor de correspondencia|edici[oó]n)\b")


def _norm(s):
    return unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower().strip()


def _pais_en(t):
    for p in PAISES:
        if re.search(rf"\b{re.escape(p)}\b", t, re.I):
            return p
    return ""


# ------------------------------------------------------------ clasificacion
def clasificar(t):
    """Etiqueta una linea de la zona de autoria."""
    s = t.strip(" ,;.")
    if not s:
        return "vacio"
    if RE_ORCID.search(s):
        return "orcid"
    if RE_EMAIL.search(s):
        return "email"
    if MARCA_INST.search(s):
        return "institucion"
    if _pais_en(s) and len(s.split()) <= 7:
        return "lugar"
    if RUIDO.search(s):
        return "ruido"
    if GRADOS.match(s):
        return "bio"
    if nombres_en(s):
        return "nombre"
    return "otro"


NO_NOMBRE = re.compile(
    r"(?i)\b(ciencias?|sociales?|estudios?|productos?|naturales?|superior|"
    r"humanidades|letras|salud|educaci[oó]n|ingenier[ií]a|tecnolog[ií]a|"
    r"agrobiolog[ií]a|biolog[ií]a|econom[ií]a|derecho|historia|filosof[ií]a|"
    r"psicolog[ií]a|patrimonio|alimentaci[oó]n|gesti[oó]n|pol[ií]ticas?|"
    r"investigaciones?|desarrollo|proyecto|programa|magíster|magister|"
    r"doctorado|postgrado|pregrado|c[aá]tedra|nacional|regional|metropolitana)\b")


def parece_nombre(t):
    s = re.sub(r"[\d*†‡§¹²³⁴⁵]", "", t).strip(" ,;.")
    if not (4 < len(s) < 80):
        return False
    if RE_EMAIL.search(s) or "@" in s or "/" in s or ":" in s:
        return False
    if re.search(r"\d{3}", t) or MARCA_INST.search(s) or RUIDO.search(s):
        return False
    # nombres de unidades academicas y disciplinas: no son personas
    if NO_NOMBRE.search(s):
        return False
    # termina en conector: es un fragmento cortado, no un nombre completo
    if re.search(r"(?i)\s(y|e|de|del|la|el|en|and|of|con|para)$", s):
        return False
    pal = [p for p in s.replace(".", " ").split() if p]
    con_coma = "," in s
    if not (2 <= len(pal) <= (6 if con_coma else 5)):
        return False
    # una coma interna con muchas palabras a los lados es una enumeracion
    if con_coma and len(pal) > 4 and not re.match(r"^[^,]{2,30},\s*\S", s):
        return False
    if s.isupper():
        return True
    cap = sum(1 for p in pal if p[:1].isupper())
    conectores = sum(1 for p in pal
                     if _norm(p) in {"de", "del", "la", "los", "da", "dos", "van", "von", "y", "e"})
    return cap >= max(2, len(pal) - conectores - 1)


def nombres_en(t):
    """Una linea puede traer varios autores: 'A y B', 'A, B y C', 'A & B'.
    Devuelve la lista de nombres que efectivamente parecen personas.
    """
    s = t.strip(" ,;.")
    if not s or len(s) > 220:
        return []
    if parece_nombre(s):
        return [s]
    partes = re.split(r"\s*(?:;|\by\b|\band\b|\be\b|&)\s*|,\s+(?=[A-ZÁÉÍÓÚÑ])", s)
    partes = [p.strip(" ,;.") for p in partes if p and len(p.strip()) > 3]
    if len(partes) < 2:
        return []
    buenos = [p for p in partes if parece_nombre(p)]
    return buenos if len(buenos) >= 2 else []


def partir_nombre(t):
    """Formato 'Apellidos, Nombres' si hay coma; si no, heuristica es-LA de dos
    apellidos finales. Se conserva la llamada de nota si existe."""
    llamada = ""
    m = RE_LLAMADA.search(t.strip())
    if m:
        llamada = m.group(0)
    s = re.sub(r"[\d*†‡§¹²³⁴⁵]", "", t).strip(" ,;.")
    if "," in s:
        ap, _, no = s.partition(",")
        return no.strip(), ap.strip(), llamada
    pal = s.split()
    if len(pal) <= 2:
        return " ".join(pal[:-1]), pal[-1], llamada
    if len(pal) == 3:
        return pal[0], " ".join(pal[1:]), llamada
    return " ".join(pal[:-2]), " ".join(pal[-2:]), llamada


# -------------------------------------------------------------- zona y bloques
def zona_autoria(doc):
    """Desde el titulo mas grande de la portada hasta el primer marcador de
    resumen, o hasta donde arranca el cuerpo."""
    from .front_matter import MARCA_RESUMEN, MARCA_KW
    lineas = [l for l in doc.utiles() if l.pagina <= 1]
    if not lineas:
        return [], []
    # la portada trae titulo y traducciones, todos en cuerpos grandes. La zona de
    # autoria empieza despues del ultimo de esos bloques, no del primero.
    cuerpo = doc.maqueta.size_cuerpo
    titulares = [l for l in lineas
                 if l.pagina == 0 and l.size > cuerpo + 1.2 and len(l.texto) > 8]
    y_ini = max((l.y1 for l in titulares), default=0)
    fin = len(lineas)
    pats = list(MARCA_RESUMEN.values()) + list(MARCA_KW.values())
    for i, l in enumerate(lineas):
        if any(re.match(p, l.texto, re.I) for p in pats):
            fin = i
            break
    # la portada trae titulo y traducciones en cuerpos grandes. Se excluyen por
    # tamano y no por posicion vertical, porque muchas portadas ponen los datos
    # del autor en una columna lateral a la misma altura que el titulo.
    cuerpo = doc.maqueta.size_cuerpo
    titulares = [l for l in lineas
                 if l.pagina == 0 and l.size > cuerpo + 1.2 and len(l.texto) > 8]
    y_tit = min((l.y0 for l in titulares), default=0)
    zona = []
    for l in lineas[:fin]:
        if l.pagina != 0 or l.size > cuerpo + 1.2 or doc.maqueta.es_nota(l):
            continue
        # cabecera de la revista: va sobre el titulo y no trae datos de contacto
        if l.y0 < y_tit - 2 and not RE_ORCID.search(l.texto) \
           and not RE_EMAIL.search(l.texto):
            continue
        zona.append(l)
    notas = [l for l in lineas if l.pagina <= 1 and doc.maqueta.es_nota(l)]
    return zona, notas


def bloques(lineas, doc):
    """Corta la zona en bloques: cambio de columna, salto vertical grande, o
    aparicion de un nombre nuevo despues de datos de contacto."""
    if not lineas:
        return []
    out, actual, prev = [], [], None
    for l in lineas:
        alto = max(1.0, l.y1 - l.y0)
        salto = (l.y0 - prev.y1) if prev is not None else 0
        col = doc.maqueta.columna_de(l) != doc.maqueta.columna_de(prev) if prev else False
        cierre = False
        if prev is not None:
            if col or salto > alto * 1.6:
                cierre = True
            elif clasificar(l.texto) == "nombre" and \
                    any(clasificar(x.texto) in ("orcid", "email") for x in actual):
                cierre = True
        if cierre and actual:
            out.append(actual)
            actual = []
        actual.append(l)
        prev = l
    if actual:
        out.append(actual)
    return out


# -------------------------------------------------------------------- armado
def extraer(doc):
    """Devuelve (autores, afiliaciones, alertas)."""
    zona, notas = zona_autoria(doc)
    alertas = []

    autores, affs = _de_bloques(bloques(zona, doc), doc)
    if not autores:
        autores, affs = _de_bloques(bloques(notas, doc), doc)
        if autores:
            alertas.append("autoria tomada de las notas al pie")

    if not autores:
        # ultimo recurso: nombres en la zona, sin datos de contacto asociados
        sueltos = []
        for l in zona:
            sueltos.extend(nombres_en(l.texto))
        for s in sueltos[:8]:
            n, ap, ll = partir_nombre(s)
            autores.append({"nombres": n, "apellidos": ap, "orcid": "", "email": "",
                            "llamada": ll, "aff_ids": [], "aff_lineas": []})
        if autores:
            alertas.append("autores detectados sin afiliacion ni ORCID asociados")

    # ORCID de la portada que quedaron sin dueno
    texto_zona = " ".join(l.texto for l in zona + notas)
    todos = [m.group(1).upper() for m in RE_ORCID.finditer(texto_zona)]
    asignados = {a["orcid"] for a in autores if a["orcid"]}
    libres = [o for o in todos if o not in asignados]
    sin = [a for a in autores if not a["orcid"]]
    for a, o in zip(sin, libres):
        a["orcid"] = o
        alertas.append(f"ORCID {o} asignado por orden de aparicion, verificar")

    affs = _ligar_por_llamada(autores, affs, notas, alertas)
    return autores, affs, alertas


def _reetiquetar(etq):
    out, visto_nombre = [], False
    for l, e in etq:
        if e == "nombre" and not visto_nombre:
            visto_nombre = True
            out.append((l, e))
            continue
        if visto_nombre and e in ("nombre", "otro", "bio"):
            # un nombre posterior solo cuenta si el bloque aun no tiene contacto
            if e == "nombre" and not any(x in ("orcid", "email", "institucion")
                                        for _, x in out):
                out.append((l, e))
            else:
                out.append((l, "institucion"))
            continue
        out.append((l, e))
    return out


def _de_bloques(bloques_, doc):
    autores, affs, mapa = [], [], {}
    for bl in bloques_:
        etq = [(l, clasificar(l.texto)) for l in bl]
        # la maqueta dominante es nombre primero y datos despues: una vez visto
        # el primer nombre, las lineas que no son contacto son afiliacion aunque
        # el clasificador las haya leido como algo distinto
        etq = _reetiquetar(etq)
        nombres = [l for l, e in etq if e == "nombre"]
        inst = [l.texto.strip(" ,;") for l, e in etq if e == "institucion"]
        lugar = [l.texto.strip(" ,;") for l, e in etq if e == "lugar"]
        orcid = next((RE_ORCID.search(l.texto).group(1).upper()
                      for l, e in etq if e == "orcid"), "")
        email = next((RE_EMAIL.search(l.texto).group(0)
                      for l, e in etq if e == "email"), "")
        if not nombres:
            continue
        aid = ""
        # solo se acepta como afiliacion si hay marca institucional o un pais:
        # de lo contrario es texto de portada mal clasificado
        util = any(MARCA_INST.search(x) for x in inst) or any(_pais_en(x) for x in inst + lugar)
        if (inst or lugar) and util:
            clave = _norm(" ".join(inst + lugar))[:70]
            if clave not in mapa:
                aid = f"aff{len(affs) + 1}"
                ciudad, pais = "", ""
                if lugar:
                    g = lugar[-1]
                    pais = _pais_en(g)
                    if pais:
                        idx = g.lower().rfind(pais.lower())
                        c = g[:idx].strip(" ,;")
                        if c and not MARCA_INST.search(c) and len(c.split()) <= 6:
                            ciudad = c
                else:
                    pais = _pais_en(" ".join(inst))
                mapa[clave] = aid
                affs.append({"id": aid, "institucion": " ".join(inst).strip(" ,;."),
                             "ciudad": ciudad, "pais": pais,
                             "texto_original": " ".join(inst + lugar)})
            aid = mapa[clave]
        # una linea puede traer varios autores y varias lineas varios bloques;
        # todos comparten la afiliacion del bloque
        expandidos = []
        for ln in nombres:
            expandidos.extend(nombres_en(ln.texto) or [ln.texto])
        for txt in expandidos:
            n, ap, ll = partir_nombre(txt)
            autores.append({"nombres": n, "apellidos": ap,
                            "orcid": orcid if len(expandidos) == 1 else "",
                            "email": email if len(expandidos) == 1 else "",
                            "llamada": ll, "aff_ids": [aid] if aid else [],
                            "aff_lineas": inst + lugar})
    return autores, affs


def _ligar_por_llamada(autores, affs, notas, alertas):
    """Si los nombres traen superindice y las notas empiezan con el mismo
    numero, la afiliacion sale de la nota correspondiente."""
    if not notas or not any(a.get("llamada") for a in autores):
        return affs
    porn = {}
    for l in notas:
        m = re.match(r"^\s*([\d*†‡§]{1,2})\s+(.{10,})", l.texto)
        if m:
            porn.setdefault(m.group(1), []).append(m.group(2))
        elif porn:
            porn[list(porn)[-1]].append(l.texto)
    for a in autores:
        ll = a.get("llamada")
        if not ll or ll not in porn or a["aff_ids"]:
            continue
        txt = " ".join(porn[ll])
        inst = " ".join(re.findall(r"[^.;]*(?:" + MARCA_INST.pattern[5:] + r")[^.;]*", txt,
                                  re.I)[:2]).strip(" ,;.") or txt[:160]
        pais = _pais_en(txt)
        aid = f"aff{len(affs) + 1}"
        affs.append({"id": aid, "institucion": re.sub(r"\s{2,}", " ", inst),
                     "ciudad": "", "pais": pais, "texto_original": txt[:300]})
        a["aff_ids"] = [aid]
        m = RE_ORCID.search(txt)
        if m and not a["orcid"]:
            a["orcid"] = m.group(1).upper()
        m = RE_EMAIL.search(txt)
        if m and not a["email"]:
            a["email"] = m.group(0)
        alertas.append(f"afiliacion de {a['apellidos']} tomada de la nota {ll}")
    return affs
