import { produce } from "immer";
import type { GameState } from "../game/types";
import type { Action } from "./actions";
import { battleReducer } from "./reducers/battle";
import { economyReducer } from "./reducers/economy";
import { inventoryReducer } from "./reducers/inventory";
import { metaReducer } from "./reducers/meta";
import { progressionReducer } from "./reducers/progression";
import { worldReducer } from "./reducers/world";

export type { Action } from "./actions";
export { activeShopId, initialState, REST_COST, TOWN_SPAWN } from "./shared";

/**
 * The pure game loop: state in, state out. Immer turns the mutation-style
 * domain reducers into an immutable update with structural sharing, so
 * unchanged branches keep their identity (a no-op action returns the same
 * state reference). The router below is the whole reducer: each action is
 * owned by exactly one domain module.
 */
export function gameReducer(state: GameState, action: Action): GameState {
  return produce(state, (draft) => route(draft as GameState, action));
}

function route(draft: GameState, action: Action): GameState | void {
  switch (action.type) {
    case "NEW_GAME":
    case "LOAD":
    case "CREATE_HERO":
    case "DISMISS_INTRO":
    case "QUIT_TO_TITLE":
      return metaReducer(draft, action);

    case "ENTER_LEVEL":
    case "ATTACK":
    case "SKILL":
    case "FLEE":
    case "USE_ITEM":
    case "NEXT_ENCOUNTER":
    case "COLLECT_AND_RETURN":
    case "RETURN_TO_WORLD":
      return battleReducer(draft, action);

    case "EQUIP":
    case "UNEQUIP":
    case "DROP":
    case "DROP_GEAR":
    case "TOGGLE_INVENTORY":
      return inventoryReducer(draft, action);

    case "BUY_PROPERTY":
    case "BUY_HOUSE":
    case "TOGGLE_STORAGE":
    case "STORE_ITEM":
    case "TAKE_ITEM":
    case "TOGGLE_SHOP":
    case "TOGGLE_HALL":
    case "FUND_TOWN":
    case "TOGGLE_BANK":
    case "BANK_DEPOSIT":
    case "BANK_WITHDRAW":
    case "FUND_VENTURE":
    case "COLLECT_VENTURE":
    case "EXPAND_PROPERTY":
    case "BUY_ITEM":
    case "SELL_ITEM":
    case "SELL_GEAR":
    case "UPGRADE_GEAR":
    case "CRAFT":
      return economyReducer(draft, action);

    case "SPEND_STAT_POINT":
    case "BUY_SKILL_NODE":
    case "CHOOSE_SPEC":
    case "CHOOSE_PATH":
      return progressionReducer(draft, action);

    case "ENTER_WORLD":
    case "EXIT_WORLD":
    case "MOVE":
    case "INTERACT":
    case "ADVANCE_DIALOGUE":
    case "FAST_TRAVEL":
    case "CLOSE_DUNGEON_SELECT":
      return worldReducer(draft, action);
  }
}
