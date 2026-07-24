import { APP_VERSION, ASSETS, CAPTURE } from "./config.js?v=99";
import { averageSideLength } from "./geometry.js?v=99";
import { createTranslator } from "./i18n.js?v=99";
import { listCharacters, loadCharacter } from "./characters.js?v=99";
import { renderCover } from "./cover.js?v=99";
import { BRAND, citationText, contactText } from "./credits.js?v=99";
import { drawFactCard } from "./facts.js?v=99";
import { drawPaperPatch } from "./tear.js?v=99";
import { SheetTracker } from "./tracker.js?v=99";
import { TextureSampler } from "./texture.js?v=99";
import { CharacterAnimator } from "./animation.js?v=99";

// Sellado por tools/sellar_version.py. Debe coincidir con APP_VERSION de config.js:
// si no coinciden, el navegador mezcló módulos de dos versiones desde su caché.
const BUILD = "99";

const $ = (id) => document.getElementById(id);
const stage = $("stage");
const video = $("cam");
const arCanvas = $("arCanvas");
const arContext = arCanvas.getContext("2d");
const overlay = $("overlay");
const overlayContext = overlay.getContext("2d");
const status = $("status");
const statusText = $("statusText");
const toggle = $("animToggle");
const switchText = $("switchText");
const gate = $("gate");
const startButton = $("startBtn");
const gateMessage = $("gateMsg");
const modal = $("modal");
const toastElement = $("toast");
const fatal = $("fatal");

if (BUILD !== APP_VERSION) {
  fatal.textContent = `Módulos de versiones distintas: app.js es v${BUILD} y config.js es v${APP_VERSION}. `
    + "El navegador está sirviendo archivos viejos desde su caché. Recargá forzado "
    + "(Ctrl+Shift+R) o borrá los datos del sitio.";
  fatal.style.display = "grid";
}

/** Lee píxeles del video en coordenadas de pantalla. Para copiar el papel del papel. */
const videoSampler = {
  canvas: document.createElement("canvas"),
  read(sx, sy) {
    const rect = stage.getBoundingClientRect();
    const vw = video.videoWidth;
    const vh = video.videoHeight;
    if (!vw || !vh) return null;
    const scale = Math.max(rect.width / vw, rect.height / vh);
    const x = Math.round((sx - (rect.width - vw * scale) / 2) / scale);
    const y = Math.round((sy - (rect.height - vh * scale) / 2) / scale);
    if (x < 1 || y < 1 || x >= vw - 1 || y >= vh - 1) return null;
    this.canvas.width = 3;
    this.canvas.height = 3;
    const c = this.canvas.getContext("2d", { willReadFrequently: true });
    c.drawImage(video, x - 1, y - 1, 3, 3, 0, 0, 3, 3);
    const d = c.getImageData(0, 0, 3, 3).data;
    let r = 0, g = 0, b = 0;
    for (let i = 0; i < d.length; i += 4) { r += d[i]; g += d[i + 1]; b += d[i + 2]; }
    return [r / 9 | 0, g / 9 | 0, b / 9 | 0];
  },
};

const tracker = new SheetTracker(video);

const textureSampler = new TextureSampler();
const animator = new CharacterAnimator();

let language = "es";
let translate = createTranslator(language);
let running = false;
let animationEnabled = true;
let textureBusy = false;
let lastTextureCapture = Number.NEGATIVE_INFINITY;
let currentStatusKey = "";
let firstTextureCaptured = false;
let lastGeometry = null;
let captureCount = 0;
let lastColoured = 0;
let lastInkRatio = 1;
// El dato que se muestra y cuándo cambió. Lo maneja el niño, no un temporizador.
let factIndex = 0;
let factSince = 0;
/**
 * La tarjeta se muestra la PRIMERA vez de cada especie y después manda el "?".
 *
 * Es un punto medio con costo medido. Que aparezca sola tapa el 29-38% de la pantalla justo
 * cuando llega la magia —tu dibujo caminando—. Que sólo aparezca apretando el "?" deja al niño
 * que nunca lo aprieta sin aprender nada, y los 91 datos verificados son para lo que existe
 * esta app, no un extra. Así que se muestra una vez para que se descubra, y de ahí decide él.
 */
