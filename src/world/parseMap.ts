import { TILES } from "./tiles";
import type { Portal, TileId, WorldMap } from "./types";

/** Characters shared by every map. `S` marks the spawn (on grass, `$` on floor). */
const CHAR_TILES: Record<string, TileId> = {
  ".": "grass",
  S: "grass",
  f: "forest",
  "^": "mountain",
  "~": "water",
  "=": "path",
  s: "sand",
  b: "bridge",
  "#": "wall",
  _: "floor",
  $: "floor",
  r: "roof",
  D: "door",
  C: "cave",
  W: "shrine",
};

const SPAWN_CHARS = ["S", "$"];
/** Tiles that transport the hero; each occurrence must have a portal defined. */
const PORTAL_CHARS = ["D", "C"];

/**
 * Parses an ASCII grid into a WorldMap and validates it. Door characters must
 * each have a matching portal definition. Throws with a precise message on any
 * inconsistency; maps are static data, so this runs once at module load and a
 * bad map fails the build's smoke tests immediately.
 */
export function parseMap(id: string, ascii: string, portals: Portal[]): WorldMap {
  const rows = ascii
    .split("\n")
    .map((row) => row.trim())
    .filter((row) => row.length > 0);
  if (rows.length === 0) throw new Error(`Map "${id}" is empty`);

  const width = rows[0].length;
  let spawn: { x: number; y: number } | null = null;
  const doors: { x: number; y: number }[] = [];

  const tiles = rows.map((row, y) => {
    if (row.length !== width) {
      throw new Error(`Map "${id}" row ${y} has width ${row.length}, expected ${width}`);
    }
    return [...row].map((char, x) => {
      const tile = CHAR_TILES[char];
      if (!tile) throw new Error(`Map "${id}" has unknown tile "${char}" at ${x},${y}`);
      if (SPAWN_CHARS.includes(char)) {
        if (spawn) throw new Error(`Map "${id}" has more than one spawn`);
        spawn = { x, y };
      }
      if (PORTAL_CHARS.includes(char)) doors.push({ x, y });
      return tile;
    });
  });

  if (!spawn) throw new Error(`Map "${id}" has no spawn (S or $)`);
  for (const door of doors) {
    if (!portals.some((p) => p.x === door.x && p.y === door.y)) {
      throw new Error(`Map "${id}" door/cave at ${door.x},${door.y} has no portal`);
    }
  }
  for (const portal of portals) {
    if (!doors.some((d) => d.x === portal.x && d.y === portal.y)) {
      throw new Error(`Map "${id}" portal at ${portal.x},${portal.y} is not on a door or cave tile`);
    }
  }

  return { id, width, height: rows.length, tiles, spawn, portals };
}

export function tileAt(map: WorldMap, x: number, y: number): TileId | null {
  if (x < 0 || y < 0 || x >= map.width || y >= map.height) return null;
  return map.tiles[y][x];
}

export function isWalkable(map: WorldMap, x: number, y: number): boolean {
  const tile = tileAt(map, x, y);
  return tile !== null && TILES[tile].walkable;
}

export function portalAt(map: WorldMap, x: number, y: number): Portal | null {
  return map.portals.find((p) => p.x === x && p.y === y) ?? null;
}
