/* =============================================================================
   js/graficos.js
   Piezas con que se arma cada gráfico: barras, barra segmentada, red de
   enfermedades, mapa de regiones, tabla equivalente y globo de detalle.
   Todo es HTML y SVG propios; no se usa ninguna librería externa.

   Reglas de color (se validaron con una herramienta de contraste y
   daltonismo; no se cambian a ojo):
     - una sola serie: un solo color (COLOR.serie);
     - categorías de una misma escala ordenada: rampa de un solo tono;
     - series distintas en un mismo gráfico: COLOR.categorias, siempre con
       leyenda y con el valor escrito.
   ============================================================================= */
(function () {
  "use strict";

  var SVG = "http://www.w3.org/2000/svg";

  var COLOR = {
    serie: "#00A499",                                   // teal USACH
    acento: "#EA7600",                                  // naranja USACH: selección
    categorias: ["#00A499", "#EA7600", "#8C4799"],      // teal, naranja, morado
    neutro: "#98A2A9",
    rampa3: ["#5DC1B8", "#00958B", "#00554F"],
    rampa4: ["#5DC1B8", "#1BA298", "#007D75", "#00514C"],
    rampa6: ["#5DC1B8", "#36AEA5", "#0F9A91", "#00847C", "#006A64", "#004A45"],
    sinDato: "#E3E8EA"
  };

  /* --------------------------------------------------------------------------
     Creación de elementos. El texto siempre entra como nodo de texto, nunca
     como HTML.
     -------------------------------------------------------------------------- */
  function el(etiqueta, atributos, hijos) {
    var nodo = document.createElement(etiqueta);
    return completar(nodo, atributos, hijos);
  }
  function svg(etiqueta, atributos, hijos) {
    var nodo = document.createElementNS(SVG, etiqueta);
    return completar(nodo, atributos, hijos);
  }
  function completar(nodo, atributos, hijos) {
    var clave;
    if (atributos) {
      for (clave in atributos) {
        if (atributos[clave] !== null && atributos[clave] !== undefined && atributos[clave] !== false) {
          nodo.setAttribute(clave, atributos[clave] === true ? "" : atributos[clave]);
        }
      }
    }
    agregar(nodo, hijos);
    return nodo;
  }
  function agregar(nodo, hijos) {
    if (hijos === null || hijos === undefined || hijos === false) return;
    if (Array.isArray(hijos)) { hijos.forEach(function (hijo) { agregar(nodo, hijo); }); return; }
    nodo.appendChild(typeof hijos === "object" ? hijos : document.createTextNode(String(hijos)));
  }

  /* --------------------------------------------------------------------------
     Globo de detalle. Acompaña al puntero o se ancla al elemento con foco.
     Nunca es la única forma de leer un valor: cada gráfico tiene su tabla.
     -------------------------------------------------------------------------- */
  var globo = null;
  function crearGlobo() {
    if (!globo) {
      globo = el("div", { "class": "globo", role: "tooltip", hidden: true });
      document.body.appendChild(globo);
    }
    return globo;
  }
  function mostrarGlobo(texto, x, y) {
    var g = crearGlobo();
    g.textContent = texto;
    g.hidden = false;
    var ancho = g.offsetWidth, alto = g.offsetHeight;
    var izq = Math.min(Math.max(8, x + 14), window.innerWidth - ancho - 8);
    var arriba = y + 18 + alto > window.innerHeight ? y - alto - 12 : y + 18;
    g.style.left = izq + "px";
    g.style.top = Math.max(8, arriba) + "px";
  }
  function ocultarGlobo() { if (globo) globo.hidden = true; }

  function conGlobo(nodo, texto) {
    var dar = typeof texto === "function" ? texto : function () { return texto; };
    nodo.addEventListener("pointerenter", function (e) { mostrarGlobo(dar(), e.clientX, e.clientY); });
    nodo.addEventListener("pointermove", function (e) { mostrarGlobo(dar(), e.clientX, e.clientY); });
    nodo.addEventListener("pointerleave", ocultarGlobo);
    nodo.addEventListener("focus", function () {
      var caja = nodo.getBoundingClientRect();
      mostrarGlobo(dar(), caja.left + caja.width / 2, caja.bottom - 6);
    });
    nodo.addEventListener("blur", ocultarGlobo);
    return nodo;
  }
  window.addEventListener("scroll", ocultarGlobo, true);

  /* --------------------------------------------------------------------------
     Barras horizontales.
       filas:  [{ etq, pct, valor, detalle, color }]
               pct     número de 0 a 100 (null si no hay dato)
               valor   texto que se escribe en la punta de la barra
               detalle texto del globo
       escala: 100 para porcentajes de un mismo grupo (por defecto) o "max"
               para estirar hasta la barra más larga. Con "max" no se dibuja
               la pista de fondo, porque una barra llena no significa 100 %.
     Si algún rótulo pasa de ROTULO_LARGO caracteres, todos van en su propia
     línea sobre la barra: se leen completos en vez de partirse en una columna
     angosta.
     -------------------------------------------------------------------------- */
  var ROTULO_LARGO = 30;
  function barras(filas, opciones) {
    opciones = opciones || {};
    var tope = 100;
    if (opciones.escala === "max") {
      tope = Math.max.apply(null, filas.map(function (f) { return f.pct || 0; }).concat([1]));
    }
    var apiladas = filas.some(function (f) { return f.etq.length > ROTULO_LARGO; });
    var lista = el("ul", { "class": "barras" + (apiladas ? " barras-apiladas" : "") +
                                    (opciones.escala === "max" ? " barras-relativas" : "") });
    filas.forEach(function (f) {
      var barra = el("span", { "class": "barra" });
      barra.style.width = (f.pct ? Math.max(f.pct / tope * 100, 0.8) : 0) + "%";
      barra.style.background = f.color || COLOR.serie;
      var fila = el("li", { "class": "fila" + (f.pct ? "" : " fila-cero") }, [
        el("span", { "class": "fila-etq" }, f.etq),
        el("span", { "class": "fila-pista" }, barra),
        el("span", { "class": "fila-val" }, f.valor)
      ]);
      if (f.detalle) conGlobo(fila, f.detalle);
      lista.appendChild(fila);
    });
    return lista;
  }

  /* --------------------------------------------------------------------------
     Barra segmentada delgada con sus cifras al lado: un todo repartido en
     pocas partes ordenadas. Cada fila de la lista lleva su muestra de color,
     así que no hace falta otra leyenda.
       filas: [{ etq, pct, valor, detalle }]   colores: rampa de un tono
     -------------------------------------------------------------------------- */
  function segmentada(filas, colores, nombre) {
    var barra = el("div", { "class": "seg-barra", role: "img", "aria-label": nombre || "" });
    var lista = el("ul", { "class": "seg-lista" });
    filas.forEach(function (f, i) {
      if (f.pct) {
        var parte = el("span", { "class": "seg-parte" });
        parte.style.flexGrow = String(f.pct);
        parte.style.background = colores[i];
        if (f.detalle) conGlobo(parte, f.detalle);
        barra.appendChild(parte);
      }
      var muestra = el("span", { "class": "muestra" });
      muestra.style.background = colores[i];
      var fila = el("li", { "class": f.pct ? "" : "fila-cero" }, [
        muestra,
        el("span", { "class": "seg-etq" }, f.etq),
        el("span", { "class": "seg-val" }, f.valor)
      ]);
      if (f.detalle) conGlobo(fila, f.detalle);
      lista.appendChild(fila);
    });
    return el("div", { "class": "seg" }, [barra, lista]);
  }

  /* --------------------------------------------------------------------------
     Leyenda de series. items: [{ etq, color }]
     -------------------------------------------------------------------------- */
  function leyenda(items, titulo) {
    return el("ul", { "class": "leyenda", "aria-label": titulo || null }, items.map(function (item) {
      var muestra = el("span", { "class": "muestra" });
      muestra.style.background = item.color;
      return el("li", null, [muestra, item.etq]);
    }));
  }

  /* --------------------------------------------------------------------------
     Tabla equivalente a un gráfico.
       columnas: [texto, ...]   filas: [[celda, ...], ...]
       La primera columna es el encabezado de fila; las demás son números.
     -------------------------------------------------------------------------- */
  function tabla(columnas, filas, titulo) {
    return el("table", { "class": "tabla" }, [
      titulo ? el("caption", null, titulo) : null,
      el("thead", null, el("tr", null, columnas.map(function (c, i) {
        return el("th", { scope: "col", "class": i ? "num" : null }, c);
      }))),
      el("tbody", null, filas.map(function (fila) {
        return el("tr", null, fila.map(function (celda, i) {
          return i === 0 ? el("th", { scope: "row" }, celda) : el("td", { "class": "num" }, celda);
        }));
      }))
    ]);
  }

  /* --------------------------------------------------------------------------
     Red de enfermedades combinadas, con los nodos en círculo.
       nodos:   [{ id, nombre, n, color, detalle }]
       aristas: [{ a, b, n, detalle }]
       elegido: id del nodo seleccionado
       alElegir(id): se llama al hacer clic o al pulsar Enter o Espacio
       compacta: dibujo para pantallas angostas (círculo más chico y letra más
                 grande, para que los rótulos se lean sin ampliar)
     El tamaño del círculo crece con la raíz del número de personas, para que
     el área (y no el radio) sea proporcional. El grosor de la línea crece con
     las personas que declaran ambas enfermedades.
     -------------------------------------------------------------------------- */
  function red(nodos, aristas, elegido, alElegir, nombre, compacta) {
    var M = compacta
      ? { ancho: 470, alto: 380, cx: 235, cy: 194, radio: 90, rMin: 6, rMas: 14, grosor: 6, letra: 17, corte: 12, aire: 10 }
      : { ancho: 700, alto: 540, cx: 350, cy: 270, radio: 178, rMin: 9, rMas: 21, grosor: 9, letra: 17, corte: 15, aire: 12 };
    var ANCHO = M.ancho, ALTO = M.alto, CX = M.cx, CY = M.cy, RADIO = M.radio;
    var maxN = Math.max.apply(null, nodos.map(function (d) { return d.n; }));
    var maxA = Math.max.apply(null, aristas.map(function (d) { return d.n; }).concat([1]));
    var pos = {};
    nodos.forEach(function (d, i) {
      var angulo = -Math.PI / 2 + i * 2 * Math.PI / nodos.length;
      pos[d.id] = {
        x: CX + RADIO * Math.cos(angulo), y: CY + RADIO * Math.sin(angulo),
        cos: Math.cos(angulo), sin: Math.sin(angulo),
        r: M.rMin + M.rMas * Math.sqrt(d.n / maxN)
      };
    });

    var raiz = svg("svg", {
      "class": "red" + (compacta ? " red-compacta" : ""), viewBox: "0 0 " + ANCHO + " " + ALTO,
      role: "group", "aria-label": nombre
    });
    var capaAristas = svg("g", { "class": "red-aristas" });
    var capaNodos = svg("g", { "class": "red-nodos" });

    // Primero las aristas ajenas al nodo elegido, encima las suyas
    aristas.slice().sort(function (p, q) {
      return (toca(p) - toca(q)) || (p.n - q.n);
    }).forEach(function (a) {
      var p = pos[a.a], q = pos[a.b];
      var trazo = "M" + p.x.toFixed(1) + " " + p.y.toFixed(1) + "L" + q.x.toFixed(1) + " " + q.y.toFixed(1);
      var grupo = svg("g", { "class": "arista" + (toca(a) ? " arista-elegida" : "") }, [
        svg("path", { d: trazo, "class": "arista-linea", "stroke-width": (1 + M.grosor * a.n / maxA).toFixed(2) }),
        svg("path", { d: trazo, "class": "arista-zona" })
      ]);
      conGlobo(grupo, a.detalle);
      capaAristas.appendChild(grupo);
    });
    function toca(a) { return a.a === elegido || a.b === elegido ? 1 : 0; }

    nodos.forEach(function (d) {
      var p = pos[d.id];
      var esElegido = d.id === elegido;
      var grupo = svg("g", {
        "class": "nodo" + (esElegido ? " nodo-elegido" : ""),
        tabindex: "0", role: "button", "aria-pressed": esElegido ? "true" : "false", "aria-label": d.detalle
      });
      if (esElegido) grupo.appendChild(svg("circle", { cx: p.x, cy: p.y, r: p.r + 5, "class": "nodo-aro" }));
      grupo.appendChild(svg("circle", { cx: p.x, cy: p.y, r: p.r, fill: d.color, "class": "nodo-disco" }));

      // Rótulo hacia afuera del círculo, partido en dos líneas si es largo
      var lineas = partir(d.nombre, M.corte);
      var distancia = p.r + M.aire;
      var tx = p.x + p.cos * distancia, ty = p.y + p.sin * distancia;
      var ancla = Math.abs(p.cos) < 0.25 ? "middle" : (p.cos > 0 ? "start" : "end");
      var arriba = p.sin < -0.25, abajo = p.sin > 0.25;
      var y0 = ty + (arriba ? -(lineas.length - 1) * M.letra - 2 : abajo ? 13 : -(lineas.length - 1) * M.letra / 2 + 5);
      var texto = svg("text", { x: tx, y: y0, "text-anchor": ancla, "class": "nodo-etq" });
      lineas.forEach(function (linea, i) {
        texto.appendChild(svg("tspan", { x: tx, dy: i ? M.letra : 0 }, linea));
      });
      grupo.appendChild(texto);

      grupo.addEventListener("click", function () { alElegir(d.id); });
      grupo.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); alElegir(d.id); }
      });
      conGlobo(grupo, d.detalle);
      capaNodos.appendChild(grupo);
    });

    raiz.appendChild(capaAristas);
    raiz.appendChild(capaNodos);
    return raiz;
  }

  // Parte un texto en líneas de hasta `largo` caracteres sin cortar palabras
  function partir(texto, largo) {
    var lineas = [], actual = "";
    texto.split(" ").forEach(function (palabra) {
      if (actual && (actual + " " + palabra).length > largo) { lineas.push(actual); actual = palabra; }
      else actual = actual ? actual + " " + palabra : palabra;
    });
    if (actual) lineas.push(actual);
    return lineas;
  }

  /* --------------------------------------------------------------------------
     Mapa de regiones (coropleta por clases).
       geo:      BD_REGIONES
       regiones: [{ cod, color, detalle }]
       elegida:  código de la región seleccionada
     La región elegida se dibuja al final para que su borde quede encima.
     El mapa se usa con el puntero. Quien navega con teclado o lector de
     pantalla elige la región en la lista o en el selector, que traen lo mismo.
     -------------------------------------------------------------------------- */
  function mapa(geo, regiones, elegida, alElegir) {
    var porCodigo = {};
    regiones.forEach(function (r) { porCodigo[r.cod] = r; });
    var raiz = svg("svg", {
      "class": "mapa", viewBox: "-6 -6 " + (geo.ancho + 12) + " " + (geo.alto + 12), "aria-hidden": "true"
    });
    geo.regiones.slice().sort(function (p, q) {
      return (p.cod === elegida ? 1 : 0) - (q.cod === elegida ? 1 : 0);
    }).forEach(function (g) {
      var r = porCodigo[g.cod];
      if (!r) return;
      var esElegida = g.cod === elegida;
      var trazo = svg("path", { d: g.d, fill: r.color, "class": "region" + (esElegida ? " region-elegida" : "") });
      trazo.addEventListener("click", function () { alElegir(g.cod); });
      conGlobo(trazo, r.detalle);
      raiz.appendChild(trazo);
    });
    return raiz;
  }

  window.RCL_GRAFICOS = {
    COLOR: COLOR, el: el, svg: svg, barras: barras, segmentada: segmentada, leyenda: leyenda,
    tabla: tabla, red: red, mapa: mapa, conGlobo: conGlobo, ocultarGlobo: ocultarGlobo
  };
})();
