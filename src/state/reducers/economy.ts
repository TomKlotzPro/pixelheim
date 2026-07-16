import { gearByUid } from "../../game/character";
import { addItem, removeItem } from "../../game/inventory";
import { getItem } from "../../game/items";
import { createGear, gearItem, gearValue } from "../../game/rarity";
import { canCraft, RECIPES } from "../../game/recipes";
import { buyPrice, FORGE_BONUS_CAP, forgeCost, sellPriceAt, SHOPS, shopStock } from "../../game/shop";
import type { GameState } from "../../game/types";
import type { EconomyAction } from "../actions";
import { activeShopId } from "../shared";

export function economyReducer(draft: GameState, action: EconomyAction): void {
  switch (action.type) {
    case "TOGGLE_SHOP": {
      // Shops live inside their keepers' buildings.
      if (draft.screen !== "world" || !activeShopId(draft)) return;
      draft.shopOpen = !draft.shopOpen;
      return;
    }

    case "BUY_ITEM": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId) return;
      const item = getItem(action.itemId);
      if (!shopStock(shopId, draft.unlockedLevel).some((stocked) => stocked.id === item.id)) return;
      const price = buyPrice(item);
      if (draft.gold < price) return;
      draft.gold -= price;
      // Shops sell honest common gear; the exciting rolls come from monsters.
      if (item.slot) draft.gear.push(createGear(item.id));
      else draft.inventory = addItem(draft.inventory, item.id);
      return;
    }

    case "SELL_ITEM": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || (draft.inventory[action.itemId] ?? 0) <= 0) return;
      const item = getItem(action.itemId);
      draft.gold += sellPriceAt(shopId, item);
      draft.inventory = removeItem(draft.inventory, item.id);
      return;
    }

    case "SELL_GEAR": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || Object.values(draft.equipped).includes(action.uid)) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance) return;
      const rate = SHOPS[shopId].buyRates[gearItem(instance).category] ?? 0.5;
      draft.gold += Math.max(1, Math.floor(gearValue(instance) * rate));
      draft.gear = draft.gear.filter((g) => g.uid !== action.uid);
      return;
    }

    case "UPGRADE_GEAR": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || !SHOPS[shopId].forge) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance || instance.bonus >= FORGE_BONUS_CAP) return;
      const cost = forgeCost(gearItem(instance), instance.bonus);
      if (draft.gold < cost) return;
      draft.gold -= cost;
      instance.bonus += 1;
      return;
    }

    case "CRAFT": {
      if (!draft.hero) return;
      const recipe = RECIPES.find((r) => r.id === action.recipeId);
      if (!recipe || !canCraft(recipe, draft.inventory)) return;
      let inventory = draft.inventory;
      for (const [itemId, count] of Object.entries(recipe.needs)) {
        inventory = removeItem(inventory, itemId, count);
      }
      draft.inventory = addItem(inventory, recipe.itemId);
    }
  }
}
