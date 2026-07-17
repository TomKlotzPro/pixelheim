import type { Item } from "../types";

type StatLineOpts = {
  /** Rarity bonus already applied on top of the base stat. */
  bonus?: number;
  /** Show a gold value at the end of the line. */
  value?: number;
};

/** Compact one-line summary of an item's numbers, shown in inventory and shop rows. */
export function itemStatLine(item: Item, { bonus = 0, value }: StatLineOpts = {}): string {
  const parts: string[] = [];
  const plus = bonus > 0 ? `+${bonus}` : "";
  if (item.damage) parts.push(`DMG ${item.damage + bonus}${plus && ` (${item.damage}${plus})`} ${item.scaling?.slice(0, 3).toUpperCase()}`);
  if (item.armor) parts.push(`ARMOR ${item.armor + bonus}${plus && ` (${item.armor}${plus})`}`);
  if (item.grants) {
    for (const [stat, amount] of Object.entries(item.grants)) {
      parts.push(`+${amount} ${stat.slice(0, 3).toUpperCase()}`);
    }
  }
  if (item.restoreHp) parts.push(`+${item.restoreHp} HP`);
  if (item.restoreMp) parts.push(`+${item.restoreMp} MP`);
  if (item.cures) parts.push(`cures ${item.cures}`);
  parts.push(`${item.weight} wt`);
  if (value !== undefined) parts.push(`${value}g`);
  return parts.join("  ");
}
