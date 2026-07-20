import { getMap } from "./maps/index";

/**
 * Door signs: the town's buildings say what they are, so nobody wanders the
 * village hunting for the forge. Keyed by the map a door leads into.
 */
export const DOOR_SIGNS: Record<string, { label: string; icon?: string }> = {
  town_shop: { label: "GOODS" },
  town_smith: { label: "FORGE", icon: "icon_anvil" },
  town_alchemist: { label: "BREWS", icon: "icon_cauldron" },
  town_inn: { label: "INN" },
  town_hall: { label: "HALL" },
};

export type DoorSign = { x: number; y: number; label: string; icon?: string };

export function signsOn(mapId: string, houseOwned = false): DoorSign[] {
  const signs = getMap(mapId).portals.flatMap((portal) =>
    portal.to.kind === "map" && DOOR_SIGNS[portal.to.mapId]
      ? [{ x: portal.x, y: portal.y, ...DOOR_SIGNS[portal.to.mapId] }]
      : [],
  );
  // The buyable house has no portal until owned; its sign lives here.
  if (mapId === "town") signs.push({ x: 60, y: 26, label: houseOwned ? "HOME" : "FOR SALE" });
  return signs;
}
