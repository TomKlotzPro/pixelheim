import { parseMap } from "../parseMap";
import type { WorldMap } from "../types";

/**
 * Dev-only proving ground for the tile engine (reach it with ?world).
 * A lake, some woods, a path loop, and a hut whose door exits the demo.
 */
export const DEMO_MAP: WorldMap = parseMap(
  "demo",
  `
  ^^^^^^^^^^^^^^^^^^^^^^
  ^....................^
  ^.~~~....ffff........^
  ^.~~~....ffff...###..^
  ^.~~~...........#D#..^
  ^................=...^
  ^....==========..=...^
  ^....=........=..=...^
  ^....=..S.....====...^
  ^....=........=......^
  ^....==========......^
  ^..ff............ff..^
  ^..ff............ff..^
  ^^^^^^^^^^^^^^^^^^^^^^
  `,
  [{ x: 17, y: 4, to: { kind: "exit" } }],
);

export const MAPS: Record<string, WorldMap> = {
  demo: DEMO_MAP,
};

export function getMap(id: string): WorldMap {
  const map = MAPS[id];
  if (!map) throw new Error(`Unknown map: ${id}`);
  return map;
}
