import { gearByUid } from "../../game/hero/character";
import { addItem, removeItem } from "../../game/economy/inventory";
import { getItem } from "../../game/economy/items";
import { createGear, gearItem, gearValue } from "../../game/economy/rarity";
import { canCraft, RECIPES } from "../../game/economy/recipes";
import { doubleBrewChance, forgeCapFor, forgeCostFor, grantJobXp, JOB_STATIONS } from "../../game/economy/jobs";
import { buyPrice, sellPriceAt, SHOPS, shopStock } from "../../game/economy/shop";
import type { GameState } from "../../game/types";
import type { EconomyAction } from "../actions";
import { activeShopId, HOUSE_DEED_COST, PROPERTY_PRICES } from "../shared";

export function economyReducer(draft: GameState, action: EconomyAction): void {
  switch (action.type) {
    case "BUY_HOUSE": {
      // The deed: 1,500g, once. The door at (30,13) is yours after.
      if (draft.house.owned || draft.gold < HOUSE_DEED_COST) return;
      draft.gold -= HOUSE_DEED_COST;
      draft.house.owned = true;
      draft.worldMessage = "The deed is yours. Welcome home.";
      return;
    }

    case "TOGGLE_STORAGE": {
      draft.storageOpen = !draft.storageOpen;
      return;
    }

    case "STORE_ITEM": {
      if (!draft.house.owned || !draft.storageOpen) return;
      const have = draft.inventory[action.itemId] ?? 0;
      const count = Math.min(action.count ?? 1, have);
      if (count <= 0) return;
      draft.inventory = removeItem(draft.inventory, action.itemId, count);
      draft.house.storage[action.itemId] = (draft.house.storage[action.itemId] ?? 0) + count;
      return;
    }

    case "TAKE_ITEM": {
      if (!draft.house.owned || !draft.storageOpen) return;
      const stored = draft.house.storage[action.itemId] ?? 0;
      const count = Math.min(action.count ?? 1, stored);
      if (count <= 0) return;
      const left = stored - count;
      if (left > 0) draft.house.storage[action.itemId] = left;
      else delete draft.house.storage[action.itemId];
      draft.inventory = addItem(draft.inventory, action.itemId, count);
      return;
    }

    case "BUY_PROPERTY": {
      // Buy the business you stand in, from the keeper behind its counter.
      const deed = PROPERTY_PRICES[action.mapId];
      if (!deed || draft.properties.includes(action.mapId) || draft.gold < deed.cost) return;
      if (draft.world?.position.mapId !== action.mapId) return;
      draft.gold -= deed.cost;
      draft.properties.push(action.mapId);
      return;
    }

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
      if (!shopId || !SHOPS[shopId].forge || !draft.hero) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance || instance.bonus >= forgeCapFor(draft.hero.jobs.smithing.level)) return;
      const cost = forgeCostFor(gearItem(instance), instance.bonus, draft.hero.jobs.smithing.level);
      if (draft.gold < cost) return;
      draft.gold -= cost;
      instance.bonus += 1;
      grantJobXp(draft.hero, "smithing", 10);
      return;
    }

    case "CRAFT": {
      if (!draft.hero) return;
      const recipe = RECIPES.find((r) => r.id === action.recipeId);
      if (!recipe || !canCraft(recipe, draft.inventory, draft.hero.jobs)) return;
      // The craft happens at its station: smithing at the forge, brews at the cauldron.
      if (draft.world?.position.mapId !== JOB_STATIONS[recipe.job.id].mapId) return;
      let inventory = draft.inventory;
      for (const [itemId, count] of Object.entries(recipe.needs)) {
        inventory = removeItem(inventory, itemId, count);
      }
      draft.inventory = inventory;
      if (getItem(recipe.itemId).slot) {
        // Smithing: forged pieces are gear instances, one at a time.
        draft.gear.push(createGear(recipe.itemId));
        grantJobXp(draft.hero, "smithing", 10);
      } else {
        // Alchemy: skilled hands sometimes brew a second one for free.
        const doubled = Math.random() < doubleBrewChance(draft.hero.jobs.alchemy.level);
        draft.inventory = addItem(draft.inventory, recipe.itemId, doubled ? 2 : 1);
        grantJobXp(draft.hero, "alchemy", 8);
      }
    }
  }
}
