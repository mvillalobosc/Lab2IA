export const APP_VERSION = "99";

export const TEMPLATE = Object.freeze({
  width: 1200,
  height: 1704,
  qr: Object.freeze({ x0: 480, y0: 126, x1: 720, y1: 366 }),
  // Lado real del cuadrado negro impreso, en px de página. Lo comparten todas las plantillas.
  markerSize: 67,
  markers: Object.freeze([
    Object.freeze([114.5, 486.5]),
    Object.freeze([1086.5, 486.5]),
    Object.freeze([1086.5, 1458.5]),
    Object.freeze([114.5, 1458.5]),
  ]),
  // Marco por defecto (vertical). Cada personaje puede traer el suyo: un dinosaurio de
  // perfil es apaisado y en un marco vertical queda diminuto. Debe caber dentro del
  // cuadrilátero de las marcas (x 114-1086, y 486-1458) y no tocar el QR.
  character: Object.freeze({ x0: 300, y0: 590, x1: 900, y1: 1390 }),
});

/** Marcos disponibles. El id viaja en el manifiesto del personaje. */
export const FRAMES = Object.freeze({
  // 600x800 = 0.75. Personajes de frente, tipo chibi.
  vertical: Object.freeze({ rect: [300, 590, 900, 1390], texture: [384, 512] }),
  // 880x490 = 1.80. Personajes de perfil: dinosaurios, animales de cuatro patas.
  apaisado: Object.freeze({ rect: [160, 700, 1040, 1190], texture: [704, 392] }),
  // 760x760 = 1.00. Término medio.
  cuadrado: Object.freeze({ rect: [220, 650, 980, 1410], texture: [512, 512] }),
});

export function frameOf(id) {
  return FRAMES[id] ?? FRAMES.vertical;
}

export function framePagePoints(frame) {
  const [x0, y0, x1, y1] = frame.rect;
  return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
}

export const ASSETS = Object.freeze({
  characterIndex: "assets/characters/index.json",
  characterDir: "assets/characters/",
});

// El QR ya no identifica a UN personaje: lleva el prefijo y el id del que hay que cargar.
export const QR_PREFIX = "clr2:";

/** Nombres de las partes, en el orden de dibujado (de atrás hacia adelante). */

export const UNIT_SQUARE = Object.freeze([[0, 0], [1, 0], [1, 1], [0, 1]]);

export const CAPTURE = Object.freeze({
  detectionIntervalMs: 55,
  // Búsqueda en frío: el binarizador de jsQR es sensible a la resolución de forma no monótona
  // (hay giros que enganchan a 640 y fallan a 960, y al revés), y a 640 se pierde la hoja
  // sostenida lejos. Se rota entre las tres resoluciones en barridos sucesivos.
  qrColdWidths: [640, 960, 1920],
  qrColdIntervalMs: 110,
  qrWarmWidth: 640,
  markerScanIntervalMs: 90,
  // El QR sólo dice QUIÉN es el personaje, no dónde. Perderlo un rato no desalinea nada, así
  // que puede sostenerse largo.
  // El QR sólo dice QUIÉN es el personaje, no dónde. Perderlo un rato no desalinea nada, así
  // que puede sostenerse largo: está para que no parpadee si una mano lo tapa un instante.
  qrHoldMs: 1200,
  // PERO sostener la identidad tiene un límite, y no es el tiempo: es el SALTO.
  //
  // Las 4 marcas negras son IDÉNTICAS en las 50 hojas: sólo el QR distingue una de otra. Al
  // cambiar de hoja, las marcas se encuentran al instante y el QR nuevo tarda en leerse
  // —necesita foco, luz, un frame nítido—. Durante ese hueco, `isQrVisible` seguía diciendo
  // que sí (era el QR VIEJO sostenido) y el personaje anterior se dibujaba sobre la hoja
  // nueva. De ahí el saurópodo que aparecía "por defecto": era el Arackar de la hoja de antes.
  //
  // Si el QR salta más que esto entre dos lecturas, no es la misma hoja: se suelta el
  // personaje y se espera a leer el QR nuevo. Un QR mide ~200 px de página; medio QR de salto
  // es muchísimo más de lo que se mueve una hoja quieta entre exploraciones.
  maxQrJumpPage: 100,
  // El sostén de la pose NO es fijo, y ése era el error.
  //
  // 900 ms dibujaba al bicho medio marco fuera de su hoja al mover el teléfono. Bajarlo a
  // 220 lo hizo desaparecer con cualquier parpadeo del detector. Ninguno de los dos está
  // bien, porque la pregunta correcta no es cuánto sostener: es **cuánto se corrió la hoja**.
  //
  // Así que el sostén se DEDUCE, no se elige: se sostiene mientras el arrastre acumulado se
  // mantenga bajo `maxArrastrePage`. Con el teléfono apoyado, eso es para siempre (se corta en
  // `markerHoldMaxMs`); con la mano temblando, medio segundo; sacudiendo, dos frames.
  //
  //   arrastre = (movimiento por exploración / detectionIntervalMs) * sostén
  //   sostén   = maxArrastrePage * detectionIntervalMs / movimiento
  //
  // 88 px de página es el 10% del ancho del marco apaisado: por debajo de eso el bicho se ve
  // pegado a su dibujo. Interpolar linealmente entre "quieto" y "moviendo" no servía: con un
  // temblor normal de 20 px daba 770 ms de sostén y la hoja se corría 280 px, un tercio del
  // marco.
  maxArrastrePage: 88,
  markerHoldMaxMs: 900,
  markerHoldMinMs: 110,   // 2 exploraciones: cubre un parpadeo del detector sin desaparecer
  // El desvanecido necesita una gracia y no es opcional: el tracker explora cada
  // detectionIntervalMs (55 ms), así que con la hoja quieta la pose SIEMPRE tiene algo de
  // edad. Midiendo desde 0, el bicho parpadeaba estando todo bien.
  poseGraceMs: 110,
  poseFadeMs: 140,
  textureRefreshMs: 650,
  maxFrameWidth: 1280,
  supersample: 2,
});

