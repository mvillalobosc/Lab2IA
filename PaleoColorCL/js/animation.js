import { DISPLAY } from "./config.js?v=99";
import { animationOf, segmentAt, transformFor } from "./rig.js?v=99";
import { TRANSLATIONS } from "./i18n.js?v=99";
import { VoiceBox } from "./voice.js?v=99";
import { AmbientBox } from "./ambient.js?v=99";

// Nombres de voces que suelen ser femeninas o agudas en cada idioma. No hay una API para
// pedir "voz linda", así que se elige por nombre y se cae con elegancia a lo que haya.
const NICE_VOICES = /m[oó]nica|paulina|marisol|sabina|in[eé]s|luciana|joana|catarina|helena|fernanda|samantha|karen|tessa|fiona|moira|victoria|zira|susan|aria|jenny|female|mujer|feminino/i;
// Nombres típicamente masculinos: no se descartan, sólo se dejan para el final.
const MALE_VOICES = /david|mark|guy|jorge|diego|carlos|juan|pablo|felipe|ricardo|daniel|thomas|fred|alex|george|james|male|hombre|masculino/i;

const TAU = Math.PI * 2;

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function smoother(value) {
  const x = clamp01(value);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

function smootherDerivative(value) {
  const x = clamp01(value);
  return 30 * x * x * (x - 1) * (x - 1);
}

function smootherSecondDerivative(value) {
  const x = clamp01(value);
  return 60 * x * (x - 1) * (2 * x - 1);
}

function lerp(a, b, amount) {
  return a + (b - a) * amount;
}


export class CharacterAnimator {
  constructor() {
    this.audioContext = null;
    this.audioUnlocked = false;
    this.lastStepBucket = -1;
    this.lastSpeechKey = "";
    this.helloUntil = Number.NEGATIVE_INFINITY;
    this.celebrateUntil = Number.NEGATIVE_INFINITY;
    this.language = "es";
    this.parts = null;
    this.rear = null;
    this.texture = [384, 512];
    this.content = null;
    this.animation = null;
    this.groundY = 474;
    this.startedAt = 0;
    this.nativeFacing = 1;
    this.wavePartId = null;
    // OJO: this.voice es la voz TTS cacheada. Los clips del personaje van en voiceBox.
    this.voiceBox = new VoiceBox();
    this.ambient = new AmbientBox();
    this.voice = null;
    this.lineIndex = 0;
    if (typeof window !== "undefined" && "speechSynthesis" in window) {
      // En Chrome getVoices() llega vacío al principio y se puebla más tarde.
      const refresh = () => { this.voice = null; };
      if (window.speechSynthesis.addEventListener) {
        window.speechSynthesis.addEventListener("voiceschanged", refresh);
      } else {
        window.speechSynthesis.onvoiceschanged = refresh;
      }
    }
  }

  /** Configura el rig sin alterar los lienzos coloreados del personaje. */
  setCharacter(character) {
    this.character = character;
    this.parts = character.parts;
    this.rear = character.rear;
    this.texture = character.frame.texture;
    this.content = character.content;
    this.animation = animationOf(character.animation);
    this.groundY = character.groundY;
    this.startedAt = typeof performance !== "undefined" ? performance.now() : 0;

    // Los dibujos no vienen orientados todos hacia el mismo lado. La posición de la cabeza
    // respecto del cuerpo permite descubrir la orientación original y evita que algunos
    // animales caminen hacia atrás al reutilizar la misma coreografía.
    const body = this.#bodyPivot();
    const heads = this.parts.filter((part) => String(part.id).startsWith("cabeza"));
    if (heads.length) {
      const headX = heads.reduce((sum, part) => sum + part.pivot[0], 0) / heads.length;
      this.nativeFacing = headX >= body[0] ? 1 : -1;
    } else {
      this.nativeFacing = 1;
    }

    // El saludo se asigna a una sola extremidad delantera visible. Las demás conservan su
    // apoyo y el personaje no parece despegar todas las patas a la vez.
    const frontLimbs = this.parts.filter((part) => part.motion === "pendulo"
      && (part.pivot[0] - body[0]) * this.nativeFacing > -4);
    this.wavePartId = frontLimbs.length ? frontLimbs[frontLimbs.length - 1].id : null;

    if (this.audioContext) {
      this.voiceBox.attach(this.audioContext);
      this.ambient.attach(this.audioContext);
    }
    if (character.habitat) this.ambient.start(character.habitat);
    this.voiceBox.load(character.voice, character.baseDir ?? "");
  }

  setLanguage(language) {
    if (language === this.language) return;
    this.language = language;
    this.voice = null;
    this.lineIndex = 0;
  }

  #strings() {
    return TRANSLATIONS[this.language] ?? TRANSLATIONS.es;
  }

  #pickVoice() {
    if (this.voice) return this.voice;
    if (!("speechSynthesis" in window)) return null;
    const voices = window.speechSynthesis.getVoices() || [];
    if (!voices.length) return null;
    // Si el dispositivo no tiene ninguna voz del idioma, se devuelve null a propósito:
    // forzar una voz de otro idioma hace que lea el castellano con fonética ajena.
    // Sin voz, el motor elige según utterance.lang, que siempre se fija.
    const candidates = voices.filter((v) => (v.lang || "").toLowerCase().startsWith(this.language));
    if (!candidates.length) return null;
    this.voice = candidates.find((v) => NICE_VOICES.test(v.name))
      || candidates.find((v) => !MALE_VOICES.test(v.name) && v.localService)
      || candidates.find((v) => !MALE_VOICES.test(v.name))
      || candidates.find((v) => v.localService)
      || candidates[0]
      || null;
    return this.voice;
  }

  /** No se espera con await desde startCamera: el arranque no puede depender del audio. */
  async unlockAudio() {
    try {
      if (!this.audioContext) this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      if (this.audioContext.state === "suspended") await this.audioContext.resume();
      this.voiceBox.attach(this.audioContext);
      this.ambient.attach(this.audioContext);
    } catch (error) {
      console.warn("AudioContext no disponible.", error);
    }
    try {
      // iOS exige que la primera locución salga de un gesto del usuario, igual que el audio.
      if ("speechSynthesis" in window) {
        const warmup = new SpeechSynthesisUtterance(" ");
        warmup.volume = 0;
        window.speechSynthesis.speak(warmup);
        this.#pickVoice();
      }
    } catch (error) {
      /* sin síntesis de voz */
    }
    this.audioUnlocked = true;
  }

  greet(now) {
    // La primera textura válida es el verdadero nacimiento del personaje. Reiniciar aquí evita
    // que aparezca ya a mitad de un giro sólo porque la cámara tardó en leer los colores.
    this.startedAt = now;
    this.helloUntil = now + 1600;
    this.celebrateUntil = now + 900;
    this.#say();
  }

  /**
   * @param pose {center, angle, width, height} del rectángulo del DIBUJO en pantalla.
   * El personaje se dibuja a escala 1:1 sobre el dibujo impreso: la textura se muestreó de
   * ese mismo rectángulo, así que en reposo calza píxel a píxel y parece que el dibujo
   * mismo se levantó del papel.
   */
  render(context, parts, pose, viewport, now) {
    if (!parts || !pose || !this.parts?.length || !this.animation) return;
    if (!Number.isFinite(pose.height) || !Number.isFinite(pose.width) || pose.height < 40) return;

    const state = this.#animationState(now);
    this.#handleAudio(state, now);

    const [textureWidth, textureHeight] = this.texture;
    const displayHeight = pose.height * DISPLAY.characterHeightInFrame;
    const scale = displayHeight / textureHeight;
    const box = this.content ?? { x0: 0, y0: 0, x1: textureWidth, y1: textureHeight };
    const contentWidth = (box.x1 - box.x0) * scale;
    const half = contentWidth / 2;
    const edge = 24;
    const screenRoom = Math.max(0, Math.min(
      pose.center[0] - half - edge,
      viewport.width - pose.center[0] - half - edge,
    ));
    const travel = Math.min(pose.width * DISPLAY.walkHalfSpanInFrame, screenRoom);
    const margin = Math.max(0, (pose.width - contentWidth) / 2);
    const anchorX = pose.center[0] + state.x * travel;
    const anchorY = pose.center[1];

    // El alzado y el vuelo se limitan por el borde real de la pantalla. La medida está en
    // píxeles de la textura porque se aplica después de la escala del personaje.
    const contentTop = pose.center[1] - (textureHeight / 2 - box.y0) * scale;
    const headroom = Math.max(0, (contentTop - 12) / Math.max(scale, 1e-6));
    const room = Math.min(1, margin / Math.max(1, pose.width * 0.06));
    const rearSpec = this.#rearSpec();

    // Busca cuánto del alzado cabe sin sacar una esquina del personaje de la pantalla.
    let rearScale = 1;
    if (rearSpec && state.rear > 0) {
      const boundary = 10;
      const fits = (amount) => {
        const angle = rearSpec.angle * amount;
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        const facing = state.direction * this.nativeFacing;
        for (const [cx, cy] of [[box.x0, box.y0], [box.x1, box.y0], [box.x1, box.y1], [box.x0, box.y1]]) {
          const dx = cx - rearSpec.pivot[0];
          const dy = cy - rearSpec.pivot[1];
          const tx = rearSpec.pivot[0] + dx * cos - dy * sin;
          const ty = rearSpec.pivot[1] + dx * sin + dy * cos;
          const screenX = anchorX + (tx - textureWidth / 2) * scale * facing;
          const screenY = anchorY + (ty - textureHeight / 2) * scale;
          if (screenX < boundary || screenX > viewport.width - boundary || screenY < boundary) return false;
        }
        return true;
      };
      if (!fits(1)) {
        let low = 0;
        let high = 1;
        for (let index = 0; index < 9; index += 1) {
          const middle = (low + high) / 2;
          if (fits(middle)) low = middle;
          else high = middle;
        }
        rearScale = low;
      }
    }

    const celebrate = now < this.celebrateUntil
      ? Math.sin(((this.celebrateUntil - now) / 900) * Math.PI) : 0;

    this.#drawShadow(context, anchorX, anchorY, pose.angle, contentWidth, scale, state, celebrate);

    const drawFacing = (direction, tilt = 0, pop = 1, widthScale = 1) => {
      context.save();
      context.translate(anchorX, anchorY);
      context.rotate(pose.angle + tilt + celebrate * 0.025 * Math.sin(now / 65));
      const facing = direction * this.nativeFacing;
      context.scale(scale * facing * pop * widthScale, scale * pop);
      const requestedLift = state.y - celebrate * 52;
      const lift = Math.max(-requestedLift, 0) > headroom ? -headroom : requestedLift;
      context.translate(-textureWidth / 2, -textureHeight / 2 + lift);
      this.#drawCharacter(context, parts, state, room, rearScale, rearSpec);
      context.restore();
    };

    if (state.turning) {
      // El giro simula perspectiva comprimiendo el ancho hasta casi cero. El cambio de espejo
      // ocurre justo ahí y deja de verse como un salto instantáneo de una pose a la otra.
      const progress = smoother(state.turnProgress);
      const arc = Math.sin(progress * Math.PI);
      const widthScale = Math.max(0.08, Math.abs(Math.cos(progress * Math.PI)));
      const direction = progress < 0.5 ? state.fromDirection : state.toDirection;
      const sign = progress < 0.5 ? -1 : 1;
      const tilt = sign * 0.09 * arc * Math.max(0.35, room);
      context.save();
      context.translate(0, -arc * Math.min(pose.height * 0.075, headroom * scale));
      drawFacing(direction, tilt, 1 + arc * 0.045, widthScale);
      context.restore();
    } else {
      drawFacing(state.direction, 0, 1 + celebrate * 0.035);
    }

    if (state.speech || now < this.helloUntil) {
      const size = displayHeight * textureWidth / textureHeight;
      const bubble = this.#speechSize(size);
      let offsetX = size * 0.34 * state.direction;
      const left = anchorX + offsetX - bubble.width / 2;
      const right = anchorX + offsetX + bubble.width / 2;
      if (right > viewport.width - 6) offsetX -= right - (viewport.width - 6);
      if (left < 6) offsetX += 6 - left;
      const bubbleBob = Math.sin(now / 190) * Math.min(3, size * 0.008);
      const offsetY = Math.max(-size * 0.52, -(anchorY - bubble.height / 2 - 6)) + bubbleBob;
      context.save();
      context.translate(anchorX, anchorY);
      context.rotate(pose.angle);
      this.#drawSpeech(context, size, offsetX, offsetY);
      context.restore();
    }
  }

  #animationState(now) {
    const animation = this.animation;
    const elapsed = Math.max(0, now - this.startedAt);
    const cyclePosition = elapsed / animation.cycleMs;
    const cycleIndex = Math.floor(cyclePosition);
    const t = cyclePosition - cycleIndex;
    const segment = segmentAt(animation, t);
    const gait = cyclePosition * animation.gaitPerCycle * TAU;
    const progress = clamp01(segment.progress);
    const eased = smoother(progress);

    let direction = segment.direction ?? 1;
    const turning = Boolean(segment.turning);
    if (turning) direction = progress < 0.5 ? segment.from : segment.to;

    let x = Number.isFinite(segment.holdX) ? segment.holdX : 0;
    let velocity = 0;
    let acceleration = 0;
    if (segment.walking) {
      const fromX = Number.isFinite(segment.fromX) ? segment.fromX : 0;
      const toX = Number.isFinite(segment.toX) ? segment.toX : fromX;
      const distance = toX - fromX;
      x = lerp(fromX, toX, eased);
      velocity = distance * smootherDerivative(progress) / segment.duration;
      acceleration = distance * smootherSecondDerivative(progress) / (segment.duration * segment.duration);
      if (Math.abs(velocity) > 1e-5) direction = velocity > 0 ? 1 : -1;
    }

    velocity = Math.max(-22, Math.min(22, velocity));
    acceleration = Math.max(-180, Math.min(180, acceleration));
    const motionWeight = segment.walking
      ? Math.pow(Math.max(0, Math.sin(progress * Math.PI)), 0.32)
      : 0;
    const stride = Math.sin(gait);
    const contact = Math.abs(Math.cos(gait));
    const gesture = Math.sin(eased * Math.PI);
    const style = animation.style ?? "walk";

    let y = -Math.sin(t * TAU) * 1.1;
    let squashY = 1;
    let squashX = 1;
    let body = 0;
    let shadowAlpha = 0.16;
    let shadowScale = 1;

    if (style === "scurry") {
      const hop = Math.max(0, Math.sin(gait)) * motionWeight;
      y = -5.4 * hop - 1.8 * contact * motionWeight;
      squashY = 1 - 0.055 * contact * motionWeight + 0.035 * hop;
      squashX = 1 + 0.04 * contact * motionWeight - 0.018 * hop;
      body = 0.018 * stride * motionWeight + velocity * 0.0018;
      shadowScale = 1 - hop * 0.12;
    } else if (style === "swim") {
      y = -5.5 * (0.5 - 0.5 * Math.cos(t * TAU)) - 2.2 * Math.sin(gait * 0.52);
      body = 0.028 * Math.sin(t * TAU - 0.5) + velocity * 0.0014;
      squashY = 1 + 0.012 * Math.sin(gait * 0.5);
      squashX = 1 - 0.008 * Math.sin(gait * 0.5);
      shadowAlpha = 0.075;
      shadowScale = 0.88;
    } else if (style === "fly") {
      const lift = 0.5 - 0.5 * Math.cos(t * TAU);
      y = -13 * lift - 3.8 * Math.abs(Math.sin(gait)) * motionWeight;
      body = -0.018 * Math.sin(gait * 0.5) + velocity * 0.0019;
      squashY = 1 + 0.016 * Math.sin(gait);
      squashX = 1 - 0.011 * Math.sin(gait);
      shadowAlpha = 0.065;
      shadowScale = 0.72 + lift * 0.18;
    } else if (style === "heavy") {
      y = -2.1 * contact * motionWeight;
      squashY = 1 - 0.026 * contact * motionWeight;
      squashX = 1 + 0.017 * contact * motionWeight;
      body = 0.007 * stride * motionWeight + velocity * 0.00075;
      shadowAlpha = 0.19;
    } else if (style === "idle") {
      y = -1.4 * Math.sin(t * TAU) - gesture * 1.2;
      body = 0.006 * Math.sin(t * TAU * 0.6);
      shadowAlpha = 0.13;
    } else {
      y = -3.2 * contact * motionWeight;
      squashY = 1 - 0.038 * contact * motionWeight;
      squashX = 1 + 0.024 * contact * motionWeight;
      body = 0.011 * stride * motionWeight + velocity * 0.0011;
    }

    const takesRear = !animation.rearEvery || cycleIndex % animation.rearEvery === 0;
    const rear = segment.rearing && takesRear ? Math.sin(eased * Math.PI) : 0;
    if (rear > 0) {
      y -= rear * 5;
      squashY += rear * 0.018;
      squashX -= rear * 0.012;
    }

    if (!segment.walking && segment.waving) y -= gesture * 1.8;

    return {
      rear,
      style,
      segment: segment.name,
      segmentProgress: progress,
      cycleIndex,
      t,
      gait,
      x,
      velocity,
      acceleration,
      motionWeight,
      direction,
      turning,
      turnProgress: progress,
      fromDirection: segment.from ?? direction,
      toDirection: segment.to ?? direction,
      waving: Boolean(segment.waving),
      looking: Boolean(segment.looking),
      waveProgress: progress,
      walking: Boolean(segment.walking),
      speech: Boolean(segment.waving),
      swims: Boolean(animation.swims),
      flies: Boolean(animation.flies),
      stepBucket: segment.walking && !animation.swims && !animation.flies
        ? Math.floor(gait / Math.PI) : -1,
      y,
      squashY,
      squashX,
      body,
      shadowAlpha,
      shadowScale,
    };
  }

  #drawCharacter(context, parts, state, room = 1, rearScale = 1, rearSpec = null) {
    const body = this.#bodyPivot();
    context.save();

    if (state.rear > 0 && rearSpec) {
      const [rearX, rearY] = rearSpec.pivot;
      context.translate(rearX, rearY);
      context.rotate(rearSpec.angle * state.rear * rearScale);
      context.translate(-rearX, -rearY);
    }

    context.translate(body[0], this.groundY);
    const scaleX = state.squashX > 1 ? 1 + (state.squashX - 1) * room : state.squashX;
    context.scale(scaleX, state.squashY);
    context.translate(-body[0], -this.groundY);
    context.translate(body[0], body[1]);
    context.rotate(state.body);
    context.translate(-body[0], -body[1]);

    for (const part of this.parts) {
      const canvas = parts[part.id];
      if (!canvas) continue;
      const move = transformFor(part, state.t, state.gait, {
        bodyPivot: body,
        nativeFacing: this.nativeFacing,
        isWavePart: part.id === this.wavePartId,
        style: state.style,
        swims: state.swims,
        flies: state.flies,
        waving: state.waving,
        looking: state.looking,
        waveProgress: state.waveProgress,
        segmentProgress: state.segmentProgress,
        walking: state.walking,
        motionWeight: state.motionWeight,
        velocity: state.velocity,
        acceleration: state.acceleration,
        rear: state.rear,
      });
      context.save();
      context.translate(part.pivot[0] + move.dx, part.pivot[1] + move.dy);
      context.rotate(move.angle);
      context.scale(move.scaleX, move.scaleY);
      context.translate(-part.pivot[0], -part.pivot[1]);
      context.drawImage(canvas, 0, 0);
      context.restore();
    }
    context.restore();
  }

  #rearSpec() {
    if (this.rear) return this.rear;
    if (this.animation?.style !== "rear") return null;
    const [textureWidth] = this.texture;
    const box = this.content ?? { x0: 0, x1: textureWidth };
    const width = Math.max(1, box.x1 - box.x0);
    const rearX = this.nativeFacing > 0
      ? box.x0 + width * 0.24
      : box.x1 - width * 0.24;
    return {
      pivot: [rearX, this.groundY],
      angle: -this.nativeFacing * 0.16,
    };
  }

  #drawShadow(context, anchorX, anchorY, angle, contentWidth, scale, state, celebrate) {
    const [, textureHeight] = this.texture;
    const groundOffset = (this.groundY - textureHeight / 2) * scale;
    const lift = Math.max(0, -state.y + celebrate * 52);
    const liftRatio = clamp01(lift / 90);
    const alpha = state.shadowAlpha * (1 - liftRatio * 0.62);
    const width = contentWidth * 0.31 * state.shadowScale * (1 + liftRatio * 0.18);
    const height = Math.max(2, contentWidth * 0.028 * (1 - liftRatio * 0.42));
    context.save();
    context.translate(anchorX, anchorY);
    context.rotate(angle);
    context.fillStyle = `rgba(24,18,31,${alpha.toFixed(3)})`;
    context.beginPath();
    context.ellipse(0, groundOffset + 2, Math.max(4, width), height, 0, 0, TAU);
    context.fill();
    context.restore();
  }

  /** Pivote del cuerpo: el de la parte marcada como ancla, o el promedio. */
  #bodyPivot() {
    const anchor = this.parts.find((p) => p.anchor) ?? this.parts[0];
    return anchor.pivot;
  }

  /** Tamaño del globo. Se calcula aparte para poder acotarlo antes de dibujarlo. */
  #bubbleText() {
    // Un dinosaurio no dice "¡Hola!". El personaje manda; el idioma es el respaldo.
    return this.character?.voice?.bubble ?? this.#strings().bubble;
  }

  #speechSize(size) {
    const text = this.#bubbleText();
    return {
      width: Math.max(74, size * 0.28 + text.length * size * 0.022),
      height: Math.max(34, size * 0.12),
    };
  }

  #drawSpeech(context, size, offsetX, offsetY) {
    const text = this.#bubbleText();
    const { width, height } = this.#speechSize(size);
    context.save();
    context.translate(offsetX, offsetY);
    context.fillStyle = "rgba(255,255,255,.97)";
    context.strokeStyle = "#25182f";
    context.lineWidth = Math.max(2, size * 0.008);
    context.beginPath();
    if (typeof context.roundRect === "function") context.roundRect(-width / 2, -height / 2, width, height, height * 0.3);
    else context.rect(-width / 2, -height / 2, width, height);
    context.fill();
    context.stroke();
    context.fillStyle = "#7c3aed";
    context.font = `900 ${Math.max(15, size * 0.055)}px system-ui`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(text, 0, 1);
    context.restore();
  }

  #handleAudio(state, now) {
    if (state.walking && state.stepBucket >= 0 && state.stepBucket !== this.lastStepBucket) {
      this.lastStepBucket = state.stepBucket;
      this.#playStep();
    }
    if (!state.walking) this.lastStepBucket = -1;
    // Antes el guard era por ciclo, así que de los dos saludos de la coreografía
    // sólo sonaba uno. La clave ahora incluye el segmento.
    if (state.speech) {
      const key = `${state.cycleIndex}:${state.segment}`;
      if (key !== this.lastSpeechKey) {
        this.lastSpeechKey = key;
        this.helloUntil = now + 1300;
        this.#say();
      }
    }
  }

  #playStep() {
    if (!this.audioContext) return;
    const time = this.audioContext.currentTime;
    const oscillator = this.audioContext.createOscillator();
    const gain = this.audioContext.createGain();
    const filter = this.audioContext.createBiquadFilter();
    oscillator.type = "triangle";
    oscillator.frequency.setValueAtTime(125, time);
    oscillator.frequency.exponentialRampToValueAtTime(70, time + 0.07);
    filter.type = "lowpass";
    filter.frequency.value = 520;
    gain.gain.setValueAtTime(0.0001, time);
    gain.gain.exponentialRampToValueAtTime(0.05, time + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.1);
    oscillator.connect(filter); filter.connect(gain); gain.connect(this.audioContext.destination);
    oscillator.start(time); oscillator.stop(time + 0.11);
  }

  #speak() {
    if (!("speechSynthesis" in window)) return false;
    try {
      const lines = this.#strings().voiceLines;
      const text = lines[this.lineIndex % lines.length];
      this.lineIndex += 1;
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      const voice = this.#pickVoice();
      if (voice) utterance.voice = voice;
      // El idioma se fija igual aunque no haya voz elegida: si no, el sistema lee
      // castellano con fonética inglesa.
      utterance.lang = voice?.lang || { es: "es-ES", en: "en-US", pt: "pt-BR" }[this.language] || "es-ES";
      utterance.pitch = 1.6;
      utterance.rate = 0.95;
      utterance.volume = 1;
      window.speechSynthesis.speak(utterance);
      return true;
    } catch (error) {
      console.warn("No se pudo reproducir la voz.", error);
      return false;
    }
  }

  /**
   * Voz del personaje: su rugido o su clip; si no tiene, la síntesis de voz.
   *
   * Había un tercer respaldo a un wav genérico. Se fue con el personaje al que pertenecía y
   * el <audio> vacío que quedó enchufado colgaba el arranque de la cámara: play() sobre un
   * elemento sin fuente deja la promesa pendiente para siempre.
   */
  #say() {
    if (this.voiceBox.play()) return;
    this.#speak();
  }
}
