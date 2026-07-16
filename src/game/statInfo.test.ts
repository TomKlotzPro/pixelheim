import { describe, expect, it } from "vitest";
import { carryCapacity, createHero } from "./character";
import { createGear, gearDamage } from "./rarity";
import { statInfo } from "./statInfo";

describe("statInfo", () => {
  it("STR readout uses the real attack and carry formulas, and previews +1", () => {
    const hero = createHero("Tess", "warrior");
    const sword = createGear("iron_sword");
    const info = statInfo("strength", hero, [sword], { weapon: sword.uid });
    expect(info.now).toBe(`ATK ${hero.stats.strength + gearDamage(sword)} · carry ${carryCapacity(hero)}`);
    expect(info.next).toContain(`ATK ${hero.stats.strength + 1 + gearDamage(sword)}`);
  });

  it("unarmed STR still shows attack (fists count for 2)", () => {
    const hero = createHero("Tess", "warrior");
    expect(statInfo("strength", hero, [], {}).now).toContain(`ATK ${hero.stats.strength + 2}`);
  });

  it("DEX shows the flee percentage moving with the stat", () => {
    const hero = createHero("Tess", "rogue");
    hero.stats.dexterity = 10;
    const info = statInfo("dexterity", hero, [], {});
    expect(info.now).toBe("flee 60%");
    expect(info.next).toBe("flee 62%");
  });

  it("DEF shows blocked damage including armor", () => {
    const hero = createHero("Tess", "warrior");
    hero.stats.defense = 5;
    expect(statInfo("defense", hero, [], {}).now).toBe("blocks 5 per hit");
  });

  it("INT shows skill power for casters", () => {
    const hero = createHero("Tess", "mage");
    const info = statInfo("intelligence", hero, [], {});
    expect(info.now).toMatch(/skill power \d+/);
    expect(info.next).not.toBe(info.now);
  });
});
