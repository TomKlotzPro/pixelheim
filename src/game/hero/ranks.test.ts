import { describe, expect, it } from "vitest";
import { applyLevelUps, createHero, xpToNext } from "./character";
import { rankIndex, rankPresence, rankTitle } from "./ranks";

describe("rank evolution", () => {
  it("ascends at levels 5, 10 and 15, then holds", () => {
    expect(rankIndex(1)).toBe(0);
    expect(rankIndex(4)).toBe(0);
    expect(rankIndex(5)).toBe(1);
    expect(rankIndex(9)).toBe(1);
    expect(rankIndex(10)).toBe(2);
    expect(rankIndex(15)).toBe(3);
    expect(rankIndex(40)).toBe(3);
  });

  it("titles follow the class ladder", () => {
    const mage = createHero("Wiz", "mage");
    expect(rankTitle(mage)).toBe("Apprentice");
    mage.level = 15;
    expect(rankTitle(mage)).toBe("Archmage");
    const necro = createHero("Morv", "necromancer");
    necro.level = 10;
    expect(rankTitle(necro)).toBe("Deathcaller");
  });

  it("crossing a rank pays a bonus skill point", () => {
    const hero = createHero("Climb", "warrior");
    hero.level = 4;
    hero.xpToNext = xpToNext(4);
    hero.xp = hero.xpToNext; // exactly one level: 4 -> 5, a rank boundary
    applyLevelUps(hero);
    expect(hero.level).toBe(5);
    expect(hero.skillPoints).toBe(2); // the level's point + the ascension bonus

    hero.xp = hero.xpToNext; // 5 -> 6, no boundary
    applyLevelUps(hero);
    expect(hero.skillPoints).toBe(3);
  });

  it("presence grows a notch per rank", () => {
    expect(rankPresence(1)).toBe(1);
    expect(rankPresence(15)).toBeCloseTo(1.15);
  });
});
