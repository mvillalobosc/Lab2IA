/**
 * Iconos vectoriales. Se dibujan con paths, no hay archivos ni tipografía de iconos: el
 * paquete es offline y una fuente de iconos son 40 KB para usar seis glifos.
 *
 * Todos se dibujan dentro de una caja de 0..1 y se escalan afuera.
 */

function huella(c) {
  // Huella de terópodo: almohadilla y tres dedos. Es LA marca de un dinosaurio.
  c.beginPath();
  c.ellipse(0.5, 0.68, 0.2, 0.24, 0, 0, Math.PI * 2);
  c.fill();
  for (const [x, y, rx, ry, rot] of [[0.22, 0.34, 0.09, 0.17, -0.42], [0.5, 0.24, 0.09, 0.19, 0], [0.78, 0.34, 0.09, 0.17, 0.42]]) {
    c.beginPath();
    c.ellipse(x, y, rx, ry, rot, 0, Math.PI * 2);
    c.fill();
  }
}

function regla(c) {
  c.beginPath();
  c.rect(0.06, 0.36, 0.88, 0.28);
  c.fill();
  c.globalCompositeOperation = "destination-out";
  for (let i = 1; i < 6; i += 1) {
    c.beginPath();
    c.rect(0.06 + i * 0.147, 0.36, 0.04, i % 2 ? 0.11 : 0.18);
    c.fill();
  }
  c.globalCompositeOperation = "source-over";
}

function reloj(c) {
  // Reloj de arena: el tiempo profundo.
  c.beginPath();
  c.moveTo(0.2, 0.08);
  c.lineTo(0.8, 0.08);
  c.lineTo(0.56, 0.5);
  c.lineTo(0.8, 0.92);
  c.lineTo(0.2, 0.92);
  c.lineTo(0.44, 0.5);
  c.closePath();
  c.fill();
}

function pin(c) {
  c.beginPath();
  c.arc(0.5, 0.38, 0.3, Math.PI, 0);
  c.lineTo(0.5, 0.96);
  c.closePath();
  c.fill();
  c.globalCompositeOperation = "destination-out";
  c.beginPath();
  c.arc(0.5, 0.38, 0.12, 0, Math.PI * 2);
  c.fill();
  c.globalCompositeOperation = "source-over";
}

function hueso(c) {
  c.beginPath();
  c.rect(0.24, 0.42, 0.52, 0.16);
  c.fill();
  for (const [x, y] of [[0.2, 0.36], [0.2, 0.64], [0.8, 0.36], [0.8, 0.64]]) {
    c.beginPath();
    c.arc(x, y, 0.15, 0, Math.PI * 2);
    c.fill();
  }
}

function estrella(c) {
  c.beginPath();
  for (let i = 0; i < 10; i += 1) {
    const r = i % 2 ? 0.19 : 0.46;
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
    const x = 0.5 + Math.cos(a) * r;
    const y = 0.5 + Math.sin(a) * r;
    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
  }
  c.closePath();
  c.fill();
}

function nino(c) {
  // Silueta de niño, para comparar tamaños. Un número en metros no le dice nada a nadie.
  c.beginPath();
  c.arc(0.5, 0.12, 0.11, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.moveTo(0.5, 0.24);
  c.lineTo(0.76, 0.42);
  c.lineTo(0.66, 0.5);
  c.lineTo(0.56, 0.44);
  c.lineTo(0.58, 0.66);
  c.lineTo(0.72, 1);
  c.lineTo(0.58, 1);
  c.lineTo(0.5, 0.78);
  c.lineTo(0.42, 1);
  c.lineTo(0.28, 1);
  c.lineTo(0.42, 0.66);
  c.lineTo(0.44, 0.44);
  c.lineTo(0.34, 0.5);
  c.lineTo(0.24, 0.42);
  c.closePath();
  c.fill();
}

export const ICONS = { huella, regla, reloj, pin, hueso, estrella, nino };

/** Dibuja un icono en (x, y) con lado `size` y color `colour`. */
export function drawIcon(context, name, x, y, size, colour) {
  const draw = ICONS[name];
  if (!draw) return;
  context.save();
  context.translate(x, y);
  context.scale(size, size);
  context.fillStyle = colour;
  draw(context);
  context.restore();
}

/** Qué icono le toca a cada dato, deducido de su etiqueta. */
export function iconFor(label) {
  const l = label.toLowerCase();
  if (l.includes("dónde") || l.includes("vivió")) return "pin";
  if (l.includes("cuándo") || l.includes("años") || l.includes("esperó") || l.includes("paciencia")) return "reloj";
  if (l.includes("grande") || l.includes("tamaño")) return "regla";
  if (l.includes("nombre")) return "hueso";
  if (l.includes("portada") || l.includes("primero") || l.includes("hito") || l.includes("mundial")) return "estrella";
  return "huella";
}
