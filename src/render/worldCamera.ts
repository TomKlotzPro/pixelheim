import type { GameState } from "../game/types";
import type { WorldMap, WorldPosition } from "../world/types";

/**
 * The one camera all three world renderers share (PIX-115). Before this
 * module, VIEW_W/H, the clamped camera and the outdoor-map set lived as three
 * hand-synced copies in the Pixi renderer, the voxel renderer and
 * WorldScreen - a viewport change meant three edits or a subtle drift.
 */
export const VIEW_W = 21;
export const VIEW_H = 13;

/** Maps under the open sky; interiors stay lit, weatherless and ember-free. */
export const OUTDOOR_MAPS = new Set(["overworld", "town", "demo", "deepwood", "mirefen"]);

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** The camera: center small maps, clamp large ones. */
export function cameraFor(map: WorldMap, pos: WorldPosition): { x: number; y: number } {
  const x =
    map.width <= VIEW_W
      ? -Math.floor((VIEW_W - map.width) / 2)
      : clamp(pos.x - Math.floor(VIEW_W / 2), 0, map.width - VIEW_W);
  const y =
    map.height <= VIEW_H
      ? -Math.floor((VIEW_H - map.height) / 2)
      : clamp(pos.y - Math.floor(VIEW_H / 2), 0, map.height - VIEW_H);
  return { x, y };
}

/**
 * The world-renderer contract every canvas renderer implements, so the two
 * classes cannot drift apart silently (they duck-typed it before PIX-115).
 */
export interface WorldRenderer {
  init(host: HTMLElement, scale: number): Promise<void>;
  update(state: GameState): void;
  destroy(): void;
}
