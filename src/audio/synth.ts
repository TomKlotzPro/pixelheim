/**
 * Tiny Web Audio synth: everything the game plays is generated here, no audio
 * files shipped (same philosophy as the sprites). Browsers block audio until
 * a user gesture, so the context is created lazily by init().
 */

import { loadSettings } from "../app/settings";

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let musicBus: GainNode | null = null;
let sfxBus: GainNode | null = null;

export type Bus = "music" | "sfx";

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
    musicBus = ctx.createGain();
    musicBus.gain.value = settings.musicVolume;
    musicBus.connect(master);
    sfxBus = ctx.createGain();
    sfxBus.gain.value = settings.sfxVolume;
    sfxBus.connect(master);
  } catch {
    ctx = null;
  }
}

export function setBusVolume(bus: Bus, volume: number): void {
  const node = bus === "music" ? musicBus : sfxBus;
  if (node && ctx) node.gain.setTargetAtTime(volume, ctx.currentTime, 0.01);
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
  return bus === "music" ? musicBus : sfxBus;
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
}: {
  duration: number;
  volume?: number;
  at?: number;
  bus?: Bus;
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
  source.connect(gain).connect(out);
  source.start(start);
}

/** Midi note number to frequency. */
export function midi(note: number): number {
  return 440 * Math.pow(2, (note - 69) / 12);
}
