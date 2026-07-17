import { describe, expect, it } from "vitest";
import { applyLevelUps, applyStatPoint, carryCapacity, carriedWeight, createHero, resourceLabel, staminaRegen, STAT_POINTS_PER_LEVEL, xpToNext } from "./character";
import { getItem } from "../economy/items";
import { createGear } from "../economy/rarity";
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
    expect(carryCapacity(hero, [], {})).toBe(60 + 30);
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

describe("resources", () => {
  it("martials run on EN, casters on MP", () => {
    expect(resourceLabel("warrior")).toBe("EN");
    expect(resourceLabel("rogue")).toBe("EN");
    expect(resourceLabel("mage")).toBe("MP");
    expect(resourceLabel("cleric")).toBe("MP");
  });

  it("stamina regen scales with endurance and is zero for casters", () => {
    const warrior = createHero("Tess", "warrior");
    warrior.stats.endurance = 12;
    expect(staminaRegen(warrior)).toBe(3);
    const mage = createHero("Tess", "mage");
    expect(staminaRegen(mage)).toBe(0);
  });

  it("INT points grow the mana pool for casters only", () => {
    const mage = createHero("Tess", "mage");
    const before = mage.stats.maxMp;
    applyStatPoint(mage, "intelligence");
    expect(mage.stats.maxMp).toBe(before + 2);
    const warrior = createHero("Tess", "warrior");
    const wBefore = warrior.stats.maxMp;
    applyStatPoint(warrior, "intelligence");
    expect(warrior.stats.maxMp).toBe(wBefore);
  });

  it("END points give everyone health, and fighters stamina on top", () => {
    const warrior = createHero("Tess", "warrior");
    const hp = warrior.stats.maxHp;
    const pool = warrior.stats.maxMp;
    applyStatPoint(warrior, "endurance");
    expect(warrior.stats.maxHp).toBe(hp + 1);
    expect(warrior.stats.maxMp).toBe(pool + 2);
    const mage = createHero("Tess", "mage");
    const mPool = mage.stats.maxMp;
    applyStatPoint(mage, "endurance");
    expect(mage.stats.maxHp).toBe(29);
    expect(mage.stats.maxMp).toBe(mPool);
  });
});
