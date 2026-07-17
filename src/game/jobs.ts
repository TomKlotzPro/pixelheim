import { FORGE_BONUS_CAP, forgeCost } from "./shop";
import type { Hero, Item, JobId, Jobs } from "./types";

/**
 * Each job earns XP from the system it belongs to and pays off inside that
 * same system - no combat power. Types live in types.ts with the rest.
 */
export type { JobId, JobProgress, Jobs } from "./types";

export const JOB_NAMES: Record<JobId, string> = {
  smithing: "Smithing",
  alchemy: "Alchemy",
  foraging: "Foraging",
};

export const JOB_LEVEL_CAP = 10;

/** Where each craft happens: the trade's station, not the open road. */
export const JOB_STATIONS: Record<"smithing" | "alchemy", { mapId: string; hint: string }> = {
  smithing: { mapId: "town_smith", hint: "Craft at Hilda's forge - the FORGE door in town" },
  alchemy: { mapId: "town_alchemist", hint: "Craft at Vex's cauldron - the BREWS door in town" },
};

/** XP the job needs to reach the next level. */
export function jobXpToNext(level: number): number {
  return 20 + level * 15;
}

export function freshJobs(): Jobs {
  return {
    smithing: { level: 1, xp: 0 },
    alchemy: { level: 1, xp: 0 },
    foraging: { level: 1, xp: 0 },
  };
}

/** Grants job XP and applies level-ups; returns levels gained. Mutates the draft hero. */
export function grantJobXp(hero: Hero, job: JobId, xp: number): number {
  const progress = hero.jobs[job];
  if (progress.level >= JOB_LEVEL_CAP) return 0;
  progress.xp += xp;
  let gained = 0;
  while (progress.level < JOB_LEVEL_CAP && progress.xp >= jobXpToNext(progress.level)) {
    progress.xp -= jobXpToNext(progress.level);
    progress.level += 1;
    gained += 1;
  }
  return gained;
}

// ---------------- what the levels buy ----------------

/** Smithing: every level shaves 4% off Hilda's forge prices (min 20g floor holds). */
export function forgeCostFor(item: Item, currentBonus: number, smithing: number): number {
  const base = forgeCost(item, currentBonus);
  return Math.max(20, Math.round(base * (1 - 0.04 * (smithing - 1))));
}

/** Smithing 5 unlocks the +8 masterwork cap. */
export function forgeCapFor(smithing: number): number {
  return FORGE_BONUS_CAP + (smithing >= 5 ? 1 : 0);
}

/** Alchemy: 6% per level chance to brew a second item for free. */
export function doubleBrewChance(alchemy: number): number {
  return Math.min(0.5, 0.06 * (alchemy - 1));
}

/** Foraging: better odds to find anything, and to find two. */
export function forageChance(foraging: number): number {
  return Math.min(0.95, 0.6 + 0.03 * (foraging - 1));
}

export function doubleForageChance(foraging: number): number {
  return Math.min(0.8, 0.35 + 0.04 * (foraging - 1));
}
