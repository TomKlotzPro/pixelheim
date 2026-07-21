import type { TileId, WorldMap, WorldState } from "./types";

/** One color per tile for map paintings; sprites are for the world itself. */
const TILE_COLORS: Partial<Record<TileId, string>> = {
  grass: "#3d7a35",
  forest: "#2a5f24",
  mountain: "#6b6f7a",
  water: "#2a4f8f",
  path: "#b89a6a",
  sand: "#d8c48a",
  bridge: "#8a6238",
  marsh: "#44603c",
  ash: "#66605a",
  wall: "#4a4e58",
  floor: "#9a713d",
  door: "#e8c34a",
  door_shut: "#8a6238",
  cave: "#16181e",
  shrine: "#4ae6c8",
  flowers: "#3d7a35",
  crops: "#c9a648",
  trophy_shelf: "#7a5230",
  garden: "#4a3524",
  lamp: "#3d7a35",
  well: "#8a8f9a",
};
const ROOF_COLOR = "#8a5638";
const FOG_COLOR = "#0b0c10";

export function tileColor(tile: TileId): string {
  return TILE_COLORS[tile] ?? (tile.startsWith("roof") ? ROOF_COLOR : "#4a4e58");
}

/**
 * Paints a map onto a 2D canvas at `tilePx` per tile, fog over anything the
 * hero has not seen. Shared by the map screen and the corner mini-map.
 */
export function paintMap(
  ctx: CanvasRenderingContext2D,
  map: WorldMap,
  discovered: WorldState["discovered"],
  tilePx: number,
): void {
  const seen = new Set(discovered[map.id] ?? []);
  for (let y = 0; y < map.height; y++) {
    for (let x = 0; x < map.width; x++) {
      ctx.fillStyle = seen.has(`${x},${y}`) ? tileColor(map.tiles[y][x]) : FOG_COLOR;
      ctx.fillRect(x * tilePx, y * tilePx, tilePx, tilePx);
    }
  }
}
