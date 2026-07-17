import { getItem } from "../game/economy/items";
import { getMap } from "./maps/index";
import { isWalkable, portalAt, regionAt } from "./parseMap";
import { SPAWNS } from "./spawns";
import type { RegionId } from "./types";

/**
 * Exploration pays: hand-placed treasure on the maps. A "chest" is solid
 * furniture you face and open; a "glint" or "herb" is ground treasure taken
 * in stride. Opened ids persist in world.openedChests (v3 save shape), so a
 * chest gives exactly once per save. One chest in the Mirefen is a mimic.
 */
export type ChestLoot =
  | { kind: "gold"; amount: number }
  | { kind: "item"; itemId: string; qty: number }
  | { kind: "gear"; itemId: string };

export type Chest = {
  id: string;
  mapId: string;
  x: number;
  y: number;
  /** chest = solid, interact to open; glint/herb = walk over to take. */
  look: "chest" | "glint" | "herb";
  /** Absent only on the mimic: its fight is the payout. */
  loot?: ChestLoot;
  mimic?: boolean;
};

export const CHESTS: Chest[] = [
  // Pixelheim village: two starter finds for players who poke around
  { id: "town_corner", mapId: "town", x: 1, y: 16, look: "chest", loot: { kind: "item", itemId: "potion_hp", qty: 2 } },
  { id: "town_nook", mapId: "town", x: 31, y: 9, look: "chest", loot: { kind: "gold", amount: 60 } },
  // the Ashenreach corners: gear a tier ahead of the road there
  { id: "ash_west", mapId: "overworld", x: 2, y: 6, look: "chest", loot: { kind: "gear", itemId: "iron_sword" } },
  { id: "ash_east", mapId: "overworld", x: 46, y: 7, look: "chest", loot: { kind: "gear", itemId: "iron_armor" } },
  { id: "forest_corner", mapId: "overworld", x: 46, y: 30, look: "chest", loot: { kind: "gear", itemId: "steel_shield" } },
  { id: "marsh_corner", mapId: "overworld", x: 1, y: 30, look: "chest", loot: { kind: "gear", itemId: "apprentice_staff" } },
  // ground treasure on the south road belly
  { id: "road_glint", mapId: "overworld", x: 20, y: 29, look: "glint", loot: { kind: "gold", amount: 45 } },
  { id: "herb_patch", mapId: "overworld", x: 28, y: 29, look: "herb", loot: { kind: "item", itemId: "forest_herb", qty: 3 } },
  // the frontier: the best finds hide deepest
  { id: "deep_courtyard", mapId: "deepwood", x: 17, y: 18, look: "chest", loot: { kind: "gear", itemId: "steel_axe" } },
  { id: "deep_corner", mapId: "deepwood", x: 28, y: 1, look: "chest", loot: { kind: "gear", itemId: "shadow_cloak" } },
  { id: "mire_maze", mapId: "mirefen", x: 11, y: 17, look: "chest", loot: { kind: "gear", itemId: "obsidian_blade" } },
  { id: "mire_mimic", mapId: "mirefen", x: 21, y: 6, look: "chest", mimic: true },
];

// Loud failure at load, like spawns and portals: bad treasure data must not
// ship. A chest needs a real walkable tile, clear of portals and of monster
// wander areas; a mimic must sit in an encounter region to build its fight.
const seen = new Set<string>();
for (const chest of CHESTS) {
  if (seen.has(chest.id)) throw new Error(`Chest id "${chest.id}" is duplicated`);
  seen.add(chest.id);
  const map = getMap(chest.mapId);
  if (!isWalkable(map, chest.x, chest.y)) {
    throw new Error(`Chest "${chest.id}" is not on walkable ground at ${chest.x},${chest.y}`);
  }
  if (portalAt(map, chest.x, chest.y)) throw new Error(`Chest "${chest.id}" sits on a portal`);
  const nearSpawn = SPAWNS.some(
    (s) => s.mapId === chest.mapId && chest.x >= s.x && chest.x <= s.x + 1 && chest.y >= s.y && chest.y <= s.y + 1,
  );
  if (nearSpawn) throw new Error(`Chest "${chest.id}" overlaps a monster spawn's wander area`);
  if (chest.mimic && regionAt(map, chest.x, chest.y) === null) {
    throw new Error(`Mimic chest "${chest.id}" sits outside every encounter region`);
  }
  if (!chest.mimic) {
    if (!chest.loot) throw new Error(`Chest "${chest.id}" has no loot`);
    if (chest.loot.kind !== "gold") getItem(chest.loot.itemId); // throws on unknown items
  }
}

export function chestsOn(mapId: string): Chest[] {
  return CHESTS.filter((c) => c.mapId === mapId);
}

export function chestAt(mapId: string, x: number, y: number): Chest | null {
  return CHESTS.find((c) => c.mapId === mapId && c.x === x && c.y === y) ?? null;
}

/** Chests are furniture and block the tile; ground treasure never does. */
export function solidChestAt(mapId: string, x: number, y: number): Chest | null {
  const chest = chestAt(mapId, x, y);
  return chest && chest.look === "chest" ? chest : null;
}

export function chestRegion(chest: Chest): RegionId | null {
  return regionAt(getMap(chest.mapId), chest.x, chest.y);
}

/** What to draw for this treasure right now; null means nothing is left. */
export function chestSpriteName(chest: Chest, opened: boolean): string | null {
  if (chest.look === "chest") return opened ? "chest_open" : "chest_closed";
  if (opened) return null;
  return chest.look === "glint" ? "road_glint" : "herb_patch";
}
