import { TILES } from "./tiles";
import { REGION_IDS, type Portal, type RegionId, type TileId, type WorldMap } from "./types";

/** Characters shared by every map. Spawn chars: `S` grass, `$` floor, `*` path. */
const CHAR_TILES: Record<string, TileId> = {
  ".": "grass",
  S: "grass",
  f: "forest",
  "^": "mountain",
  "~": "water",
  "=": "path",
  "*": "path",
  s: "sand",
  b: "bridge",
  w: "marsh",
  a: "ash",
  k: "crops",
  "#": "wall",
  _: "floor",
  $: "floor",
  r: "roof",
  "1": "roof_slate",
  "2": "roof_thatch",
  "3": "roof_awning",
  "4": "roof_moss",
  h: "sign_smith",
  m: "sign_inn",
  p: "sign_potion",
  g: "sign_goods",
  F: "fence",
  x: "flowers",
  o: "barrel",
  c: "crate",
  O: "well",
  L: "lamp",
  A: "anvil",
  e: "forge",
  t: "shelf",
  u: "cauldron",
  n: "counter",
  B: "bed",
  H: "hearth",
  D: "door",
  d: "door_shut",
  C: "cave",
  W: "shrine",
};

const SPAWN_CHARS = new Set(["S", "$", "*"]);
/** Tiles that transport the hero; each occurrence must have a portal defined. */
const PORTAL_CHARS = new Set(["D", "C"]);

/**
 * Parses an ASCII grid into a WorldMap and validates it. Door characters must
 * each have a matching portal definition. Throws with a precise message on any
 * inconsistency; maps are static data, so this runs once at module load and a
 * bad map fails the build's smoke tests immediately.
 */
export type RegionSpec = {
  /** Same dimensions as the tile grid; `-` means no region. */
  grid: string;
  /** Maps region grid chars to region ids used by encounter tables. */
  legend: Record<string, RegionId>;
};

function trimGrid(ascii: string): string[] {
  return ascii
    .split("\n")
    .map((row) => row.trim())
    .filter((row) => row.length > 0);
}

export function parseMap(id: string, ascii: string, portals: Portal[], regionSpec?: RegionSpec): WorldMap {
  const rows = trimGrid(ascii);
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
      if (SPAWN_CHARS.has(char)) {
        if (spawn) throw new Error(`Map "${id}" has more than one spawn`);
        spawn = { x, y };
      }
      if (PORTAL_CHARS.has(char)) doors.push({ x, y });
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

  let regions: (RegionId | null)[][] | null = null;
  if (regionSpec) {
    const regionRows = trimGrid(regionSpec.grid);
    if (regionRows.length !== rows.length) {
      throw new Error(`Map "${id}" region grid has ${regionRows.length} rows, expected ${rows.length}`);
    }
    regions = regionRows.map((row, y) => {
      if (row.length !== width) {
        throw new Error(`Map "${id}" region row ${y} has width ${row.length}, expected ${width}`);
      }
      return [...row].map((char, x) => {
        if (char === "-") return null;
        const region = regionSpec.legend[char];
        if (!region) throw new Error(`Map "${id}" has unknown region "${char}" at ${x},${y}`);
        if (!REGION_IDS.includes(region)) {
          throw new Error(`Map "${id}" legend maps "${char}" to unknown region id "${region}"`);
        }
        return region;
      });
    });
  }

  return { id, width, height: rows.length, tiles, spawn, portals, regions };
}

export function regionAt(map: WorldMap, x: number, y: number): RegionId | null {
  return map.regions?.[y]?.[x] ?? null;
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
