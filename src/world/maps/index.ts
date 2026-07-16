import { isWalkable } from "../parseMap";
import type { WorldMap } from "../types";
import {
  OVERWORLD_MAP,
  TOWN_ALCHEMIST_MAP,
  TOWN_INN_MAP,
  TOWN_MAP,
  TOWN_SHOP_MAP,
  TOWN_SMITH_MAP,
} from "./ashenreach";
import { DEMO_HUT_MAP, DEMO_MAP } from "./demo";

export const MAPS: Record<string, WorldMap> = {
  [OVERWORLD_MAP.id]: OVERWORLD_MAP,
  [TOWN_MAP.id]: TOWN_MAP,
  [TOWN_SHOP_MAP.id]: TOWN_SHOP_MAP,
  [TOWN_INN_MAP.id]: TOWN_INN_MAP,
  [TOWN_SMITH_MAP.id]: TOWN_SMITH_MAP,
  [TOWN_ALCHEMIST_MAP.id]: TOWN_ALCHEMIST_MAP,
  [DEMO_MAP.id]: DEMO_MAP,
  [DEMO_HUT_MAP.id]: DEMO_HUT_MAP,
};

// Cross-map validation: every portal target must exist and be standable.
// Runs at module load, so a broken link fails the test suite immediately.
for (const map of Object.values(MAPS)) {
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

export function getMap(id: string): WorldMap {
  const map = MAPS[id];
  if (!map) throw new Error(`Unknown map: ${id}`);
  return map;
}