let factHidden = false;
const yaVista = new Set();
let factZones = null;
/**
 * El hueco que deja el bicho al levantarse del papel: gris OPACO.
 *
 * Opaco, y ésa es toda la idea. Se probó translúcido —una sombra al 22%— y **no tapaba nada**:
 * medido, el trazo negro impreso seguía visible y encima el resto se oscurecía, dejando un
 * **284%** de píxeles oscuros contra el dibujo sin tapar. Una sombra oscurece, no tapa.
 *
 * Y opaco resuelve lo que mató al camuflaje. El camuflaje tenía que **adivinar el color del
 * papel** de la propia foto, y ese color cambia con la luz, el ángulo, la sombra de la mesa y
 * la cámara: en una foto de terreno el parche salió 25 tonos más oscuro que el papel de al
 * lado. Un gris opaco **no le acierta a nada**: es gris y ya. No puede fallar porque no está
 * adivinando.
 *
 * Se lee como un hueco, a propósito: el dinosaurio se levantó y ahí quedó su silueta.
 */

let activeCharacter = null;
let loadingCharacter = null;

const debugEnabled = new URLSearchParams(window.location.search).get("debug") === "1";
const debugImage = debugEnabled ? document.body.appendChild(Object.assign(document.createElement("img"), {
  className: "debug-texture",
  alt: "Textura capturada desde la hoja",
})) : null;

function showToast(message) {
  toastElement.textContent = message;
  toastElement.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toastElement.classList.remove("show"), 1300);
}

function setStatus(kind, message, key = `${kind}:${message}`) {
  if (key === currentStatusKey) return;
  currentStatusKey = key;
  status.className = `status ${kind}`;
  statusText.textContent = message;
}

function applyLanguage() {
  document.documentElement.lang = language;
  translate = createTranslator(language);
  animator.setLanguage(language);
  $("appTitle").textContent = translate("appTitle");
  $("appSub").textContent = translate("appSub");
  $("animationLabel").textContent = translate("animationLabel");
  $("animationHelp").textContent = translate("animationHelp");
  $("templateBtn").textContent = translate("template");
  $("helpBtn").textContent = translate("help");
  $("gateEyebrow").textContent = translate("gateEyebrow");
  $("gateTitle").textContent = translate("gateTitle");
  $("gateCopy").textContent = translate("gateCopy");
  $("gateTemplate").textContent = translate("download");
  $("gateVersion").textContent = `v${APP_VERSION}`;
  $("modalCredit").textContent = citationText();
  $("gateCredit").textContent = citationText();
  $("gateContact").textContent = contactText();
  $("modalContact").textContent = contactText();
  $("modalEyebrow").textContent = translate("modalEyebrow");
  $("modalTitle").textContent = translate("modalTitle");
  $("modalNote").textContent = translate("modalNote");
  if (!running) startButton.textContent = translate("start");
  const steps = $("modalSteps");
  steps.innerHTML = "";
  for (const text of translate("modalSteps")) {
    const item = document.createElement("li");
    item.textContent = text;
    steps.appendChild(item);
  }
}

/** Lista de personajes instalados: la app ya no sabe de ninguno en particular. */
/**
 * Portada: sólo las siluetas.
 *
 * Había además una lista con los 15 nombres en chips. Sobraba: las siluetas ya dicen quiénes
 * están, y mejor. Los nombres son un muro de texto que nadie lee antes de encender la cámara,
 * y para eso está plantillas.html, que además los deja filtrar.
 */
async function renderCharacterList() {
  const list = await listCharacters();
  const art = $("coverArt");
  if (!(await renderCover(art, list))) art.hidden = true;
}

function setAnimation(enabled, announce = false) {
  animationEnabled = enabled;
  toggle.classList.toggle("on", enabled);
  toggle.setAttribute("aria-checked", enabled ? "true" : "false");
  switchText.textContent = enabled ? "ON" : "OFF";
  if (!enabled) clearCanvas(arCanvas, arContext);
  if (announce) showToast(enabled ? translate("onToast") : translate("offToast"));
}

