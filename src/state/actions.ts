import type { EquippedSlot, GameState, RoleId, SpendableStat } from "../game/types";
import type { Direction } from "../world/types";

/** Session lifecycle: starting, loading and creating a game. */
export type MetaAction =
  | { type: "NEW_GAME" }
  | { type: "LOAD"; state: GameState }
  | { type: "CREATE_HERO"; name: string; roleId: RoleId }
  | { type: "DISMISS_INTRO" }
  | { type: "QUIT_TO_TITLE" };

/** Everything that happens on the battle screen. */
export type BattleAction =
  | { type: "ENTER_LEVEL"; level: number }
  | { type: "ATTACK" }
  | { type: "SKILL"; skillIndex: number }
  | { type: "FLEE" }
  | { type: "USE_ITEM"; itemId: string }
  | { type: "NEXT_ENCOUNTER" }
  | { type: "COLLECT_AND_RETURN" }
  | { type: "RETURN_TO_WORLD" };

/** Managing gear and the pack, outside of any shop. */
export type InventoryAction =
  | { type: "EQUIP"; uid: string }
  | { type: "UNEQUIP"; slot: EquippedSlot }
  | { type: "DROP"; itemId: string }
  | { type: "DROP_GEAR"; uid: string }
  | { type: "TOGGLE_INVENTORY" };

/** Shops, the Forge and crafting: anything that spends or earns. */
export type EconomyAction =
  | { type: "TOGGLE_SHOP" }
  | { type: "BUY_ITEM"; itemId: string }
  | { type: "SELL_ITEM"; itemId: string }
  | { type: "SELL_GEAR"; uid: string }
  | { type: "UPGRADE_GEAR"; uid: string }
  | { type: "CRAFT"; recipeId: string };

/** Spending the points a level-up banked. */
export type ProgressionAction =
  | { type: "SPEND_STAT_POINT"; stat: SpendableStat }
  | { type: "BUY_SKILL_NODE"; nodeId: string };

/** Moving through the overworld, talking, and the doors it opens. */
export type WorldAction =
  | { type: "ENTER_WORLD"; mapId: string }
  | { type: "EXIT_WORLD" }
  | { type: "MOVE"; direction: Direction }
  | { type: "INTERACT" }
  | { type: "ADVANCE_DIALOGUE" }
  | { type: "FAST_TRAVEL"; waypointId: string }
  | { type: "CLOSE_DUNGEON_SELECT" };

export type Action =
  | MetaAction
  | BattleAction
  | InventoryAction
  | EconomyAction
  | ProgressionAction
  | WorldAction;
