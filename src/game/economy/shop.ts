import { getItem } from "./items";
import type { Item, ItemCategory } from "../types";

type ShopEntry = {
  itemId: string;
  /** Stocked once the hero has unlocked this dungeon floor. */
  unlockLevel: number;
};

/** Everything any shop can ever stock. Reward-only gear is never sold. */
const CATALOG: ShopEntry[] = [
  { itemId: "bread", unlockLevel: 1 },
  { itemId: "cheese_wheel", unlockLevel: 1 },
  { itemId: "apple", unlockLevel: 1 },
  { itemId: "dried_meat", unlockLevel: 2 },
  { itemId: "potion_hp", unlockLevel: 1 },
  { itemId: "rusty_sword", unlockLevel: 1 },
  { itemId: "hunting_bow", unlockLevel: 1 },
  { itemId: "traveler_cloak", unlockLevel: 1 },
  { itemId: "potion_mp", unlockLevel: 2 },
  { itemId: "antidote", unlockLevel: 2 },
  { itemId: "leather_armor", unlockLevel: 2 },
  { itemId: "iron_sword", unlockLevel: 3 },
  { itemId: "apprentice_staff", unlockLevel: 3 },
  { itemId: "elixir", unlockLevel: 4 },
  { itemId: "ember_salve", unlockLevel: 4 },
  { itemId: "steel_shield", unlockLevel: 5 },
  { itemId: "shadow_dagger", unlockLevel: 6 },
  { itemId: "mage_robe", unlockLevel: 6 },
  { itemId: "steel_axe", unlockLevel: 7 },
  { itemId: "iron_armor", unlockLevel: 7 },
  { itemId: "arch_staff", unlockLevel: 8 },
  { itemId: "moon_wand", unlockLevel: 5 },
  { itemId: "longbow", unlockLevel: 6 },
  { itemId: "war_hammer", unlockLevel: 8 },
  { itemId: "tower_shield", unlockLevel: 8 },
  { itemId: "shadow_cloak", unlockLevel: 9 },
  { itemId: "greater_potion", unlockLevel: 11 },
  // the wardrobe and the jewelry counter
  { itemId: "wool_gloves", unlockLevel: 1 },
  { itemId: "worn_boots", unlockLevel: 1 },
  { itemId: "leather_cap", unlockLevel: 2 },
  { itemId: "bone_charm", unlockLevel: 3 },
  { itemId: "marchers_boots", unlockLevel: 4 },
  { itemId: "band_of_grit", unlockLevel: 5 },
  { itemId: "ring_of_clarity", unlockLevel: 5 },
  { itemId: "quickstep_ring", unlockLevel: 5 },
];

export type ShopId = "odo" | "smith" | "alchemist";

export type ShopDef = {
  id: ShopId;
  keeper: string;
  sprite: string;
  greeting: string;
  /** Categories this shop sells (from the catalog). */
  sells: ItemCategory[];
  /** Categories bought at a better-than-scrap rate: category -> value multiplier. */
  buyRates: Partial<Record<ItemCategory, number>>;
  /** The blacksmith can improve gear for gold. */
  forge?: boolean;
};

export const SHOPS: Record<ShopId, ShopDef> = {
  odo: {
    id: "odo",
    keeper: "Merchant Odo",
    sprite: "merchant",
    greeting: "General goods! Food, sundries, and I will buy nearly anything.",
    sells: ["food", "misc"],
    buyRates: {},
  },
  smith: {
    id: "smith",
    keeper: "Smith Hilda",
    sprite: "smith",
    greeting: "Steel sold, steel sharpened. The forge takes gold, not promises.",
    sells: ["weapons", "apparel"],
    buyRates: { weapons: 0.6, apparel: 0.6 },
    forge: true,
  },
  alchemist: {
    id: "alchemist",
    keeper: "Alchemist Vex",
    sprite: "alchemist",
    greeting: "Brews, cures, reagents. I pay full price for raw materials.",
    sells: ["potions"],
    buyRates: { misc: 1 },
  },
};

/** Which building's interior hosts which shop. */
export const SHOP_MAPS: Record<string, ShopId> = {
  town_shop: "odo",
  town_smith: "smith",
  town_alchemist: "alchemist",
};

export function shopStock(shopId: ShopId, unlockedLevel: number): Item[] {
  const def = SHOPS[shopId];
  return CATALOG.filter((entry) => entry.unlockLevel <= unlockedLevel)
    .map((entry) => getItem(entry.itemId))
    .filter((item) => def.sells.includes(item.category));
}

export function buyPrice(item: Item): number {
  return item.value;
}

/** Base scrap rate is half; specialists pay their listed rates. */
export function sellPriceAt(shopId: ShopId, item: Item): number {
  const rate = SHOPS[shopId].buyRates[item.category] ?? 0.5;
  return Math.max(1, Math.floor(item.value * rate));
}

/** Forge: each +1 costs more as the piece grows. Bonus is capped at +7. */
export const FORGE_BONUS_CAP = 7;

export function forgeCost(item: Item, currentBonus: number): number {
  return Math.max(20, Math.round(item.value * 0.25 * (currentBonus + 1)));
}
