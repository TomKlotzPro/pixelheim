import type { TileDef, TileId } from "./types";

export const TILES: Record<TileId, TileDef> = {
  grass: { id: "grass", sprite: "tile_grass", walkable: true },
  forest: { id: "forest", sprite: "tile_forest", walkable: true },
  mountain: { id: "mountain", sprite: "tile_mountain", walkable: false },
  water: { id: "water", sprite: "tile_water", walkable: false },
  path: { id: "path", sprite: "tile_path", walkable: true },
  sand: { id: "sand", sprite: "tile_sand", walkable: true },
  bridge: { id: "bridge", sprite: "tile_bridge", walkable: true },
  marsh: { id: "marsh", sprite: "tile_marsh", walkable: true },
  ash: { id: "ash", sprite: "tile_ash", walkable: true },
  wall: { id: "wall", sprite: "tile_wall", walkable: false },
  floor: { id: "floor", sprite: "tile_floor", walkable: true },
  roof: { id: "roof", sprite: "tile_roof", walkable: false },
  door: { id: "door", sprite: "tile_door", walkable: true },
  cave: { id: "cave", sprite: "tile_cave", walkable: true },
  shrine: { id: "shrine", sprite: "tile_shrine", walkable: true },
};
