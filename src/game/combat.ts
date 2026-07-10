import { totalArmor, weaponOf } from "./character";
import { getMonster } from "./monsters";
import { ROLES } from "./roles";
import type { BattleMonster, EncounterDef, Equipped, Hero } from "./types";

export function spawnMonster(def: EncounterDef): BattleMonster {
  const base = getMonster(def.monsterId);
  const mult = def.elite ? 1.5 : 1;
  const maxHp = Math.round(base.maxHp * mult);
  return {
    def: base,
    name: def.elite ? `Elite ${base.name}` : base.name,
    hp: maxHp,
    maxHp,
    attack: Math.round(base.attack * mult),
    defense: Math.round(base.defense * (def.elite ? 1.3 : 1)),
    xp: Math.round(base.xp * mult),
    gold: Math.round(base.gold * mult),
  };
}

function variance(base: number): number {
  return Math.max(1, Math.round(base * (0.85 + Math.random() * 0.3)));
}

export function heroAttackDamage(hero: Hero, equipped: Equipped, monster: BattleMonster): number {
  const weapon = weaponOf(equipped);
  const stat = hero.stats[weapon?.scaling ?? "strength"];
  const raw = stat + (weapon?.damage ?? 2);
  return Math.max(1, variance(raw) - monster.defense);
}

export function heroSkillPower(hero: Hero): number {
  const skill = ROLES[hero.roleId].skill;
  return Math.round(hero.stats[skill.stat] * skill.multiplier);
}

export function heroSkillDamage(hero: Hero, monster: BattleMonster): number {
  return Math.max(1, variance(heroSkillPower(hero)) - Math.floor(monster.defense / 2));
}

export function monsterAttackDamage(monster: BattleMonster, hero: Hero, equipped: Equipped): number {
  const mitigation = hero.stats.defense + totalArmor(equipped);
  return Math.max(1, variance(monster.attack) - mitigation);
}

export function fleeChance(hero: Hero): number {
  return Math.min(0.9, 0.4 + hero.stats.dexterity * 0.02);
}
