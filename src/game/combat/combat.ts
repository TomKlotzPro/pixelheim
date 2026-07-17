import { effectiveStat, totalDefense, weaponOf } from "../hero/character";
import { masteryBonus } from "../hero/mastery";
import { getMonster } from "./monsters";
import { gearDamage, gearItem } from "../economy/rarity";
import { getPassives } from "../hero/skillTree";
import type { BattleMonster, EncounterDef, Equipped, GearInstance, Hero, Infliction, Skill, StatusEffect } from "../types";

export function spawnMonster(def: EncounterDef): BattleMonster {
  const base = getMonster(def.monsterId);
  const mult = def.elite ? 1.5 : 1;
  const maxHp = Math.round(base.maxHp * mult);
  return {
    def: base,
    name: def.elite ? `Elite ${base.name}` : base.name,
    elite: def.elite ?? false,
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

export function heroAttackDamage(hero: Hero, gear: GearInstance[], equipped: Equipped, monster: BattleMonster): number {
  const weapon = weaponOf(gear, equipped);
  const stat = effectiveStat(hero, gear, equipped, weapon ? (gearItem(weapon).scaling ?? "strength") : "strength");
  let raw = stat + (weapon ? gearDamage(weapon) : 2);
  const passives = getPassives(hero);
  if (passives.critChance > 0 && Math.random() < passives.critChance) raw *= 1.5;
  if (passives.lowHpBonus > 0 && monster.hp / monster.maxHp < 0.3) raw *= 1 + passives.lowHpBonus;
  raw *= 1 + masteryBonus(hero, monster.def.id);
  return Math.max(1, variance(raw) - monster.defense);
}

export function heroSkillPower(hero: Hero, skill: Skill, gear: GearInstance[], equipped: Equipped): number {
  return Math.round(effectiveStat(hero, gear, equipped, skill.stat) * skill.multiplier);
}

export function heroSkillDamage(hero: Hero, skill: Skill, gear: GearInstance[], equipped: Equipped, monster: BattleMonster): number {
  const raw = heroSkillPower(hero, skill, gear, equipped) * (1 + masteryBonus(hero, monster.def.id));
  return Math.max(1, variance(raw) - Math.floor(monster.defense / 2));
}

export function monsterAttackDamage(monster: BattleMonster, hero: Hero, gear: GearInstance[], equipped: Equipped): number {
  return Math.max(1, variance(monster.attack) - totalDefense(hero, gear, equipped));
}

export function fleeChance(hero: Hero, gear: GearInstance[], equipped: Equipped): number {
  return Math.min(0.95, 0.4 + effectiveStat(hero, gear, equipped, "dexterity") * 0.02 + getPassives(hero).fleeBonus);
}

// ---------------- status effects ----------------

/**
 * Rolls an infliction against a combatant's active effects. On success the
 * effect is added, or refreshed if the same kind is already active (duration
 * and power both take the higher value; they never stack additively).
 */
export function rollInfliction(
  effects: StatusEffect[],
  infliction: Infliction | undefined,
): { effects: StatusEffect[]; applied: boolean } {
  if (!infliction || Math.random() >= infliction.chance) return { effects, applied: false };
  const current = effects.find((e) => e.kind === infliction.kind);
  const refreshed: StatusEffect = {
    kind: infliction.kind,
    turnsLeft: Math.max(infliction.turns, current?.turnsLeft ?? 0),
    power: Math.max(infliction.power, current?.power ?? 0),
  };
  return { effects: [...effects.filter((e) => e.kind !== infliction.kind), refreshed], applied: true };
}

/** Applies one tick of every damage-over-time effect and expires used-up ones. */
export function tickDamageEffects(effects: StatusEffect[]): {
  effects: StatusEffect[];
  ticks: { kind: StatusEffect["kind"]; damage: number }[];
} {
  const ticks: { kind: StatusEffect["kind"]; damage: number }[] = [];
  const remaining: StatusEffect[] = [];
  for (const effect of effects) {
    if (effect.kind === "stun") {
      remaining.push(effect);
      continue;
    }
    ticks.push({ kind: effect.kind, damage: effect.power });
    if (effect.turnsLeft > 1) remaining.push({ ...effect, turnsLeft: effect.turnsLeft - 1 });
  }
  return { effects: remaining, ticks };
}

export function isStunned(effects: StatusEffect[]): boolean {
  return effects.some((e) => e.kind === "stun");
}

/** Spends one stunned turn: decrements the stun and drops it once used up. */
export function consumeStun(effects: StatusEffect[]): StatusEffect[] {
  return effects
    .map((e) => (e.kind === "stun" ? { ...e, turnsLeft: e.turnsLeft - 1 } : e))
    .filter((e) => e.turnsLeft > 0);
}
