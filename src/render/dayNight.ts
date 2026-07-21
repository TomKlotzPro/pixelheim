/**
 * The day/night wheel, turned by worldSteps (deterministic, saved) - one
 * clock for every renderer (PIX-115). Before this module the stops table and
 * interpolation lived as two byte-identical copies in the Pixi and voxel
 * atmospheres, kept in lockstep by hand.
 */
export const DAY_CYCLE_STEPS = 480;

const SKY_STOPS: { at: number; color: [number, number, number, number] }[] = [
  { at: 0.0, color: [0, 0, 0, 0] }, // day
  { at: 0.45, color: [0, 0, 0, 0] },
  { at: 0.55, color: [255, 122, 50, 0.13] }, // dusk
  { at: 0.65, color: [10, 16, 48, 0.36] }, // night
  { at: 0.85, color: [10, 16, 48, 0.36] },
  { at: 0.93, color: [255, 190, 110, 0.1] }, // dawn
  { at: 1.0, color: [0, 0, 0, 0] },
];

/** The sky tint right now: 0-255 rgb plus overlay alpha. Renderers map it to
 *  their own color type (packed int for Pixi, Color for three.js). */
export function skyAt(steps: number): { r: number; g: number; b: number; alpha: number } {
  const t = (steps % DAY_CYCLE_STEPS) / DAY_CYCLE_STEPS;
  let i = 0;
  while (i < SKY_STOPS.length - 2 && SKY_STOPS[i + 1].at < t) i++;
  const a = SKY_STOPS[i];
  const b = SKY_STOPS[i + 1];
  const k = (t - a.at) / (b.at - a.at || 1);
  const mix = a.color.map((v, c) => v + (b.color[c] - v) * k);
  return { r: mix[0], g: mix[1], b: mix[2], alpha: mix[3] };
}

/** Ember weather shared by both canvas atmospheres. */
export const EMBER_CAP = 36;
export const EMBER_TINT_INTS = [0xffa03c, 0xff7a28, 0xffc86e];
