import { getMap } from "./maps";

/**
 * Door signs: the town's buildings say what they are, so nobody wanders the
 * village hunting for the forge. Keyed by the map a door leads into.
 */
export const DOOR_SIGNS: Record<string, string> = {
  town_shop: "GOODS",
  town_smith: "FORGE",
  town_alchemist: "BREWS",
  town_inn: "INN",
};

export type DoorSign = { x: number; y: number; label: string };

export function signsOn(mapId: string): DoorSign[] {
  return getMap(mapId).portals.flatMap((portal) =>
    portal.to.kind === "map" && DOOR_SIGNS[portal.to.mapId]
      ? [{ x: portal.x, y: portal.y, label: DOOR_SIGNS[portal.to.mapId] }]
      : [],
  );
}
