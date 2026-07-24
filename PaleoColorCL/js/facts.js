import { BRAND } from "./credits.js?v=99";
import { drawIcon, iconFor } from "./icons.js?v=99";
import { HABITAT_COLOUR, HABITAT_LABEL } from "./ambient.js?v=99";

/**
 * Datos en realidad aumentada.
 *
 * No van impresos en la hoja: aparecen en pantalla, junto al dibujo, y siguen a la hoja
 * cuando se mueve el teléfono. La tarjeta se dibuja **derecha**, no rotada con la hoja: un
 * texto que gira con el papel es ilegible en cuanto la hoja se inclina, y el punto es que un
 * niño lo lea.
 *
 * Van pasando de a uno. Mostrar seis a la vez sobre una hoja de 10 cm en pantalla no se lee.
 */
const FADE_MS = 380;

/**
 * Los datos NO avanzan solos.
 *
 * Iban de a uno cada 7 segundos y era muy rápido: un niño de 8 años no alcanza a leer 3 líneas
 * y mirar al bicho al mismo tiempo, y si se pierde uno no puede volver. Ahora manda él: toca la
 * pantalla y viene el siguiente.
 *
 * Se evaluó una palabra clave por voz ("dime más"). Se descartó: SpeechRecognition manda el
 * audio a un servidor de Google, o sea necesita red —y esta app es offline— y sube voces de
 * niños a un tercero. Firefox no lo soporta. Y en una sala con veinte niños el micrófono agarra
 * todo. Un toque es offline, instantáneo y sin permisos.
 */

/**
 * Texto con palabras destacadas. `**así**` se pinta en negrita y en teal.
 *
 * No alcanza con partir por espacios y medir: cada palabra puede tener su propia tipografía,
 * así que el ancho hay que medirlo palabra por palabra con la fuente que le toca.
 */
function tokenize(text) {
  const out = [];
  for (const chunk of text.split(/(\*\*[^*]+\*\*)/g)) {
    if (!chunk) continue;
    const bold = chunk.startsWith("**") && chunk.endsWith("**");
    const body = bold ? chunk.slice(2, -2) : chunk;
    for (const word of body.split(/(\s+)/)) {
      if (word === "") continue;
      out.push({ text: word, bold });
    }
  }
  return out;
}

const FONT = { normal: "400 17px system-ui, sans-serif", bold: "800 17px system-ui, sans-serif" };

function layout(context, text, maxWidth) {
  const lines = [[]];
  let width = 0;
  for (const token of tokenize(text)) {
    context.font = token.bold ? FONT.bold : FONT.normal;
    const w = context.measureText(token.text).width;
    const espacio = /^\s+$/.test(token.text);
    if (espacio && !lines[lines.length - 1].length) continue;   // sin espacios al inicio de línea
    if (width + w > maxWidth && lines[lines.length - 1].length) {
      if (espacio) continue;
      lines.push([]);
      width = 0;
    }
    lines[lines.length - 1].push({ ...token, w });
    width += w;
  }
  return lines.filter((l) => l.length);
}

function drawLines(context, lines, x, y, lineHeight) {
  lines.forEach((line, i) => {
    let cursor = x;
    for (const token of line) {
      context.font = token.bold ? FONT.bold : FONT.normal;
      context.fillStyle = token.bold ? BRAND.teal : "#3f4750";
      context.fillText(token.text, cursor, y + i * lineHeight);
      cursor += token.w;
    }
  });
}

/**
 * Franja de identidad: grupo, tamaño comparado y edad.
 *
 * "8 metros" no le dice nada a nadie. Al lado de la silueta de un niño de 1,3 m, sí.
 */
