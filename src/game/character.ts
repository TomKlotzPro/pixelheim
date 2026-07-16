import { getItem } from "./items";
import { gearArmor, gearItem } from "./rarity";
import { ROLES } from "./roles";
import { getPassives, rootNode } from "./skillTree";
import type { Equipped, GearInstance, Hero, RoleId } from "./types";

export function xpToNext(level: number): number {
  return 20 + level * 18;
}

/** Combat-stat points banked per level, spent by the player. */
export const STAT_POINTS_PER_LEVEL = 5;

export function createHero(name: string, roleId: RoleId): Hero {
  const role = ROLES[roleId];
  return {
    name,
    roleId,
    level: 1,
    xp: 0,
    xpToNext: xpToNext(1),
    hp: role.baseStats.maxHp,
    mp: role.baseStats.maxMp,
    stats: { ...role.baseStats },
    statPoints: 0,
    skillPoints: 0,
    skillNodes: [rootNode(roleId).id],
  };
}

/**
 * Applies pending XP, returns the number of levels gained. Levels fully heal,
 * grow HP/MP by role, and bank stat points for the player to place.
 */
export function applyLevelUps(hero: Hero): number {
  const role = ROLES[hero.roleId];
  let gained = 0;
  while (hero.xp >= hero.xpToNext) {
    hero.xp -= hero.xpToNext;
    hero.level += 1;
    hero.xpToNext = xpToNext(hero.level);
    hero.stats.maxHp += role.growth.maxHp;
    hero.stats.maxMp += role.growth.maxMp;
    hero.statPoints += STAT_POINTS_PER_LEVEL;
    hero.skillPoints += 1;
    hero.hp = hero.stats.maxHp;
    hero.mp = hero.stats.maxMp;
    gained += 1;
  }
  return gained;
}

export function gearByUid(gear: GearInstance[], uid: string | undefined): GearInstance | null {
  if (!uid) return null;
  return gear.find((g) => g.uid === uid) ?? null;
}

export function weaponOf(gear: GearInstance[], equipped: Equipped): GearInstance | null {
  return gearByUid(gear, equipped.weapon);
}

export function totalArmor(gear: GearInstance[], equipped: Equipped): number {
  return (["body", "offhand"] as const).reduce((sum, slot) => {
    const instance = gearByUid(gear, equipped[slot]);
    return sum + (instance ? gearArmor(instance) : 0);
  }, 0);
}

export function carryCapacity(hero: Hero): number {
  return 60 + hero.stats.strength * 3 + getPassives(hero).carryBonus;
}

/** Innate defense plus armor plus passive skill effects. */
export function totalDefense(hero: Hero, gear: GearInstance[], equipped: Equipped): number {
  return hero.stats.defense + totalArmor(gear, equipped) + getPassives(hero).defense;
}

/** Stackables plus unequipped gear; what you wear does not weigh you down. */
export function carriedWeight(inventory: Record<string, number>, gear: GearInstance[], equipped: Equipped): number {
  const equippedUids = new Set(Object.values(equipped));
  const stacks = Object.entries(inventory).reduce((sum, [id, count]) => sum + getItem(id).weight * count, 0);
  const carriedGear = gear.reduce(
    (sum, instance) => sum + (equippedUids.has(instance.uid) ? 0 : gearItem(instance).weight),
    0,
  );
  return stacks + carriedGear;
}
