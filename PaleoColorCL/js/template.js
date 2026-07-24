import { FRAMES, TEMPLATE, QR_PREFIX, frameOf, framePagePoints, markerPagePoints, qrPagePoints } from "./config.js?v=99";
import { BRAND, CONTACT, citationLines } from "./credits.js?v=99";

/**
 * Genera la hoja imprimible. La geometría (QR, marcas, rectángulo del personaje) es la misma
 * para todos los personajes y sale de config.js, así que el visor la reconoce sin saber nada
 * del dibujo.
 */

// Corrección M: aguanta manoseo y smudge de lápiz. Con M el id admite hasta 9 caracteres
// manteniendo el QR en versión 1 (21x21 = 11,43 px por módulo en los 240 px de la hoja).
// Un id más largo salta a versión 2 (25x25 = 9,6 px por módulo) y le quita alcance a jsQR.
const QR_ERROR_LEVEL = "M";
export const MAX_ID_LENGTH = 9;

export function idIsValid(id) {
  return /^[a-z0-9-]{1,9}$/.test(id);
}

export function payloadFor(id) {
  return `${QR_PREFIX}${id}`;
}

function drawQr(context, payload) {
  const qr = window.qrcode(1, QR_ERROR_LEVEL);
  qr.addData(payload);
  qr.make();
  const count = qr.getModuleCount();
  const [topLeft, , bottomRight] = qrPagePoints();
  const side = bottomRight[0] - topLeft[0];
  context.fillStyle = "#000";
  for (let row = 0; row < count; row += 1) {
    for (let column = 0; column < count; column += 1) {
      if (!qr.isDark(row, column)) continue;
      // Se redondea cada borde por separado para que no queden costuras entre módulos.
      const x0 = topLeft[0] + Math.round(column * side / count);
      const x1 = topLeft[0] + Math.round((column + 1) * side / count);
      const y0 = topLeft[1] + Math.round(row * side / count);
      const y1 = topLeft[1] + Math.round((row + 1) * side / count);
      context.fillRect(x0, y0, x1 - x0, y1 - y0);
    }
  }
  return { version: 1, modules: count, modulePx: side / count };
}

function drawMarkers(context) {
  const size = TEMPLATE.markerSize;
  context.fillStyle = "#000";
  for (const [x, y] of markerPagePoints()) {
    context.fillRect(Math.round(x - size / 2), Math.round(y - size / 2), size, size);
  }
}

// Los datos del personaje NO van en la hoja: aparecen en realidad aumentada, alrededor de la
// figura, en el visor. La hoja se queda con el dibujo, el QR y las marcas.

/**
 * Pie de la hoja.
 *
 * El espacio es de 155 px y no negociable: las marcas inferiores terminan en y=1492 y una
 * impresora no imprime los últimos ~10 mm (57 px). Apilado —logo arriba, cita abajo— la última
 * tinta caía en y=1701 y se recortaba en el borde del papel. Va en dos columnas: logo a la
 * izquierda, cita a la derecha, contacto abajo.
 */
function drawFooter(context, logo) {
  const { width } = TEMPLATE;
  const top = 1520;
  const left = 60;
  let textLeft = left;

  if (logo) {
    const logoWidth = 230;
    const logoHeight = logoWidth * logo.height / logo.width;
    context.drawImage(logo, left, top + 4, logoWidth, logoHeight);
    textLeft = left + logoWidth + 26;
  }

  context.textAlign = "left";
  context.textBaseline = "top";
  const textWidth = width - textLeft - left;
  let y = top;
  context.fillStyle = "#9aa1ab";
  context.font = "700 13px system-ui, sans-serif";
  context.fillText("Basado en:", textLeft, y);
  y += 16;
  context.fillStyle = "#6b7280";
  context.font = "400 12px system-ui, sans-serif";
  for (const line of citationLines()) {
    for (const wrapped of wrap(context, line, textWidth)) {
      context.fillText(wrapped, textLeft, y);
      y += 15;
    }
  }
  // Esta hoja se la lleva un niño: si un dato está malo, alguien tiene que poder avisar.
  y += 5;
  context.fillStyle = BRAND.teal;
  context.font = "700 13px system-ui, sans-serif";
  context.fillText(`${CONTACT.note} ${CONTACT.email}`, textLeft, y);
}

function wrap(context, text, maxWidth) {
  const words = text.split(" ");
  const lines = [];
  let current = "";
  for (const word of words) {
    const attempt = current ? `${current} ${word}` : word;
    if (context.measureText(attempt).width > maxWidth && current) {
      lines.push(current);
      current = word;
    } else {
      current = attempt;
    }
  }
  if (current) lines.push(current);
  return lines;
}

/**
 * @param {object} options
 * @param {string} options.id        id corto del personaje, va dentro del QR
 * @param {string} options.name      nombre visible, sólo decorativo
 * @param {CanvasImageSource} options.lineart  dibujo del personaje
 * @param {CanvasImageSource|null} options.logo
 * @returns {{canvas: HTMLCanvasElement, qr: object}}
 */
export function renderSheet({ id, name, lineart, logo, frame, number }) {
  if (!idIsValid(id)) throw new Error(`id inválido: "${id}"`);
  // El marco es obligatorio y a propósito no tiene default. Lo tenía ("vertical") y
  // plantillas.html no se lo pasaba: imprimía TODAS las hojas con el dibujo en el rect
  // vertical mientras la app muestreaba el rect del manifiesto. Nunca calzaban, y nada
  // avisaba porque el default hacía que pareciera correcto.
  if (!FRAMES[frame]) {
    throw new Error(`renderSheet necesita un marco válido, llegó "${frame}". Marcos: ${Object.keys(FRAMES).join(", ")}`);
  }
  const canvas = document.createElement("canvas");
  canvas.width = TEMPLATE.width;
  canvas.height = TEMPLATE.height;
  const context = canvas.getContext("2d");
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);

  const qr = drawQr(context, payloadFor(id));
  drawMarkers(context);

  const [topLeft, , bottomRight] = framePagePoints(frameOf(frame));
  const width = bottomRight[0] - topLeft[0];
  const height = bottomRight[1] - topLeft[1];
  context.fillStyle = "#fff";
  context.fillRect(topLeft[0], topLeft[1], width, height);
  if (lineart) context.drawImage(lineart, topLeft[0], topLeft[1], width, height);

  context.fillStyle = BRAND.slate;
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.font = "800 40px system-ui, sans-serif";
  context.fillText(name || id, TEMPLATE.width / 2, 62);
  if (number) {
    // Número identificador: para coleccionar la serie y para nombrar la hoja sin leerla.
    // Va lejos del QR y de las marcas; a este tamaño no lo confunde el detector, que
    // descarta manchas fuera de [1122, 11469] px de área.
    context.fillStyle = BRAND.orange;
    context.beginPath();
    context.arc(96, 62, 34, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = "#fff";
    context.font = "900 34px system-ui, sans-serif";
    context.fillText(String(number), 96, 64);
  }
  context.fillStyle = "#9aa1ab";
  context.font = "600 22px system-ui, sans-serif";
  context.fillText("Colorea el dibujo · no pintes el QR ni las 4 marcas negras", TEMPLATE.width / 2, 548);
  context.font = "600 24px system-ui, sans-serif";
  context.fillText("Después apunta la cámara: sus datos aparecen alrededor", TEMPLATE.width / 2, 586);

  drawFooter(context, logo);
  return { canvas, qr };
}

export function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`No se pudo cargar ${url}`));
    image.src = url;
  });
}

export function loadBrandLogo() {
  return loadImage(BRAND.logo).catch(() => null);
}
