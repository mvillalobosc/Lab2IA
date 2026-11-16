/* =============================================================================
   js/app.js
   Estado, navegación, ayudas y armado de cada vista del dashboard.

   El dashboard no calcula nada: lee los conteos y porcentajes de
   data/bd_encuesta.js (window.BD_ENCUESTA) y el contorno de las regiones de
   data/bd_regiones.js (window.BD_REGIONES), y los muestra con los textos de
   js/textos.js en el idioma elegido.

   La página tiene dos vistas, que se eligen en la barra superior:
     por enfermedad  a la izquierda se elige la enfermedad y a la derecha se
                     ve su ficha con cinco pestañas (SECCIONES)
     por región      a la izquierda se elige la región en el mapa o en la
                     lista y a la derecha se ve quiénes respondieron ahí

   Estado (se guarda en la dirección de la página, después de #):
     modo     "enfermedad" o "region"
     seccion  pestaña de la vista por enfermedad
     enf      enfermedad elegida
     reg      región elegida
     lang     idioma

   Ayudas: bienvenida la primera vez, botón "?" junto a cada cifra y a cada
   gráfico, y la guía de uso (botón Ayuda) con su glosario.
   ============================================================================= */
(function () {
  "use strict";

  var BD = window.BD_ENCUESTA, GEO = window.BD_REGIONES;
  var TEXTOS = window.RCL_TEXTOS, NOMBRE_REGION = window.RCL_REGIONES, G = window.RCL_GRAFICOS;

  var raiz = document.getElementById("contenido");
  if (!BD || !GEO || !TEXTOS || !G) {
    raiz.textContent = "No se pudieron cargar los datos del dashboard. Revise que existan data/bd_encuesta.js y " +
      "data/bd_regiones.js junto a index.html; se generan con tools/preparar_datos.R.";
    return;
  }
  var el = G.el, icono = G.icono, COLOR = G.COLOR;

  var IDIOMAS = ["es", "en", "pt"];
  var MODOS = ["enfermedad", "region"];
  var SECCIONES = ["resumen", "combinadas", "perfil", "tratamientos", "acceso"];
  var ICONO_SECCION = { resumen: "rejilla", combinadas: "red", perfil: "persona", tratamientos: "capsula", acceso: "balanza" };
  var PESTANAS_GUIA = ["uso", "leer", "secciones", "glosario", "datos"];
  var GRUPO_CHICO = 30;                        // bajo este tamaño se avisa que el grupo es pequeño
  var CLASES_MAPA = [1, 10, 25, 50, 100, 200];  // límite inferior de cada clase de encuestados
  var GUARDA_IDIOMA = "rheumacl_idioma";        // claves del almacenamiento del navegador
  var GUARDA_BIENVENIDA = "rheumacl_sin_bienvenida";

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

  var estado = { modo: "enfermedad", seccion: "resumen", enf: null, reg: null, lang: "es" };
  var T = TEXTOS.es;
  var PANTALLA_ANGOSTA = window.matchMedia("(max-width: 680px)");   // mismo corte que css/estilos.css
  var vistaTabla = {};      // tarjetas que el usuario dejó en vista de tabla
  var grupoAbierto = {};    // grupos que el usuario abrió (true) o cerró (false)
  var guia = { abierta: false, pestana: "uso", vuelveA: null };
  var bienvenida = { abierta: false, vuelveA: null };

  /* --------------------------------------------------------------------------
     Textos, números y almacenamiento
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
  function personas(n) { return n === 1 ? t("ficha.persona") : t("ficha.personas", { n: num(n) }); }
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
  function porNombre(a, b) { return enf(a).localeCompare(enf(b), estado.lang); }
  function mayor(ids, tamano) {
    return ids.slice().sort(function (a, b) { return tamano(b) - tamano(a); })[0];
  }
  function leerGuardado(clave) {
    try { return window.localStorage.getItem(clave); } catch (e) { return null; }
  }
  function guardar(clave, valor) {
    try { window.localStorage.setItem(clave, valor); } catch (e) { /* sin almacenamiento: no se recuerda */ }
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
    if (MODOS.indexOf(datos.modo) >= 0) estado.modo = datos.modo;
    if (SECCIONES.indexOf(datos.seccion) >= 0) estado.seccion = datos.seccion;
    if (BD.porEnfermedad[datos.enf]) estado.enf = datos.enf;
    if (BD.porRegion[datos.reg]) estado.reg = Number(datos.reg);
    if (IDIOMAS.indexOf(datos.lang) >= 0) estado.lang = datos.lang;
  }
  function escribirDireccion(nuevaEntrada) {
    var direccion = "#modo=" + estado.modo + "&seccion=" + estado.seccion + "&enf=" + estado.enf +
      "&reg=" + estado.reg + "&lang=" + estado.lang;
    if (window.location.hash === direccion) return;
    try {
      if (nuevaEntrada) window.history.pushState(null, "", direccion);
      else window.history.replaceState(null, "", direccion);
    } catch (e) { window.location.hash = direccion; }
  }
  function idiomaInicial() {
    var guardado = leerGuardado(GUARDA_IDIOMA);
    if (IDIOMAS.indexOf(guardado) >= 0) return guardado;
    var navegador = (window.navigator.language || "es").slice(0, 2).toLowerCase();
    return IDIOMAS.indexOf(navegador) >= 0 ? navegador : "es";
  }

  /* --------------------------------------------------------------------------
     Acciones. Cada una cambia el estado y vuelve a pintar; "enfocar" es el id
     del elemento que recibe el foco después, para que quien usa el teclado no
     pierda su lugar.
     -------------------------------------------------------------------------- */
  function cambiar(cambios, nuevaEntrada, enfocar) {
    var hubo = false;
    Object.keys(cambios).forEach(function (k) {
      if (estado[k] !== cambios[k]) { estado[k] = cambios[k]; hubo = true; }
    });
    if (!hubo) return false;
    if (cambios.lang) guardar(GUARDA_IDIOMA, estado.lang);
    escribirDireccion(nuevaEntrada);
    pintar();
    var nodo = enfocar ? document.getElementById(enfocar) : null;
    if (nodo) nodo.focus({ preventScroll: true });
    return true;
  }
  function elegirModo(modo) {
    if (cambiar({ modo: modo }, true, "modo-" + modo)) window.scrollTo(0, 0);
  }
  function irA(seccion) {
    if (cambiar({ seccion: seccion }, true, "pestana-" + seccion)) mostrarPanel();
  }
  function elegirEnfermedad(id, enfocar) { cambiar({ enf: id }, false, enfocar); }
  function elegirRegion(codigo, enfocar) { cambiar({ reg: Number(codigo) }, false, enfocar); }
  function elegirIdioma(codigo) { cambiar({ lang: codigo }, false); }

  // Si el comienzo del panel quedó escondido bajo la barra de pestañas, lo trae a la vista
  function mostrarPanel() {
    var panel = document.getElementById("panel"), barra = document.getElementById("barra-pestanas");
    if (!panel || !barra) return;
    var tope = barra.getBoundingClientRect().bottom, inicio = panel.getBoundingClientRect().top;
    if (inicio < tope) window.scrollBy(0, inicio - tope - 8);
  }

  /* --------------------------------------------------------------------------
     Piezas comunes
     -------------------------------------------------------------------------- */
  // Cifra destacada: rótulo con su "?", valor y una línea que dice qué se cuenta.
  // texto: el valor es una categoría (un grupo de edad, por ejemplo) y va más chico.
  function cifra(o) {
    return el("div", { "class": "cifra" }, [
      el("div", { "class": "cifra-cab" }, [
        el("p", { "class": "cifra-rotulo" }, o.rotulo),
        o.ayuda ? G.botonAyuda(o.rotulo, o.ayuda) : null
      ]),
      el("p", { "class": "cifra-valor" + (o.texto ? " cifra-texto" : "") }, o.valor),
      o.desc ? el("p", { "class": "cifra-desc" }, o.desc) : null
    ]);
  }
  function cifras(lista, clase) {
    return el("div", { "class": clase || "rejilla-cifras" }, lista.map(cifra));
  }
  function rejilla(hijos, columnas) {
    return el("div", { "class": "rejilla rejilla-" + (columnas || 2) }, hijos);
  }
  // Cifras en una columna angosta al lado de uno o dos gráficos
  function lado(listaCifras, graficos) {
    return el("div", { "class": "rejilla-lado" }, [
      cifras(listaCifras, "columna"),
      graficos.length > 1 ? rejilla(graficos) : graficos[0]
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
  // Tabla equivalente a un gráfico de barras: texto para mostrar y números para el CSV
  function datosDe(filas) {
    return {
      columnas: [t("comun.col_respuesta"), t("comun.col_personas"), t("comun.col_pct")],
      filas: filas.map(function (f) { return [f.etq, num(f.n), f.valor]; }),
      crudas: filas.map(function (f) { return [f.etq, f.n, f.pct === null || f.pct === undefined ? "" : f.pct]; })
    };
  }

  /* Tarjeta de gráfico.
       partes.ayuda    texto del botón "?"
       partes.base     sobre cuántas personas se calcula
       partes.grafico  nodo o lista de nodos
       partes.datos    { columnas, filas, crudas, desliza }: tabla equivalente,
                       que también se descarga en CSV
       partes.nota     nota al pie
       partes.ancha    ocupa todo el ancho de la rejilla */
  function tarjeta(id, titulo, partes) {
    var enTabla = !!vistaTabla[id] && !!partes.datos;
    var cuerpoGrafico = el("div", { "class": "tarjeta-grafico", hidden: enTabla }, partes.grafico);
    var cuerpoTabla = null, acciones = null;
    if (partes.datos) {
      cuerpoTabla = el("div", { "class": "tarjeta-tabla" + (partes.datos.desliza ? " tabla-desliza" : ""), hidden: !enTabla },
        G.tabla(partes.datos.columnas, partes.datos.filas, titulo));
      var botonTabla = el("button", { type: "button", "class": "boton-icono-chico" });
      var rotular = function () {
        var rotulo = t(enTabla ? "comun.ver_grafico" : "comun.ver_tabla");
        botonTabla.textContent = "";
        botonTabla.appendChild(icono(enTabla ? "barras" : "tabla"));
        botonTabla.setAttribute("aria-label", rotulo + ": " + titulo);
        botonTabla.setAttribute("title", rotulo);
        botonTabla.setAttribute("aria-pressed", enTabla ? "true" : "false");
      };
      rotular();
      botonTabla.addEventListener("click", function () {
        enTabla = !enTabla;
        vistaTabla[id] = enTabla;
        cuerpoGrafico.hidden = enTabla;
        cuerpoTabla.hidden = !enTabla;
        rotular();
      });
      var botonCsv = el("button", {
        type: "button", "class": "boton-icono-chico",
        "aria-label": t("comun.descargar") + ": " + titulo, title: t("comun.descargar")
      }, icono("descargar"));
      botonCsv.addEventListener("click", function () { descargarCsv(id, partes.datos); });
      acciones = el("div", { "class": "tarjeta-acciones" }, [botonTabla, botonCsv]);
    }
    return el("article", { "class": "tarjeta" + (partes.ancha ? " tarjeta-ancha" : "") }, [
      el("header", { "class": "tarjeta-cab" }, [
        el("div", { "class": "tarjeta-titulo" }, [
          el("h4", null, titulo),
          partes.ayuda ? G.botonAyuda(titulo, partes.ayuda) : null
        ]),
        acciones
      ]),
      partes.base ? el("p", { "class": "tarjeta-base" }, partes.base) : null,
      cuerpoGrafico,
      cuerpoTabla,
      partes.nota ? el("p", { "class": "tarjeta-nota" }, partes.nota) : null
    ]);
  }

  /* Tarjeta de barras para una tabla de la base.
       opciones.variable  nombre en T.cat para traducir los códigos
       opciones.ayuda     texto del "?"
       opciones.ranking   ordena de mayor a menor (categorías sin orden natural)
       opciones.fijas     con ranking, dos códigos que van primero y último
       opciones.multiple  pregunta de respuesta múltiple: agrega la nota
       opciones.color     función código -> color (series distintas)
       opciones.leyenda   nodo de leyenda, si hay series distintas
       opciones.grupos    { de, orden, nombre }: presenta las barras bajo un
                          subtítulo por grupo, en el orden dado, conservando
                          el orden de las barras dentro de cada grupo */
  function tarjetaBarras(id, titulo, tablaBD, opciones) {
    if (!tablaBD.base) {
      return tarjeta(id, titulo, { ayuda: opciones.ayuda, grafico: el("p", { "class": "vacio" }, t("comun.sin_datos")) });
    }
    var filas = filasDe(tablaBD, opciones.etiqueta || function (c) { return T.cat[opciones.variable][c]; }, opciones.color);
    if (opciones.ranking) filas = ordenar(filas);
    if (opciones.fijas) {
      filas = filas.filter(function (f) { return f.cod === opciones.fijas[0]; })
        .concat(filas.filter(function (f) { return opciones.fijas.indexOf(f.cod) < 0; }))
        .concat(filas.filter(function (f) { return f.cod === opciones.fijas[1]; }));
    }
    if (opciones.grupos) {
      filas = opciones.grupos.orden.reduce(function (todas, g) {
        return todas.concat(filas.filter(function (f) { return opciones.grupos.de(f.cod) === g; })
          .map(function (f) { f.grupo = opciones.grupos.nombre(g); return f; }));
      }, []);
    }
    return tarjeta(id, titulo, {
      ayuda: opciones.ayuda,
      base: opciones.base || textoBase(tablaBD),
      grafico: [opciones.leyenda || null, G.barras(filas, { escala: opciones.escala })],
      datos: datosDe(filas),
      nota: opciones.nota || (opciones.multiple ? t("comun.multiple") : null),
      ancha: opciones.ancha
    });
  }

  /* Bloque con título que no se cierra (Resumen) y grupo que se abre y se
     cierra (las demás pestañas). Por omisión solo el primer grupo de cada
     pestaña queda abierto: la pestaña muestra de entrada su índice y no un
     muro de gráficos. Cerrado, el grupo dice qué gráficos trae. */
  function bloque(titulo, nombreIcono, hijos) {
    return el("section", { "class": "bloque" }, [
      el("header", { "class": "bloque-cab" }, [
        el("span", { "class": "grupo-icono" }, icono(nombreIcono)),
        el("h3", { "class": "grupo-titulo" }, titulo)
      ]),
      el("div", { "class": "bloque-cuerpo" }, hijos)
    ]);
  }
  function grupo(id, titulo, nombreIcono, hijos, abiertoPorOmision) {
    var cuerpo = el("div", { "class": "bloque-cuerpo" }, hijos);
    var contenido = Array.prototype.map.call(cuerpo.querySelectorAll(".tarjeta h4"), function (h) { return h.textContent; });
    var abierto = grupoAbierto.hasOwnProperty(id) ? grupoAbierto[id] : !!abiertoPorOmision;
    var detalle = el("details", { "class": "grupo", id: "grupo-" + id, open: abierto }, [
      el("summary", null, [
        el("span", { "class": "grupo-icono" }, icono(nombreIcono)),
        el("span", { "class": "grupo-textos" }, [
          el("h3", { "class": "grupo-titulo" }, titulo),
          contenido.length ? el("span", { "class": "grupo-pista" }, contenido.join(", ")) : null
        ]),
        icono("flecha", "grupo-flecha")
      ]),
      cuerpo
    ]);
    detalle.addEventListener("toggle", function () {
      grupoAbierto[id] = detalle.open;
      actualizarAbrirTodo();
    });
    return detalle;
  }
  function actualizarAbrirTodo() {
    var boton = document.getElementById("abrir-todo");
    if (!boton) return;
    var todos = Array.prototype.every.call(raiz.querySelectorAll("details.grupo"), function (d) { return d.open; });
    boton.textContent = t(todos ? "ficha.cerrar_todo" : "ficha.abrir_todo");
    boton.setAttribute("data-abrir", todos ? "0" : "1");
  }

  /* --------------------------------------------------------------------------
     Descargas, enlace y avisos
     -------------------------------------------------------------------------- */
  // CSV en UTF-8 con BOM, separado por comas y con los números sin formato
  function descargarCsv(id, datos) {
    var celda = function (v) {
      var s = String(v);
      return /[",;\r\n]/.test(s) ? "\"" + s.replace(/"/g, "\"\"") + "\"" : s;
    };
    var lineas = [datos.columnas].concat(datos.crudas).map(function (fila) { return fila.map(celda).join(","); });
    var grupoActual = estado.modo === "enfermedad" ? estado.enf : "region" + estado.reg;
    var blob = new Blob(["﻿" + lineas.join("\r\n") + "\r\n"], { type: "text/csv;charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var enlace = el("a", { href: url, download: "rheumacl_" + grupoActual + "_" + id + ".csv", "class": "oculto" });
    document.body.appendChild(enlace);
    enlace.click();
    enlace.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
  }

  function copiarEnlace(boton) {
    var texto = window.location.href;
    var respaldo = function () {
      var area = el("textarea", { readonly: true, "class": "oculto" });
      area.value = texto;
      document.body.appendChild(area);
      area.select();
      var copiado = false;
      try { copiado = document.execCommand("copy"); } catch (e) { copiado = false; }
      area.remove();
      boton.focus({ preventScroll: true });
      avisar(t(copiado ? "ficha.copiado" : "ficha.no_copiado"));
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(texto).then(function () { avisar(t("ficha.copiado")); }, respaldo);
    } else {
      respaldo();
    }
  }

  var relojAviso = null;
  function avisar(texto) {
    var nodo = document.getElementById("tostada");
    nodo.textContent = texto;
    nodo.classList.add("tostada-visible");
    clearTimeout(relojAviso);
    relojAviso = setTimeout(function () { nodo.classList.remove("tostada-visible"); }, 2600);
  }

  /* --------------------------------------------------------------------------
     Ficha del grupo elegido y pestañas
     -------------------------------------------------------------------------- */
  function ficha(o) {
    var copiar = el("button", { type: "button", "class": "boton boton-ficha" }, [icono("enlace"), el("span", null, t("ficha.copiar"))]);
    copiar.addEventListener("click", function () { copiarEnlace(copiar); });
    return el("section", { "class": "ficha", "aria-labelledby": "titulo-vista" }, [
      el("div", { "class": "ficha-icono" }, icono(o.icono)),
      el("div", { "class": "ficha-texto" }, [
        el("h2", { id: "titulo-vista", tabindex: "-1" }, o.titulo),
        el("p", { "class": "ficha-cifras" }, [el("b", null, personas(o.n)), ", " + t("ficha.de_muestra", { pct: pct(o.pct) })]),
        o.desc ? el("p", { "class": "ficha-desc" }, o.desc) : null,
        o.n < GRUPO_CHICO ? el("p", { "class": "ficha-aviso" }, [
          icono("alerta"), el("span", null, [el("b", null, t("ficha.chico") + ". "), t("ficha.chico_ayuda")])
        ]) : null
      ]),
      copiar
    ]);
  }

  function pestanas() {
    var lista = el("div", { role: "tablist", "class": "pestanas", "aria-label": enf(estado.enf) });
    SECCIONES.forEach(function (s, i) {
      var activa = s === estado.seccion;
      var boton = el("button", {
        type: "button", role: "tab", id: "pestana-" + s, "aria-selected": activa ? "true" : "false",
        "aria-controls": "panel", tabindex: activa ? "0" : "-1"
      }, [icono(ICONO_SECCION[s]), el("span", null, t("nav." + s))]);
      boton.addEventListener("click", function () { irA(s); });
      boton.addEventListener("keydown", function (e) {
        var j = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: SECCIONES.length - 1 }[e.key];
        if (j === undefined) return;
        e.preventDefault();
        irA(SECCIONES[(j + SECCIONES.length) % SECCIONES.length]);
      });
      lista.appendChild(boton);
    });
    var barra = el("div", { "class": "barra-pestanas", id: "barra-pestanas" }, lista);
    if (estado.seccion !== "resumen" && estado.seccion !== "combinadas") {
      var abrirTodo = el("button", { type: "button", "class": "boton-texto", id: "abrir-todo" });
      abrirTodo.addEventListener("click", function () {
        var abrir = abrirTodo.getAttribute("data-abrir") === "1";
        Array.prototype.forEach.call(raiz.querySelectorAll("details.grupo"), function (d) { d.open = abrir; });
        actualizarAbrirTodo();
      });
      barra.appendChild(abrirTodo);
    }
    return barra;
  }

  /* --------------------------------------------------------------------------
     Pestañas de la vista por enfermedad
     -------------------------------------------------------------------------- */
  function seccionResumen(P) {
    var r = P.resumen;
    return [
      bloque(t("resumen.b_epi"), "pulso", cifras([
        { rotulo: t("resumen.k_prev"), valor: pct(P.prev), desc: t("resumen.d_prev"), ayuda: t("ayuda.prev", { total: num(BD.meta.encuestados) }) },
        { rotulo: t("resumen.k_disc"), valor: pct(r.discapacidad), desc: t("resumen.d_disc"), ayuda: t("ayuda.disc") },
        { rotulo: t("resumen.k_dolor"), valor: pct(r.dolor), desc: t("resumen.d_dolor"), ayuda: t("ayuda.dolor") }
      ])),
      bloque(t("resumen.b_perfil"), "persona", cifras([
        { rotulo: t("resumen.k_sexo"), valor: cat("sexo", r.sexo), desc: t("resumen.d_sexo", { pct: pct(r.sexo_pct) }), ayuda: t("ayuda.sexo_moda"), texto: true },
        { rotulo: t("resumen.k_edad"), valor: cat("edad", r.edad), desc: t("resumen.d_edad"), ayuda: t("ayuda.edad_moda"), texto: true },
        { rotulo: t("resumen.k_comorb"), valor: pct(r.comorbilidad), desc: t("resumen.d_comorb"), ayuda: t("ayuda.comorb") }
      ])),
      bloque(t("resumen.b_trat"), "capsula", cifras([
        { rotulo: t("resumen.k_farm"), valor: num(r.farmacos_media, 1), desc: t("resumen.d_farm"), ayuda: t("ayuda.farm") },
        { rotulo: t("resumen.k_adh"), valor: pct(r.adherencia), desc: t("resumen.d_adh"), ayuda: t("ayuda.adh") },
        { rotulo: t("resumen.k_alt"), valor: pct(r.alternativos), desc: t("resumen.d_alt"), ayuda: t("ayuda.alt") }
      ])),
      bloque(t("resumen.b_acceso"), "balanza", cifras([
        { rotulo: t("resumen.k_gasto"), valor: cat("gasto", r.gasto), desc: t("resumen.d_gasto"), ayuda: t("ayuda.gasto_moda"), texto: true },
        { rotulo: t("resumen.k_fin"), valor: pct(r.financiamiento), desc: t("resumen.d_fin"), ayuda: t("ayuda.fin") },
        { rotulo: t("resumen.k_cont"), valor: pct(r.continuidad), desc: t("resumen.d_cont"), ayuda: t("ayuda.cont") }
      ]))
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
    var celda = function (fila, col) { return fila === col ? nodoDe[fila].n : (pares[fila + "|" + col] || 0); };
    var matriz = {
      columnas: [""].concat(ids.map(enf)),
      filas: ids.map(function (fila) { return [enf(fila)].concat(ids.map(function (col) { return num(celda(fila, col)); })); }),
      crudas: ids.map(function (fila) { return [enf(fila)].concat(ids.map(function (col) { return celda(fila, col); })); }),
      desliza: true
    };

    var otras = P.combinada.otras.map(function (f) {
      return {
        etq: enf(f[0]), n: f[1], pct: f[2], valor: pct(f[2]),
        detalle: t("comun.tip", { etq: enf(f[0]), n: num(f[1]), base: num(P.n), pct: pct(f[2]) })
      };
    });

    return [
      cifras([
        { rotulo: t("combinadas.k_grado"), valor: t("combinadas.v_grado", { g: nodoDe[id].grado }), ayuda: t("ayuda.grado") },
        { rotulo: t("combinadas.k_cred"), valor: num(P.combinada.credencial_n), desc: t("combinadas.d_de", { n: num(P.n) }), ayuda: t("ayuda.cred_n") },
        { rotulo: t("combinadas.k_pension"), valor: num(P.combinada.pension_n), desc: t("combinadas.d_de", { n: num(P.n) }), ayuda: t("ayuda.pension") }
      ]),
      el("div", { "class": "dos-columnas" }, [
        tarjeta("red", t("combinadas.red"), {
          ayuda: t("ayuda.red"),
          grafico: [
            G.red(nodos, aristas, id, function (otra, conTeclado) {
              elegirEnfermedad(otra, conTeclado ? "nodo-" + otra : null);
            }, t("combinadas.red"), PANTALLA_ANGOSTA.matches),
            el("div", { "class": "leyenda-bloque" }, [
              el("span", { "class": "leyenda-titulo" }, t("combinadas.leyenda")),
              G.leyenda(itemsLeyenda, t("combinadas.leyenda"))
            ])
          ],
          datos: matriz
        }),
        tarjeta("otras", t("combinadas.otras"), {
          ayuda: t("ayuda.otras"),
          base: textoBase({ base: P.n, sin_respuesta: 0 }),
          grafico: G.barras(otras),
          datos: datosDe(otras),
          nota: t("combinadas.otras_nota", { enf: enf(id) })
        })
      ])
    ];
  }

  function seccionPerfil(P) {
    var p = P.perfil;
    function b(clave, variable, ayuda, opciones) {
      opciones = opciones || {};
      opciones.variable = variable;
      opciones.ayuda = t("ayuda." + ayuda);
      return tarjetaBarras("perfil-" + clave, t("perfil.c_" + clave), p[clave === "anios" ? "anios_dx" : clave], opciones);
    }
    return [
      grupo("perfil-socio", t("perfil.g_socio"), "personas", rejilla([b("sexo", "sexo", "sexo"), b("edad", "edad", "edad")]), true),
      grupo("perfil-vida", t("perfil.g_vida"), "hoja", rejilla([
        b("actividad", "actividad", "actividad"), b("dieta", "dieta", "dieta", { ranking: true }),
        b("tabaco", "tabaco", "tabaco"), b("alcohol", "alcohol", "alcohol")
      ])),
      grupo("perfil-salud", t("perfil.g_salud"), "corazon", rejilla([b("salud", "salud", "salud"), b("dolor", "dolor", "dolor_c")])),
      grupo("perfil-diag", t("perfil.g_diag"), "reloj", rejilla([
        b("anios", "anios_dx", "anios"), b("especialista", "especialista", "especialista", { ranking: true, multiple: true })
      ])),
      grupo("perfil-vinculo", t("perfil.g_vinculo"), "dialogo", rejilla([
        b("relacion", "relacion", "relacion"), b("preguntas", "preguntas", "preguntas"), b("decision", "decision", "decision")
      ], 3))
    ];
  }

  function seccionTratamientos(P) {
    var tr = P.tratamientos, cob = COBERTURA[estado.enf];
    var textoCob = { si: t("comun.si"), no: t("comun.no"), parcial: t("comun.parcial") };

    var filasComplejidad = filasDe(tr.complejidad, function (c) { return T.cat.complejidad[c]; });
    var combinaciones = tr.combinaciones.map(function (c) {
      var etq = c[0].map(function (f) { return T.cat.farmacos_corto[f]; }).join(" + ");
      return {
        etq: etq, n: c[1], pct: c[2], valor: pct(c[2]),
        detalle: t("comun.tip", { etq: etq, n: num(c[1]), base: num(tr.con_farmaco), pct: pct(c[2]) })
      };
    });

    var cobertura = tarjeta("trat-cobertura", t("tratamientos.c_cobertura"), {
      ayuda: t("ayuda.cobertura"),
      grafico: el("dl", { "class": "datos-lista" }, [["cob_ges", cob.ges], ["cob_guia", cob.guia], ["cob_lrs", cob.lrs]].map(function (par) {
        return el("div", null, [el("dt", null, t("tratamientos." + par[0])), el("dd", { "class": "cob-" + par[1] }, textoCob[par[1]])]);
      })),
      nota: (cob.nota ? t("tratamientos." + cob.nota) + " " : "") + t("tratamientos.cob_nota")
    });

    return [
      cifras([
        { rotulo: t("tratamientos.k_poli"), valor: pct(tr.politerapia), ayuda: t("ayuda.poli") },
        { rotulo: t("tratamientos.k_aines"), valor: pct(tr.aines), ayuda: t("ayuda.aines") },
        { rotulo: t("tratamientos.k_bio"), valor: pct(tr.biologicos), ayuda: t("ayuda.bio") }
      ]),
      grupo("trat-farmacos", t("tratamientos.g_farmacos"), "capsula", rejilla([
        tarjetaBarras("trat-farmacos", t("tratamientos.c_farmacos"), tr.farmacos, {
          variable: "farmacos", ranking: true, multiple: true, ayuda: t("ayuda.farmacos"),
          color: function (c) { return COLOR_CATEGORIA[CATEGORIA_FARMACO[c]]; },
          grupos: {
            de: function (c) { return CATEGORIA_FARMACO[c]; },
            orden: ["modificador", "antiinflamatorio", "otro"],
            nombre: function (g) { return T.cat.categoria[g]; }
          }
        }),
        tarjeta("trat-complejidad", t("tratamientos.c_complejidad"), {
          ayuda: t("ayuda.complejidad"),
          base: textoBase(tr.complejidad),
          grafico: G.segmentada(filasComplejidad, COLOR.rampa4, t("tratamientos.c_complejidad")),
          datos: datosDe(filasComplejidad)
        })
      ]), true),
      combinaciones.length ? grupo("trat-comb", t("tratamientos.g_comb"), "capas",
        tarjeta("trat-combinaciones", t("tratamientos.c_combinaciones"), {
          ayuda: t("ayuda.combinaciones"),
          base: t("tratamientos.comb_base", { n: num(tr.con_farmaco) }),
          grafico: G.barras(combinaciones, { escala: "max" }),
          datos: datosDe(combinaciones),
          nota: t("tratamientos.comb_nota", { n: num(tr.con_farmaco) })
        })) : null,
      grupo("trat-otros", t("tratamientos.g_otros"), "escudo", rejilla([
        tarjetaBarras("trat-complementarias", t("tratamientos.c_complementarias"), tr.complementarias,
          { variable: "complementarias", multiple: true, ayuda: t("ayuda.complementarias") }),
        cobertura
      ]))
    ];
  }

  function seccionAcceso(P) {
    var a = P.acceso;
    function colorAdherencia(c) {
      return c === "adherente" ? COLOR.categorias[0] : c === "sin_razon" ? COLOR.neutro : COLOR.categorias[1];
    }
    var leyendaAdherencia = G.leyenda([
      { color: COLOR.categorias[0], etq: t("acceso.l_adherente") },
      { color: COLOR.categorias[1], etq: t("acceso.l_razon") },
      { color: COLOR.neutro, etq: t("acceso.l_sin_razon") }
    ]);
    function b(id, clave, tablaBD, variable, opciones) {
      opciones = opciones || {};
      opciones.variable = variable;
      opciones.ayuda = t("ayuda." + clave);
      return tarjetaBarras(id, t("acceso.c_" + clave), tablaBD, opciones);
    }
    return [
      grupo("acc-adh", t("acceso.g_adh"), "visto", lado([
        { rotulo: t("acceso.k_adh"), valor: pct(a.adherencia_pct), ayuda: t("ayuda.adh") },
        { rotulo: t("acceso.k_cont"), valor: pct(a.continuidad), ayuda: t("ayuda.cont") }
      ], [b("acc-adherencia", "adherencia", a.adherencia, "adherencia", {
        ranking: true, fijas: ["adherente", "sin_razon"], color: colorAdherencia, leyenda: leyendaAdherencia,
        nota: t("acceso.adh_nota")
      })]), true),
      grupo("acc-ges", t("acceso.g_ges"), "escudo", lado([
        { rotulo: t("acceso.k_ges"), valor: pct(a.ges_pct), ayuda: t("ayuda.ges_k") },
        { rotulo: t("acceso.k_seguro"), valor: pct(a.seguro), ayuda: t("ayuda.seguro") },
        { rotulo: t("acceso.k_particular"), valor: pct(a.particular), ayuda: t("ayuda.particular") }
      ], [b("acc-ges", "ges", a.ges, "ges", { ranking: true })])),
      grupo("acc-gasto", t("acceso.g_gasto"), "billete", lado([
        { rotulo: t("acceso.k_gasto"), valor: pct(a.gasto_alto), ayuda: t("ayuda.gasto_alto") },
        { rotulo: t("acceso.k_fin"), valor: pct(a.financiamiento), ayuda: t("ayuda.fin") }
      ], [b("acc-gasto", "gasto", a.gasto, "gasto"),
          b("acc-fuentes", "fuentes", a.financiamiento_fuentes, "fuentes", { ranking: true, multiple: true })])),
      grupo("acc-legal", t("acceso.g_legal"), "credito", lado([
        { rotulo: t("acceso.k_cred"), valor: pct(a.credito_pct), ayuda: t("ayuda.credito_k") }
      ], [b("acc-credito", "credito", a.credito, "credito", { ranking: true }),
          b("acc-judicial", "judicial", a.judicial, "judicial", { ranking: true })]))
    ];
  }

  function vistaEnfermedad() {
    var P = BD.porEnfermedad[estado.enf];
    var armar = { resumen: seccionResumen, combinadas: seccionCombinadas, perfil: seccionPerfil,
                  tratamientos: seccionTratamientos, acceso: seccionAcceso }[estado.seccion];
    return [
      ficha({ icono: "pulso", titulo: enf(estado.enf), n: P.n, pct: P.prev, desc: T.enf[estado.enf].desc }),
      pestanas(),
      el("div", { id: "panel", "class": "panel", role: "tabpanel", "aria-labelledby": "pestana-" + estado.seccion }, armar(P))
    ];
  }

  /* --------------------------------------------------------------------------
     Vista por región
     -------------------------------------------------------------------------- */
  function vistaRegion() {
    var R = BD.porRegion[estado.reg];
    var enfermedades = R.enfermedades.map(function (f) {
      return {
        etq: enf(f[0]), n: f[1], pct: f[2], valor: pct(f[2]),
        detalle: t("comun.tip", { etq: enf(f[0]), n: num(f[1]), base: num(R.n), pct: pct(f[2]) })
      };
    });
    var claves = ["educacion", "envejecimiento", "pobreza"];
    function indicador(clave) {
      var tablaBD = R[clave], titulo = t("territorio.i_" + clave);
      if (!tablaBD.base) return el("div", { "class": "indicador" }, [el("h5", null, titulo), el("p", { "class": "vacio" }, t("comun.sin_datos"))]);
      return el("div", { "class": "indicador" }, [
        el("h5", null, titulo),
        el("p", { "class": "tarjeta-base" }, textoBase(tablaBD)),
        G.segmentada(filasDe(tablaBD, function (c) { return T.cat.nivel3[c]; }), COLOR.rampa3, titulo)
      ]);
    }
    var filasComuna = [];
    claves.forEach(function (clave) {
      filasDe(R[clave], function (c) { return T.cat.nivel3[c]; }).forEach(function (f) {
        filasComuna.push({ etq: t("territorio.i_" + clave) + ": " + f.etq, n: f.n, pct: f.pct, valor: f.valor });
      });
    });

    return [
      ficha({ icono: "mapa", titulo: NOMBRE_REGION[estado.reg].largo, n: R.n, pct: R.pct_muestra, desc: t("ficha.region_desc") }),
      el("div", { id: "panel", "class": "panel panel-region" }, [
        cifras([
          { rotulo: t("territorio.k_traslado"), valor: pct(R.traslado), ayuda: t("ayuda.traslado") },
          { rotulo: t("territorio.k_disc"), valor: pct(R.discapacidad), ayuda: t("ayuda.disc") },
          { rotulo: t("territorio.k_cred"), valor: pct(R.credencial), ayuda: t("ayuda.cred_pct") }
        ]),
        rejilla([
          tarjeta("reg-enf", t("territorio.c_enf"), {
            ayuda: t("ayuda.reg_enf"),
            base: textoBase({ base: R.n, sin_respuesta: 0 }),
            grafico: G.barras(enfermedades),
            datos: datosDe(enfermedades),
            nota: t("comun.multiple")
          }),
          el("div", { "class": "columna" }, [
            tarjetaBarras("reg-sexo", t("territorio.c_sexo"), R.sexo, { variable: "sexo", ayuda: t("ayuda.sexo") }),
            tarjetaBarras("reg-edad", t("territorio.c_edad"), R.edad, { variable: "edad", ayuda: t("ayuda.edad") })
          ]),
          tarjeta("reg-comuna", t("territorio.c_comuna"), {
            ayuda: t("ayuda.comuna"),
            grafico: el("div", { "class": "indicadores" }, claves.map(indicador)),
            datos: datosDe(filasComuna),
            nota: t("territorio.comuna_nota"),
            ancha: true
          })
        ])
      ])
    ];
  }

  /* --------------------------------------------------------------------------
     Panel de selección (a la izquierda). En pantallas angostas se reemplaza
     por una lista desplegable: es el mismo control, no un acceso repetido.
     -------------------------------------------------------------------------- */
  function cabeceraSelector(titulo, ayuda) {
    return el("div", { "class": "selector-cab" }, [el("h2", null, titulo), G.botonAyuda(titulo, ayuda)]);
  }
  function selectorMovil(rotulo, opciones, valor, alCambiar) {
    var lista = el("select", { id: "selector-movil" }, opciones.map(function (o) {
      return el("option", { value: o.valor, selected: String(o.valor) === String(valor) }, o.texto);
    }));
    lista.addEventListener("change", function () { alCambiar(lista.value); });
    return el("div", { "class": "selector-movil" }, [el("label", { "for": "selector-movil" }, rotulo), lista]);
  }
  function opcion(idBoton, nombre, n, ancho, color, elegida, alElegir) {
    var barra = el("span", { "class": "opcion-barra" });
    barra.style.width = Math.max(ancho, 1.5) + "%";
    if (color) barra.style.background = color;
    var boton = el("button", { type: "button", id: idBoton, "class": "opcion", "aria-pressed": elegida ? "true" : "false" }, [
      el("span", { "class": "opcion-nombre" }, nombre),
      el("span", { "class": "opcion-n" }, num(n)),
      el("span", { "class": "opcion-pista", "aria-hidden": "true" }, barra)
    ]);
    boton.addEventListener("click", alElegir);
    return el("li", null, boton);
  }

  function selectorEnfermedad(caja) {
    var ids = BD.enfermedades.slice().sort(porNombre);
    var maxN = Math.max.apply(null, ids.map(function (id) { return BD.porEnfermedad[id].n; }));
    caja.appendChild(cabeceraSelector(t("selector.lista_enf"), t("selector.ayuda_enf")));
    caja.appendChild(selectorMovil(t("selector.enfermedad"), ids.map(function (id) {
      return { valor: id, texto: t("selector.opcion", { nombre: enf(id), n: num(BD.porEnfermedad[id].n) }) };
    }), estado.enf, function (valor) { elegirEnfermedad(valor, "selector-movil"); }));
    caja.appendChild(el("ul", { "class": "opciones" }, ids.map(function (id) {
      var n = BD.porEnfermedad[id].n;
      return opcion("op-" + id, enf(id), n, n / maxN * 100, null, id === estado.enf,
        function () { elegirEnfermedad(id, "op-" + id); });
    })));
    caja.appendChild(el("p", { "class": "selector-nota" }, t("selector.nota_enf")));
  }

  function selectorRegion(caja) {
    var maxN = Math.max.apply(null, BD.regiones.map(function (c) { return BD.porRegion[c].n; }));
    var regiones = BD.regiones.map(function (c) {
      var n = BD.porRegion[c].n, k = -1;
      CLASES_MAPA.forEach(function (limite, i) { if (n >= limite) k = i; });
      return {
        cod: c, n: n, color: k < 0 ? COLOR.sinDato : COLOR.rampa6[k],
        detalle: t("selector.globo_region", { reg: NOMBRE_REGION[c].corto, n: num(n) })
      };
    });
    var itemsLeyenda = CLASES_MAPA.map(function (limite, i) {
      var siguiente = CLASES_MAPA[i + 1];
      return {
        color: COLOR.rampa6[i],
        etq: siguiente ? t("territorio.clase", { a: limite, b: siguiente - 1 }) : t("territorio.clase_mas", { a: limite })
      };
    });
    caja.appendChild(cabeceraSelector(t("selector.lista_reg"), t("selector.ayuda_reg")));
    caja.appendChild(selectorMovil(t("selector.region"), BD.regiones.map(function (c) {
      return { valor: c, texto: t("selector.opcion", { nombre: NOMBRE_REGION[c].corto, n: num(BD.porRegion[c].n) }) };
    }), estado.reg, function (valor) { elegirRegion(valor, "selector-movil"); }));
    caja.appendChild(el("div", { "class": "leyenda-bloque" }, [
      el("span", { "class": "leyenda-titulo" }, t("selector.leyenda")),
      G.leyenda(itemsLeyenda, t("selector.leyenda"))
    ]));
    caja.appendChild(el("div", { "class": "mapa-y-lista" }, [
      el("div", { "class": "mapa-caja" }, G.mapa(GEO, regiones, estado.reg, function (cod) { elegirRegion(cod); })),
      el("ul", { "class": "opciones opciones-region" }, regiones.map(function (r) {
        return opcion("op-r" + r.cod, NOMBRE_REGION[r.cod].corto, r.n, r.n / maxN * 100, r.color, r.cod === estado.reg,
          function () { elegirRegion(r.cod, "op-r" + r.cod); });
      }))
    ]));
    caja.appendChild(el("p", { "class": "selector-nota" }, t("selector.islas")));
  }

  /* --------------------------------------------------------------------------
     Guía de uso (panel lateral) y bienvenida
     -------------------------------------------------------------------------- */
  function contenidoGuia(pestana) {
    if (pestana === "uso") {
      return el("ol", { "class": "guia-pasos" }, T.guia.uso.map(function (paso) {
        return el("li", null, el("div", null, [el("b", null, paso[0]), el("p", null, paso[1])]));
      }));
    }
    if (pestana === "leer") {
      var regMayor = mayor(BD.regiones, function (c) { return BD.porRegion[c].n; });
      return el("ul", { "class": "guia-lista" }, [
        t("guia.leer_base"), t("guia.leer_multiple"),
        t("guia.leer_muestra", { pct: pct(BD.porRegion[regMayor].pct_muestra), reg: NOMBRE_REGION[regMayor].largo }),
        t("guia.leer_chico"), t("guia.leer_tabla")
      ].map(function (texto) { return el("li", null, texto); }));
    }
    if (pestana === "secciones") {
      return el("dl", { "class": "guia-definiciones" }, SECCIONES.map(function (s) {
        return el("div", null, [el("dt", null, [icono(ICONO_SECCION[s]), t("nav." + s)]), el("dd", null, t("guia.sec_" + s))]);
      }).concat([el("div", null, [el("dt", null, [icono("mapa"), t("modo.region")]), el("dd", null, t("guia.sec_region"))])]));
    }
    if (pestana === "glosario") {
      return el("dl", { "class": "guia-definiciones" }, T.guia.glosario.slice().sort(function (a, b) {
        return a[0].localeCompare(b[0], estado.lang);
      }).map(function (par) { return el("div", null, [el("dt", null, par[0]), el("dd", null, par[1])]); }));
    }
    return el("div", null, [
      el("h3", null, t("guia.h_que")),
      el("p", null, t("guia.p_que", { n: num(BD.meta.encuestados), regiones: BD.meta.regiones, enfermedades: BD.meta.enfermedades })),
      el("h3", null, t("guia.h_enf")),
      el("dl", { "class": "guia-definiciones" }, BD.enfermedades.slice().sort(porNombre).map(function (id) {
        return el("div", null, [
          el("dt", null, [enf(id), el("span", { "class": "guia-n" }, t("guia.enf_n", { n: num(BD.porEnfermedad[id].n) }))]),
          el("dd", null, T.enf[id].desc)
        ]);
      })),
      el("h3", null, t("guia.h_origen")),
      el("p", null, t("guia.p_origen")),
      el("h3", null, t("guia.h_creditos")),
      el("p", null, t("guia.p_creditos"))
    ]);
  }

  function pintarGuia() {
    var caja = document.getElementById("guia");
    caja.textContent = "";
    var cerrar = el("button", { type: "button", id: "guia-cerrar", "class": "boton-icono", "aria-label": t("comun.cerrar"), title: t("comun.cerrar") }, icono("cerrar"));
    cerrar.addEventListener("click", cerrarGuia);
    var lista = el("div", { role: "tablist", "class": "guia-pestanas", "aria-label": t("guia.titulo") });
    PESTANAS_GUIA.forEach(function (p, i) {
      var activa = p === guia.pestana;
      var boton = el("button", {
        type: "button", role: "tab", id: "guia-pestana-" + p, "aria-selected": activa ? "true" : "false",
        "aria-controls": "guia-cuerpo", tabindex: activa ? "0" : "-1"
      }, t("guia.t_" + p));
      var elegir = function (q) {
        guia.pestana = q;
        pintarGuia();
        document.getElementById("guia-pestana-" + q).focus();
      };
      boton.addEventListener("click", function () { elegir(p); });
      boton.addEventListener("keydown", function (e) {
        var j = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: PESTANAS_GUIA.length - 1 }[e.key];
        if (j === undefined) return;
        e.preventDefault();
        elegir(PESTANAS_GUIA[(j + PESTANAS_GUIA.length) % PESTANAS_GUIA.length]);
      });
      lista.appendChild(boton);
    });
    caja.appendChild(el("header", { "class": "guia-cab" }, [
      el("span", { "class": "grupo-icono" }, icono("ayuda")),
      el("h2", { id: "guia-titulo" }, t("guia.titulo")),
      cerrar
    ]));
    caja.appendChild(lista);
    caja.appendChild(el("div", {
      "class": "guia-cuerpo", id: "guia-cuerpo", role: "tabpanel", tabindex: "0",
      "aria-labelledby": "guia-pestana-" + guia.pestana
    }, contenidoGuia(guia.pestana)));
    // En pantallas angostas las pestañas se desplazan: la elegida queda a la vista
    var activa = document.getElementById("guia-pestana-" + guia.pestana);
    lista.scrollLeft = Math.max(0, activa.offsetLeft - (lista.clientWidth - activa.offsetWidth) / 2);
  }
  function abrirGuia() {
    guia.abierta = true;
    guia.vuelveA = document.activeElement;
    G.ocultarGlobo();
    pintarGuia();
    var caja = document.getElementById("guia");
    document.getElementById("velo").hidden = false;
    caja.hidden = false;
    document.body.classList.add("sin-desplazar");
    window.requestAnimationFrame(function () { caja.classList.add("guia-abierta"); });
    document.getElementById("guia-cerrar").focus();
  }
  function cerrarGuia() {
    guia.abierta = false;
    var caja = document.getElementById("guia");
    caja.classList.remove("guia-abierta");
    caja.hidden = true;
    document.getElementById("velo").hidden = true;
    document.body.classList.remove("sin-desplazar");
    if (guia.vuelveA && document.contains(guia.vuelveA)) guia.vuelveA.focus();
    else document.getElementById("abrir-ayuda").focus();
  }

  function pintarBienvenida() {
    var caja = document.getElementById("bienvenida");
    caja.textContent = "";
    var marcar = el("input", { type: "checkbox", id: "bienvenida-marcar" });
    var entrar = el("button", { type: "button", "class": "boton boton-primario", id: "bienvenida-entrar" }, t("bienvenida.entrar"));
    var cerrar = el("button", { type: "button", "class": "boton-icono bienvenida-cerrar", "aria-label": t("comun.cerrar"), title: t("comun.cerrar") }, icono("cerrar"));
    entrar.addEventListener("click", cerrarBienvenida);
    cerrar.addEventListener("click", cerrarBienvenida);
    var iconos = ["pulso", "rejilla", "ayuda"];
    caja.appendChild(el("div", { "class": "bienvenida-caja" }, [
      cerrar,
      el("img", { "class": "bienvenida-logo", src: "assets/usach.png", alt: t("app.logo"), width: "113", height: "36" }),
      el("h2", { id: "bienvenida-titulo" }, t("bienvenida.titulo")),
      el("p", { "class": "bienvenida-texto" }, t("bienvenida.texto", { n: num(BD.meta.encuestados) })),
      el("ol", { "class": "pasos" }, [1, 2, 3].map(function (i) {
        return el("li", null, [
          el("span", { "class": "paso-icono" }, icono(iconos[i - 1])),
          el("h3", null, t("bienvenida.p" + i + "_t")),
          el("p", null, t("bienvenida.p" + i, { k: BD.meta.enfermedades }))
        ]);
      })),
      el("p", { "class": "bienvenida-nota" }, [icono("info"), el("span", null, t("bienvenida.nota"))]),
      entrar,
      el("label", { "class": "bienvenida-marcar", "for": "bienvenida-marcar" }, [marcar, el("span", null, t("bienvenida.no_mostrar"))])
    ]));
  }
  function abrirBienvenida() {
    bienvenida.abierta = true;
    bienvenida.vuelveA = document.activeElement;
    pintarBienvenida();
    document.getElementById("bienvenida").hidden = false;
    document.body.classList.add("sin-desplazar");
    document.getElementById("bienvenida-entrar").focus({ preventScroll: true });
  }
  function cerrarBienvenida() {
    var marcar = document.getElementById("bienvenida-marcar");
    if (marcar && marcar.checked) guardar(GUARDA_BIENVENIDA, "1");
    bienvenida.abierta = false;
    document.getElementById("bienvenida").hidden = true;
    document.body.classList.remove("sin-desplazar");
    var titulo = document.getElementById("titulo-vista");
    if (titulo) titulo.focus({ preventScroll: true });
  }

  // Mientras la guía o la bienvenida están abiertas, el tabulador no sale de ellas
  function atraparFoco(e, caja) {
    var enfocables = Array.prototype.filter.call(
      caja.querySelectorAll("button, [href], input, select, [tabindex]:not([tabindex='-1'])"),
      function (n) { return !n.disabled && n.offsetParent !== null; });
    if (!enfocables.length) return;
    var primero = enfocables[0], ultimo = enfocables[enfocables.length - 1];
    if (e.shiftKey && document.activeElement === primero) { e.preventDefault(); ultimo.focus(); }
    else if (!e.shiftKey && document.activeElement === ultimo) { e.preventDefault(); primero.focus(); }
    else if (!caja.contains(document.activeElement)) { e.preventDefault(); primero.focus(); }
  }

  /* --------------------------------------------------------------------------
     Pintado
     -------------------------------------------------------------------------- */
  function pintarBarra() {
    document.getElementById("saltar").textContent = t("app.saltar");
    document.getElementById("titulo-1").textContent = t("app.titulo_1");
    document.getElementById("titulo-2").textContent = t("app.titulo_2");
    document.getElementById("logo").alt = t("app.logo");
    document.getElementById("texto-ayuda").textContent = t("comun.ayuda");
    var idiomas = document.getElementById("idiomas");
    idiomas.setAttribute("aria-label", t("app.idioma"));
    Array.prototype.forEach.call(idiomas.querySelectorAll("button"), function (boton) {
      boton.setAttribute("aria-pressed", boton.getAttribute("data-idioma") === estado.lang ? "true" : "false");
    });
    var modos = document.getElementById("modos");
    modos.setAttribute("aria-label", t("app.vistas"));
    modos.textContent = "";
    MODOS.forEach(function (m) {
      var boton = el("button", { type: "button", id: "modo-" + m, "aria-pressed": m === estado.modo ? "true" : "false" },
        [icono(m === "enfermedad" ? "pulso" : "mapa"), el("span", null, t("modo." + m))]);
      boton.addEventListener("click", function () { elegirModo(m); });
      modos.appendChild(boton);
    });
  }

  function pintar() {
    T = TEXTOS[estado.lang];
    G.ocultarGlobo();
    document.documentElement.lang = estado.lang === "pt" ? "pt-BR" : estado.lang;
    document.title = T.app.titulo;
    pintarBarra();

    var selector = document.getElementById("selector");
    selector.textContent = "";
    selector.setAttribute("aria-label", t(estado.modo === "enfermedad" ? "selector.lista_enf" : "selector.lista_reg"));
    if (estado.modo === "enfermedad") selectorEnfermedad(selector); else selectorRegion(selector);

    raiz.textContent = "";
    (estado.modo === "enfermedad" ? vistaEnfermedad() : vistaRegion()).forEach(function (nodo) {
      if (nodo) raiz.appendChild(nodo);
    });
    actualizarAbrirTodo();

    document.getElementById("pie").textContent = t("app.pie") + " " +
      t("app.pie_base", { fecha: fecha(BD.meta.generado), n: num(BD.meta.encuestados) });
    if (guia.abierta) pintarGuia();
    medirBarra();
  }

  // Alto real de la barra superior, para que la barra de pestañas y el panel
  // de selección queden pegados justo debajo de ella
  function medirBarra() {
    var barra = document.querySelector(".cabecera");
    var pegada = window.getComputedStyle(barra).position === "sticky";
    document.documentElement.style.setProperty("--alto-barra", (pegada ? barra.offsetHeight : 0) + "px");
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
  document.getElementById("abrir-ayuda").addEventListener("click", abrirGuia);
  document.getElementById("velo").addEventListener("click", cerrarGuia);
  document.addEventListener("click", function () { G.ocultarGlobo(); });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      if (guia.abierta) cerrarGuia();
      else if (bienvenida.abierta) cerrarBienvenida();
      else G.ocultarGlobo();
    } else if (e.key === "Tab") {
      if (guia.abierta) atraparFoco(e, document.getElementById("guia"));
      else if (bienvenida.abierta) atraparFoco(e, document.getElementById("bienvenida"));
    }
  });
  window.addEventListener("hashchange", function () { leerDireccion(); pintar(); });
  window.addEventListener("popstate", function () { leerDireccion(); pintar(); });
  window.addEventListener("resize", medirBarra);
  // La red se dibuja distinto en pantallas angostas: se repinta al cruzar el corte
  var alCambiarAncho = function () { if (estado.modo === "enfermedad" && estado.seccion === "combinadas") pintar(); };
  if (PANTALLA_ANGOSTA.addEventListener) PANTALLA_ANGOSTA.addEventListener("change", alCambiarAncho);
  else if (PANTALLA_ANGOSTA.addListener) PANTALLA_ANGOSTA.addListener(alCambiarAncho);

  pintar();
  escribirDireccion(false);
  if (leerGuardado(GUARDA_BIENVENIDA) !== "1") abrirBienvenida();
})();
