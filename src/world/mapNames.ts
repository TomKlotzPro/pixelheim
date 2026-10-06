/** The friendly names of the maps worth charting. */
export const MAP_NAMES: Record<string, string> = {
  overworld: "The Ashenreach",
  town: "Pixelheim",
  deepwood: "The Deepwood",
  mirefen: "The Mirefen",
  demo: "The Proving Grounds",
};

/** The chart shows where you STAND (PIX-114 fallout: it always painted the
 *  overworld, so opening it in town showed a wall of fog - "broken" to any
 *  fresh save). Interiors chart their parent town; anywhere else, the world. */
export function chartedMapId(mapId: string): string {
  if (MAP_NAMES[mapId]) return mapId;
  return mapId.startsWith("town") ? "town" : "overworld";
}
