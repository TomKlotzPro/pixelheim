import type { TileDef, TileId } from "./types";

export const TILES: Record<TileId, TileDef> = {
  grass: { id: "grass", sprite: "tile_grass", walkable: true },
  forest: { id: "forest", sprite: "tile_forest", walkable: true },
  mountain: { id: "mountain", sprite: "tile_mountain", walkable: false },
  water: { id: "water", sprite: "tile_water", walkable: false },
  path: { id: "path", sprite: "tile_path", walkable: true },
  wall: { id: "wall", sprite: "tile_wall", walkable: false },
  door: { id: "door", sprite: "tile_door", walkable: true },
};
