import { carryCapacity, totalDefense, weaponOf } from "./character";
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
  intelligence: "The power of your skills and heals (and INT weapons like staves).",
  dexterity: "Your chance to flee a fight you want no part of.",
  defense: "Damage shaved off every hit you take.",
};

function withStat(hero: Hero, stat: SpendableStat, value: number): Hero {
  return { ...hero, stats: { ...hero.stats, [stat]: value } };
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
      if (parts.length === 0) parts.push("powers INT skills");
      return parts.join(" · ");
    }
    case "dexterity":
      return `flee ${Math.round(fleeChance(hero) * 100)}%`;
    case "defense":
      return `blocks ${totalDefense(hero, gear, equipped)} per hit`;
  }
}

/** Everything the stat sheet needs to explain a stat and preview a point. */
export function statInfo(stat: SpendableStat, hero: Hero, gear: GearInstance[], equipped: Equipped): StatInfo {
  return {
    blurb: BLURBS[stat],
    now: readout(stat, hero, gear, equipped),
    next: readout(stat, withStat(hero, stat, hero.stats[stat] + 1), gear, equipped),
  };
}
