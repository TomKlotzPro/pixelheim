import { parseMap } from "../parseMap";
import type { WorldMap } from "../types";

/**
 * Dev-only proving ground for the tile engine (reach it with ?world).
 * A lake with a sandy shore, woods, a path loop, a shrine, and a hut
 * you can actually walk into.
 */
export const DEMO_MAP: WorldMap = parseMap(
  "demo",
  `
  ^^^^^^^^^^^^^^^^^^^^^^
  ^....................^
  ^.~~~....ffff........^
  ^.~~~....ffff...###..^
  ^.~~~...........#D#..^
  ^.sss............=...^
  ^....==========..=...^
  ^....=........=..=...^
  ^....=..S.....====...^
  ^....=........=......^
  ^....==========......^
  ^..ff....W.......ff..^
  ^..ff............ff..^
  ^^^^^^^^^^^^^^^^^^^^^^
  `,
  [{ x: 17, y: 4, to: { kind: "map", mapId: "demo_hut", x: 3, y: 3 } }],
);

export const DEMO_HUT_MAP: WorldMap = parseMap(
  "demo_hut",
  `
  ########
  #______#
  #______#
  #__$___#
  ###D####
  `,
  [{ x: 3, y: 4, to: { kind: "map", mapId: "demo", x: 17, y: 5 } }],
);