function resizeCanvases() {
  const rectangle = stage.getBoundingClientRect();
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  for (const canvas of [arCanvas, overlay]) {
    const width = Math.max(1, Math.round(rectangle.width * ratio));
    const height = Math.max(1, Math.round(rectangle.height * ratio));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    canvas.style.width = `${rectangle.width}px`;
    canvas.style.height = `${rectangle.height}px`;
  }
}

function clearCanvas(canvas, context) {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  context.setTransform(ratio, 0, 0, ratio, 0, 0);
  context.clearRect(0, 0, canvas.width / ratio, canvas.height / ratio);
}

function videoToStage(x, y) {
  const rectangle = stage.getBoundingClientRect();
  const width = video.videoWidth || 1;
  const height = video.videoHeight || 1;
  const scale = Math.max(rectangle.width / width, rectangle.height / height);
  return [(rectangle.width - width * scale) / 2 + x * scale, (rectangle.height - height * scale) / 2 + y * scale];
}

/** Cuadrilátero del QR, sólo para la guía en pantalla. */
function qrPose(now) {
  if (!tracker.isQrVisible(now)) return null;
  const corners = tracker.getQrCorners();
  if (!corners) return null;
  const points = corners.map(([x, y]) => videoToStage(x, y));
  return { points, side: averageSideLength(points) };
}

function strokeQuad(context, points, colour, width) {
  context.strokeStyle = colour;
  context.lineWidth = width;
  context.beginPath();
  context.moveTo(points[0][0], points[0][1]);
  for (let index = 1; index < points.length; index += 1) context.lineTo(points[index][0], points[index][1]);
  context.closePath();
  context.stroke();
}

function drawQrGuide(now) {
  clearCanvas(overlay, overlayContext);
  const pose = qrPose(now);
  if (!pose) return;
  overlayContext.save();
  strokeQuad(overlayContext, pose.points, textureSampler.ready ? "rgba(52,211,153,.9)" : "rgba(255,196,35,.92)", 3);
  if (debugEnabled) {
    const geometry = lastGeometry;
    if (geometry) {
      strokeQuad(overlayContext, geometry.corners.map(([x, y]) => videoToStage(x, y)), "rgba(124,58,237,.95)", 2);
    }
    const markers = tracker.getMarkers();
    if (markers) {
      overlayContext.fillStyle = "rgba(255,92,168,.95)";
      for (const marker of markers) {
        if (!marker) continue;
        const [x, y] = videoToStage(marker[0], marker[1]);
        overlayContext.beginPath();
        overlayContext.arc(x, y, 4, 0, Math.PI * 2);
        overlayContext.fill();
      }
    }
  }
  overlayContext.restore();
  drawDebugHud(now);
}

function updateStatus(now) {
  if (!animationEnabled) return setStatus("off", translate("off"), `off:${language}`);
  if (!tracker.isQrVisible(now)) return setStatus("searching", translate("search"), `search:${language}`);
  if (!activeCharacter) return setStatus("searching", translate("loadingCharacter"), `loading:${language}`);
  // Sin tinta dentro de la silueta: el dibujo impreso no está donde el personaje dice.
  if (textureSampler.ready && lastInkRatio < 0.03) {
    return setStatus("searching", translate("sheetMismatch"), `mismatch:${language}`);
  }
  if (!lastGeometry) {
    const { markerCount } = tracker.getDiagnostics();
    return setStatus("searching", `${translate("markers")} (${markerCount}/4)`, `markers:${language}:${markerCount}`);
  }
  if (textureBusy) return setStatus("searching", translate("reading"), `reading:${language}`);
  if (!textureSampler.ready) return setStatus("searching", translate("reading"), `reading:${language}`);
  setStatus("ready", translate("ready"), `ready:${language}`);
}

