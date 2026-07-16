import { getItem } from "./items";
import type { Item } from "./types";

type ShopEntry = {
  itemId: string;
  /** The merchant stocks this once the hero has unlocked this dungeon floor. */
  unlockLevel: number;
};

/** Everything the merchant can ever stock. Reward-only gear (Dragonbane, misc trophies) is not sold. */
const CATALOG: ShopEntry[] = [
  { itemId: "bread", unlockLevel: 1 },
  { itemId: "cheese_wheel", unlockLevel: 1 },
  { itemId: "potion_hp", unlockLevel: 1 },
  { itemId: "rusty_sword", unlockLevel: 1 },
  { itemId: "potion_mp", unlockLevel: 2 },
  { itemId: "leather_armor", unlockLevel: 2 },
  { itemId: "iron_sword", unlockLevel: 3 },
  { itemId: "apprentice_staff", unlockLevel: 3 },
  { itemId: "elixir", unlockLevel: 4 },
  { itemId: "steel_shield", unlockLevel: 5 },
  { itemId: "shadow_dagger", unlockLevel: 6 },
  { itemId: "mage_robe", unlockLevel: 6 },
  { itemId: "steel_axe", unlockLevel: 7 },
  { itemId: "iron_armor", unlockLevel: 7 },
  { itemId: "arch_staff", unlockLevel: 8 },
];

export function shopStock(unlockedLevel: number): Item[] {
  return CATALOG.filter((entry) => entry.unlockLevel <= unlockedLevel).map((entry) => getItem(entry.itemId));
}

export function buyPrice(item: Item): number {
  return item.value;
}

/** The merchant has a business to run. */
export function sellPrice(item: Item): number {
  return Math.max(1, Math.floor(item.value / 2));
}
