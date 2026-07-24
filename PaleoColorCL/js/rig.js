/**
 * Rig genérico.
 *
 * Cada personaje conserva sus propios lienzos coloreados. Este módulo sólo calcula
 * transformaciones continuas para esas piezas; no modifica máscaras, texturas ni colores.
 */

const TAU = Math.PI * 2;

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function smoother(value) {
  const x = clamp01(value);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

function waveEase(progress) {
  const x = clamp01(progress);
  return Math.sin(smoother(x) * Math.PI);
}

/**
 * Primitivas de movimiento. Reciben:
 *   t     0..1, avance del ciclo completo
 *   gait  radianes, fase del paso
 *   p     parámetros de la parte y estado del personaje
 *
 * Devuelven cualquier subconjunto de { angle, dx, dy, scaleX, scaleY }.
 */
export const MOTIONS = {
  /** Parte rígida. El movimiento general del cuerpo se aplica fuera de esta función. */
  fija: () => ({}),

  /**
   * Extremidades. El paso combina una onda principal con armónicos pequeños para evitar el
   * aspecto de metrónomo. La amplitud entra y sale suavemente al comenzar y terminar un tramo.
   */
  pendulo: (t, gait, p) => {
    const phase = p.phase * TAU;
    const locomotion = p.motionWeight ?? (p.walking ? 1 : 0);
    // Aletas y alas no se congelan cuando el personaje se detiene a vocalizar.
    const active = p.flies ? Math.max(0.48, locomotion)
      : p.swims ? Math.max(0.28, locomotion)
        : locomotion;
    const idle = Math.sin(t * TAU * 0.72 + phase) * p.amount * 0.045;

    let stride = Math.sin(gait + phase) * 0.78
      + Math.sin((gait + phase) * 2 - 0.45) * 0.16
      + Math.sin((gait + phase) * 3 + 0.7) * 0.06;

    if (p.swims) {
      stride = Math.sin(gait + phase) * 0.64
        + Math.sin(gait * 0.5 + phase - 0.8) * 0.28;
    } else if (p.flies) {
      stride = Math.sin(gait + phase) * 0.9
        + Math.sin((gait + phase) * 2 - 0.6) * 0.18;
    }

    let angle = idle + p.amount * stride * active;

    // Una extremidad delantera saluda. Se usa una elevación moderada para que también funcione
    // en cuadrúpedos: no intenta convertir una pata en un brazo humano.
    if (p.waving && p.isWavePart) {
      const lift = waveEase(p.waveProgress);
      const wiggle = Math.sin(p.waveProgress * Math.PI * 8) * 0.08 * lift;
      angle = -p.nativeFacing * (p.amount * 2.35 * lift + wiggle) + idle * 0.25;
    }

    return { angle };
  },

  /**
   * Colas y segmentos largos. Se retrasan respecto del cuerpo, reaccionan a la aceleración y
   * mezclan frecuencias lentas para transmitir peso sin vibrar.
   */
  arrastre: (t, gait, p) => {
    const phase = p.phase * TAU;
    const locomotion = p.motionWeight ?? (p.walking ? 1 : 0);
    const slow = Math.sin(gait * 0.48 + phase - 0.55) * 0.62
      + Math.sin(gait * 0.24 + phase + 0.7) * 0.27
      + Math.sin(t * TAU * 0.43 + phase) * 0.11;
    const inertia = Math.max(-1, Math.min(1, -(p.acceleration ?? 0) * 0.028 - (p.velocity ?? 0) * 0.018));
    const floating = p.swims || p.flies ? 0.82 : 0.38;
    const weight = Math.max(floating, locomotion);
    return {
      angle: p.amount * slow * weight + p.amount * inertia,
      dy: (p.swims || p.flies) ? Math.sin(t * TAU * 0.65 + phase) * p.amount * 2.2 : 0,
    };
  },

  /**
   * Cabeza o cadena de cuello. Contrarresta parte del rebote del cuerpo, añade observación en
   * reposo y un asentimiento suave mientras el personaje vocaliza.
   */
  cabeceo: (t, gait, p) => {
    const phase = p.phase * TAU;
    const active = p.motionWeight ?? (p.walking ? 1 : 0);
    const footBob = -p.amount * 0.42 * Math.abs(Math.sin(gait + phase)) * active;
    const drift = Math.sin(t * TAU * 0.54 + phase) * p.amount * 0.12;
    const observe = p.looking
      ? Math.sin(smoother(p.segmentProgress) * Math.PI) * p.amount * 0.34
      : 0;
    const nod = p.waving
      ? Math.sin(p.waveProgress * Math.PI * 4) * waveEase(p.waveProgress) * p.amount * 0.13
      : 0;
    const speedCounter = -(p.velocity ?? 0) * 0.0016 * p.nativeFacing;

    return {
      dy: footBob + drift - observe - Math.abs(nod) * 0.45,
      dx: (p.looking ? Math.sin(p.segmentProgress * Math.PI) : 0) * p.amount * 0.18 * p.nativeFacing,
      angle: p.amount * 0.012 * Math.sin(gait * 0.5 + phase)
        + nod * 0.012
        + speedCounter,
    };
  },

  /** Respiración orgánica con una inspiración algo más corta que la espiración. */
  respira: (t, gait, p) => {
    const base = Math.sin(t * TAU - 0.3);
    const second = Math.sin(t * TAU * 2 + 0.8) * 0.22;
    const breath = base * 0.78 + second;
    const locomotion = p.motionWeight ?? (p.walking ? 1 : 0);
    const brace = locomotion * Math.abs(Math.cos(gait)) * p.amount * 0.32;
    return {
      scaleY: 1 + p.amount * breath - brace,
      scaleX: 1 - p.amount * 0.44 * breath + brace * 0.38,
      angle: (p.velocity ?? 0) * 0.00022 * p.nativeFacing,
    };
  },

  /** Compatibilidad con personajes futuros que declaren explícitamente una parte que saluda. */
  saluda: (t, gait, p) => {
    if (!p.waving) {
      return { angle: p.amount * 0.16 * Math.sin(gait + p.phase * TAU) * (p.motionWeight ?? 0) };
    }
    const lift = waveEase(p.waveProgress);
    return {
      angle: -p.nativeFacing * p.amount * (1.75 * lift
        + 0.18 * Math.sin(p.waveProgress * Math.PI * 8) * lift),
    };
  },
};

export const MOTION_NAMES = Object.keys(MOTIONS);

/**
 * Coreografías. `fromX`, `toX` y `holdX` mantienen la trayectoria continua: cada ciclo nace
 * exactamente donde terminó el anterior y ya no hay saltos laterales entre caminar, detenerse
 * y girar.
 */
export const ANIMATIONS = {
  correteo: {
    style: "scurry",
    cycleMs: 6200,
    travel: 0.43,
    turns: true,
    gaitPerCycle: 21,
    bounce: 0.62,
    segments: [
      { name: "correDerecha", until: 0.16, walking: true, direction: 1, fromX: 0, toX: 1 },
      { name: "husmea", until: 0.30, waving: true, looking: true, direction: 1, holdX: 1 },
      { name: "giraIzquierda", until: 0.37, turning: true, from: 1, to: -1, holdX: 1 },
      { name: "correIzquierda", until: 0.63, walking: true, direction: -1, fromX: 1, toX: -1 },
      { name: "husmea2", until: 0.79, waving: true, looking: true, direction: -1, holdX: -1 },
      { name: "giraDerecha", until: 0.86, turning: true, from: -1, to: 1, holdX: -1 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -1, toX: 0 },
    ],
  },

  nada: {
    style: "swim",
    cycleMs: 9800,
    travel: 0.46,
    turns: true,
    gaitPerCycle: 5,
    bounce: 0.3,
    swims: true,
    segments: [
      { name: "nadaDerecha", until: 0.22, walking: true, direction: 1, fromX: 0, toX: 1 },
      { name: "canta", until: 0.34, waving: true, direction: 1, holdX: 1 },
      { name: "giraIzquierda", until: 0.41, turning: true, from: 1, to: -1, holdX: 1 },
      { name: "nadaIzquierda", until: 0.68, walking: true, direction: -1, fromX: 1, toX: -1 },
      { name: "cantaIzquierda", until: 0.79, waving: true, direction: -1, holdX: -1 },
      { name: "giraDerecha", until: 0.86, turning: true, from: -1, to: 1, holdX: -1 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -1, toX: 0 },
    ],
  },

  vuela: {
    style: "fly",
    cycleMs: 8400,
    travel: 0.5,
    turns: true,
    gaitPerCycle: 8,
    bounce: 1.9,
    flies: true,
    segments: [
      { name: "vuelaDerecha", until: 0.22, walking: true, direction: 1, fromX: 0, toX: 1 },
      { name: "chilla", until: 0.33, waving: true, direction: 1, holdX: 1 },
      { name: "giraIzquierda", until: 0.40, turning: true, from: 1, to: -1, holdX: 1 },
      { name: "vuelaIzquierda", until: 0.69, walking: true, direction: -1, fromX: 1, toX: -1 },
      { name: "chillaIzquierda", until: 0.79, waving: true, direction: -1, holdX: -1 },
      { name: "giraDerecha", until: 0.86, turning: true, from: -1, to: 1, holdX: -1 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -1, toX: 0 },
    ],
  },

  alzada: {
    style: "rear",
    cycleMs: 9600,
    travel: 0.46,
    turns: true,
    gaitPerCycle: 9,
    bounce: 0.72,
    rearEvery: 2,
    segments: [
      { name: "vaDerecha", until: 0.22, walking: true, direction: 1, fromX: 0, toX: 0.86 },
      { name: "seAlza", until: 0.42, rearing: true, waving: true, direction: 1, holdX: 0.86 },
      { name: "giraIzquierda", until: 0.49, turning: true, from: 1, to: -1, holdX: 0.86 },
      { name: "vaIzquierda", until: 0.76, walking: true, direction: -1, fromX: 0.86, toX: -0.86 },
      { name: "gruneIzquierda", until: 0.86, waving: true, direction: -1, holdX: -0.86 },
      { name: "giraDerecha", until: 0.92, turning: true, from: -1, to: 1, holdX: -0.86 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -0.86, toX: 0 },
    ],
  },

  parada: {
    style: "idle",
    cycleMs: 6200,
    travel: 0,
    turns: false,
    gaitPerCycle: 1,
    bounce: 0.28,
    segments: [
      { name: "quieto", until: 0.45, direction: 1, holdX: 0 },
      { name: "observa", until: 0.68, looking: true, direction: 1, holdX: 0 },
      { name: "saludo", until: 0.87, waving: true, direction: 1, holdX: 0 },
      { name: "quieto2", until: 1, direction: 1, holdX: 0 },
    ],
  },

  camina: {
    style: "walk",
    cycleMs: 7600,
    travel: 0.5,
    turns: true,
    gaitPerCycle: 10,
    bounce: 0.82,
    segments: [
      { name: "vaDerecha", until: 0.24, walking: true, direction: 1, fromX: 0, toX: 1 },
      { name: "saludaDerecha", until: 0.35, waving: true, direction: 1, holdX: 1 },
      { name: "giraIzquierda", until: 0.42, turning: true, from: 1, to: -1, holdX: 1 },
      { name: "vaIzquierda", until: 0.72, walking: true, direction: -1, fromX: 1, toX: -1 },
      { name: "saludaIzquierda", until: 0.82, waving: true, direction: -1, holdX: -1 },
      { name: "giraDerecha", until: 0.89, turning: true, from: -1, to: 1, holdX: -1 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -1, toX: 0 },
    ],
  },

  desfile: {
    style: "heavy",
    cycleMs: 8600,
    travel: 0.53,
    turns: true,
    gaitPerCycle: 8,
    bounce: 0.58,
    segments: [
      { name: "vaDerecha", until: 0.23, walking: true, direction: 1, fromX: 0, toX: 0.9 },
      { name: "rugeDerecha", until: 0.35, waving: true, direction: 1, holdX: 0.9 },
      { name: "giraIzquierda", until: 0.43, turning: true, from: 1, to: -1, holdX: 0.9 },
      { name: "vaIzquierda", until: 0.72, walking: true, direction: -1, fromX: 0.9, toX: -0.9 },
      { name: "rugeIzquierda", until: 0.83, waving: true, direction: -1, holdX: -0.9 },
      { name: "giraDerecha", until: 0.91, turning: true, from: -1, to: 1, holdX: -0.9 },
      { name: "vuelveCentro", until: 1, walking: true, direction: 1, fromX: -0.9, toX: 0 },
    ],
  },
};

export const ANIMATION_NAMES = Object.keys(ANIMATIONS);

export function animationOf(id) {
  return ANIMATIONS[id] ?? ANIMATIONS.parada;
}

/** Segmento activo y su avance interno. */
export function segmentAt(animation, t) {
  let start = 0;
  for (const segment of animation.segments) {
    if (t < segment.until) {
      const duration = Math.max(1e-6, segment.until - start);
      return {
        ...segment,
        start,
        duration,
        progress: clamp01((t - start) / duration),
      };
    }
    start = segment.until;
  }
  const last = animation.segments[animation.segments.length - 1];
  return { ...last, start, duration: 1e-6, progress: 1 };
}

/** Aplica la primitiva de una parte y devuelve su transformación. */
export function transformFor(part, t, gait, context) {
  const motion = MOTIONS[part.motion] ?? MOTIONS.fija;
  const id = String(part.id || "").toLowerCase();
  const bodyPivot = context.bodyPivot ?? [0, 0];
  const nativeFacing = context.nativeFacing ?? 1;
  const isLimb = id.startsWith("pata");
  const isHead = id.startsWith("cabeza");
  const isTail = id.startsWith("cola");
  const isFront = isLimb && (part.pivot[0] - bodyPivot[0]) * nativeFacing > -4;

  const out = motion(t, gait, {
    amount: Number.isFinite(part.amount) ? part.amount : 0.1,
    phase: Number.isFinite(part.phase) ? part.phase : 0,
    nativeFacing,
    isLimb,
    isHead,
    isTail,
    isFront,
    ...context,
  });
  return { angle: 0, dx: 0, dy: 0, scaleX: 1, scaleY: 1, ...out };
}
