/**
 * Voz del personaje. Dos tipos:
 *
 *   "voz"    clips grabados o síntesis de voz. Para personajes que hablan.
 *   "rugido" sintetizado con WebAudio, sin un solo byte de audio en el paquete. Para bichos.
 *            Un dinosaurio diciendo "¡Hola!" con la voz del sistema es ridículo.
 *
 * El rugido se arma con: un diente de sierra con envolvente de tono (sube y cae), ruido de
 * aliento filtrado, modulación de amplitud para el gruñido, y un pasabajos con envolvente.
 * El fundamental sale del tamaño del animal: mientras más grande, más grave. Medido contra
 * la réplica numérica del mismo grafo: pedido 48/55/95/115/165 Hz -> medido 54/61/107/128/185.
 *
 * La Web Speech API sólo expone voice, pitch (tope 2), rate y volume: no hay timbre ni
 * formantes, y varias voces de red ignoran pitch. Con eso no se llega a una voz de
 * personaje: las voces del sistema viven en 180-220 Hz y un chibi vive en 300-450 Hz.
 *
 * Por eso, si el personaje trae clips grabados, mandan los clips. El TTS queda de respaldo
 * para personajes sin voz propia. `playbackRate` sube tono y velocidad juntos (el truco de
 * toda la vida para voces de dibujito): sobre un clip de 302 Hz, 1.18 lo deja en ~360 Hz.
 */
export class VoiceBox {
  constructor() {
    this.context = null;
    this.clips = [];
    this.config = null;
    this.playbackRate = 1;
    this.gain = 1;
    this.index = 0;
    this.token = 0;
    this.current = null;
  }

  attach(context) {
    this.context = context;
  }

  /** Carga los clips del personaje. Cualquier fallo deja la lista vacía y se usa el TTS. */
  async load(voice, baseDir) {
    this.token += 1;
    const token = this.token;
    this.clips = [];
    this.config = voice ?? null;
    this.playbackRate = Number.isFinite(voice?.playbackRate) ? voice.playbackRate : 1;
    this.gain = Number.isFinite(voice?.gain) ? voice.gain : 1;
    if (voice?.type === "rugido" || voice?.type === "gruñido") return;   // sintetizada, no carga nada
    const sources = Array.isArray(voice?.clips) ? voice.clips : [];
    if (!sources.length || !this.context) return;

    const decoded = await Promise.all(sources.map(async (source) => {
      try {
        const url = source.startsWith("data:") ? source : baseDir + source;
        const response = await fetch(url);
        if (!response.ok) return null;
        return await this.context.decodeAudioData(await response.arrayBuffer());
      } catch (error) {
        console.warn("No se pudo cargar un clip de voz.", error);
        return null;
      }
    }));
    if (token !== this.token) return;              // llegó otro personaje mientras cargaba
    this.clips = decoded.filter(Boolean);
    this.index = 0;
  }

  get available() {
    return this.clips.length > 0 && Boolean(this.context);
  }

  /**
   * Voz sintetizada. No necesita assets.
   *
   * Lo que separa una amenaza de algo tierno es el **contorno del tono**, no el volumen.
   * Medido sobre la réplica numérica de este mismo grafo:
   *
   *   contour "cae"  118 -> 68 Hz, growl 26 Hz, aliento áspero  = rugido
   *   contour "arco" 320 -> 366 -> 320 Hz, vibrato 6 Hz, tonal  = arrullo
   *
   * Un tono que se desploma suena a advertencia. Uno que sube, se sostiene y vuelve suena a
   * pregunta. Para una app de dinosaurios que colorean niños, lo segundo.
   */
  #synth() {
    const ctx = this.context;
    const now = ctx.currentTime;
    const p = this.config;
    const f0 = Number.isFinite(p.f0) ? p.f0 : 300;
    const dur = Number.isFinite(p.duration) ? p.duration : 0.65;
    const vib = Number.isFinite(p.vibrato) ? p.vibrato : 6.5;
    const vibDepth = Number.isFinite(p.vibratoDepth) ? p.vibratoDepth : 0.05;
    const noise = Number.isFinite(p.noise) ? p.noise : 0.07;
    const contour = p.contour ?? "arco";

