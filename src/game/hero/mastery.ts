import type { Hero } from "../types";

/**
 * Monster mastery: every kill teaches. Kills are counted per FAMILY (the list
 * stays readable), thresholds grant permanent damage bonuses against that
 * family, and crossing one earns a slayer title worth announcing.
 */
export type Family = "beasts" | "greenskins" | "undead" | "constructs" | "fireborn";

export const FAMILY_OF: Record<string, Family> = {
  slime: "beasts",
  wolf: "beasts",
  goblin: "greenskins",
  orc: "greenskins",
  troll: "greenskins",
  skeleton: "undead",
  ghost: "undead",
  shade: "undead",
  boneknight: "undead",
  lich: "undead",
  golem: "constructs",
  mimic: "constructs",
  imp: "fireborn",
  wyvern: "fireborn",
  dragon: "fireborn",
};

export const FAMILY_NAMES: Record<Family, string> = {
  beasts: "Beasts",
  greenskins: "Greenskins",
  undead: "The Undead",
  constructs: "Constructs",
  fireborn: "The Fireborn",
};

/** Kills needed for tiers I / II / III, and the damage bonus each grants. */
export const MASTERY_TIERS = [
  { kills: 10, bonus: 0.05 },
  { kills: 25, bonus: 0.1 },
  { kills: 50, bonus: 0.15 },
] as const;

export function familyOf(monsterId: string): Family | null {
  return FAMILY_OF[monsterId] ?? null;
}

export function killsOf(hero: Hero, family: Family): number {
  return hero.mastery?.[family] ?? 0;
}

/** The mastery tier (0-3) reached against a family. */
export function masteryTier(hero: Hero, family: Family): number {
  const kills = killsOf(hero, family);
  let tier = 0;
  for (const t of MASTERY_TIERS) if (kills >= t.kills) tier += 1;
  return tier;
}

/** Damage multiplier bonus vs a monster (0 when unmastered or unknown). */
export function masteryBonus(hero: Hero, monsterId: string): number {
  const family = familyOf(monsterId);
  if (!family) return 0;
  const tier = masteryTier(hero, family);
  return tier > 0 ? MASTERY_TIERS[tier - 1].bonus : 0;
}

/**
 * Records a kill on the draft hero; returns the slayer announcement if a
 * tier was crossed, else null.
 */
export function recordKill(hero: Hero, monsterId: string): string | null {
  const family = familyOf(monsterId);
  if (!family) return null;
  if (!hero.mastery) hero.mastery = {};
  const before = masteryTier(hero, family);
  hero.mastery[family] = (hero.mastery[family] ?? 0) + 1;
  const after = masteryTier(hero, family);
  if (after > before) {
    const roman = ["I", "II", "III"][after - 1];
    const bonus = Math.round(MASTERY_TIERS[after - 1].bonus * 100);
    return `Mastery: ${FAMILY_NAMES[family]} Slayer ${roman} - +${bonus}% damage against ${FAMILY_NAMES[family].toLowerCase()}!`;
  }
  return null;
}
