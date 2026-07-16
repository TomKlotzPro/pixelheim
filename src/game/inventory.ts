/** Stackable inventory helpers: counts keyed by item id, zero means gone. */

export function addItem(inventory: Record<string, number>, itemId: string, count = 1): Record<string, number> {
  return { ...inventory, [itemId]: (inventory[itemId] ?? 0) + count };
}

export function removeItem(inventory: Record<string, number>, itemId: string, count = 1): Record<string, number> {
  const next = { ...inventory };
  const remaining = (next[itemId] ?? 0) - count;
  if (remaining > 0) next[itemId] = remaining;
  else delete next[itemId];
  return next;
}