// Tolerancias de registro. Todo en px de página (1200x1704) salvo indicación.
export const REGISTRATION = Object.freeze({
  minMarkers: 4,
  // Radio de búsqueda, en múltiplos del lado del marcador.
  // Frío: se predice con la homografía del QR extrapolada; a 5,5 alturas de QR hacia abajo
  // el error llega a ~3 lados de marca en vistas oblicuas, así que hay que abrir.
  searchRadiusCold: 3.2,
  // Medio: predicho con un ajuste que ya incorpora las marcas encontradas.
  searchRadiusMedium: 2.0,
  // Estrecho: sólo para reafinar una marca que ya se localizó.
  searchRadiusWarm: 1.0,
  // Gates de forma. Todos invariantes a rotación: en la imagen el cuadrado impreso es un
  // paralelogramo rotado, así que el bounding box alineado a los ejes no dice nada.
  // Lado equivalente sqrt(área) contra el esperado. El escorzo reduce el área proyectada:
  // a 60° de inclinación queda en 0,5, o sea 0,71 de lado.
  minSideRatio: 0.5,
  maxSideRatio: 1.6,
  // Solidez = área / área de la envolvente convexa. Un paralelogramo da ~1 en cualquier
  // rotación; una letra, un trazo del dibujo o una sombra irregular caen por debajo.
  minSolidity: 0.86,
  // Elongación = sqrt(lambda1/lambda2) de los momentos centrales. Un cuadrado da 1 en
  // cualquier rotación; el escorzo lo estira poco. Los trazos se disparan.
  maxElongation: 2.4,
  minContrast: 34,
  // Chequeo de cordura, NO de precisión: con las 4 marcas la homografía las reproyecta
  // con error 0 (4 puntos, 8 grados de libertad), así que el residuo sobre ellas no sirve
  // para validar. Se valida reproyectando el QR: un ajuste correcto da ~25-45 px de página
  // (es el ruido propio de jsQR); haber enganchado una marca falsa dispara a 47-71.
  maxQrSanityPage: 58,
  // No hay umbral de movimiento y es a propósito. La geometría sale del mismo frame que se
  // muestrea, así que moverse no desalinea, sólo desenfoca; y el desenfoque ya se auto-regula:
  // a ~16 px de arrastre jsQR deja de leer el QR y a las marcas se les dispara la elongación,
  // así que un frame demasiado movido no produce geometría y nunca llega a capturarse.
  // Un umbral explícito sólo rechazaba frames buenos: mostrar la hoja a la cámara con la mano
  // da 40-60 px de página entre exploraciones, y la textura no se refrescaba nunca.
  // Resolución máxima del recorte por marca. Acota costo y evita descartar recortes grandes.
  roiRaster: 200,
  refineIterations: 2,
  markerWeight: 4,
  qrWeight: 1,
});

export const DISPLAY = Object.freeze({
  // El personaje animado ocupa el MISMO lugar y tamaño que el dibujo impreso: es el mismo
  // dibujo cobrando vida ahí, no una copia flotando en otro lado. Antes esto era relativo al
  // QR y lo plantaba sobre el código, en la mitad opuesta de la hoja al dibujo.
  characterHeightInFrame: 1,
  // Antes 0.22: el personaje recorría 40 px midiendo 210 de alto, menos de un quinto de su
  // altura, y se leía como maniquí deslizándose.
  // Recorrido de la caminata, en fracción del ancho del marco.
  // Cuánto recorre a cada lado, en anchos del marco.
  //
  // 0,12 y no más, porque el AGUJERO tiene que contenerlo. El agujero mide el marco más un
  // margen a cada lado, y tiene que caber en la hoja: con 0,28 pedía **1373 px en una hoja de
  // 1200** —se salía por los dos lados—; con 0,12 mide 1091 y cabe con margen.
  //
  // El bicho recorre menos que antes, pero nunca se sale de su agujero, que era el problema:
  // barre 3 a 5 veces su propia silueta por ciclo y cada paso destapaba el borde impreso.
  walkHalfSpanInFrame: 0.12,
});

export function qrPagePoints() {
  const { qr } = TEMPLATE;
  return [[qr.x0, qr.y0], [qr.x1, qr.y0], [qr.x1, qr.y1], [qr.x0, qr.y1]];
}

export function markerPagePoints() {
  return TEMPLATE.markers.map((point) => point.slice());
}

