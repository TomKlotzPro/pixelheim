import { midi, now, playNoise, playTone } from "./synth";

function nowPlus(seconds: number): number {
  return now() + seconds;
}

/** Short retro stingers. Each is a few oscillator blips; nothing is sampled. */
export const SFX = {
  /** The hero lands a hit. */
  hit(): void {
    playTone({ freq: 220, duration: 0.08, type: "square", slideTo: 110, volume: 0.09 });
    playNoise({ duration: 0.05, volume: 0.05 });
  },
  /** The hero takes damage. */
  hurt(): void {
    playTone({ freq: 160, duration: 0.15, type: "sawtooth", slideTo: 60, volume: 0.08 });
  },
  heal(): void {
    playTone({ freq: midi(72), duration: 0.09, type: "triangle", volume: 0.09 });
    playTone({ freq: midi(76), duration: 0.09, type: "triangle", volume: 0.09, at: nowPlus(0.08) });
    playTone({ freq: midi(79), duration: 0.14, type: "triangle", volume: 0.09, at: nowPlus(0.16) });
  },
  coin(): void {
    playTone({ freq: midi(88), duration: 0.06, type: "square", volume: 0.07 });
    playTone({ freq: midi(93), duration: 0.12, type: "square", volume: 0.07, at: nowPlus(0.06) });
  },
  levelUp(): void {
    [60, 64, 67, 72].forEach((note, i) =>
      playTone({ freq: midi(note), duration: 0.12, type: "square", volume: 0.09, at: nowPlus(i * 0.09) }),
    );
    playTone({ freq: midi(76), duration: 0.3, type: "square", volume: 0.09, at: nowPlus(0.36) });
  },
  victory(): void {
    [67, 67, 67, 72].forEach((note, i) =>
      playTone({ freq: midi(note), duration: i === 3 ? 0.4 : 0.1, type: "square", volume: 0.09, at: nowPlus(i * 0.12) }),
    );
  },
  defeat(): void {
    [58, 54, 49].forEach((note, i) =>
      playTone({ freq: midi(note), duration: 0.25, type: "sawtooth", volume: 0.07, at: nowPlus(i * 0.2) }),
    );
  },
  step(): void {
    playNoise({ duration: 0.025, volume: 0.02 });
  },
  door(): void {
    playTone({ freq: 90, duration: 0.12, type: "square", slideTo: 180, volume: 0.06 });
  },
  drop(): void {
    playTone({ freq: midi(84), duration: 0.07, type: "triangle", volume: 0.08 });
    playTone({ freq: midi(89), duration: 0.07, type: "triangle", volume: 0.08, at: nowPlus(0.07) });
    playTone({ freq: midi(96), duration: 0.16, type: "triangle", volume: 0.08, at: nowPlus(0.14) });
  },
};
