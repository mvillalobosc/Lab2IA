"""Modelo interno neutro. Todo emisor XML parte desde aca, nunca desde el PDF."""
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional
import json


@dataclass
class Afiliacion:
    id: str = ""
    institucion: str = ""
    ciudad: str = ""
    pais: str = ""
    ror: str = ""
    texto_original: str = ""


@dataclass
class Autor:
    nombres: str = ""
    apellidos: str = ""
    orcid: str = ""
    email: str = ""
    aff_ids: List[str] = field(default_factory=list)
    correspondencia: bool = False


@dataclass
class Referencia:
    id: str = ""
    orden: int = 0
    texto_plano: str = ""
    tipo: str = "other"          # journal, book, chapter, thesis, web, other
    autores: List[Dict] = field(default_factory=list)
    anio: str = ""
    titulo: str = ""
    fuente: str = ""             # revista o editorial
    volumen: str = ""
    numero: str = ""
    paginas: str = ""
    doi: str = ""
    url: str = ""


@dataclass
class Seccion:
    titulo: str = ""
    nivel: int = 1
    parrafos: List[str] = field(default_factory=list)


@dataclass
class Articulo:
    # procedencia
    archivo: str = ""
    revista_codigo: str = ""
    confianza: Dict[str, float] = field(default_factory=dict)
    alertas: List[str] = field(default_factory=list)
    # campos que un editor ya reviso; el resto queda marcado al margen
    revisado: Dict[str, bool] = field(default_factory=dict)

    # journal-meta
    revista_titulo: str = ""
    revista_abrev: str = ""
    issn_electronico: str = ""
    issn_impreso: str = ""
    editorial: str = ""

    # article-meta
    doi: str = ""
    pid_scielo: str = ""
    tipo_articulo: str = "research-article"
    idioma: str = "es"
    titulos: Dict[str, str] = field(default_factory=dict)      # {"es": ..., "en": ...}
    subtitulos: Dict[str, str] = field(default_factory=dict)
    autores: List[Autor] = field(default_factory=list)
    afiliaciones: List[Afiliacion] = field(default_factory=list)
    resumenes: Dict[str, str] = field(default_factory=dict)
    keywords: Dict[str, List[str]] = field(default_factory=dict)
    fecha_recibido: str = ""
    fecha_aceptado: str = ""
    fecha_publicado: str = ""
    anio: str = ""
    mes: str = ""
    dia: str = ""
    volumen: str = ""
    numero: str = ""
    fpage: str = ""
    lpage: str = ""
    licencia: str = ""
    licencia_url: str = ""
    financiamiento: List[str] = field(default_factory=list)

    # body / back
    secciones: List[Seccion] = field(default_factory=list)
    referencias: List[Referencia] = field(default_factory=list)

    def to_json(self, ruta=None, indent=2):
        d = asdict(self)
        s = json.dumps(d, ensure_ascii=False, indent=indent)
        if ruta:
            with open(ruta, "w", encoding="utf-8") as f:
                f.write(s)
        return s

    def campos_faltantes(self):
        """Lo que un JATS/SPS valido exige y aca no esta."""
        falta = []
        if not self.titulos:
            falta.append("titulo")
        if not self.autores:
            falta.append("autores")
        if not self.afiliaciones:
            falta.append("afiliaciones")
        if not self.doi:
            falta.append("doi")
        if not self.issn_electronico and not self.issn_impreso:
            falta.append("issn")
        if not self.resumenes:
            falta.append("resumen")
        if not self.keywords:
            falta.append("keywords")
        if not self.anio:
            falta.append("anio")
        if not self.volumen:
            falta.append("volumen")
        if not self.fpage:
            falta.append("paginacion")
        if not self.referencias:
            falta.append("referencias")
        if not self.secciones:
            falta.append("cuerpo")
        for a in self.autores:
            if not a.orcid:
                falta.append(f"orcid:{a.apellidos or a.nombres}")
        return falta
