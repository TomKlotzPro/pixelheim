import type { RegionId } from "../world/types";

/**
 * Crafting: turn foraged materials into consumables from the inventory's
 * Craft tab. Materials come from winning wild battles in their region.
 */
export type Recipe = {
  id: string;
  /** Item produced (always 1). */
  itemId: string;
  /** itemId -> count consumed. */
  needs: Record<string, number>;
};

export const RECIPES: Recipe[] = [
  { id: "brew_potion_hp", itemId: "potion_hp", needs: { forest_herb: 1, marsh_reed: 1 } },
  { id: "brew_potion_mp", itemId: "potion_mp", needs: { marsh_reed: 2 } },
  { id: "brew_antidote", itemId: "antidote", needs: { forest_herb: 2 } },
  { id: "brew_ember_salve", itemId: "ember_salve", needs: { ember_shard: 2 } },
  { id: "brew_elixir", itemId: "elixir", needs: { forest_herb: 1, marsh_reed: 1, ember_shard: 1 } },
  { id: "brew_greater", itemId: "greater_potion", needs: { forest_herb: 2, ember_shard: 2 } },
];

export function canCraft(recipe: Recipe, inventory: Record<string, number>): boolean {
  return Object.entries(recipe.needs).every(([itemId, count]) => (inventory[itemId] ?? 0) >= count);
}

/** What a region yields when its monsters fall. */
export const REGION_MATERIALS: Record<RegionId, string> = {
  forest: "forest_herb",
  marsh: "marsh_reed",
  ash: "ember_shard",
};
