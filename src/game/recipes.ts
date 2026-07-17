import type { Jobs, JobId } from "./types";
import type { RegionId } from "../world/types";

/**
 * Crafting: turn materials into items from the inventory's Craft tab. The
 * gate is always the MAKING - job levels and rare materials - never the
 * wearing: once a thing exists, anyone can equip or drink it.
 */
export type Recipe = {
  id: string;
  /** Item produced (one per craft; skilled alchemists sometimes brew two). */
  itemId: string;
  /** itemId -> count consumed. */
  needs: Record<string, number>;
  /** The profession that makes it, and the level the recipe demands. */
  job: { id: Extract<JobId, "smithing" | "alchemy">; level: number };
};

export const RECIPES: Recipe[] = [
  // brews - Alchemy
  { id: "brew_potion_hp", itemId: "potion_hp", needs: { forest_herb: 1, marsh_reed: 1 }, job: { id: "alchemy", level: 1 } },
  { id: "brew_potion_mp", itemId: "potion_mp", needs: { marsh_reed: 2 }, job: { id: "alchemy", level: 1 } },
  { id: "brew_antidote", itemId: "antidote", needs: { forest_herb: 2 }, job: { id: "alchemy", level: 1 } },
  { id: "brew_ember_salve", itemId: "ember_salve", needs: { ember_shard: 2 }, job: { id: "alchemy", level: 1 } },
  { id: "brew_stamina", itemId: "stamina_draught", needs: { marsh_reed: 2, forest_herb: 1 }, job: { id: "alchemy", level: 2 } },
  { id: "brew_stew", itemId: "hunters_stew", needs: { dried_meat: 1, forest_herb: 2 }, job: { id: "alchemy", level: 3 } },
  { id: "brew_elixir", itemId: "elixir", needs: { forest_herb: 1, marsh_reed: 1, ember_shard: 1 }, job: { id: "alchemy", level: 4 } },
  { id: "brew_greater", itemId: "greater_potion", needs: { forest_herb: 2, ember_shard: 2 }, job: { id: "alchemy", level: 5 } },
  { id: "brew_dragon_tonic", itemId: "dragon_tonic", needs: { dragon_scale: 1, forest_herb: 2, marsh_reed: 2 }, job: { id: "alchemy", level: 6 } },
  // gear - Smithing (craft-only: none of these ever appear in a shop)
  { id: "craft_reed_buckler", itemId: "reed_buckler", needs: { marsh_reed: 4, wolf_pelt: 1 }, job: { id: "smithing", level: 2 } },
  { id: "craft_beast_cleaver", itemId: "beast_cleaver", needs: { wolf_pelt: 2, imp_horn: 1 }, job: { id: "smithing", level: 3 } },
  { id: "craft_emberwood_staff", itemId: "emberwood_staff", needs: { ember_shard: 3, forest_herb: 2 }, job: { id: "smithing", level: 4 } },
  { id: "craft_wyrmfang_dagger", itemId: "wyrmfang_dagger", needs: { dragon_scale: 1, imp_horn: 2 }, job: { id: "smithing", level: 5 } },
  { id: "craft_scaled_mail", itemId: "scaled_mail", needs: { dragon_scale: 2, wolf_pelt: 2 }, job: { id: "smithing", level: 6 } },
  // the wardrobe - armor for the new slots (craft-only tiers)
  { id: "craft_iron_helm", itemId: "iron_helm", needs: { wolf_pelt: 1, ember_shard: 1 }, job: { id: "smithing", level: 3 } },
  { id: "craft_smith_gauntlets", itemId: "smith_gauntlets", needs: { wolf_pelt: 2, imp_horn: 1 }, job: { id: "smithing", level: 4 } },
  { id: "craft_scaled_greaves", itemId: "scaled_greaves", needs: { dragon_scale: 1, wolf_pelt: 2 }, job: { id: "smithing", level: 6 } },
  // steeped jewelry - Alchemy's side of the wardrobe
  { id: "brew_wolfstooth_collar", itemId: "wolfstooth_collar", needs: { wolf_pelt: 2, grave_moss: 1 }, job: { id: "alchemy", level: 4 } },
  // frontier recipes - the new regions' forage feeding the top of both trades
  { id: "brew_troll_salve", itemId: "troll_salve", needs: { deep_root: 2, forest_herb: 1 }, job: { id: "alchemy", level: 5 } },
  { id: "craft_deeproot_bow", itemId: "deeproot_bow", needs: { deep_root: 3, wolf_pelt: 2 }, job: { id: "smithing", level: 7 } },
  { id: "craft_grave_ward", itemId: "grave_ward", needs: { grave_moss: 3, dragon_scale: 1 }, job: { id: "smithing", level: 8 } },
];

/** True when the pack holds the materials AND the hands know the craft. */
export function canCraft(recipe: Recipe, inventory: Record<string, number>, jobs: Jobs): boolean {
  if (jobs[recipe.job.id].level < recipe.job.level) return false;
  return Object.entries(recipe.needs).every(([itemId, count]) => (inventory[itemId] ?? 0) >= count);
}

/** What a region yields when its monsters fall. */
export const REGION_MATERIALS: Record<RegionId, string> = {
  forest: "forest_herb",
  marsh: "marsh_reed",
  ash: "ember_shard",
  deepwood: "deep_root",
  mire: "grave_moss",
};
