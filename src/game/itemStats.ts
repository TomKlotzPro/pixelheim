import type { Item } from "./types";

/** Compact one-line summary of an item's numbers, shown in inventory and shop rows. */
export function itemStatLine(item: Item, { withValue = false } = {}): string {
  const parts: string[] = [];
  if (item.damage) parts.push(`DMG ${item.damage} (${item.scaling?.slice(0, 3).toUpperCase()})`);
  if (item.armor) parts.push(`ARMOR ${item.armor}`);
  if (item.restoreHp) parts.push(`+${item.restoreHp} HP`);
  if (item.restoreMp) parts.push(`+${item.restoreMp} MP`);
  parts.push(`${item.weight} wt`);
  if (withValue) parts.push(`${item.value}g`);
  return parts.join("  ");
}
