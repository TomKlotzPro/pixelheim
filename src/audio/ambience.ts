import type { GameState } from "../game/types";
import { audioReady, midi, playNoise, playTone } from "./synth";

/**
 * The world under the music: loose, randomized one-shots per place on a slow
 * scheduler. Birdsong in the greenwood, drips and frogs in the bogs, fire
 * crackle indoors. Randomness is fine here - ambience is weather, not rules.
 */
export type AmbiencePlace = "greenwood" | "deepforest" | "marsh" | "indoor" | "none";

const rand = (lo: number, hi: number) => lo + Math.random() * (hi - lo);

/** One ambient event: chance per tick, and the sound it makes. */
type AmbientEvent = { chance: number; play: () => void };

const PALETTES: Record<Exclude<AmbiencePlace, "none">, AmbientEvent[]> = {
  greenwood: [
    {
      // a bird, two or three quick high chirps
      chance: 0.18,
      play: () => {
        const base = midi(Math.floor(rand(88, 96)));
        for (let i = 0; i < Math.floor(rand(2, 4)); i++) {
          playTone({ freq: base * rand(0.95, 1.1), duration: 0.05, type: "sine", slideTo: base * 1.3, volume: 0.025, bus: "ambience", at: undefined });
        }
      },
    },
    {
      // a breath of wind through grass
      chance: 0.1,
      play: () => playNoise({ duration: rand(0.8, 1.6), volume: 0.012, lowpass: 900, bus: "ambience" }),
    },
  ],
  deepforest: [
    {
      // something low calls, twice
      chance: 0.1,
      play: () => {
        const f = midi(Math.floor(rand(62, 68)));
        playTone({ freq: f, duration: 0.16, type: "sine", volume: 0.02, bus: "ambience" });
        playTone({ freq: f * 0.94, duration: 0.2, type: "sine", volume: 0.016, bus: "ambience", at: undefined });
      },
    },
    {
      // old wind in old branches
      chance: 0.14,
      play: () => playNoise({ duration: rand(1.2, 2.2), volume: 0.014, lowpass: 500, bus: "ambience" }),
    },
  ],
  marsh: [
    {
      // a drip
      chance: 0.2,
      play: () =>
        playTone({ freq: rand(900, 1400), duration: 0.05, type: "sine", slideTo: rand(400, 600), volume: 0.025, bus: "ambience" }),
    },
    {
      // a frog clears its throat
      chance: 0.1,
      play: () => playTone({ freq: rand(90, 130), duration: 0.12, type: "sawtooth", slideTo: 70, volume: 0.02, bus: "ambience" }),
    },
    {
      // bog gas, politely
      chance: 0.06,
      play: () => playNoise({ duration: rand(0.15, 0.3), volume: 0.012, lowpass: 300, bus: "ambience" }),
    },
  ],
  indoor: [
    {
      // the hearth pops
      chance: 0.22,
      play: () => playNoise({ duration: rand(0.02, 0.05), volume: rand(0.01, 0.025), lowpass: 1800, bus: "ambience" }),
    },
    {
      // a settling beam
      chance: 0.04,
      play: () => playTone({ freq: rand(70, 110), duration: 0.09, type: "triangle", volume: 0.014, bus: "ambience" }),
    },
  ],
};

/** Where the hero's ears are, given the state. */
export function ambienceForState(state: GameState): AmbiencePlace {
  if (state.screen !== "world" || !state.world) return "none";
  const map = state.world.position.mapId;
  if (map === "overworld" || map === "town" || map === "demo") return "greenwood";
  if (map === "deepwood") return "deepforest";
  if (map === "mirefen") return "marsh";
  return "indoor";
}

let current: AmbiencePlace = "none";
let timer: ReturnType<typeof setInterval> | null = null;

const TICK_MS = 700;

export function setAmbience(place: AmbiencePlace): void {
  if (current === place) return;
  current = place;
  if (timer) clearInterval(timer);
  timer = null;
  if (place === "none") return;
  timer = setInterval(() => {
    if (!audioReady()) return;
    for (const event of PALETTES[place]) {
      if (Math.random() < event.chance) event.play();
    }
  }, TICK_MS);
}

export function stopAmbience(): void {
  setAmbience("none");
}
