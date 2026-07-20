import { isWalkable } from "../parseMap";
import type { WorldMap } from "../types";
import {
  OVERWORLD_MAP,
  TOWN_ALCHEMIST_MAP,
  TOWN_HALL_MAP,
  TOWN_HOUSE_MAP,
  TOWN_INN_MAP,
  TOWN_MAP,
  TOWN_MAPS,
  TOWN_SHOP_MAP,
  TOWN_SMITH_MAP,
} from "./ashenreach";
import { DEMO_HUT_MAP, DEMO_MAP } from "./demo";
import { DEEPWOOD_MAP, MIREFEN_MAP } from "./frontier";

export const MAPS: Record<string, WorldMap> = {
  [OVERWORLD_MAP.id]: OVERWORLD_MAP,
  [DEEPWOOD_MAP.id]: DEEPWOOD_MAP,
  [MIREFEN_MAP.id]: MIREFEN_MAP,
  [TOWN_MAP.id]: TOWN_MAP,
  [TOWN_SHOP_MAP.id]: TOWN_SHOP_MAP,
  [TOWN_INN_MAP.id]: TOWN_INN_MAP,
  [TOWN_SMITH_MAP.id]: TOWN_SMITH_MAP,
  [TOWN_ALCHEMIST_MAP.id]: TOWN_ALCHEMIST_MAP,
  [TOWN_HOUSE_MAP.id]: TOWN_HOUSE_MAP,
  [TOWN_HALL_MAP.id]: TOWN_HALL_MAP,
  [DEMO_MAP.id]: DEMO_MAP,
  [DEMO_HUT_MAP.id]: DEMO_HUT_MAP,
};

// Cross-map validation: every portal target must exist and be standable.
// Runs at module load, so a broken link fails the test suite immediately.
// Every town tier is validated: a tier redraw must never strand a portal.
for (const map of [...Object.values(MAPS), ...TOWN_MAPS]) {
  for (const portal of map.portals) {
    if (portal.to.kind !== "map") continue;
    const target = MAPS[portal.to.mapId];
    if (!target) {
      throw new Error(`Map "${map.id}" portal at ${portal.x},${portal.y} targets unknown map "${portal.to.mapId}"`);
    }
    if (!isWalkable(target, portal.to.x, portal.to.y)) {
      throw new Error(
        `Map "${map.id}" portal at ${portal.x},${portal.y} lands on unwalkable ${portal.to.x},${portal.to.y} in "${portal.to.mapId}"`,
      );
    }
  }
}

/**
 * The town-tier mirror (PIX-91). Every consumer of `getMap` passes only a map
 * id, so the current tier lives here as a module mirror, set from a store
 * subscription (see state/store.ts) - the same pattern as persistSave. Pure
 * unit tests that never touch the store see tier 1, the founding Hamlet.
 */
let townTier = 1;

export function setTownTier(tier: number): void {
  townTier = Math.min(TOWN_MAPS.length, Math.max(1, Math.floor(tier)));
}

export function getTownTier(): number {
  return townTier;
}

/** The settlers mirror (PIX-92): same contract as the tier mirror above. */
let settlers: string[] = [];

export function setSettlers(ids: string[]): void {
  settlers = ids;
}

export function getSettlers(): string[] {
  return settlers;
}

export function getMap(id: string): WorldMap {
  if (id === "town") return TOWN_MAPS[townTier - 1];
  const map = MAPS[id];
  if (!map) throw new Error(`Unknown map: ${id}`);
  return map;
}
