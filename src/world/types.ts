export type Direction = "up" | "down" | "left" | "right";

/** Every encounter region in the game; maps may only reference these. */
export const REGION_IDS = ["forest", "marsh", "ash", "deepwood", "mire"] as const;
export type RegionId = (typeof REGION_IDS)[number];

export type TileId =
  | "grass"
  | "forest"
  | "mountain"
  | "water"
  | "path"
  | "sand"
  | "bridge"
  | "marsh"
  | "ash"
  | "wall"
  | "floor"
  | "roof"
  | "roof_slate"
  | "roof_thatch"
  | "roof_awning"
  | "roof_moss"
  | "sign_goods"
  | "sign_smith"
  | "sign_potion"
  | "sign_inn"
  | "fence"
  | "flowers"
  | "barrel"
  | "crate"
  | "well"
  | "lamp"
  | "anvil"
  | "forge"
  | "shelf"
  | "cauldron"
  | "counter"
  | "bed"
  | "hearth"
  | "door"
  | "door_shut"
  | "cave"
  | "shrine";

export type TileDef = {
  id: TileId;
  sprite: string;
  walkable: boolean;
};

export type DungeonId = "mountain" | "undermountain";

export type PortalTarget =
  { kind: "exit" } | { kind: "map"; mapId: string; x: number; y: number } | { kind: "dungeon"; dungeon: DungeonId };

export type Portal = {
  x: number;
  y: number;
  to: PortalTarget;
};

export type WorldMap = {
  id: string;
  width: number;
  height: number;
  /** tiles[y][x] */
  tiles: TileId[][];
  spawn: { x: number; y: number };
  portals: Portal[];
  /** Per-tile encounter region id (regions[y][x]), null where nothing lurks. */
  regions: (RegionId | null)[][] | null;
};

/** The hero's position in the world. */
export type WorldPosition = {
  mapId: string;
  x: number;
  y: number;
  facing: Direction;
};

/**
 * Everything the world remembers about the hero, stored in GameState and
 * persisted in saves (SAVE_VERSION 3+). Exploration survives leaving the
 * world screen; only `position` changes as the hero walks.
 */
export type WorldState = {
  position: WorldPosition;
  /** Seen tiles per map, as "x,y" keys. Feeds the fog-of-war map screen. */
  discovered: Record<string, string[]>;
  /** Opened chest ids, once chests exist. */
  openedChests: string[];
  /** Spawn ids cleared on the CURRENT map; resets when the map changes. */
  slain: string[];
};
