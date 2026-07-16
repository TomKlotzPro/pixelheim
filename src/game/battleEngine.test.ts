import { afterEach, describe, expect, it, vi } from "vitest";
import { initialState } from "../state/gameReducer";
import type { GameState } from "./types";
import { createDungeonBattle, createWildBattle, grantFloorRewards, heroAttack, heroStunGate } from "./battleEngine";
import { createHero } from "./character";
import { getLevel } from "./levels";

afterEach(() => vi.restoreAllMocks());

/** random=0.5: neutral variance, no crits, drops and forage resolve deterministically. */
const neutralRng = () => vi.spyOn(Math, "random").mockReturnValue(0.5);

function dungeonState(): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.screen = "battle";
  s.battle = createDungeonBattle(1);
  return s;
}

describe("createDungeonBattle", () => {
  it("opens on the floor's first encounter with a narrated log", () => {
    const battle = createDungeonBattle(1);
    expect(battle.dungeonLevel).toBe(1);
    expect(battle.encounterIndex).toBe(0);
    expect(battle.phase).toBe("player");
    expect(battle.log.some((line) => line.includes(getLevel(1).name))).toBe(true);
  });
});

describe("heroAttack", () => {
  it("kills, pays out XP and gold, and advances the phase", () => {
    neutralRng();
    const s = dungeonState();
    s.hero!.stats.strength = 50;
    s.battle!.monster.hp = 1;
    const goldBefore = s.gold;
    heroAttack(s);
    expect(s.battle!.monster.hp).toBe(0);
    expect(["won", "cleared"]).toContain(s.battle!.phase);
    expect(s.gold).toBeGreaterThan(goldBefore);
    // XP was paid: either banked toward the next level or already leveled up
    expect(s.hero!.xp > 0 || s.hero!.level > 1).toBe(true);
    // ailments never linger between fights
    expect(s.battle!.heroEffects).toEqual([]);
  });

  it("a surviving monster answers back", () => {
    neutralRng();
    const s = dungeonState();
    s.hero!.stats.strength = 1;
    s.hero!.stats.defense = 0;
    s.battle!.monster.hp = 9999;
    s.battle!.monster.maxHp = 9999;
    const hpBefore = s.hero!.hp;
    heroAttack(s);
    expect(s.battle!.monster.hp).toBeLessThan(9999);
    expect(s.hero!.hp).toBeLessThan(hpBefore);
  });
});

describe("heroStunGate", () => {
  it("wastes the stunned hero's turn and lets the monster act", () => {
    neutralRng();
    const s = dungeonState();
    s.hero!.stats.defense = 0;
    s.battle!.heroEffects = [{ kind: "stun", turnsLeft: 1, power: 0 }];
    const hpBefore = s.hero!.hp;
    const skipped = heroStunGate(s, s.hero!, s.battle!.log);
    expect(skipped).toBe(true);
    expect(s.battle!.heroEffects).toEqual([]);
    expect(s.hero!.hp).toBeLessThan(hpBefore);
  });

  it("does nothing when the hero is clear-headed", () => {
    const s = dungeonState();
    expect(heroStunGate(s, s.hero!, s.battle!.log)).toBe(false);
  });
});

describe("wild battles", () => {
  it("wild wins forage the region's material and return quietly", () => {
    neutralRng();
    const s = structuredClone(initialState);
    s.hero = createHero("Tess", "warrior");
    s.hero.stats.strength = 50;
    s.screen = "battle";
    s.battle = createWildBattle({
      def: { monsterId: "slime" },
      dropFloor: 1,
      regionName: "the Greenwood",
      regionId: "forest",
    });
    s.battle.monster.hp = 1;
    heroAttack(s);
    expect(s.battle!.phase).toBe("cleared");
    expect(s.inventory.forest_herb).toBe(1);
  });

  it("wild rewards are reduced from the bestiary numbers", () => {
    const battle = createWildBattle({
      def: { monsterId: "slime" },
      dropFloor: 1,
      regionName: "the Greenwood",
      regionId: "forest",
    });
    const dungeonMonster = createDungeonBattle(1).monster;
    expect(battle.wild).toBe(true);
    expect(battle.monster.xp).toBeLessThan(Math.max(2, dungeonMonster.xp));
  });
});

describe("grantFloorRewards", () => {
  it("pays the floor's gold, items and unlocks the next floor", () => {
    const s = dungeonState();
    const level = getLevel(1);
    const goldBefore = s.gold;
    grantFloorRewards(s, 1);
    expect(s.clearedLevels).toContain(1);
    expect(s.gold).toBe(goldBefore + level.rewardGold);
    expect(s.unlockedLevel).toBeGreaterThanOrEqual(2);
  });
});
