import { describe, expect, it } from "vitest";
import { applyLevelUps, carryCapacity, carriedWeight, createHero, STAT_POINTS_PER_LEVEL, xpToNext } from "./character";
import { getItem } from "./items";
import { createGear } from "./rarity";
import { rootNode } from "./skillTree";

describe("createHero", () => {
  it("starts at level 1 with the role's free root skill and nothing banked", () => {
    const hero = createHero("Tess", "mage");
    expect(hero.level).toBe(1);
    expect(hero.statPoints).toBe(0);
    expect(hero.skillPoints).toBe(0);
    expect(hero.skillNodes).toEqual([rootNode("mage").id]);
    expect(hero.hp).toBe(hero.stats.maxHp);
  });
});

describe("applyLevelUps", () => {
  it("levels once, banks points, grows by role, and fully restores", () => {
    const hero = createHero("Tess", "warrior");
    const beforeHp = hero.stats.maxHp;
    hero.hp = 1;
    hero.xp = xpToNext(1);
    const gained = applyLevelUps(hero);
    expect(gained).toBe(1);
    expect(hero.level).toBe(2);
    expect(hero.xp).toBe(0);
    expect(hero.statPoints).toBe(STAT_POINTS_PER_LEVEL);
    expect(hero.skillPoints).toBe(1);
    expect(hero.stats.maxHp).toBeGreaterThan(beforeHp);
    expect(hero.hp).toBe(hero.stats.maxHp);
  });

  it("chains multiple level-ups from one XP windfall", () => {
    const hero = createHero("Tess", "warrior");
    hero.xp = xpToNext(1) + xpToNext(2);
    expect(applyLevelUps(hero)).toBe(2);
    expect(hero.level).toBe(3);
    expect(hero.statPoints).toBe(2 * STAT_POINTS_PER_LEVEL);
  });
});

describe("carry", () => {
  it("capacity grows with strength", () => {
    const hero = createHero("Tess", "warrior");
    hero.stats.strength = 10;
    expect(carryCapacity(hero)).toBe(60 + 30);
  });

  it("equipped gear weighs nothing; the pack does", () => {
    const sword = createGear("iron_sword");
    const cheeseWeight = getItem("cheese_wheel").weight;
    const swordWeight = getItem("iron_sword").weight;
    const carriedAll = carriedWeight({ cheese_wheel: 2 }, [sword], {});
    const wearingSword = carriedWeight({ cheese_wheel: 2 }, [sword], { weapon: sword.uid });
    expect(carriedAll).toBe(2 * cheeseWeight + swordWeight);
    expect(wearingSword).toBe(2 * cheeseWeight);
  });
});
