// Runs in a headless browser (scripts/render-audio.ts): renders the web
// game's own synth - every stinger, every theme's loop, the ambient one-shots -
// on an OfflineAudioContext and hands back 16-bit mono WAVs as base64.
import { PALETTES, type AmbiencePlace } from "../../src/audio/ambience";
import { scheduleLoop, type TrackName } from "../../src/audio/music";
import { SFX } from "../../src/audio/sfx";
import { initAudioWith } from "../../src/audio/synth";

const SFX_RATE = 44100;
const MUSIC_RATE = 22050;
/** The music bus's echo rings on past a loop; it folds back onto the start. */
const ECHO_TAIL_S = 1.5;
const STINGER_S = 1.4;

function wav(samples: Float32Array, rate: number): string {
  const bytes = new Uint8Array(44 + samples.length * 2);
  const view = new DataView(bytes.buffer);
  const text = (at: number, value: string) => [...value].forEach((c, i) => view.setUint8(at + i, c.charCodeAt(0)));
  text(0, "RIFF");
  view.setUint32(4, 36 + samples.length * 2, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, samples.length * 2, true);
  samples.forEach((sample, i) => view.setInt16(44 + i * 2, Math.max(-1, Math.min(1, sample)) * 32767, true));
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

async function render(seconds: number, rate: number, play: () => void): Promise<Float32Array> {
  const context = new OfflineAudioContext(1, Math.ceil(seconds * rate), rate);
  initAudioWith(context, { music: 1, sfx: 1 });
  play();
  const buffer = await context.startRendering();
  return buffer.getChannelData(0);
}

/** Drops the silence after the last audible sample. */
function trim(samples: Float32Array, rate: number): Float32Array {
  let end = samples.length;
  while (end > 0 && Math.abs(samples[end - 1]) < 1e-4) end--;
  return samples.slice(0, Math.min(samples.length, end + Math.round(rate * 0.02)));
}

async function stinger(name: keyof typeof SFX): Promise<string> {
  return wav(trim(await render(STINGER_S, SFX_RATE, () => SFX[name]()), SFX_RATE), SFX_RATE);
}

async function track(name: TrackName): Promise<{ seconds: number; wav: string }> {
  let seconds = 0;
  const probe = new OfflineAudioContext(1, 1, MUSIC_RATE);
  initAudioWith(probe, { music: 1, sfx: 1 });
  seconds = scheduleLoop(name, 0);
  const samples = await render(seconds + ECHO_TAIL_S, MUSIC_RATE, () => scheduleLoop(name, 0));
  const length = Math.round(seconds * MUSIC_RATE);
  const loop = samples.slice(0, length);
  for (let i = length; i < samples.length; i++) loop[(i - length) % length] += samples[i];
  return { seconds, wav: wav(loop, MUSIC_RATE) };
}

async function ambient(place: Exclude<AmbiencePlace, "none">, index: number): Promise<string> {
  const samples = await render(2.6, SFX_RATE, () => PALETTES[place][index].play());
  return wav(trim(samples, SFX_RATE), SFX_RATE);
}

Object.assign(window, {
  pixelheimAudio: {
    stingers: Object.keys(SFX),
    stinger,
    track,
    palettes: Object.fromEntries(
      Object.entries(PALETTES).map(([place, events]) => [place, events.map((event) => event.chance)]),
    ),
    ambient,
  },
});
