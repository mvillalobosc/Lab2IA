import { BRAND } from "./credits.js?v=99";

/**
 * Ambiente por hábitat, sintetizado. Cero bytes de audio, igual que las voces.
 *
 * No es decoración: es el dato de dónde vivía el bicho, contado por el oído. Un niño no lee
 * "plesiosaurio marino"; escucha el mar y ya sabe.
 *
 *   tierra  rumor volcánico grave + pasto: ruido rosa filtrado con un vaivén lento
 *   aire    viento: ruido pasabanda con la banda moviéndose en ráfagas
 *   agua    bajo el mar: ruido muy grave + burbujas ocasionales
 *
 * Todo arranca y para con el personaje, y a volumen bajo: acompaña, no tapa el gruñido.
 */

const AMBIENTS = {
  tierra: { gain: 0.05, lowpass: 320, band: 90, sweep: 0.07, bubbles: 0 },
  aire:   { gain: 0.06, lowpass: 1800, band: 700, sweep: 0.22, bubbles: 0 },
  agua:   { gain: 0.05, lowpass: 420, band: 160, sweep: 0.05, bubbles: 1 },
};

export const HABITATS = Object.keys(AMBIENTS);

export class AmbientBox {
  constructor() {
    this.context = null;
    this.nodes = null;
    this.habitat = null;
  }

  attach(context) {
    this.context = context;
  }

  /** Ruido rosa: el blanco suena a estática; el rosa suena a naturaleza. */
  #noiseBuffer(seconds) {
    const ctx = this.context;
    const frames = Math.floor(ctx.sampleRate * seconds);
    const buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    let b0 = 0, b1 = 0, b2 = 0;
    for (let i = 0; i < frames; i += 1) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99765 * b0 + white * 0.0990460;
      b1 = 0.96300 * b1 + white * 0.2965164;
      b2 = 0.57000 * b2 + white * 1.0526913;
      data[i] = (b0 + b1 + b2 + white * 0.1848) * 0.22;
    }
    return buffer;
  }

  /** Arranca el ambiente del hábitat. Llamarlo de nuevo con otro cambia sin cortes bruscos. */
  start(habitat) {
    if (!this.context || !AMBIENTS[habitat]) return false;
    if (this.habitat === habitat && this.nodes) return true;
    this.stop();
    const cfg = AMBIENTS[habitat];
    const ctx = this.context;
    const now = ctx.currentTime;
    try {
      if (ctx.state === "suspended") ctx.resume();
      const source = ctx.createBufferSource();
      source.buffer = this.#noiseBuffer(4);
      source.loop = true;

      const filter = ctx.createBiquadFilter();
      filter.type = "lowpass";
      filter.frequency.value = cfg.lowpass;
      filter.Q.value = 0.6;

      // El vaivén es lo que lo separa de una estática: el viento racha, el mar respira.
      const lfo = ctx.createOscillator();
      lfo.frequency.value = cfg.sweep;
      const lfoGain = ctx.createGain();
      lfoGain.gain.value = cfg.band;
      lfo.connect(lfoGain);
      lfoGain.connect(filter.frequency);
      lfo.start(now);

      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(cfg.gain, now + 1.2);   // entra de a poco

      source.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
      source.start(now);

      let bubbles = null;
      if (cfg.bubbles) bubbles = setInterval(() => this.#bubble(), 1700);

      this.nodes = { source, lfo, gain, bubbles };
      this.habitat = habitat;
      return true;
    } catch (error) {
      console.warn("No se pudo iniciar el ambiente.", error);
      return false;
    }
  }

  /** Una burbujita: seno que sube rápido y se apaga. */
  #bubble() {
    const ctx = this.context;
    if (!ctx || ctx.state !== "running") return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    osc.type = "sine";
    const f = 420 + Math.random() * 520;
    osc.frequency.setValueAtTime(f * 0.55, now);
    osc.frequency.exponentialRampToValueAtTime(f, now + 0.09);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.035, now + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.13);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.14);
  }

  stop() {
    if (!this.nodes) return;
    const { source, lfo, gain, bubbles } = this.nodes;
    try {
      const now = this.context.currentTime;
      gain.gain.cancelScheduledValues(now);
      gain.gain.setValueAtTime(gain.gain.value || 0.0001, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.4);
      source.stop(now + 0.45);
      lfo.stop(now + 0.45);
    } catch (error) { /* ya estaba detenido */ }
    if (bubbles) clearInterval(bubbles);
    this.nodes = null;
    this.habitat = null;
  }
}

/** Etiqueta e icono del hábitat, para la franja de datos. */
export const HABITAT_LABEL = { tierra: "Terrestre", aire: "Volador", agua: "Marino" };
export const HABITAT_COLOUR = { tierra: BRAND.orange, aire: "#5a9fd4", agua: "#0e7c9c" };
