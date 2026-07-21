import type { GameState } from "../types";

/**
 * The bank (PIX-93): gold that works. Everything resolves deterministically
 * from worldSteps - no wall clock, no unseeded dice - so saves, the sim and
 * replays all agree. Mirelle the Banker (a tier-3 settler) keeps the ledger.
 */
export type Investments = {
  /** The savings pot: safe, slow, capped - not a money printer. */
  savings?: { principal: number; at: number };
  /** One caravan at a time: real risk, resolved after half a day on the road. */
  venture?: { stake: number; at: number };
  /** Owned businesses expanded for richer rent (mapIds). */
  expansions: string[];
};

/** One in-game day, in world steps - the same wheel the sky turns on. */
export const DAY_STEPS = 480;
export const SAVINGS_RATE = 0.02;
export const SAVINGS_MAX_DAYS = 10;
export const VENTURE_COST = 500;
export const VENTURE_STEPS = 240;
export const EXPANSION_COST = 1000;
/** Extra rent per victory from an expanded business. */
export const EXPANSION_RENT = 2;

export function investmentsOf(state: GameState): Investments {
  return state.investments ?? { expansions: [] };
}

/** Days accrued so far, capped: interest rewards patience, not parking. */
export function savingsDays(savings: { at: number }, steps: number): number {
  return Math.min(SAVINGS_MAX_DAYS, Math.max(0, Math.floor((steps - savings.at) / DAY_STEPS)));
}

/** What the pot is worth right now. */
export function savingsValue(savings: { principal: number; at: number }, steps: number): number {
  return Math.floor(savings.principal * (1 + SAVINGS_RATE * savingsDays(savings, steps)));
}

export function ventureReady(venture: { at: number }, steps: number): boolean {
  return steps - venture.at >= VENTURE_STEPS;
}

/**
 * The caravan's fate, sealed the moment it left: a hash of departure step and
 * stake. About two roads in three come home heavy; the rest limp back light.
 */
export function ventureOutcome(venture: { stake: number; at: number }): { won: boolean; payout: number } {
  let h = (venture.at * 2654435761 + venture.stake * 97) >>> 0;
  h = ((h ^ (h >>> 13)) * 1274126177) >>> 0;
  const won = h % 100 < 65;
  return { won, payout: won ? Math.floor(venture.stake * 1.6) : Math.floor(venture.stake * 0.4) };
}

/** The landlord's improved cut: expanded owned businesses pay extra rent. */
export function expansionRent(state: GameState): number {
  const inv = investmentsOf(state);
  return inv.expansions.filter((mapId) => state.properties.includes(mapId)).length * EXPANSION_RENT;
}
