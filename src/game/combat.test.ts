import { afterEach, describe, expect, it, vi } from "vitest";
import { createHero } from "./character";
import {
  consumeStun,
  fleeChance,
  heroAttackDamage,
  isStunned,
  monsterAttackDamage,
  rollInfliction,
  spawnMonster,
  tickDamageEffects,
} from "./combat";
import { getMonster } from "./monsters";
import type { StatusEffect } from "./types";

afterEach(() => vi.restoreAllMocks());

/** variance() at random=0.5 multiplies by exactly 1.0, so damage math is exact. */
const neutralRng = () => vi.spyOn(Math, "random").mockReturnValue(0.5);

describe("spawnMonster", () => {
  it("elites scale hp/attack/xp/gold by 1.5 and defense by 1.3", () => {
    const base = getMonster("slime");
    const elite = spawnMonster({ monsterId: "slime", elite: true });
    expect(elite.name).toBe(`Elite ${base.name}`);
    expect(elite.maxHp).toBe(Math.round(base.maxHp * 1.5));
    expect(elite.attack).toBe(Math.round(base.attack * 1.5));
    expect(elite.defense).toBe(Math.round(base.defense * 1.3));
    expect(elite.xp).toBe(Math.round(base.xp * 1.5));
    expect(elite.gold).toBe(Math.round(base.gold * 1.5));
  });

  it("normal spawns copy the bestiary entry", () => {
    const base = getMonster("slime");
    const normal = spawnMonster({ monsterId: "slime" });
    expect(normal.hp).toBe(base.maxHp);
    expect(normal.elite).toBe(false);
  });
});

describe("heroAttackDamage", () => {
  it("scales with strength and is reduced by monster defense", () => {
    neutralRng();
    const hero = createHero("T", "warrior");
    const monster = spawnMonster({ monsterId: "slime" });
    hero.stats.strength = 10;
    const weak = heroAttackDamage(hero, [], {}, monster);
    hero.stats.strength = 20;
    const strong = heroAttackDamage(hero, [], {}, monster);
    // unarmed: raw = STR + 2, minus defense
    expect(weak).toBe(Math.max(1, 12 - monster.defense));
    expect(strong).toBe(Math.max(1, 22 - monster.defense));
    expect(strong).toBeGreaterThan(weak);
  });

  it("never deals less than 1", () => {
    neutralRng();
    const hero = createHero("T", "warrior");
    hero.stats.strength = 1;
    const tank = spawnMonster({ monsterId: "slime" });
    tank.defense = 999;
    expect(heroAttackDamage(hero, [], {}, tank)).toBe(1);
  });
});

describe("monsterAttackDamage", () => {
  it("is reduced by the hero's total defense and floors at 1", () => {
    neutralRng();
    const hero = createHero("T", "warrior");
    const monster = spawnMonster({ monsterId: "slime" });
    hero.stats.defense = 0;
    const soft = monsterAttackDamage(monster, hero, [], {});
    hero.stats.defense = 999;
    const hard = monsterAttackDamage(monster, hero, [], {});
    expect(soft).toBe(Math.max(1, monster.attack));
    expect(hard).toBe(1);
  });
});

describe("fleeChance", () => {
  it("scales with dexterity and caps at 95%", () => {
    const hero = createHero("T", "rogue");
    hero.stats.dexterity = 10;
    expect(fleeChance(hero, [], {})).toBeCloseTo(0.6);
    hero.stats.dexterity = 999;
    expect(fleeChance(hero, [], {})).toBe(0.95);
  });
});

describe("status effects", () => {
  it("rollInfliction applies under the chance and refreshes to the higher values", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.1);
    const first = rollInfliction([], { kind: "poison", chance: 0.5, turns: 3, power: 2 });
    expect(first.applied).toBe(true);
    const refreshed = rollInfliction(first.effects, { kind: "poison", chance: 0.5, turns: 1, power: 5 });
    expect(refreshed.effects).toEqual([{ kind: "poison", turnsLeft: 3, power: 5 }]);
  });

  it("rollInfliction misses at or above the chance", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.5);
    const roll = rollInfliction([], { kind: "burn", chance: 0.5, turns: 2, power: 3 });
    expect(roll.applied).toBe(false);
    expect(roll.effects).toEqual([]);
  });

  it("tickDamageEffects damages, counts down and expires, but never ticks stun", () => {
    const effects: StatusEffect[] = [
      { kind: "poison", turnsLeft: 2, power: 3 },
      { kind: "burn", turnsLeft: 1, power: 4 },
      { kind: "stun", turnsLeft: 1, power: 0 },
    ];
    const { effects: remaining, ticks } = tickDamageEffects(effects);
    expect(ticks).toEqual([
      { kind: "poison", damage: 3 },
      { kind: "burn", damage: 4 },
    ]);
    expect(remaining).toEqual([
      { kind: "poison", turnsLeft: 1, power: 3 },
      { kind: "stun", turnsLeft: 1, power: 0 },
    ]);
  });

  it("consumeStun spends one stunned turn and drops it at zero", () => {
    const stunned: StatusEffect[] = [{ kind: "stun", turnsLeft: 1, power: 0 }];
    expect(isStunned(stunned)).toBe(true);
    const after = consumeStun(stunned);
    expect(after).toEqual([]);
    expect(isStunned(after)).toBe(false);
  });
});
