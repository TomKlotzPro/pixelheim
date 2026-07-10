import { getItem } from "./items";
import { ROLES } from "./roles";
import type { Equipped, Hero, RoleId, Stats } from "./types";

export function xpToNext(level: number): number {
  return 20 + level * 18;
}

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
  };
}

/** Applies pending XP, returns the number of levels gained. Levels fully heal. */
export function applyLevelUps(hero: Hero): number {
  const role = ROLES[hero.roleId];
  let gained = 0;
  while (hero.xp >= hero.xpToNext) {
    hero.xp -= hero.xpToNext;
    hero.level += 1;
    hero.xpToNext = xpToNext(hero.level);
    const stats = hero.stats as Stats;
    for (const key of Object.keys(role.growth) as (keyof Stats)[]) {
      stats[key] += role.growth[key];
    }
    hero.hp = stats.maxHp;
    hero.mp = stats.maxMp;
    gained += 1;
  }
  return gained;
}

export function weaponOf(equipped: Equipped) {
  return equipped.weapon ? getItem(equipped.weapon) : null;
}

export function totalArmor(equipped: Equipped): number {
  return (["body", "offhand"] as const).reduce(
    (sum, slot) => sum + (equipped[slot] ? (getItem(equipped[slot]!).armor ?? 0) : 0),
    0,
  );
}

export function carryCapacity(hero: Hero): number {
  return 60 + hero.stats.strength * 3;
}

export function carriedWeight(inventory: Record<string, number>): number {
  return Object.entries(inventory).reduce((sum, [id, count]) => sum + getItem(id).weight * count, 0);
}
