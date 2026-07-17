import { gearByUid } from "../../game/character";
import { removeItem } from "../../game/inventory";
import { gearItem } from "../../game/rarity";
import type { GameState } from "../../game/types";
import type { InventoryAction } from "../actions";

export function inventoryReducer(draft: GameState, action: InventoryAction): void {
  switch (action.type) {
    case "EQUIP": {
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance) return;
      const slot = gearItem(instance).slot;
      if (!slot) return;
      if (Object.values(draft.equipped).includes(action.uid)) return;
      // A ring fits either finger: first the empty one, else replace the first.
      if (slot === "ring") {
        const finger = !draft.equipped.ring1 ? "ring1" : !draft.equipped.ring2 ? "ring2" : "ring1";
        draft.equipped[finger] = action.uid;
        return;
      }
      draft.equipped[slot] = action.uid;
      return;
    }

    case "UNEQUIP": {
      if (!draft.equipped[action.slot]) return;
      delete draft.equipped[action.slot];
      return;
    }

    case "DROP": {
      if ((draft.inventory[action.itemId] ?? 0) <= 0) return;
      draft.inventory = removeItem(draft.inventory, action.itemId);
      return;
    }

    case "DROP_GEAR": {
      if (Object.values(draft.equipped).includes(action.uid)) return;
      if (!gearByUid(draft.gear, action.uid)) return;
      draft.gear = draft.gear.filter((g) => g.uid !== action.uid);
      return;
    }

    case "TOGGLE_INVENTORY": {
      draft.inventoryOpen = !draft.inventoryOpen;
    }
  }
}
