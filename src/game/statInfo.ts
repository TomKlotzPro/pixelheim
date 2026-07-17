import { applyStatPoint, carryCapacity, resourceLabel, staminaRegen, totalDefense, weaponOf } from "./character";
import { ROLES } from "./roles";
import { fleeChance, heroSkillPower } from "./combat";
import { gearDamage, gearItem } from "./rarity";
import { getHeroSkills } from "./skillTree";
import type { Equipped, GearInstance, Hero, SpendableStat } from "./types";

export type StatInfo = {
  /** What the stat does, in plain words. */
  blurb: string;
  /** Live derived numbers at the hero's current value. */
  now: string;
  /** The same numbers if one point were spent here. */
  next: string;
};

const BLURBS: Record<SpendableStat, string> = {
  strength: "Melee attack with STR weapons, and how much you can carry.",
  intelligence: "The power of your skills and heals - and for casters, the size of the mana pool.",
  dexterity: "Your chance to flee a fight you want no part of.",
  defense: "Damage shaved off every hit you take.",
  endurance: "Grit: a little health for everyone, and for fighters the stamina pool and how fast it refills.",
};

/** The hero after truly spending one point: pools included, nothing re-derived. */
function afterPoint(hero: Hero, stat: SpendableStat): Hero {
  const clone = structuredClone(hero);
  applyStatPoint(clone, stat);
  return clone;
}

/**
 * The derived numbers a stat drives, computed with the real combat formulas
 * (never re-derived here) so the sheet cannot drift from the game.
 */
function readout(stat: SpendableStat, hero: Hero, gear: GearInstance[], equipped: Equipped): string {
  const weapon = weaponOf(gear, equipped);
  const scaling = weapon ? (gearItem(weapon).scaling ?? "strength") : "strength";
  switch (stat) {
    case "strength": {
      const parts: string[] = [];
      if (scaling === "strength") parts.push(`ATK ${hero.stats.strength + (weapon ? gearDamage(weapon) : 2)}`);
      parts.push(`carry ${carryCapacity(hero)}`);
      return parts.join(" · ");
    }
    case "intelligence": {
      const parts: string[] = [];
      if (scaling === "intelligence") parts.push(`ATK ${hero.stats.intelligence + gearDamage(weapon!)}`);
      const spells = getHeroSkills(hero).filter((skill) => skill.stat === "intelligence");
      const strongest = spells.map((skill) => heroSkillPower(hero, skill)).toSorted((a, b) => b - a)[0];
      if (strongest !== undefined) parts.push(`skill power ${strongest}`);
      if (ROLES[hero.roleId].resource === "mana") parts.push(`MP ${hero.stats.maxMp}`);
      if (parts.length === 0) parts.push("powers INT skills");
      return parts.join(" · ");
    }
    case "dexterity":
      return `flee ${Math.round(fleeChance(hero) * 100)}%`;
    case "defense":
      return `blocks ${totalDefense(hero, gear, equipped)} per hit`;
    case "endurance": {
      const parts: string[] = [`HP ${hero.stats.maxHp}`];
      if (ROLES[hero.roleId].resource === "endurance") {
        parts.push(`${resourceLabel(hero.roleId)} ${hero.stats.maxMp}`, `regen ${staminaRegen(hero)}/turn`);
      }
      return parts.join(" · ");
    }
  }
}

/** Everything the stat sheet needs to explain a stat and preview a point. */
export function statInfo(stat: SpendableStat, hero: Hero, gear: GearInstance[], equipped: Equipped): StatInfo {
  return {
    blurb: BLURBS[stat],
    now: readout(stat, hero, gear, equipped),
    next: readout(stat, afterPoint(hero, stat), gear, equipped),
  };
}
