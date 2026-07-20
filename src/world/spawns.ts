import { WILD_TILES } from "../state/shared";
import { getMap } from "./maps/index";
import { isWalkable, portalAt, regionAt } from "./parseMap";
import type { RegionId, WorldMap } from "./types";

/**
 * Visible monsters: hand-placed spawn points on wild ground. What lives there
 * comes from the tile's region table, picked deterministically per spawn -
 * the beast you see is the beast you fight. Bump into it to start the fight;
 * a slain spawn stays clear until you leave the map and return.
 */
export type MonsterSpawn = {
  id: string;
  mapId: string;
  x: number;
  y: number;
};

export const SPAWNS: MonsterSpawn[] = [
  // the Ashenreach: ash fields up north
  { id: "ash_1", mapId: "overworld", x: 36, y: 8 },
  { id: "ash_2", mapId: "overworld", x: 14, y: 16 },
  { id: "ash_3", mapId: "overworld", x: 58, y: 18 },
  { id: "ash_4", mapId: "overworld", x: 92, y: 26 },
  // the eastern forest
  { id: "forest_1", mapId: "overworld", x: 62, y: 34 },
  { id: "forest_2", mapId: "overworld", x: 82, y: 42 },
  { id: "forest_3", mapId: "overworld", x: 72, y: 52 },
  // the western marsh
  { id: "marsh_1", mapId: "overworld", x: 2, y: 34 },
  { id: "marsh_2", mapId: "overworld", x: 22, y: 42 },
  { id: "marsh_3", mapId: "overworld", x: 12, y: 52 },
  // the Deepwood
  { id: "deep_1", mapId: "deepwood", x: 2, y: 16 },
  { id: "deep_2", mapId: "deepwood", x: 14, y: 22 },
  { id: "deep_3", mapId: "deepwood", x: 6, y: 30 },
  { id: "deep_4", mapId: "deepwood", x: 56, y: 44 },
  // the Mirefen
  { id: "mire_1", mapId: "mirefen", x: 4, y: 16 },
  { id: "mire_2", mapId: "mirefen", x: 42, y: 22 },
  { id: "mire_3", mapId: "mirefen", x: 48, y: 30 },
  { id: "mire_4", mapId: "mirefen", x: 56, y: 44 },
];

// Loud failure at load, like every other piece of map data: a spawn must sit
// on walkable wild ground inside an encounter region, clear of portals.
for (const spawn of SPAWNS) {
  const map = getMap(spawn.mapId);
  const tile = map.tiles[spawn.y]?.[spawn.x];
  if (!tile || !isWalkable(map, spawn.x, spawn.y) || !WILD_TILES.has(tile)) {
    throw new Error(`Spawn "${spawn.id}" is not on walkable wild ground at ${spawn.x},${spawn.y}`);
  }
  if (regionAt(map, spawn.x, spawn.y) === null) {
    throw new Error(`Spawn "${spawn.id}" sits outside every encounter region`);
  }
  if (portalAt(map, spawn.x, spawn.y)) {
    throw new Error(`Spawn "${spawn.id}" sits on a portal`);
  }
}

/** The same pacing trick the NPCs use: a small deterministic wander loop. */
const LOOP: [number, number][] = [
  [0, 0],
  [1, 0],
  [1, 1],
  [0, 1],
];

function hash(id: string): number {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) % 997;
  return h;
}

const validOffsets = new Map<string, [number, number][]>();
for (const spawn of SPAWNS) {
  const map = getMap(spawn.mapId);
  const offsets = LOOP.filter(([dx, dy]) => {
    const x = spawn.x + dx;
    const y = spawn.y + dy;
    const tile = map.tiles[y]?.[x];
    return (
      tile && isWalkable(map, x, y) && WILD_TILES.has(tile) && !portalAt(map, x, y) && regionAt(map, x, y) !== null
    );
  });
  validOffsets.set(spawn.id, offsets.length > 0 ? offsets : [[0, 0]]);
}

export function spawnsOn(mapId: string): MonsterSpawn[] {
  return SPAWNS.filter((s) => s.mapId === mapId);
}

/** Where the spawn's beast prowls right now, given the player's step count. */
export function spawnPosition(spawn: MonsterSpawn, steps: number): { x: number; y: number } {
  const offsets = validOffsets.get(spawn.id)!;
  const [dx, dy] = offsets[Math.floor((steps + hash(spawn.id)) / 3) % offsets.length];
  return { x: spawn.x + dx, y: spawn.y + dy };
}

export function spawnRegion(spawn: MonsterSpawn): RegionId {
  return regionAt(getMap(spawn.mapId), spawn.x, spawn.y)!;
}

/** The living spawn standing on a tile, if any. */
export function monsterSpawnAt(
  map: WorldMap,
  x: number,
  y: number,
  steps: number,
  slain: string[],
): MonsterSpawn | null {
  return (
    spawnsOn(map.id).find((spawn) => {
      if (slain.includes(spawn.id)) return false;
      const at = spawnPosition(spawn, steps);
      return at.x === x && at.y === y;
    }) ?? null
  );
}