function drawStrip(context, facts, x, y, width, character, reservaEquis) {
  context.textAlign = "left";
  context.textBaseline = "top";

  drawIcon(context, "huella", x, y, 16, BRAND.teal);
  context.font = "800 13px system-ui, sans-serif";
  context.fillStyle = BRAND.teal;
  let cx = x + 22;
  if (facts.group) {
    context.fillText(facts.group.toUpperCase(), cx, y + 3);
    cx += context.measureText(facts.group.toUpperCase()).width + 10;
  }
  // El hábitat es lo que explica el ambiente que se escucha de fondo.
  if (character?.habitat) {
    const etiqueta = HABITAT_LABEL[character.habitat] ?? character.habitat;
    context.fillStyle = HABITAT_COLOUR[character.habitat] ?? "#7d858e";
    context.font = "800 12px system-ui, sans-serif";
    context.fillText(etiqueta.toUpperCase(), cx, y + 4);
  }

  if (facts.age) {
    // La edad va a la derecha, y ahí arriba está la ✕. Medido comparando la tarjeta con y sin
    // ✕: tapaba 84 px de texto en el primer dato y 220 en el segundo. Se le deja su hueco.
    const edad = `${facts.age} Ma`;
    context.font = "800 13px system-ui, sans-serif";
    const w = context.measureText(edad).width;
    const derecha = x + width - (reservaEquis ?? 0);
    drawIcon(context, "reloj", derecha - w - 20, y + 1, 14, "#a6adb5");
    context.fillStyle = "#79818a";
    context.fillText(edad, derecha - w, y + 3);
  }

  // Comparación de tamaño: un niño de 1,3 m contra el largo del bicho.
  const base = y + 48;
  const alto = 24;
  drawIcon(context, "nino", x, base - alto, alto, "#c8cfd6");
  const escala = alto / 1.3;
  const largo = Math.min((facts.sizeM ?? 2) * escala, width - 96);
  const bx = x + 24;
  context.fillStyle = BRAND.teal;
  context.fillRect(bx, base - 10, largo, 10);
  context.fillStyle = "#aeb6bf";
  context.fillRect(bx, base - 14, 2, 18);
  context.fillRect(bx + largo - 2, base - 14, 2, 18);
  context.font = "800 14px system-ui, sans-serif";
  context.fillStyle = "#454d56";
  context.fillText(`${facts.sizeM} m`, bx + largo + 9, base - 13);
  return y + 56;
}

/** Baja el cuerpo de la letra hasta que el texto quepa en `maxWidth`. */
function fitFont(context, text, maxWidth, size, min) {
  for (let s = size; s > min; s -= 1) {
    context.font = `800 ${s}px system-ui, sans-serif`;
    if (context.measureText(text).width <= maxWidth) return s;
  }
  return min;
}

function roundRect(context, x, y, w, h, r) {
  context.beginPath();
  if (typeof context.roundRect === "function") context.roundRect(x, y, w, h, r);
  else context.rect(x, y, w, h);
}

/**
 * @param character personaje activo (trae facts en su manifiesto)
 * @param viewport  {width, height} de la escena
 */
/**
 * @param state {index, since} — cuál dato y hace cuánto cambió, para el fundido de entrada.
 */
/**
 * Devuelve las zonas tocables: { card, hide }, o null si no dibujó nada.
 *
 * NO recibe la pose, y eso es deliberado: la tarjeta va siempre abajo y centrada. Es texto en
 * pantalla, no está pegada al papel.
 *
 * Antes avanzaba tocando CUALQUIER parte de la pantalla, y eso era peor que el temporizador:
 * acomodar el agarre pasaba el dato sin querer. Ahora sólo cuenta el toque sobre la tarjeta,
 * que mide 55-63 mm (el mínimo recomendado son 9), así que acertarle no es el problema.
 */
