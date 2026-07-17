import { getItem } from "./items";
import type { GearInstance, Item, Rarity } from "../types";

type RarityDef = {
  label: string;
  /** Inclusive bonus roll ranges. */
  weaponBonus: [number, number];
  armorBonus: [number, number];
  valueMult: number;
};

export const RARITIES: Record<Rarity, RarityDef> = {
  common: { label: "", weaponBonus: [0, 0], armorBonus: [0, 0], valueMult: 1 },
  fine: { label: "Fine", weaponBonus: [1, 3], armorBonus: [1, 2], valueMult: 2 },
  epic: { label: "Epic", weaponBonus: [4, 7], armorBonus: [3, 5], valueMult: 4 },
};

function rollBetween([min, max]: [number, number]): number {
  return min + Math.floor(Math.random() * (max - min + 1));
}

let uidCounter = 0;

/** Unique within a save: monotonic prefix + entropy. */
export function gearUid(): string {
  uidCounter += 1;
  return `g${Date.now().toString(36)}${uidCounter}${Math.random().toString(36).slice(2, 6)}`;
}

export function createGear(itemId: string, rarity: Rarity = "common"): GearInstance {
  const item = getItem(itemId);
  const def = RARITIES[rarity];
  const bonus = rarity === "common" ? 0 : rollBetween(item.category === "weapons" ? def.weaponBonus : def.armorBonus);
  return { uid: gearUid(), itemId, rarity, bonus };
}

export function gearItem(instance: GearInstance): Item {
  return getItem(instance.itemId);
}

export function gearName(instance: GearInstance): string {
  const label = RARITIES[instance.rarity].label;
  const name = gearItem(instance).name;
  return label ? `${label} ${name}` : name;
}

export function gearDamage(instance: GearInstance): number {
  return (gearItem(instance).damage ?? 0) + (gearItem(instance).category === "weapons" ? instance.bonus : 0);
}

export function gearArmor(instance: GearInstance): number {
  return (gearItem(instance).armor ?? 0) + (gearItem(instance).category === "apparel" ? instance.bonus : 0);
}

export function gearValue(instance: GearInstance): number {
  return Math.round(gearItem(instance).value * RARITIES[instance.rarity].valueMult);
}

/** Rolls a rarity from weights (common/fine/epic summing to 1). */
export function rollRarity(weights: Record<Rarity, number>): Rarity {
  const roll = Math.random();
  if (roll < weights.epic) return "epic";
  if (roll < weights.epic + weights.fine) return "fine";
  return "common";
}
