import { SHOP_MAPS } from "../game/economy/shop";
import type { GameState } from "../game/types";
import type { Direction, TileId } from "../world/types";

export const REST_COST = 10;

export const initialState: GameState = {
  screen: "title",
  hero: null,
  gold: 0,
  inventory: {},
  gear: [],
  equipped: {},
  unlockedLevel: 1,
  clearedLevels: [],
  battle: null,
  inventoryOpen: false,
  shopOpen: false,
  storageOpen: false,
  house: { owned: false, storage: {} },
  properties: [],
  quests: {},
  world: null,
  dungeonSelect: null,
  introSeen: true,
  worldMessage: null,
  worldSteps: 0,
  dialogue: null,
};

/** The player house: the shut door in town, and what the deed costs. */
export const HOUSE_DOOR = { mapId: "town", x: 60, y: 26 };
export const HOUSE_DEED_COST = 1500;
/** Fitting a workbench + small cauldron into the house shelf (PIX-109). */
export const WORKBENCH_COST = 800;

/** Business deeds: buy the shop you stand in from its keeper. */
export const PROPERTY_PRICES: Record<string, { name: string; cost: number }> = {
  town_shop: { name: "Odo's Emporium", cost: 2500 },
  town_smith: { name: "Hilda's Smithy", cost: 4000 },
  town_alchemist: { name: "Vex's Workshop", cost: 3500 },
};
/** Gold each owned business pays after every victory. */
export const RENT_PER_VICTORY = 2;

/** Where heroes wake up: the middle of Pixelheim village. */
export const TOWN_SPAWN = { mapId: "town", x: 28, y: 30, facing: "down" as const };
/** The inn interior: entering it rests the hero for coin. */
export const INN_MAP_ID = "town_inn";

/** Where a defeated hero comes to: a bed at the village inn. */
export const INN_REST = { mapId: "town", x: 12, y: 5, facing: "down" as const };

export const DIRECTION_DELTAS: Record<Direction, { dx: number; dy: number }> = {
  up: { dx: 0, dy: -1 },
  down: { dx: 0, dy: 1 },
  left: { dx: -1, dy: 0 },
  right: { dx: 1, dy: 0 },
};

/** Terrain that can hide monsters; paths, bridges and buildings are safe. */
export const WILD_TILES = new Set<TileId>(["grass", "forest", "marsh", "ash", "sand"]);

/** The shop whose building the hero is standing in, if any. */
export function activeShopId(state: GameState) {
  return state.world ? (SHOP_MAPS[state.world.position.mapId] ?? null) : null;
}