function captureTexture(now) {
  // La geometría debe salir del MISMO frame que se muestrea, no de una detección de hace 90 ms.
  if (!activeCharacter) return;
  tracker.sync(now);
  // La cadencia se respeta pase lo que pase: si esto se marcara sólo tras una captura exitosa,
  // un intento fallido dejaría la condición del ciclo en verdadero y tracker.sync() correría
  // en cada frame, con una detección completa de jsQR por frame.
  lastTextureCapture = now;
  const geometry = tracker.getCharacterGeometry(now, activeCharacter.frame);
  lastGeometry = geometry;
  if (!geometry) return;
  textureBusy = true;
  try {
    const result = textureSampler.capture(video, geometry);
    if (!result.ok) return;
    captureCount += 1;
    lastInkRatio = result.inkRatio;
    lastColoured = result.colouredPixels;
    window.__COLOREA_DEBUG__ = {
      version: APP_VERSION,
      textureReady: true,
      geometryMode: result.mode,
      markerCount: result.markerCount,
      qrSanityErrorPage: result.error,
      motionPage: geometry.motion,
      colouredPixels: result.colouredPixels,
      darkPixels: result.darkPixels,
      visiblePixels: result.visiblePixels,
      paperColour: result.paperColour,
      textureDataUrl: textureSampler.getDebugDataUrl(),
    };
    if (debugImage) debugImage.src = window.__COLOREA_DEBUG__.textureDataUrl;
    if (!firstTextureCaptured) {
      firstTextureCaptured = true;
      animator.greet(now);
    } else if (result.colouredPixels > 0) {
      showToast(translate("updated"));
    }
  } finally {
    textureBusy = false;
  }
}

function drawDebugHud(now) {
  if (!debugEnabled) return;
  const d = tracker.getDiagnostics();
  const lines = [
    `v${APP_VERSION}  qr:${tracker.isQrVisible(now) ? "sí" : "no"}  marcas:${d.markerCount}/4  pj:${activeCharacter?.id ?? "-"}`,
    `capturas:${captureCount}  color:${lastColoured}  tinta:${(lastInkRatio*100).toFixed(0)}%`,
    `errQR:${d.qrErrorPage ?? "-"} px pág   movim:${d.motionPage ?? "-"} px pág`,
    `geometría:${lastGeometry ? "sí" : "no"}  textura:${textureSampler.ready ? "sí" : "no"}`,
    d.missing.length ? `faltan: ${d.missing.join(", ")}` : "",
  ].filter(Boolean);
  overlayContext.save();
  overlayContext.font = "600 12px ui-monospace, monospace";
  overlayContext.textBaseline = "top";
  const width = Math.max(...lines.map((line) => overlayContext.measureText(line).width)) + 16;
  overlayContext.fillStyle = "rgba(23,17,31,.82)";
  overlayContext.fillRect(8, 96, width, lines.length * 16 + 12);
  overlayContext.fillStyle = "#c8f7e0";
  lines.forEach((line, index) => overlayContext.fillText(line, 16, 102 + index * 16));
  overlayContext.restore();
}

/**
 * Pose del DIBUJO en pantalla, no del QR. El personaje animado tiene que ocupar el lugar
 * exacto del dibujo impreso: es ese dibujo cobrando vida ahí mismo.
 */
function framePose() {
  if (!lastGeometry) return null;
  const points = lastGeometry.corners.map(([x, y]) => videoToStage(x, y));
  const center = points.reduce((sum, p) => [sum[0] + p[0] / 4, sum[1] + p[1] / 4], [0, 0]);
  const top = Math.hypot(points[1][0] - points[0][0], points[1][1] - points[0][1]);
  const bottom = Math.hypot(points[2][0] - points[3][0], points[2][1] - points[3][1]);
  const left = Math.hypot(points[3][0] - points[0][0], points[3][1] - points[0][1]);
  const right = Math.hypot(points[2][0] - points[1][0], points[2][1] - points[1][1]);
  return {
    points,
    center,
    width: (top + bottom) / 2,
    height: (left + right) / 2,
    angle: Math.atan2(points[1][1] - points[0][1], points[1][0] - points[0][0]),
  };
}

/**
 * Aclara el dibujo impreso para que el animado destaque, sin borrarlo.
 *
 * Va con la transformación del MARCO del personaje —igual que el bicho— porque el velo sigue a
 * su silueta, no a la hoja.
 */
function paperPatch(context, pose) {
  if (!activeCharacter) return;
  const [tw, th] = activeCharacter.frame.texture;
  context.save();
  context.translate(pose.center[0], pose.center[1]);
  context.rotate(pose.angle);
  context.scale(pose.width / tw, pose.height / th);
  context.translate(-tw / 2, -th / 2);
  drawPaperPatch(context, activeCharacter, textureSampler.paperColour);
  context.restore();
}

