import { gearByUid } from "../../game/hero/character";
import { addItem, removeItem } from "../../game/economy/inventory";
import { getItem } from "../../game/economy/items";
import { createGear, gearItem } from "../../game/economy/rarity";
import { canCraft, RECIPES } from "../../game/economy/recipes";
import { atJobStation, doubleBrewChance, forgeCapFor, forgeCostFor, grantJobXp } from "../../game/economy/jobs";
import { fundBlocker, nextTier, townTierOf } from "../../game/economy/town";
import {
  EXPANSION_COST,
  investmentsOf,
  savingsValue,
  VENTURE_COST,
  ventureOutcome,
  ventureReady,
} from "../../game/economy/bank";
import { isSettled } from "../../game/settlers";
import {
  nextHouseTier,
  NOOK_COMBINES,
  TROPHY_BUFFS,
  trophySellMultiplier,
  trophyStatDelta,
} from "../../game/economy/house";
import { buyPrice, gearSellPriceAt, sellPriceAt, SHOPS, shopStock } from "../../game/economy/shop";
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

    case "TOGGLE_HALL": {
      // The ledger lives across the mayor's counter, nowhere else.
      if (draft.screen !== "world" || draft.world?.position.mapId !== "town_hall") return;
      draft.hallOpen = !draft.hallOpen;
      return;
    }

    case "TOGGLE_BANK": {
      // The ledger opens across Mirelle's counter in town, nowhere else.
      if (draft.screen !== "world" || draft.world?.position.mapId !== "town") return;
      if (!isSettled(draft, "settler_mirelle")) return;
      draft.bankOpen = !draft.bankOpen;
      return;
    }

    case "BANK_DEPOSIT": {
      if (!draft.bankOpen || action.amount <= 0 || draft.gold < action.amount) return;
      const inv = investmentsOf(draft);
      // depositing folds any accrued interest into the new principal
      const carried = inv.savings ? savingsValue(inv.savings, draft.worldSteps) : 0;
      draft.gold -= action.amount;
      draft.investments = { ...inv, savings: { principal: carried + action.amount, at: draft.worldSteps } };
      return;
    }

    case "BANK_WITHDRAW": {
      const inv = investmentsOf(draft);
      if (!draft.bankOpen || !inv.savings) return;
      const value = savingsValue(inv.savings, draft.worldSteps);
      draft.gold += value;
      draft.investments = { ...inv, savings: undefined };
      draft.worldMessage = `Withdrawn: ${value}g. Mirelle stamps the ledger.`;
      return;
    }

    case "FUND_VENTURE": {
      const inv = investmentsOf(draft);
      if (!draft.bankOpen || inv.venture || draft.gold < VENTURE_COST) return;
      draft.gold -= VENTURE_COST;
      draft.investments = { ...inv, venture: { stake: VENTURE_COST, at: draft.worldSteps } };
      draft.worldMessage = "The caravan rolls out. Give it half a day on the road.";
      return;
    }

    case "COLLECT_VENTURE": {
      const inv = investmentsOf(draft);
      if (!draft.bankOpen || !inv.venture || !ventureReady(inv.venture, draft.worldSteps)) return;
      const { won, payout } = ventureOutcome(inv.venture);
      draft.gold += payout;
      draft.investments = { ...inv, venture: undefined };
      draft.worldMessage = won
        ? `The caravan returns heavy! +${payout}g.`
        : `Raiders hit the caravan. ${payout}g salvaged from the wreck.`;
      return;
    }

    case "EXPAND_PROPERTY": {
      const inv = investmentsOf(draft);
      if (!draft.bankOpen || !draft.properties.includes(action.mapId)) return;
      if (inv.expansions.includes(action.mapId) || draft.gold < EXPANSION_COST) return;
      draft.gold -= EXPANSION_COST;
      draft.investments = { ...inv, expansions: [...inv.expansions, action.mapId] };
      draft.worldMessage = "The expansion is funded: that business pays richer rent now.";
      return;
    }

    case "BUY_HOUSE_UPGRADE": {
      // Odo sells the bigger deeds (PIX-34): Cottage, then Manor. The new
      // interior is served by the house-tier mirror the moment you walk in.
      const next = draft.shopOpen && activeShopId(draft) === "odo" ? nextHouseTier(draft) : null;
      if (!next || draft.gold < next.cost) return;
      draft.gold -= next.cost;
      draft.house.tier = next.tier;
      draft.worldMessage = `The ${next.name.toUpperCase()} deed is signed. Your house grew while you were out.`;
      return;
    }

    case "TOGGLE_TROPHIES": {
      draft.trophiesOpen = !draft.trophiesOpen;
      return;
    }

    case "TOGGLE_NOOK": {
      draft.nookOpen = !draft.nookOpen;
      return;
    }

    case "DISPLAY_TROPHY": {
      // Sell it for gold, or shelve it for power: the trophy finally decides.
      if (!draft.trophiesOpen || !TROPHY_BUFFS[action.itemId]) return;
      const shown = draft.house.trophies ?? [];
      if (shown.includes(action.itemId) || (draft.inventory[action.itemId] ?? 0) <= 0) return;
      draft.inventory = removeItem(draft.inventory, action.itemId);
      draft.house.trophies = [...shown, action.itemId];
      if (draft.hero) {
        for (const [stat, delta] of Object.entries(trophyStatDelta(action.itemId))) {
          draft.hero.stats[stat as "defense"] += delta;
        }
      }
      return;
    }

    case "TAKE_TROPHY": {
      if (!draft.trophiesOpen || !(draft.house.trophies ?? []).includes(action.itemId)) return;
      draft.house.trophies = (draft.house.trophies ?? []).filter((id) => id !== action.itemId);
      draft.inventory = addItem(draft.inventory, action.itemId);
      if (draft.hero) {
        for (const [stat, delta] of Object.entries(trophyStatDelta(action.itemId))) {
          draft.hero.stats[stat as "defense"] -= delta;
        }
      }
      return;
    }

    case "COMBINE_POTIONS": {
      // The manor's alchemy nook: two of a brew distill into one better one.
      const recipe = draft.nookOpen ? NOOK_COMBINES.find((c) => c.from === action.itemId) : null;
      if (!recipe || (draft.inventory[action.itemId] ?? 0) < 2) return;
      draft.inventory = removeItem(draft.inventory, recipe.from, 2);
      draft.inventory = addItem(draft.inventory, recipe.to);
      draft.worldMessage = `The nook bubbles: 2x ${getItem(recipe.from).name} became ${getItem(recipe.to).name}.`;
      return;
    }

    case "FUND_TOWN": {
      // The gold sink with a skyline (PIX-91): requirements checked, treasury
      // paid, tier raised. The town redraws itself the moment you walk out.
      const next = nextTier(draft);
      if (!next || fundBlocker(draft) !== null) return;
      draft.gold -= next.cost ?? 0;
      draft.townTier = next.tier;
      draft.worldMessage = `Pixelheim rises: the ${next.name.toUpperCase()} charter is signed. Walk outside.`;
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
      draft.gold += Math.floor(sellPriceAt(shopId, item, townTierOf(draft)) * trophySellMultiplier(draft));
      draft.inventory = removeItem(draft.inventory, item.id);
      return;
    }

    case "SELL_GEAR": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || Object.values(draft.equipped).includes(action.uid)) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance) return;
      draft.gold += Math.floor(gearSellPriceAt(shopId, instance, townTierOf(draft)) * trophySellMultiplier(draft));
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
      // The craft happens at its station: the forge, the cauldron, or the
      // fitted workbench at home (PIX-109).
      if (!atJobStation(recipe.job.id, draft.world?.position.mapId, draft.house.workbench ?? false)) return;
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
