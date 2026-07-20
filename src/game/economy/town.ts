import type { GameState } from "../types";
import { PROPERTY_PRICES, RENT_PER_VICTORY, REST_COST } from "../../state/shared";

/**
 * Town tiers (PIX-91): Pixelheim grows when its champion pays for it. Each
 * tier is a hand-drawn redraw of the town map (see maps/ashenreach.ts) plus a
 * town-wide perk. Funding happens at the city hall ledger; the wow moment is
 * walking back out the door into a bigger town.
 */
export type TownTier = {
  /** 1-4; also indexes the authored map variant. */
  tier: number;
  name: string;
  blurb: string;
  /** What this tier adds, shown in the ledger. */
  perks: string[];
  /** Cost to REACH this tier (undefined for tier 1, the founding state). */
  cost?: number;
  /** Human requirement line + its predicate, both undefined when gold alone pays. */
  requires?: { line: string; met: (state: GameState) => boolean };
};

export const TOWN_TIERS: TownTier[] = [
  {
    tier: 1,
    name: "Hamlet",
    blurb: "A stubborn cluster of roofs under the mountain. It held. Now it can grow.",
    perks: ["The founding stone: shops, an inn, and people who stayed"],
  },
  {
    tier: 2,
    name: "Village",
    blurb: "Lamps on the street, stalls on the square, and a new face who chose to stay.",
    perks: ["Market stalls and street lamps dress the square", "Rent rises: +1g per property after every victory"],
    cost: 2500,
  },
  {
    tier: 3,
    name: "Town",
    blurb: "A fountain sings in the plaza. Builders raise new roofs. Word spreads.",
    perks: ["A fountain plaza and new houses", "The inn honors its patron: rest costs half"],
    cost: 7000,
    requires: {
      line: "The council funds a patron who lives here: own your house",
      met: (state) => state.house.owned,
    },
  },
  {
    tier: 4,
    name: "City",
    blurb: "Paved streets, lamplit avenues, full houses. Pixelheim, city of the Ashenreach.",
    perks: ["Paved avenues, more homes, more citizens", "Merchants pay 20% more for everything you sell"],
    cost: 15000,
    requires: {
      line: "A city stands on commerce: own all three businesses",
      met: (state) => Object.keys(PROPERTY_PRICES).every((mapId) => state.properties.includes(mapId)),
    },
  },
];

export const MAX_TOWN_TIER = TOWN_TIERS.length;

export function townTierOf(state: GameState): number {
  return Math.min(MAX_TOWN_TIER, Math.max(1, state.townTier ?? 1));
}

export function currentTier(state: GameState): TownTier {
  return TOWN_TIERS[townTierOf(state) - 1];
}

/** The tier the ledger offers next, or null at the cap. */
export function nextTier(state: GameState): TownTier | null {
  return TOWN_TIERS[townTierOf(state)] ?? null;
}

/** Why the next tier cannot be funded right now, or null when it can. */
export function fundBlocker(state: GameState): string | null {
  const next = nextTier(state);
  if (!next) return "Pixelheim stands at its full height.";
  if (next.requires && !next.requires.met(state)) return next.requires.line;
  if (state.gold < (next.cost ?? 0)) return `The treasury asks ${next.cost}g.`;
  return null;
}

// ---------------- what the tiers buy ----------------

/** Village rent: every property pays one coin more per victory. */
export function rentPerProperty(tier: number): number {
  return RENT_PER_VICTORY + (tier >= 2 ? 1 : 0);
}

/** Town inns respect their patron: half price from tier 3. */
export function restCostFor(tier: number): number {
  return tier >= 3 ? Math.ceil(REST_COST / 2) : REST_COST;
}

export { sellMultiplier } from "./shop";