export function drawFactCard(context, character, state, viewport) {
  const facts = character?.facts;
  const items = facts?.items ?? [];
  if (!items.length) return null;

  // Escondida: sólo queda un botoncito para traerla de vuelta. La tarjeta ocupa el tercio de
  // abajo y a veces uno quiere ver al bicho y nada más.
  if (state.hidden) return { chip: drawChip(context, viewport) };

  const index = ((state.index % items.length) + items.length) % items.length;
  const item = items[index];
  const alpha = Math.min(1, Math.max(0, state.since) / FADE_MS);
  if (alpha <= 0.02) return null;

  // 14 px era ilegible para un niño a un brazo de distancia. 17 con interlínea de 23.
  // El margen contra el borde tiene que ser mayor que el difuminado de la sombra (18 px) o
  // la sombra se asoma: con 14 px, dos personajes daban 9-11 px de tinta en el borde derecho.
  const margen = 22;
  const width = Math.min(344, viewport.width - margen * 2);
  context.save();
  const lines = layout(context, item.text, width - 30);
  const first = index === 0 && facts.pronunciation;
  const headerHeight = first ? 48 : 0;
  // La franja de identidad va SIEMPRE. El grupo, el tamaño y la edad no son un dato más que
  // haya que esperar siete segundos: son quién es el bicho.
  const stripHeight = facts.group ? 56 : 0;
  const height = 15 + headerHeight + stripHeight + 25 + lines.length * 23 + 62;

  // Se busca dónde no tape el dibujo: debajo de la hoja, si no arriba, si no al costado.
  // SIEMPRE abajo y centrada. No sigue a la hoja, y es a propósito.
  //
  // Antes se colocaba respecto de la pose: debajo de la hoja, o encima si no cabía, o pegada al
  // fondo si tampoco. Tres reglas encadenadas que hacían que **saltara de lugar** al mover el
  // teléfono, justo mientras el niño estaba leyendo. Es texto en pantalla, no está pegada al
  // papel: no tiene por qué moverse.
  //
  // Y de paso deja de depender de la pose, que es lo que la hacía desaparecer al perder el QR.
  const x = Math.round((viewport.width - width) / 2);
  const y = Math.round(viewport.height - height - 20);

  context.globalAlpha = alpha;
  context.shadowColor = "rgba(0,0,0,.35)";
  context.shadowBlur = 18;
  context.shadowOffsetY = 4;
  roundRect(context, x, y, width, height, 14);
  context.fillStyle = "rgba(255,255,255,.96)";
  context.fill();
  context.shadowColor = "transparent";
  context.shadowBlur = 0;
  context.shadowOffsetY = 0;

  context.textAlign = "left";
  context.textBaseline = "top";
  let cursor = y + 15;
  if (first) {
    // La pronunciación se encoge hasta caber. Sin esto, un nombre largo se sale del cuadro:
    // "bur·ke·SU·chus ma·llin·gran·DEN·sis" mide 372 px a 18 px, en una tarjeta de 344.
    context.fillStyle = BRAND.teal;
    context.font = `800 ${fitFont(context, facts.pronunciation, width - 78, 18, 11)}px system-ui, sans-serif`;
    context.fillText(facts.pronunciation, x + 15, cursor);
    context.fillStyle = "#98a0aa";
    context.font = `italic 400 ${fitFont(context, facts.meaning ?? "", width - 78, 15, 10)}px system-ui, sans-serif`;
    context.fillText(facts.meaning ?? "", x + 15, cursor + 23);
    cursor += headerHeight;
    context.strokeStyle = "#e6eaed";
    context.lineWidth = 1;
    context.beginPath();
    context.moveTo(x + 15, cursor - 8);
    context.lineTo(x + width - 15, cursor - 8);
    context.stroke();
  }

  // La ✕ sólo estorba a la franja cuando NO hay encabezado que la empuje hacia abajo: con
  // encabezado la franja va a y+63 y la ✕ termina en y+46.
  const reserva = first ? 0 : 46;
  if (facts.group || character.habitat) cursor = drawStrip(context, facts, x + 15, cursor, width - 30, character, reserva);

  drawIcon(context, iconFor(item.label), x + 15, cursor, 16, BRAND.orange);
  context.font = "800 15px system-ui, sans-serif";
  context.fillStyle = BRAND.orange;
  context.textAlign = "left";
  context.textBaseline = "top";
  context.fillText(item.label.toUpperCase(), x + 38, cursor + 1);
  drawLines(context, lines, x + 15, cursor + 27, 23);

  // Botones de VERDAD: con fondo, altos y con contraste. Antes eran texto suelto de 11-12 px
  // —uno gris claro sobre blanco— y nadie los tocaba porque no parecían tocables.
  const bh = 40;
  const by = y + height - bh - 12;
  const label = index < items.length - 1 ? "DIME MÁS  ▸" : "VOLVER AL PRIMERO  ↺";
  context.font = "900 14px system-ui, sans-serif";
  const bw = Math.min(width - 30, context.measureText(label).width + 34);
  const bx = x + width - 15 - bw;
  roundRect(context, bx, by, bw, bh, 20);
  context.fillStyle = index < items.length - 1 ? BRAND.teal : "#8f979f";
  context.fill();
  context.fillStyle = "#fff";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(label, bx + bw / 2, by + bh / 2 + 1);

  // Cerrar: una ✕ y nada más. La pastilla "OCULTAR ✕" medía 5-6 mm de alto (bajo el mínimo
  // de 9) y encima gastaba una palabra en algo que una ✕ dice sola.
  //
  // El DIBUJO mide 34 px y la ZONA TOCABLE 48: no tienen por qué medir lo mismo. Una ✕ de
  // 48 px se ve como un botón de alarma; una de 34 se ve bien pero un dedo de niño no le
  // acierta. En canvas se controlan por separado, así que se hacen distintas.
  const dib = 34;
  const zona = 48;
  const cxx = x + width - 12 - dib / 2;
  const cyy = y + 12 + dib / 2;
  const hide = { x: cxx - zona / 2, y: cyy - zona / 2, w: zona, h: zona };
  context.beginPath();
  context.arc(cxx, cyy, dib / 2, 0, Math.PI * 2);
  context.fillStyle = "#eef1f4";
  context.fill();
  context.strokeStyle = "#dbe1e6";
  context.lineWidth = 1.5;
  context.stroke();
  context.strokeStyle = "#7a828a";
  context.lineWidth = 2.4;
  context.lineCap = "round";
  const b = 6.5;
  context.beginPath();
  context.moveTo(cxx - b, cyy - b);
  context.lineTo(cxx + b, cyy + b);
  context.moveTo(cxx + b, cyy - b);
  context.lineTo(cxx - b, cyy + b);
  context.stroke();
  context.lineCap = "butt";
  context.textAlign = "left";
  context.textBaseline = "top";

  // Puntitos: cuántos datos hay y en cuál va.
  const dotY = y + height - bh - 22;
  const total = items.length;
  const dotsWidth = total * 10 - 4;
  items.forEach((_, i) => {
    context.fillStyle = i === index ? BRAND.teal : "#dfe4e8";
    context.beginPath();
    context.arc(x + width / 2 - dotsWidth / 2 + i * 10 + 2, dotY, 2.5, 0, Math.PI * 2);
    context.fill();
  });
  context.restore();
  return { card: { x, y, w: width, h: height }, hide };
}

