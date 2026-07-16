export type Direction = "up" | "down" | "left" | "right";

export type TileId = "grass" | "forest" | "mountain" | "water" | "path" | "wall" | "door";

export type TileDef = {
  id: TileId;
  sprite: string;
  walkable: boolean;
};

export type PortalTarget = { kind: "exit" } | { kind: "map"; mapId: string; x: number; y: number };

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
};

/** The hero's position in the world, stored in GameState. */
export type WorldPosition = {
  mapId: string;
  x: number;
  y: number;
  facing: Direction;
};
