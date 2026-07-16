import type { WorldMap } from "./types";
import type { WorldState } from "./types";

/** How far the hero sees around themselves, in tiles (Chebyshev distance). */
const SIGHT_RADIUS = 2;

/**
 * Marks the tiles around the given position as discovered. Returns the same
 * `discovered` object when nothing new was seen so reducers can cheaply reuse
 * state.
 */
export function discoverAround(
  discovered: WorldState["discovered"],
  map: WorldMap,
  x: number,
  y: number,
): WorldState["discovered"] {
  const seen = new Set(discovered[map.id] ?? []);
  const before = seen.size;
  for (let dy = -SIGHT_RADIUS; dy <= SIGHT_RADIUS; dy++) {
    for (let dx = -SIGHT_RADIUS; dx <= SIGHT_RADIUS; dx++) {
      const tx = x + dx;
      const ty = y + dy;
      if (tx < 0 || ty < 0 || tx >= map.width || ty >= map.height) continue;
      seen.add(`${tx},${ty}`);
    }
  }
  if (seen.size === before) return discovered;
  return { ...discovered, [map.id]: [...seen] };
}