/**
 * Botón para pedir los datos.
 *
 * No es un "?": la app ya tiene "Cómo funciona" abajo, y para un niño "?" y "Cómo funciona"
 * son lo mismo — ayuda. Este botón no es ayuda, es "contame de ESTE bicho".
 *
 * Lleva la HUELLA, el mismo icono que encabeza la franja de la tarjeta
 * (huella + ANQUILOSAURIO · TERRESTRE · 72 Ma): el niño ya la tiene asociada a "info del
 * animal". Y lleva la palabra, porque un icono solo siempre es una adivinanza.
 *
 * Pasa de 1,1% a 2,4% de la pantalla. La tarjeta entera tapa el 35%.
 */
function drawChip(context, viewport) {
  context.save();
  context.font = "900 13px system-ui, sans-serif";
  const texto = "SUS DATOS";
  const w = Math.round(context.measureText(texto).width) + 58;
  const h = 52;
  const x = viewport.width - w - 18;
  const y = viewport.height - h - 22;

  context.shadowColor = "rgba(0,0,0,.45)";
  context.shadowBlur = 16;
  context.shadowOffsetY = 4;
  roundRect(context, x, y, w, h, h / 2);
  context.fillStyle = BRAND.teal;
  context.fill();
  context.shadowColor = "transparent";
  context.strokeStyle = "rgba(255,255,255,.55)";
  context.lineWidth = 2;
  context.stroke();

  drawIcon(context, "huella", x + 15, y + h / 2 - 11, 22, "#fff");
  context.fillStyle = "#fff";
  context.textAlign = "left";
  context.textBaseline = "middle";
  context.fillText(texto, x + 45, y + h / 2 + 1);
  context.restore();
  return { x, y, w, h };
}
