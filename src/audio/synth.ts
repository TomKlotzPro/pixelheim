/**
 * Tiny Web Audio synth: everything the game plays is generated here, no audio
 * files shipped (same philosophy as the sprites). Browsers block audio until
 * a user gesture, so the context is created lazily by init().
 */

import { loadSettings } from "../app/settings";

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let musicBus: GainNode | null = null;
let musicFade: GainNode | null = null;
let sfxBus: GainNode | null = null;
let ambienceBus: GainNode | null = null;

export type Bus = "music" | "sfx" | "ambience";

const MUTE_KEY = "pixelheim-muted";
let muted = false;
try {
  muted = localStorage.getItem(MUTE_KEY) === "1";
} catch {
  // storage unavailable; start unmuted
}

/** Call from a user-gesture handler; safe to call repeatedly. */
export function initAudio(): void {
  if (ctx) return;
  try {
    const settings = loadSettings();
    ctx = new AudioContext();
    master = ctx.createGain();
    master.gain.value = muted ? 0 : 1;
    master.connect(ctx.destination);
    // music -> fade (crossfades) -> bus (user volume) -> master, plus a
    // touch of feedback echo so the chip score has a room to live in
    musicBus = ctx.createGain();
    musicBus.gain.value = settings.musicVolume;
    musicBus.connect(master);
    musicFade = ctx.createGain();
    musicFade.gain.value = 1;
    musicFade.connect(musicBus);
    const delay = ctx.createDelay(1);
    delay.delayTime.value = 0.27;
    const feedback = ctx.createGain();
    feedback.gain.value = 0.22;
    const wet = ctx.createGain();
    wet.gain.value = 0.16;
    musicFade.connect(delay);
    delay.connect(feedback).connect(delay);
    delay.connect(wet).connect(musicBus);
    sfxBus = ctx.createGain();
    sfxBus.gain.value = settings.sfxVolume;
    sfxBus.connect(master);
    // ambience rides the sfx volume, quieter: birdsong should never shout
    ambienceBus = ctx.createGain();
    ambienceBus.gain.value = settings.sfxVolume * 0.55;
    ambienceBus.connect(master);
  } catch {
    ctx = null;
  }
}

export function setBusVolume(bus: Bus, volume: number): void {
  const node = bus === "music" ? musicBus : bus === "sfx" ? sfxBus : ambienceBus;
  if (node && ctx) node.gain.setTargetAtTime(volume, ctx.currentTime, 0.01);
  if (bus === "sfx" && ambienceBus && ctx) ambienceBus.gain.setTargetAtTime(volume * 0.55, ctx.currentTime, 0.01);
}

/** Ramp the crossfade stage (0..1) without touching the user's volume. */
export function rampMusicFade(to: number, seconds: number): void {
  if (musicFade && ctx) musicFade.gain.setTargetAtTime(to, ctx.currentTime, seconds / 3);
}

export function audioReady(): boolean {
  return ctx !== null && ctx.state === "running";
}

export function isMuted(): boolean {
  return muted;
}

export function setMuted(value: boolean): void {
  muted = value;
  try {
    localStorage.setItem(MUTE_KEY, value ? "1" : "0");
  } catch {
    // fine
  }
  if (master && ctx) master.gain.setTargetAtTime(value ? 0 : 1, ctx.currentTime, 0.01);
}

export function now(): number {
  return ctx?.currentTime ?? 0;
}

export type ToneOpts = {
  freq: number;
  /** Seconds. */
  duration: number;
  type?: OscillatorType;
  volume?: number;
  /** Start time in AudioContext seconds; defaults to now. */
  at?: number;
  /** Glide the pitch to this frequency over the duration. */
  slideTo?: number;
  bus?: Bus;
};

function busNode(bus: Bus): GainNode | null {
  return bus === "music" ? musicFade : bus === "sfx" ? sfxBus : ambienceBus;
}

export function playTone({ freq, duration, type = "square", volume = 0.08, at, slideTo, bus = "sfx" }: ToneOpts): void {
  const out = busNode(bus);
  if (!ctx || !out) return;
  const start = at ?? ctx.currentTime;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, start);
  if (slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(1, slideTo), start + duration);
  gain.gain.setValueAtTime(volume, start);
  gain.gain.exponentialRampToValueAtTime(0.001, start + duration);
  osc.connect(gain).connect(out);
  osc.start(start);
  osc.stop(start + duration + 0.02);
}

export function playNoise({
  duration,
  volume = 0.06,
  at,
  bus = "sfx",
  lowpass,
}: {
  duration: number;
  volume?: number;
  at?: number;
  bus?: Bus;
  /** Filter cutoff in Hz; wind and rumble are noise through a small hole. */
  lowpass?: number;
}): void {
  const out = busNode(bus);
  if (!ctx || !out) return;
  const start = at ?? ctx.currentTime;
  const length = Math.max(1, Math.floor(ctx.sampleRate * duration));
  const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i++) data[i] = Math.random() * 2 - 1;
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(volume, start);
  gain.gain.exponentialRampToValueAtTime(0.001, start + duration);
  if (lowpass) {
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = lowpass;
    source.connect(filter).connect(gain).connect(out);
  } else {
    source.connect(gain).connect(out);
  }
  source.start(start);
}

/** Midi note number to frequency. */
export function midi(note: number): number {
  return 440 * Math.pow(2, (note - 69) / 12);
}