function render(now) {
  clearCanvas(arCanvas, arContext);
  const viewport = stage.getBoundingClientRect();
  const pose = framePose();

  // EL PERSONAJE depende de todo esto: de la animación, de tener colores capturados y de una
  // pose fresca. Si falta algo, no se dibuja.
  if (animationEnabled && textureSampler.ready && pose) {
    // Se desvanece con la edad de la pose: si envejece, mejor que no esté a que esté corrido.
    arContext.save();
    arContext.globalAlpha = tracker.poseFreshness(now);
    // El agujero primero: el bicho salió DE ahí, así que va encima.
    paperPatch(arContext, pose);
    animator.render(arContext, textureSampler.getParts(), pose, viewport, now);
    arContext.restore();
  }

  // LA TARJETA no depende de nada de eso, y ése era el error: `render` se salía antes con
  // `if (!pose) return`. Es texto en pantalla, no está pegada a la hoja. Si el QR se pierde un
  // segundo —una sombra, un parpadeo, mover el teléfono— el dato que el niño está leyendo NO
  // tiene por qué desaparecerle en la cara.
  //
  // Se va por tres razones, y las tres son decisiones de alguien:
  //   - el niño toca la ✕
  //   - aparece OTRO QR: es otro bicho y sus datos son otros (lo maneja syncCharacter)
  //   - todavía no hay personaje
  if (activeCharacter) {
    factZones = drawFactCard(arContext, activeCharacter,
      { index: factIndex, since: now - factSince, hidden: factHidden }, viewport);
  } else {
    factZones = null;
  }
}

async function syncCharacter() {
  // El QR saltó: es OTRA hoja. Se suelta el personaje y se espera a leer el QR nuevo.
  //
  // Sin esto, las 4 marcas —que son idénticas en las 50 hojas— daban pose al instante mientras
  // el QR viejo se sostenía 1,2 s, y el personaje anterior se dibujaba sobre la hoja nueva. Eso
  // era el saurópodo que aparecía "por defecto": el Arackar de la hoja de antes.
  if (tracker.sheetChanged) {
    tracker.sheetChanged = false;
    if (tracker.characterId !== activeCharacter?.id) {
      activeCharacter = null;
      factZones = null;
      firstTextureCaptured = false;
      lastTextureCapture = Number.NEGATIVE_INFINITY;
    }
  }
  const id = tracker.characterId;
  if (!id || id === activeCharacter?.id || id === loadingCharacter) return;
  loadingCharacter = id;
  try {
    const character = await loadCharacter(id);
    activeCharacter = character;
    textureSampler.load(character);
    animator.setCharacter(character);
    firstTextureCaptured = false;
    factIndex = 0;
    factSince = performance.now();
    // primera vez de esta especie: se muestra. Después, lo que el niño haya decidido.
      factHidden = yaVista.has(id);
    yaVista.add(id);
    lastTextureCapture = Number.NEGATIVE_INFINITY;
    showToast(character.name);
  } catch (error) {
    console.warn(error);
    setStatus("searching", `${translate("unknownCharacter")} (${id})`, `unknown:${id}`);
  } finally {
    loadingCharacter = null;
  }
}

function loop(now) {
  requestAnimationFrame(loop);
  if (!running) return;
  tracker.update(now);
  syncCharacter();
  lastGeometry = activeCharacter ? tracker.getCharacterGeometry(now, activeCharacter.frame) : null;
  if (activeCharacter && tracker.isQrVisible(now) && now - lastTextureCapture >= CAPTURE.textureRefreshMs) captureTexture(now);
  render(now);
  drawQrGuide(now);
  updateStatus(now);
}