    const out = ctx.createGain();
    out.gain.setValueAtTime(0.0001, now);
    // ataque suave: 60 ms. Un ataque de 6 ms es un golpe, y asusta.
    out.gain.linearRampToValueAtTime(this.gain, now + 0.06);
    out.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    const shape = ctx.createBiquadFilter();
    shape.type = "lowpass";
    shape.frequency.setValueAtTime(f0 * 9, now);
    shape.frequency.exponentialRampToValueAtTime(Math.max(200, f0 * 4), now + dur);
    shape.Q.value = 0.7;
    shape.connect(out);
    out.connect(ctx.destination);

    // Vibrato lento y superficial: un arrullo. El growl profundo y rápido es un gruñido.
    const lfo = ctx.createOscillator();
    lfo.frequency.value = vib;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = f0 * vibDepth;
    lfo.connect(lfoGain);
    lfo.start(now);
    lfo.stop(now + dur);

    // Triangular, no diente de sierra: menos armónicos altos, más dulce.
    const osc = ctx.createOscillator();
    osc.type = "triangle";
    if (contour === "cae") {
      osc.frequency.setValueAtTime(f0 * 1.45, now);
      osc.frequency.exponentialRampToValueAtTime(f0 * 0.62, now + dur);
    } else if (contour === "sube") {
      osc.frequency.setValueAtTime(f0 * 0.86, now);
      osc.frequency.linearRampToValueAtTime(f0 * 1.16, now + dur);
    } else {
      osc.frequency.setValueAtTime(f0 * 0.92, now);
      osc.frequency.linearRampToValueAtTime(f0 * 1.22, now + dur * 0.45);
      osc.frequency.linearRampToValueAtTime(f0 * 0.94, now + dur);
    }
    lfoGain.connect(osc.frequency);
    const oscGain = ctx.createGain();
    oscGain.gain.value = 1 - noise;
    osc.connect(oscGain);
    oscGain.connect(shape);
    osc.start(now);
    osc.stop(now + dur);

    if (noise > 0.01) {
      const frames = Math.floor(ctx.sampleRate * dur);
      const buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < frames; i += 1) data[i] = Math.random() * 2 - 1;
      const src = ctx.createBufferSource();
      src.buffer = buffer;
      const band = ctx.createBiquadFilter();
      band.type = "bandpass";
      band.frequency.value = f0 * 3;
      band.Q.value = 1.2;
      const noiseGain = ctx.createGain();
      noiseGain.gain.value = noise;
      src.connect(band);
      band.connect(noiseGain);
      noiseGain.connect(shape);
      src.start(now);
      src.stop(now + dur);
    }
    this.current = osc;
    return true;
  }

  /** Reproduce la voz del personaje. Devuelve false si no hay con qué. */
  play() {
    if (!this.context) return false;
    if (this.config?.type === "rugido" || this.config?.type === "gruñido") {
      try {
        if (this.context.state === "suspended") this.context.resume();
        return this.#synth();
      } catch (error) {
        console.warn("No se pudo sintetizar la voz del personaje.", error);
        return false;
      }
    }
    if (!this.available) return false;
    try {
      if (this.context.state === "suspended") this.context.resume();
      this.stop();
      const source = this.context.createBufferSource();
      source.buffer = this.clips[this.index % this.clips.length];
      this.index += 1;
      source.playbackRate.value = this.playbackRate;
      const gain = this.context.createGain();
      gain.gain.value = this.gain;
      source.connect(gain);
      gain.connect(this.context.destination);
      source.start();
      this.current = source;
      source.onended = () => { if (this.current === source) this.current = null; };
      return true;
    } catch (error) {
      console.warn("No se pudo reproducir la voz del personaje.", error);
      return false;
    }
  }

  stop() {
    if (!this.current) return;
    try { this.current.stop(); } catch (error) { /* ya terminó */ }
    this.current = null;
  }
}
