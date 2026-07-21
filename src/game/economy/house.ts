import type { GameState } from "../types";

/**
 * The house grows with you (PIX-34): three tiers with their own interiors,
 * trophies displayed for living buffs, a garden fed by victories, and
 * furniture placed wherever the floor is free.
 */
export type PlacedFurniture = { itemId: string; x: number; y: number };

export const HOUSE_TIERS = [
  { tier: 1, name: "Cozy Hut", cost: 0 },
  { tier: 2, name: "Cottage", cost: 5000 },
  { tier: 3, name: "Manor", cost: 12_000 },
] as const;

export function houseTier(state: GameState): number {
  return state.house.owned ? (state.house.tier ?? 1) : 0;
}

/** The next deed Odo can sell, if any. */
export function nextHouseTier(state: GameState): (typeof HOUSE_TIERS)[number] | null {
  const tier = houseTier(state);
  if (tier === 0) return null;
  return HOUSE_TIERS.find((t) => t.tier === tier + 1) ?? null;
}

// ---------------- trophies: sell for gold, or display for power ----------------

export const TROPHY_BUFFS: Record<string, { label: string }> = {
  dragon_scale: { label: "+2 DEF while displayed" },
  lich_crown: { label: "+2 to every stat while displayed" },
  gem: { label: "+10% shop sell price while displayed" },
};

export function displayedTrophies(state: GameState): string[] {
  return state.house.trophies ?? [];
}

/**
 * Stat deltas applied the moment a trophy goes on the shelf and removed the
 * moment it comes down - the same accumulator model as level-ups and paths.
 */
export function trophyStatDelta(
  itemId: string,
): Partial<Record<"strength" | "intelligence" | "dexterity" | "defense", number>> {
  if (itemId === "dragon_scale") return { defense: 2 };
  if (itemId === "lich_crown") return { strength: 2, intelligence: 2, dexterity: 2, defense: 2 };
  return {};
}

export function trophySellMultiplier(state: GameState): number {
  return displayedTrophies(state).includes("gem") ? 1.1 : 1;
}

// ---------------- the garden: victories become breakfast ----------------

export const GARDEN_WINS_PER_YIELD = 6;

/** What the next ripe harvest yields: bread and cheese, turn and turn about. */
export function gardenYield(harvests: number): string {
  return harvests % 2 === 0 ? "bread" : "cheese_wheel";
}

// ---------------- the alchemy nook: two brews become a better one ----------------

/** Two of the left make one of the right; the nook knows no other recipes. */
export const NOOK_COMBINES: { from: string; to: string }[] = [
  { from: "potion_hp", to: "greater_potion" },
  { from: "greater_potion", to: "elixir" },
  { from: "potion_mp", to: "elixir" },
];

// ---------------- furniture placement ----------------

export function furnitureOn(state: GameState, mapId: string): PlacedFurniture[] {
  return mapId === "town_house" ? (state.house.furniture ?? []) : [];
}

export function furnitureAt(state: GameState, mapId: string, x: number, y: number): PlacedFurniture | null {
  return furnitureOn(state, mapId).find((f) => f.x === x && f.y === y) ?? null;
}

/** Rugs lie flat underfoot; everything else takes the tile. */
export function furnitureBlocks(itemId: string): boolean {
  return itemId !== "furn_rug";
}
