import { getItem } from "../economy/items";
import { freshJobs } from "../economy/jobs";
import { gearArmor, gearItem } from "../economy/rarity";
import { ROLES } from "./roles";
import { rankIndex } from "./ranks";
import { getPassives, rootNode } from "./skillTree";
import type { Equipped, GearInstance, GrantStat, Hero, RoleId, SpendableStat } from "../types";

export function xpToNext(level: number): number {
  return 20 + level * 18;
}

/** Combat-stat points banked per level, spent by the player. */
export const STAT_POINTS_PER_LEVEL = 5;

export function createHero(name: string, roleId: RoleId, look = 0): Hero {
  const role = ROLES[roleId];
  return {
    name,
    roleId,
    look,
    level: 1,
    xp: 0,
    xpToNext: xpToNext(1),
    hp: role.baseStats.maxHp,
    mp: role.baseStats.maxMp,
    stats: { ...role.baseStats },
    statPoints: 0,
    skillPoints: 0,
    skillNodes: [rootNode(roleId).id],
    jobs: freshJobs(),
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
    // Crossing a rank threshold grants a bonus point: ascension pays.
    if (rankIndex(hero.level) > rankIndex(hero.level - 1)) hero.skillPoints += 1;
    hero.hp = hero.stats.maxHp;
    hero.mp = hero.stats.maxMp;
    gained += 1;
  }
  return gained;
}

/** The hero's sprite, look applied: palette-swap variants share one grid. */
export function heroSprite(hero: Hero): string {
  const base = ROLES[hero.roleId].sprite;
  const look = hero.look ? `_l${hero.look}` : "";
  const rank = rankIndex(hero.level);
  return `${base}${look}${rank > 0 ? `_r${rank}` : ""}`;
}

/**
 * What shows ON the hero: the actual equipped items' sprites, worn at body
 * offsets (weapon in hand, shield on the arm, helm on the head). Offsets are
 * in 16px-art fractions so both renderers scale them identically.
 */
export const WORN_SLOTS = [
  { slot: "offhand", x: 0.02, y: 0.42, size: 0.5 },
  { slot: "head", x: 0.28, y: -0.18, size: 0.45 },
  { slot: "weapon", x: 0.55, y: 0.3, size: 0.6 },
] as const;

export function wornSprites(
  gear: GearInstance[],
  equipped: Equipped,
): { slot: string; sprite: string; x: number; y: number; size: number }[] {
  return WORN_SLOTS.flatMap(({ slot, x, y, size }) => {
    const instance = gearByUid(gear, equipped[slot]);
    return instance ? [{ slot, sprite: gearItem(instance).sprite, x, y, size }] : [];
  });
}

export function gearByUid(gear: GearInstance[], uid: string | undefined): GearInstance | null {
  if (!uid) return null;
  return gear.find((g) => g.uid === uid) ?? null;
}

export function weaponOf(gear: GearInstance[], equipped: Equipped): GearInstance | null {
  return gearByUid(gear, equipped.weapon);
}

/** Every worn position that can carry armor (everything but the weapon hand). */
export const ARMOR_SLOTS = ["body", "offhand", "head", "hands", "feet", "neck", "ring1", "ring2"] as const;

export function totalArmor(gear: GearInstance[], equipped: Equipped): number {
  return ARMOR_SLOTS.reduce((sum, slot) => {
    const instance = gearByUid(gear, equipped[slot]);
    return sum + (instance ? gearArmor(instance) : 0);
  }, 0);
}

/** Flat stat bonus from everything worn - jewelry, mostly. */
export function grantedStat(gear: GearInstance[], equipped: Equipped, stat: GrantStat): number {
  return Object.values(equipped).reduce((sum, uid) => {
    const instance = gearByUid(gear, uid);
    return sum + (instance ? (gearItem(instance).grants?.[stat] ?? 0) : 0);
  }, 0);
}

/** The stat the world actually feels: base plus everything worn. */
export function effectiveStat(hero: Hero, gear: GearInstance[], equipped: Equipped, stat: GrantStat): number {
  return hero.stats[stat] + grantedStat(gear, equipped, stat);
}

export function carryCapacity(hero: Hero, gear: GearInstance[], equipped: Equipped): number {
  return 60 + effectiveStat(hero, gear, equipped, "strength") * 3 + getPassives(hero).carryBonus;
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

/** What the hero's skill bar is made of: "MP" for casters, "EN" for martials. */
export function resourceLabel(roleId: RoleId): "MP" | "EN" {
  return ROLES[roleId].resource === "endurance" ? "EN" : "MP";
}

/** Martials catch their breath every combat round; casters do not. */
export function staminaRegen(hero: Hero): number {
  if (ROLES[hero.roleId].resource !== "endurance") return 0;
  return 1 + Math.floor(hero.stats.endurance / 6);
}

/**
 * One stat point, spent: the single source of truth for what a point buys,
 * used by both the reducer and the stat sheet's +1 preview. INT grows the
 * mana pool for casters; END grows the stamina pool for martials and gives
 * everyone a little health.
 */
export function applyStatPoint(hero: Hero, stat: SpendableStat): void {
  hero.stats[stat] += 1;
  const resource = ROLES[hero.roleId].resource;
  if (stat === "intelligence" && resource === "mana") {
    hero.stats.maxMp += 2;
    hero.mp += 2;
  }
  if (stat === "endurance") {
    hero.stats.maxHp += 1;
    hero.hp += 1;
    if (resource === "endurance") {
      hero.stats.maxMp += 2;
      hero.mp += 2;
    }
  }
}
