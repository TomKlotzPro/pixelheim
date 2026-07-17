import type { Hero, RoleId } from "../types";

/**
 * Rank evolution: every 5 levels the hero ascends - a new title, a stronger
 * presence in the world, and a bonus skill point at the moment of crossing.
 * Rank is derived from level (never stored), so old saves are already ranked.
 */
export const RANK_TITLES: Record<RoleId, [string, string, string, string]> = {
  warrior: ["Footman", "Warrior", "Champion", "Warlord"],
  mage: ["Apprentice", "Mage", "Magus", "Archmage"],
  rogue: ["Cutpurse", "Rogue", "Shadow", "Phantom"],
  cleric: ["Acolyte", "Cleric", "Prelate", "Saint"],
  ranger: ["Tracker", "Ranger", "Pathfinder", "Wildlord"],
  paladin: ["Squire", "Paladin", "Justicar", "Crusader"],
  necromancer: ["Gravedigger", "Necromancer", "Deathcaller", "Lichlord"],
};

/** Aura per rank: nothing, then silver, gold, radiant. Hex for both renderers. */
export const RANK_AURAS: [null, string, string, string] = [null, "#9ab0d8", "#e8c34a", "#4ae6c8"];

/** 0-3: ascends at levels 5, 10 and 15. */
export function rankIndex(level: number): number {
  return Math.min(3, Math.floor(level / 5));
}

export function rankTitle(hero: Hero): string {
  return RANK_TITLES[hero.roleId][rankIndex(hero.level)];
}

/** How much bigger the hero stands at this rank (sprite scale factor). */
export function rankPresence(level: number): number {
  return 1 + rankIndex(level) * 0.05;
}
