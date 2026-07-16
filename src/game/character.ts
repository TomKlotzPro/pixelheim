import { getItem } from "./items";
import { gearArmor, gearItem } from "./rarity";
import { ROLES } from "./roles";
import type { Equipped, GearInstance, Hero, RoleId, Stats } from "./types";

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
  return 60 + hero.stats.strength * 3;
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