async function startCamera() {
  if (running) return;
  startButton.disabled = true;
  startButton.textContent = translate("starting");
  gateMessage.textContent = "";
  try {
    // Sin await: el desbloqueo de audio tiene que ocurrir DENTRO del gesto del usuario, y eso
    // se cumple con sólo invocarlo acá. Esperarlo no aporta nada y sí puede colgar el arranque:
    // con un <audio> sin fuente, play() deja la promesa pendiente para siempre y la cámara
    // nunca se llegaba a pedir.
    animator.unlockAudio();
    if (!navigator.mediaDevices?.getUserMedia) throw new Error("NO_CAMERA_API");
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: "environment" }, width: { ideal: 1920 }, height: { ideal: 1080 } },
    });
    video.srcObject = stream;
    await video.play();
    running = true;
    gate.classList.add("hidden");
    resizeCanvases();
  } catch (error) {
    console.error(error);
    startButton.disabled = false;
    startButton.textContent = translate("start");
    if (error?.name === "NotAllowedError" || error?.name === "SecurityError") gateMessage.textContent = translate("denied");
    else if (error?.name === "NotFoundError" || error?.message === "NO_CAMERA_API") gateMessage.textContent = translate("noCamera");
    else gateMessage.textContent = translate("genericError");
  }
}

for (const button of document.querySelectorAll("[data-lang]")) {
  button.addEventListener("click", () => {
    language = button.dataset.lang;
    for (const item of document.querySelectorAll("[data-lang]")) item.setAttribute("aria-pressed", item === button ? "true" : "false");
    applyLanguage();
  });
}

/**
 * Sólo cuenta el toque SOBRE la tarjeta, no sobre cualquier parte de la pantalla: si vale toda
 * la escena, acomodar el agarre pasa el dato sin querer, y eso es peor que un temporizador
 * porque es impredecible. La tarjeta mide 55-63 mm; el mínimo recomendado son 9.
 */
stage.addEventListener("pointerdown", (event) => {
  if (!running || !factZones) return;
  if (event.target.closest(".controls, .gate, .topbar, .modal, .menu")) return;
  const rect = stage.getBoundingClientRect();
  const px = event.clientX - rect.left;
  const py = event.clientY - rect.top;
  const dentro = (z) => z && px >= z.x && px <= z.x + z.w && py >= z.y && py <= z.y + z.h;

  if (dentro(factZones.chip)) {
    factHidden = false;
    factSince = performance.now();
    return;
  }
  if (dentro(factZones.hide)) {
    factHidden = true;
    return;
  }
  if (dentro(factZones.card)) {
    factIndex += 1;
    factSince = performance.now();
  }
});

/** El menú: se abre, y se cierra al tocar afuera o al elegir algo. */
const menu = $("menu");
const menuBtn = $("menuBtn");
const cerrarMenu = () => { menu.hidden = true; menuBtn.setAttribute("aria-expanded", "false"); };
menuBtn.addEventListener("click", (e) => {
  e.stopPropagation();
  menu.hidden = !menu.hidden;
  menuBtn.setAttribute("aria-expanded", String(!menu.hidden));
});
document.addEventListener("click", (e) => {
  if (!menu.hidden && !menu.contains(e.target) && e.target !== menuBtn) cerrarMenu();
});
menu.addEventListener("click", (e) => { if (e.target.tagName === "BUTTON" && e.target.id !== "animToggle") cerrarMenu(); });

$("templateBtn").addEventListener("click", () => window.open(`plantillas.html?v=${APP_VERSION}`, "_blank", "noopener"));
$("gateTemplate").addEventListener("click", () => window.open(`plantillas.html?v=${APP_VERSION}`, "_blank", "noopener"));
$("helpBtn").addEventListener("click", () => { modal.classList.add("open"); modal.setAttribute("aria-hidden", "false"); });
$("closeModal").addEventListener("click", () => { modal.classList.remove("open"); modal.setAttribute("aria-hidden", "true"); });
modal.addEventListener("click", (event) => { if (event.target === modal) { modal.classList.remove("open"); modal.setAttribute("aria-hidden", "true"); } });
toggle.addEventListener("click", () => setAnimation(!animationEnabled, true));
startButton.addEventListener("click", startCamera);
window.addEventListener("resize", resizeCanvases);
document.addEventListener("visibilitychange", () => { if (!document.hidden && running && video.paused) video.play().catch(() => {}); });
window.addEventListener("error", (event) => { fatal.textContent = `Error de la aplicación: ${event.message}`; fatal.style.display = "grid"; });

$("gateLogo").src = BRAND.logo;
$("barLogo").src = BRAND.logo;
renderCharacterList();
setAnimation(true);
applyLanguage();
resizeCanvases();
requestAnimationFrame(loop);
