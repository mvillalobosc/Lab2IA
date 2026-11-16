/* =============================================================================
   js/app.js
   Estado, navegación y armado de cada sección del dashboard.

   El dashboard no calcula nada: lee los conteos y porcentajes de
   data/bd_encuesta.js (window.BD_ENCUESTA) y el contorno de las regiones de
   data/bd_regiones.js (window.BD_REGIONES), y los muestra con los textos de
   js/textos.js en el idioma elegido.

   Estado (se guarda en la dirección de la página, después de #):
     seccion  una de SECCIONES
     enf      enfermedad elegida (rige Resumen, Enfermedades combinadas,
              Perfil, Tratamientos y Brechas de acceso)
     reg      región elegida (rige Territorio)
     lang     idioma
   ============================================================================= */
(function () {
  "use strict";

  var BD = window.BD_ENCUESTA, GEO = window.BD_REGIONES;
  var TEXTOS = window.RCL_TEXTOS, NOMBRE_REGION = window.RCL_REGIONES, G = window.RCL_GRAFICOS;
  var el = G.el, COLOR = G.COLOR;

  var IDIOMAS = ["es", "en", "pt"];
  var SECCIONES = ["resumen", "combinadas", "perfil", "territorio", "tratamientos", "acceso", "datos"];
  var SECCIONES_POR_REGION = ["territorio"];
  var SECCIONES_SIN_FILTRO = ["datos"];
  var GRUPO_CHICO = 30;                       // bajo este tamaño se avisa que el grupo es pequeño
  var CLASES_MAPA = [1, 10, 25, 50, 100, 200]; // límite inferior de cada clase de encuestados

  /* Referencia del sistema de salud chileno (no viene de la encuesta). Sale
     del dashboard original, salvo la artrosis: el problema GES n.º 41 cubre el
     tratamiento médico de la artrosis de cadera o rodilla, leve o moderada,
     desde los 55 años, y tiene guía clínica, así que va como "parcial". */
  var COBERTURA = {
    V8:  { ges: "si", guia: "si", lrs: "no" },
    V9:  { ges: "no", guia: "no", lrs: "si" },
    V10: { ges: "si", guia: "si", lrs: "si" },
    V11: { ges: "parcial", guia: "parcial", lrs: "no", nota: "cob_artrosis" },
    V12: { ges: "no", guia: "no", lrs: "no" },
    V13: { ges: "no", guia: "no", lrs: "no" },
    V14: { ges: "no", guia: "no", lrs: "no" },
    V15: { ges: "si", guia: "si", lrs: "si" },
    V16: { ges: "no", guia: "no", lrs: "no" },
    V17: { ges: "no", guia: "no", lrs: "no" },
    V18: { ges: "no", guia: "no", lrs: "no" },
    V20: { ges: "no", guia: "no", lrs: "no" }
  };

  /* Categoría de cada tipo de fármaco, como en el dashboard original */
  var CATEGORIA_FARMACO = {
    aines: "antiinflamatorio", analgesicos: "antiinflamatorio", corticoides: "antiinflamatorio",
    antirreumaticos: "modificador", inmunosupresores: "modificador", biologicos: "modificador", moleculas: "modificador",
    suplementos: "otro", calcio: "otro", gotas: "otro", opioides: "otro", psicofarmacos: "otro"
  };
  var COLOR_CATEGORIA = { antiinflamatorio: COLOR.categorias[1], modificador: COLOR.categorias[0], otro: COLOR.neutro };

  var raiz = document.getElementById("contenido");
  if (!BD || !GEO || !TEXTOS || !G) {
    raiz.textContent = "No se pudieron cargar los datos del dashboard. Revise que existan data/bd_encuesta.js y " +
      "data/bd_regiones.js junto a index.html; se generan con tools/preparar_datos.R.";
    return;
  }

  var estado = { seccion: "resumen", enf: null, reg: null, lang: "es" };
  var PANTALLA_ANGOSTA = window.matchMedia("(max-width: 680px)");   // mismo corte que css/estilos.css
  var T = TEXTOS.es;
  var vistaTabla = {};     // tarjetas que el usuario dejó en vista de tabla

  /* --------------------------------------------------------------------------
     Textos y números
     -------------------------------------------------------------------------- */
  function t(ruta, valores) {
    var texto = ruta.split(".").reduce(function (o, k) { return o ? o[k] : undefined; }, T);
    if (texto === undefined) return ruta;
    if (valores) {
      Object.keys(valores).forEach(function (k) { texto = texto.split("{" + k + "}").join(valores[k]); });
    }
    return texto;
  }
  function num(x, decimales) {
    var partes = Number(x).toFixed(decimales || 0).split(".");
    partes[0] = partes[0].replace(/\B(?=(\d{3})+(?!\d))/g, T.numero.miles);
    return partes.join(T.numero.decimal);
  }
  function pct(x) { return x === null || x === undefined ? "-" : num(x, 1) + T.numero.pct; }
  // "2026-11-16" como fecha escrita en el idioma elegido
  function fecha(iso) {
    var p = iso.split("-").map(Number);
    try {
      return new Date(p[0], p[1] - 1, p[2]).toLocaleDateString(estado.lang === "pt" ? "pt-BR" : estado.lang === "es" ? "es-CL" : "en-GB",
        { year: "numeric", month: "long", day: "numeric" });
    } catch (e) { return iso; }
  }
  function enf(id) { return T.enf[id].nombre; }
  function cat(variable, codigos) {
    return [].concat(codigos).map(function (c) { return T.cat[variable][c]; }).join(t("comun.y"));
  }
  function textoBase(tabla) {
    var texto = tabla.base === 1 ? t("comun.base_una") : t("comun.base", { n: num(tabla.base) });
    if (tabla.sin_respuesta) texto += ", " + t("comun.sin_respuesta", { n: num(tabla.sin_respuesta) });
    return texto;
  }

  /* --------------------------------------------------------------------------
     Estado en la dirección de la página
     -------------------------------------------------------------------------- */
  function leerDireccion() {
    var datos = {};
    window.location.hash.replace(/^#/, "").split("&").forEach(function (par) {
      var kv = par.split("=");
      if (kv.length === 2) datos[kv[0]] = decodeURIComponent(kv[1]);
    });
    if (SECCIONES.indexOf(datos.seccion) >= 0) estado.seccion = datos.seccion;
    if (BD.porEnfermedad[datos.enf]) estado.enf = datos.enf;
    if (BD.porRegion[datos.reg]) estado.reg = Number(datos.reg);
    if (IDIOMAS.indexOf(datos.lang) >= 0) estado.lang = datos.lang;
  }
  function escribirDireccion(nuevaEntrada) {
    var direccion = "#seccion=" + estado.seccion + "&enf=" + estado.enf + "&reg=" + estado.reg + "&lang=" + estado.lang;
    if (window.location.hash === direccion) return;
    try {
      if (nuevaEntrada) window.history.pushState(null, "", direccion);
      else window.history.replaceState(null, "", direccion);
    } catch (e) { window.location.hash = direccion; }
  }
  function idiomaInicial() {
    try {
      var guardado = window.localStorage.getItem("rheumacl_idioma");
      if (IDIOMAS.indexOf(guardado) >= 0) return guardado;
    } catch (e) { /* sin almacenamiento: se sigue con el idioma del navegador */ }
    var navegador = (window.navigator.language || "es").slice(0, 2).toLowerCase();
    return IDIOMAS.indexOf(navegador) >= 0 ? navegador : "es";
  }
  function mayor(ids, tamano) {
    return ids.slice().sort(function (a, b) { return tamano(b) - tamano(a); })[0];
  }

  /* --------------------------------------------------------------------------
     Acciones
     -------------------------------------------------------------------------- */
  function irA(seccion) {
    if (seccion === estado.seccion) return;
    estado.seccion = seccion;
    escribirDireccion(true);
    pintar();
    window.scrollTo(0, 0);
    var titulo = document.getElementById("titulo-seccion");
    if (titulo) titulo.focus({ preventScroll: true });
  }
  function elegirEnfermedad(id) {
    if (id === estado.enf) return;
    estado.enf = id;
    escribirDireccion(false);
    pintar();
  }
  function elegirRegion(codigo) {
    codigo = Number(codigo);
    if (codigo === estado.reg) return;
    estado.reg = codigo;
    escribirDireccion(false);
    pintar();
  }
  function elegirIdioma(codigo) {
    if (codigo === estado.lang) return;
    estado.lang = codigo;
    try { window.localStorage.setItem("rheumacl_idioma", codigo); } catch (e) { /* no se recuerda */ }
    escribirDireccion(false);
    pintar();
  }

  /* --------------------------------------------------------------------------
     Piezas comunes
     -------------------------------------------------------------------------- */
  // Tarjeta con un gráfico y su tabla equivalente; el botón alterna entre ambos.
  function tarjeta(id, titulo, partes) {
    var enTabla = !!vistaTabla[id];
    var cuerpoGrafico = el("div", { "class": "tarjeta-grafico", hidden: enTabla }, partes.grafico);
    var cuerpoTabla = partes.tabla ? el("div", { "class": "tarjeta-tabla", hidden: !enTabla }, partes.tabla) : null;
    var boton = null;
    if (cuerpoTabla) {
      boton = el("button", { type: "button", "class": "boton-tabla", "aria-pressed": enTabla ? "true" : "false" },
        t(enTabla ? "comun.ver_grafico" : "comun.ver_tabla"));
      boton.addEventListener("click", function () {
        enTabla = !enTabla;
        vistaTabla[id] = enTabla;
        cuerpoGrafico.hidden = enTabla;
        cuerpoTabla.hidden = !enTabla;
        boton.textContent = t(enTabla ? "comun.ver_grafico" : "comun.ver_tabla");
        boton.setAttribute("aria-pressed", enTabla ? "true" : "false");
      });
    }
    return el("article", { "class": "tarjeta" + (partes.ancha ? " tarjeta-ancha" : "") }, [
      el("header", { "class": "tarjeta-cab" }, [
        el("div", null, [
          el("h3", null, titulo),
          partes.base ? el("p", { "class": "tarjeta-base" }, partes.base) : null
        ]),
        boton
      ]),
      cuerpoGrafico,
      cuerpoTabla,
      partes.nota ? el("p", { "class": "tarjeta-nota" }, partes.nota) : null
    ]);
  }

  // Filas de un gráfico a partir de una tabla de la base
  function filasDe(tablaBD, etiqueta, colorDe) {
    return tablaBD.filas.map(function (f) {
      var etq = etiqueta(f[0]);
      return {
        cod: f[0], etq: etq, n: f[1], pct: f[2], valor: pct(f[2]),
        color: colorDe ? colorDe(f[0]) : null,
        detalle: t("comun.tip", { etq: etq, n: num(f[1]), base: num(tablaBD.base), pct: pct(f[2]) })
      };
    });
  }
  function ordenar(filas) {
    return filas.map(function (f, i) { return { f: f, i: i }; })
      .sort(function (a, b) { return (b.f.n - a.f.n) || (a.i - b.i); })
      .map(function (x) { return x.f; });
  }
  function tablaDe(filas, titulo) {
    return G.tabla([t("comun.col_respuesta"), t("comun.col_personas"), t("comun.col_pct")],
      filas.map(function (f) { return [f.etq, num(f.n), f.valor]; }), titulo);
  }

  /* Tarjeta de barras para una tabla de la base.
       opciones.variable  nombre en T.cat para traducir los códigos
       opciones.ranking   ordena de mayor a menor (categorías sin orden natural)
       opciones.fijas     con ranking, dos códigos que van primero y último
       opciones.multiple  pregunta de respuesta múltiple: agrega la nota
       opciones.color     función código -> color (series distintas)
       opciones.leyenda   nodo de leyenda, si hay series distintas */
  function tarjetaBarras(id, titulo, tablaBD, opciones) {
    if (!tablaBD.base) {
      return tarjeta(id, titulo, { grafico: el("p", { "class": "vacio" }, t("comun.sin_datos")) });
    }
    var filas = filasDe(tablaBD, opciones.etiqueta || function (c) { return T.cat[opciones.variable][c]; }, opciones.color);
    if (opciones.ranking) filas = ordenar(filas);
    if (opciones.fijas) {     // códigos que conservan su lugar: [primero, último]
      filas = filas.filter(function (f) { return f.cod === opciones.fijas[0]; })
        .concat(filas.filter(function (f) { return opciones.fijas.indexOf(f.cod) < 0; }))
        .concat(filas.filter(function (f) { return f.cod === opciones.fijas[1]; }));
    }
    return tarjeta(id, titulo, {
      base: opciones.base || textoBase(tablaBD),
      grafico: [opciones.leyenda || null, G.barras(filas, { escala: opciones.escala })],
      tabla: tablaDe(filas, titulo),
      nota: opciones.nota || (opciones.multiple ? t("comun.multiple") : null),
      ancha: opciones.ancha
    });
  }

  // Cifra destacada: rótulo, valor y una línea que dice qué se cuenta.
  // esTexto: el valor es una categoría (por ejemplo, un grupo de edad) y va
  // en un tamaño menor que los números.
  function cifra(rotulo, valor, descripcion, esTexto) {
    return el("div", { "class": "cifra" }, [
      el("p", { "class": "cifra-rotulo" }, rotulo),
      el("p", { "class": "cifra-valor" + (esTexto ? " cifra-texto" : "") }, valor),
      descripcion ? el("p", { "class": "cifra-desc" }, descripcion) : null
    ]);
  }
  function cabecera(titulo, intro) {
    return el("header", { "class": "seccion-cab" }, [
      el("h2", { id: "titulo-seccion", tabindex: "-1" }, titulo),
      intro ? el("p", null, intro) : null
    ]);
  }
  // Grupo de tarjetas bajo un subtítulo. Sin clase propia, las tarjetas se
  // reparten en dos columnas (2 o 4 tarjetas) o en tres (3 tarjetas), para
  // que ninguna quede sola en una fila.
  function grupo(titulo, hijos, clase) {
    return el("section", { "class": "grupo" }, [
      el("h3", { "class": "grupo-titulo" }, titulo),
      el("div", { "class": clase || ("rejilla rejilla-" + (hijos.length === 3 ? 3 : 2)) }, hijos)
    ]);
  }

  /* --------------------------------------------------------------------------
     Secciones
     -------------------------------------------------------------------------- */
  function seccionResumen(P) {
    var r = P.resumen;
    return [
      cabecera(t("resumen.titulo", { enf: enf(estado.enf) }), t("resumen.intro")),
      grupo(t("resumen.b_epi"), [
        cifra(t("resumen.k_prev"), pct(P.prev), t("resumen.d_prev")),
        cifra(t("resumen.k_disc"), pct(r.discapacidad), t("resumen.d_disc")),
        cifra(t("resumen.k_dolor"), pct(r.dolor), t("resumen.d_dolor"))
      ], "rejilla-cifras"),
      grupo(t("resumen.b_perfil"), [
        cifra(t("resumen.k_sexo"), cat("sexo", r.sexo), t("resumen.d_sexo", { pct: pct(r.sexo_pct) }), true),
        cifra(t("resumen.k_edad"), cat("edad", r.edad), t("resumen.d_edad"), true),
        cifra(t("resumen.k_comorb"), pct(r.comorbilidad), t("resumen.d_comorb"))
      ], "rejilla-cifras"),
      grupo(t("resumen.b_trat"), [
        cifra(t("resumen.k_farm"), num(r.farmacos_media, 1), t("resumen.d_farm")),
        cifra(t("resumen.k_adh"), pct(r.adherencia), t("resumen.d_adh")),
        cifra(t("resumen.k_alt"), pct(r.alternativos), t("resumen.d_alt"))
      ], "rejilla-cifras"),
      grupo(t("resumen.b_acceso"), [
        cifra(t("resumen.k_gasto"), cat("gasto", r.gasto), t("resumen.d_gasto"), true),
        cifra(t("resumen.k_fin"), pct(r.financiamiento), t("resumen.d_fin")),
        cifra(t("resumen.k_cont"), pct(r.continuidad), t("resumen.d_cont"))
      ], "rejilla-cifras")
    ];
  }

  function seccionCombinadas(P) {
    var id = estado.enf;
    var nodoDe = {};
    BD.red.nodos.forEach(function (nd) { nodoDe[nd.id] = nd; });
    var colorNivel = { bajo: COLOR.rampa3[0], medio: COLOR.rampa3[1], alto: COLOR.rampa3[2] };

    var nodos = BD.red.nodos.map(function (nd) {
      return {
        id: nd.id, nombre: enf(nd.id), n: nd.n, color: colorNivel[nd.nivel],
        detalle: t("combinadas.nodo", { enf: enf(nd.id), n: num(nd.n), g: nd.grado })
      };
    });
    var aristas = BD.red.aristas.map(function (a) {
      return { a: a[0], b: a[1], n: a[2], detalle: t("combinadas.arista", { a: enf(a[0]), b: enf(a[1]), n: num(a[2]) }) };
    });

    // Leyenda con el rango real de cada nivel, en vez de "alto, medio, bajo"
    var itemsLeyenda = ["bajo", "medio", "alto"].map(function (nivel) {
      var grados = BD.red.nodos.filter(function (nd) { return nd.nivel === nivel; }).map(function (nd) { return nd.grado; });
      if (!grados.length) return null;
      var a = Math.min.apply(null, grados), b = Math.max.apply(null, grados);
      return { color: colorNivel[nivel], etq: a === b ? String(a) : t("combinadas.rango", { a: a, b: b }) };
    }).filter(Boolean);

    // Tabla equivalente a la red: personas que declaran cada par
    var ids = BD.enfermedades, pares = {};
    BD.red.aristas.forEach(function (a) { pares[a[0] + "|" + a[1]] = a[2]; pares[a[1] + "|" + a[0]] = a[2]; });
    var matriz = G.tabla([""].concat(ids.map(enf)), ids.map(function (fila) {
      return [enf(fila)].concat(ids.map(function (col) {
        return fila === col ? num(nodoDe[fila].n) : num(pares[fila + "|" + col] || 0);
      }));
    }), t("combinadas.matriz"));

    var otras = P.combinada.otras.map(function (f) {
      return {
        etq: enf(f[0]), n: f[1], pct: f[2], valor: pct(f[2]),
        detalle: t("comun.tip", { etq: enf(f[0]), n: num(f[1]), base: num(P.n), pct: pct(f[2]) })
      };
    });

    return [
      cabecera(t("combinadas.titulo", { enf: enf(id) }), t("combinadas.intro")),
      el("div", { "class": "dos-columnas" }, [
        tarjeta("red", t("combinadas.red"), {
          grafico: [
            G.red(nodos, aristas, id, elegirEnfermedad, t("combinadas.red"), PANTALLA_ANGOSTA.matches),
            el("div", { "class": "leyenda-bloque" }, [
              el("span", { "class": "leyenda-titulo" }, t("combinadas.leyenda")),
              G.leyenda(itemsLeyenda, t("combinadas.leyenda"))
            ])
          ],
          tabla: el("div", { "class": "tabla-desliza" }, matriz)
        }),
        el("div", { "class": "columna" }, [
          el("article", { "class": "tarjeta" }, [
            el("header", { "class": "tarjeta-cab" }, el("h3", null, enf(id))),
            el("dl", { "class": "datos-lista" }, [
              [t("combinadas.k_n"), num(P.n)],
              [t("combinadas.k_prev"), pct(P.prev)],
              [t("combinadas.k_grado"), t("combinadas.v_grado", { g: nodoDe[id].grado })],
              [t("combinadas.k_disc"), pct(P.resumen.discapacidad)],
              [t("combinadas.k_cred"), num(P.combinada.credencial_n)],
              [t("combinadas.k_pension"), num(P.combinada.pension_n)],
              [t("combinadas.k_comorb"), pct(P.resumen.comorbilidad)]
            ].map(function (par) { return el("div", null, [el("dt", null, par[0]), el("dd", null, par[1])]); }))
          ]),
          tarjeta("otras", t("combinadas.otras"), {
            base: textoBase({ base: P.n, sin_respuesta: 0 }),
            grafico: G.barras(otras),
            tabla: tablaDe(otras, t("combinadas.otras")),
            nota: t("combinadas.otras_nota", { enf: enf(id) })
          })
        ])
      ])
    ];
  }

  function seccionPerfil(P) {
    var p = P.perfil;
    function b(clave, variable, opciones) {
      opciones = opciones || {};
      opciones.variable = variable;
      return tarjetaBarras("perfil-" + clave, t("perfil.c_" + clave), p[clave === "anios" ? "anios_dx" : clave], opciones);
    }
    return [
      cabecera(t("perfil.titulo", { enf: enf(estado.enf) }), t("perfil.intro")),
      grupo(t("perfil.g_socio"), [b("sexo", "sexo"), b("edad", "edad")]),
      grupo(t("perfil.g_vida"), [b("actividad", "actividad"), b("dieta", "dieta", { ranking: true }),
                                 b("tabaco", "tabaco"), b("alcohol", "alcohol")]),
      grupo(t("perfil.g_salud"), [b("salud", "salud"), b("dolor", "dolor")]),
      grupo(t("perfil.g_diag"), [b("anios", "anios_dx"),
                                 b("especialista", "especialista", { ranking: true, multiple: true })]),
      grupo(t("perfil.g_vinculo"), [b("relacion", "relacion"), b("preguntas", "preguntas"), b("decision", "decision")])
    ];
  }

  function seccionTerritorio() {
    var cod = estado.reg, R = BD.porRegion[cod];
    var maxN = Math.max.apply(null, BD.regiones.map(function (c) { return BD.porRegion[c].n; }));
    function clase(n) {
      var k = -1;
      CLASES_MAPA.forEach(function (limite, i) { if (n >= limite) k = i; });
      return k;
    }
    var regiones = BD.regiones.map(function (c) {
      var n = BD.porRegion[c].n, k = clase(n);
      return {
        cod: c, n: n, color: k < 0 ? COLOR.sinDato : COLOR.rampa6[k],
        detalle: t("territorio.region", { reg: NOMBRE_REGION[c].corto, n: num(n) })
      };
    });
    var itemsLeyenda = CLASES_MAPA.map(function (limite, i) {
      var siguiente = CLASES_MAPA[i + 1];
      return {
        color: COLOR.rampa6[i],
        etq: siguiente ? t("territorio.clase", { a: limite, b: siguiente - 1 }) : t("territorio.clase_mas", { a: limite })
      };
    });

    var lista = el("ul", { "class": "regiones" }, regiones.map(function (r) {
      var barra = el("span", { "class": "barra" });
      barra.style.width = Math.max(r.n / maxN * 100, 1) + "%";
      barra.style.background = r.color;
      var boton = el("button", { type: "button", "aria-pressed": r.cod === cod ? "true" : "false" }, [
        el("span", { "class": "regiones-nombre" }, NOMBRE_REGION[r.cod].corto),
        el("span", { "class": "fila-pista" }, barra),
        el("span", { "class": "regiones-n" }, num(r.n))
      ]);
      boton.addEventListener("click", function () { elegirRegion(r.cod); });
      return el("li", null, boton);
    }));

    var prevalencias = R.enfermedades.map(function (f) {
      return {
        etq: enf(f[0]), n: f[1], pct: f[2], valor: pct(f[2]),
        detalle: t("comun.tip", { etq: enf(f[0]), n: num(f[1]), base: num(R.n), pct: pct(f[2]) })
      };
    });

    function indicador(clave) {
      var tablaBD = R[clave];
      var titulo = t("territorio.i_" + clave);
      if (!tablaBD.base) return el("div", { "class": "indicador" }, [el("h4", null, titulo), el("p", { "class": "vacio" }, t("comun.sin_datos"))]);
      var filas = filasDe(tablaBD, function (c) { return T.cat.nivel3[c]; });
      return el("div", { "class": "indicador" }, [
        el("h4", null, titulo),
        el("p", { "class": "tarjeta-base" }, textoBase(tablaBD)),
        G.segmentada(filas, COLOR.rampa3, titulo)
      ]);
    }
    function tablaIndicadores() {
      var filas = [];
      ["educacion", "envejecimiento", "pobreza"].forEach(function (clave) {
        filasDe(R[clave], function (c) { return T.cat.nivel3[c]; }).forEach(function (f) {
          filas.push([t("territorio.i_" + clave) + ": " + f.etq, num(f.n), f.valor]);
        });
      });
      return G.tabla([t("comun.col_respuesta"), t("comun.col_personas"), t("comun.col_pct")], filas, t("territorio.c_comuna"));
    }

    var mapaSvg = G.mapa(GEO, regiones, cod, elegirRegion);

    return [
      cabecera(t("territorio.titulo", { reg: NOMBRE_REGION[cod].largo }), t("territorio.intro")),
      el("div", { "class": "territorio" }, [
        el("article", { "class": "tarjeta territorio-mapa" }, [
          el("header", { "class": "tarjeta-cab" }, el("h3", null, t("territorio.mapa"))),
          el("div", { "class": "mapa-caja" }, [
            mapaSvg,
            el("div", { "class": "leyenda-bloque leyenda-vertical" }, [
              el("span", { "class": "leyenda-titulo" }, t("territorio.leyenda")),
              G.leyenda(itemsLeyenda, t("territorio.leyenda"))
            ])
          ]),
          el("p", { "class": "tarjeta-nota" }, t("territorio.islas"))
        ]),
        el("article", { "class": "tarjeta territorio-lista" }, [
          el("header", { "class": "tarjeta-cab" }, el("h3", null, t("territorio.lista"))),
          lista
        ]),
        el("div", { "class": "territorio-panel" }, [
          el("div", { "class": "rejilla-cifras" }, [
            cifra(t("territorio.k_n"), num(R.n), t("territorio.k_pct") + ": " + pct(R.pct_muestra)),
            cifra(t("territorio.k_traslado"), pct(R.traslado)),
            cifra(t("territorio.k_disc"), pct(R.discapacidad)),
            cifra(t("territorio.k_cred"), pct(R.credencial))
          ]),
          el("div", { "class": "rejilla" }, [
            tarjeta("reg-enf", t("territorio.c_enf"), {
              base: textoBase({ base: R.n, sin_respuesta: 0 }),
              grafico: G.barras(prevalencias),
              tabla: tablaDe(prevalencias, t("territorio.c_enf")),
              nota: t("comun.multiple")
            }),
            el("div", { "class": "columna" }, [
              tarjetaBarras("reg-sexo", t("territorio.c_sexo"), R.sexo, { variable: "sexo" }),
              tarjetaBarras("reg-edad", t("territorio.c_edad"), R.edad, { variable: "edad" })
            ]),
            tarjeta("reg-comuna", t("territorio.c_comuna"), {
              grafico: el("div", { "class": "indicadores" }, ["educacion", "envejecimiento", "pobreza"].map(indicador)),
              tabla: tablaIndicadores(),
              nota: t("territorio.comuna_nota"),
              ancha: true
            })
          ])
        ])
      ])
    ];
  }

  function seccionTratamientos(P) {
    var tr = P.tratamientos, id = estado.enf, cob = COBERTURA[id];
    var textoCob = { si: t("comun.si"), no: t("comun.no"), parcial: t("comun.parcial") };

    var filasComplejidad = filasDe(tr.complejidad, function (c) { return T.cat.complejidad[c]; });
    var combinaciones = tr.combinaciones.map(function (c) {
      var etq = c[0].map(function (f) { return T.cat.farmacos_corto[f]; }).join(" + ");
      return {
        etq: etq, n: c[1], pct: c[2], valor: pct(c[2]),
        detalle: t("comun.tip", { etq: etq, n: num(c[1]), base: num(tr.con_farmaco), pct: pct(c[2]) })
      };
    });
    var leyendaCategorias = G.leyenda(["modificador", "antiinflamatorio", "otro"].map(function (c) {
      return { color: COLOR_CATEGORIA[c], etq: T.cat.categoria[c] };
    }), t("tratamientos.leyenda_cat"));

    return [
      cabecera(t("tratamientos.titulo", { enf: enf(id) }), t("tratamientos.intro")),
      el("div", { "class": "rejilla-cifras" }, [
        cifra(t("tratamientos.k_poli"), pct(tr.politerapia)),
        cifra(t("tratamientos.k_aines"), pct(tr.aines)),
        cifra(t("tratamientos.k_bio"), pct(tr.biologicos))
      ]),
      el("div", { "class": "rejilla rejilla-2" }, [
        tarjetaBarras("trat-farmacos", t("tratamientos.c_farmacos"), tr.farmacos, {
          variable: "farmacos", ranking: true, multiple: true,
          color: function (c) { return COLOR_CATEGORIA[CATEGORIA_FARMACO[c]]; },
          leyenda: leyendaCategorias
        }),
        el("div", { "class": "columna" }, [
          tarjeta("trat-complejidad", t("tratamientos.c_complejidad"), {
            base: textoBase(tr.complejidad),
            grafico: G.segmentada(filasComplejidad, COLOR.rampa4, t("tratamientos.c_complejidad")),
            tabla: tablaDe(filasComplejidad, t("tratamientos.c_complejidad"))
          }),
          tarjetaBarras("trat-complementarias", t("tratamientos.c_complementarias"), tr.complementarias,
            { variable: "complementarias", multiple: true }),
          el("article", { "class": "tarjeta" }, [
            el("header", { "class": "tarjeta-cab" }, el("h3", null, t("tratamientos.c_cobertura"))),
            el("dl", { "class": "datos-lista" }, [["cob_ges", cob.ges], ["cob_guia", cob.guia], ["cob_lrs", cob.lrs]].map(function (par) {
              return el("div", null, [el("dt", null, t("tratamientos." + par[0])), el("dd", null, textoCob[par[1]])]);
            })),
            cob.nota ? el("p", { "class": "tarjeta-nota" }, t("tratamientos." + cob.nota)) : null,
            el("p", { "class": "tarjeta-nota" }, t("tratamientos.cob_nota"))
          ])
        ]),
        combinaciones.length ? tarjeta("trat-combinaciones", t("tratamientos.c_combinaciones"), {
          base: t("tratamientos.comb_base", { n: num(tr.con_farmaco) }),
          grafico: G.barras(combinaciones, { escala: "max" }),
          tabla: tablaDe(combinaciones, t("tratamientos.c_combinaciones")),
          nota: t("tratamientos.comb_nota", { n: num(tr.con_farmaco) }),
          ancha: true
        }) : null
      ])
    ];
  }

  function seccionAcceso(P) {
    var a = P.acceso, id = estado.enf;
    function colorAdherencia(c) {
      return c === "adherente" ? COLOR.categorias[0] : c === "sin_razon" ? COLOR.neutro : COLOR.categorias[1];
    }
    var leyendaAdherencia = G.leyenda([
      { color: COLOR.categorias[0], etq: t("acceso.l_adherente") },
      { color: COLOR.categorias[1], etq: t("acceso.l_razon") },
      { color: COLOR.neutro, etq: t("acceso.l_sin_razon") }
    ]);
    return [
      cabecera(t("acceso.titulo", { enf: enf(id) }), t("acceso.intro")),
      el("div", { "class": "rejilla-cifras rejilla-cifras-4" }, [
        cifra(t("acceso.k_adh"), pct(a.adherencia_pct)),
        cifra(t("acceso.k_cont"), pct(a.continuidad)),
        cifra(t("acceso.k_ges"), pct(a.ges_pct)),
        cifra(t("acceso.k_seguro"), pct(a.seguro)),
        cifra(t("acceso.k_particular"), pct(a.particular)),
        cifra(t("acceso.k_gasto"), pct(a.gasto_alto)),
        cifra(t("acceso.k_fin"), pct(a.financiamiento)),
        cifra(t("acceso.k_cred"), pct(a.credito_pct))
      ]),
      el("div", { "class": "rejilla" }, [
        tarjetaBarras("acc-adherencia", t("acceso.c_adherencia"), a.adherencia, {
          variable: "adherencia", ranking: true, fijas: ["adherente", "sin_razon"],
          color: colorAdherencia, leyenda: leyendaAdherencia,
          nota: t("acceso.adh_nota")
        }),
        tarjetaBarras("acc-ges", t("acceso.c_ges"), a.ges, { variable: "ges", ranking: true }),
        tarjetaBarras("acc-gasto", t("acceso.c_gasto"), a.gasto, { variable: "gasto" }),
        tarjetaBarras("acc-fuentes", t("acceso.c_fuentes"), a.financiamiento_fuentes,
          { variable: "fuentes", ranking: true, multiple: true }),
        tarjetaBarras("acc-credito", t("acceso.c_credito"), a.credito, { variable: "credito", ranking: true }),
        tarjetaBarras("acc-judicial", t("acceso.c_judicial"), a.judicial, { variable: "judicial", ranking: true })
      ])
    ];
  }

  function seccionDatos() {
    var regMayor = mayor(BD.regiones, function (c) { return BD.porRegion[c].n; });
    return [
      cabecera(t("datos.titulo")),
      el("div", { "class": "texto" }, [
        el("h3", null, t("datos.h_que")),
        el("p", null, t("datos.p_que", { n: num(BD.meta.encuestados), regiones: BD.meta.regiones, enfermedades: BD.meta.enfermedades })),
        el("h3", null, t("datos.h_leer")),
        el("ul", null, [
          el("li", null, t("datos.l_base")),
          el("li", null, t("datos.l_multiple")),
          el("li", null, t("datos.l_muestra", { pct: pct(BD.porRegion[regMayor].pct_muestra), reg: NOMBRE_REGION[regMayor].largo })),
          el("li", null, t("datos.l_chico")),
          el("li", null, t("datos.l_tabla"))
        ]),
        el("h3", null, t("datos.h_enf")),
        el("dl", { "class": "glosario" }, BD.enfermedades.slice().sort(porNombre).map(function (id) {
          return el("div", null, [
            el("dt", null, [enf(id), el("span", null, t("datos.enf_n", { n: num(BD.porEnfermedad[id].n) }))]),
            el("dd", null, T.enf[id].desc)
          ]);
        })),
        el("h3", null, t("datos.h_origen")),
        el("p", null, t("datos.p_origen")),
        el("h3", null, t("datos.h_creditos")),
        el("p", null, t("datos.p_creditos"))
      ])
    ];
  }
  function porNombre(a, b) { return enf(a).localeCompare(enf(b), estado.lang); }

  /* --------------------------------------------------------------------------
     Barra de filtro: un solo selector, que rige todo lo que hay debajo
     -------------------------------------------------------------------------- */
  function filtro() {
    if (SECCIONES_SIN_FILTRO.indexOf(estado.seccion) >= 0) return null;
    var porRegion = SECCIONES_POR_REGION.indexOf(estado.seccion) >= 0;
    var total = BD.meta.encuestados;
    var selector = el("select", { id: "selector" });
    var n, resumen, descripcion = null;

    if (porRegion) {
      BD.regiones.forEach(function (c) {
        selector.appendChild(el("option", { value: c, selected: c === estado.reg },
          t("filtro.opcion", { nombre: NOMBRE_REGION[c].corto, n: num(BD.porRegion[c].n) })));
      });
      selector.addEventListener("change", function () { elegirRegion(selector.value); });
      n = BD.porRegion[estado.reg].n;
      resumen = t("filtro.grupo_reg", { n: num(n), total: num(total), pct: pct(BD.porRegion[estado.reg].pct_muestra) });
    } else {
      BD.enfermedades.slice().sort(porNombre).forEach(function (id) {
        selector.appendChild(el("option", { value: id, selected: id === estado.enf },
          t("filtro.opcion", { nombre: enf(id), n: num(BD.porEnfermedad[id].n) })));
      });
      selector.addEventListener("change", function () { elegirEnfermedad(selector.value); });
      n = BD.porEnfermedad[estado.enf].n;
      resumen = t("filtro.grupo_enf", { n: num(n), total: num(total), pct: pct(BD.porEnfermedad[estado.enf].prev) });
      descripcion = T.enf[estado.enf].desc;
    }

    return el("div", { "class": "filtro" }, el("div", { "class": "ancho filtro-caja" }, [
      el("div", { "class": "filtro-control" }, [
        el("label", { "for": "selector" }, t(porRegion ? "filtro.region" : "filtro.enfermedad")),
        selector
      ]),
      el("div", { "class": "filtro-texto" }, [
        el("p", { "class": "filtro-grupo" }, resumen),
        descripcion ? el("p", { "class": "filtro-desc" }, descripcion) : null,
        n < GRUPO_CHICO ? el("p", { "class": "aviso" }, t("filtro.chico")) : null
      ])
    ]));
  }

  /* --------------------------------------------------------------------------
     Pintado
     -------------------------------------------------------------------------- */
  function pintar() {
    T = TEXTOS[estado.lang];
    G.ocultarGlobo();
    document.documentElement.lang = estado.lang === "pt" ? "pt-BR" : estado.lang;
    document.title = T.app.titulo;

    // Textos fijos de la página
    document.getElementById("saltar").textContent = t("app.saltar");
    document.getElementById("titulo-app").textContent = t("app.titulo");
    document.getElementById("logo").alt = t("app.logo");
    document.getElementById("idiomas").setAttribute("aria-label", t("app.idioma"));
    Array.prototype.forEach.call(document.querySelectorAll("#idiomas button"), function (boton) {
      boton.setAttribute("aria-pressed", boton.getAttribute("data-idioma") === estado.lang ? "true" : "false");
    });

    // Navegación
    var nav = document.getElementById("nav");
    nav.setAttribute("aria-label", t("app.secciones"));
    nav.textContent = "";
    SECCIONES.forEach(function (s) {
      var boton = el("button", { type: "button", "aria-current": s === estado.seccion ? "page" : null }, t("nav." + s));
      boton.addEventListener("click", function () { irA(s); });
      nav.appendChild(boton);
    });
    var actual = nav.querySelector("[aria-current]");
    if (actual && actual.scrollIntoView && nav.scrollWidth > nav.clientWidth) {
      nav.scrollLeft = actual.offsetLeft - nav.clientWidth / 2 + actual.offsetWidth / 2;
    }

    // Filtro y contenido
    var cajaFiltro = document.getElementById("filtro");
    var teniaFoco = document.activeElement && document.activeElement.id === "selector";
    cajaFiltro.textContent = "";
    var nodoFiltro = filtro();
    if (nodoFiltro) cajaFiltro.appendChild(nodoFiltro);
    if (teniaFoco && document.getElementById("selector")) document.getElementById("selector").focus();

    var P = BD.porEnfermedad[estado.enf];
    var contenido = {
      resumen: seccionResumen, combinadas: seccionCombinadas, perfil: seccionPerfil,
      territorio: seccionTerritorio, tratamientos: seccionTratamientos, acceso: seccionAcceso, datos: seccionDatos
    }[estado.seccion](P);
    var principal = document.getElementById("contenido");
    principal.textContent = "";
    principal.className = "ancho seccion seccion-" + estado.seccion;
    contenido.forEach(function (nodo) { if (nodo) principal.appendChild(nodo); });

    document.getElementById("pie").textContent = t("app.pie") + " " +
      t("app.pie_base", { fecha: fecha(BD.meta.generado), n: num(BD.meta.encuestados) });
  }

  /* --------------------------------------------------------------------------
     Inicio
     -------------------------------------------------------------------------- */
  estado.lang = idiomaInicial();
  estado.enf = mayor(BD.enfermedades, function (id) { return BD.porEnfermedad[id].n; });
  estado.reg = mayor(BD.regiones, function (c) { return BD.porRegion[c].n; });
  leerDireccion();

  Array.prototype.forEach.call(document.querySelectorAll("#idiomas button"), function (boton) {
    boton.addEventListener("click", function () { elegirIdioma(boton.getAttribute("data-idioma")); });
  });
  window.addEventListener("hashchange", function () { leerDireccion(); pintar(); });
  window.addEventListener("popstate", function () { leerDireccion(); pintar(); });
  // La red se dibuja distinto en pantallas angostas: se repinta al cruzar el corte
  var alCambiarAncho = function () { if (estado.seccion === "combinadas") pintar(); };
  if (PANTALLA_ANGOSTA.addEventListener) PANTALLA_ANGOSTA.addEventListener("change", alCambiarAncho);
  else if (PANTALLA_ANGOSTA.addListener) PANTALLA_ANGOSTA.addListener(alCambiarAncho);

  pintar();
  escribirDireccion(false);
})();
