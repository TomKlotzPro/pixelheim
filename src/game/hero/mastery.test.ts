import { describe, expect, it } from "vitest";
import { createHero } from "./character";
import { FAMILY_OF, masteryBonus, masteryTier, recordKill } from "./mastery";
import { MONSTERS } from "../combat/monsters";

describe("monster mastery", () => {
  it("every monster belongs to a family", () => {
    for (const id of Object.keys(MONSTERS)) expect(FAMILY_OF[id], id).toBeDefined();
  });

  it("kills climb tiers and tiers pay damage", () => {
    const hero = createHero("Hunter", "ranger");
    expect(masteryBonus(hero, "wolf")).toBe(0);

    let announced: string | null = null;
    for (let i = 0; i < 10; i++) announced = recordKill(hero, "wolf");
    expect(announced).toMatch(/Beasts Slayer I/);
    expect(masteryTier(hero, "beasts")).toBe(1);
    expect(masteryBonus(hero, "slime")).toBeCloseTo(0.05); // family-wide

    for (let i = 0; i < 40; i++) announced = recordKill(hero, "slime");
    expect(announced).toMatch(/Slayer III/);
    expect(masteryBonus(hero, "wolf")).toBeCloseTo(0.15);
    // other families untouched
    expect(masteryBonus(hero, "ghost")).toBe(0);
  });

  it("old saves without mastery are simply unmastered", () => {
    const hero = createHero("Vet", "warrior");
    delete (hero as { mastery?: unknown }).mastery;
    expect(masteryBonus(hero, "dragon")).toBe(0);
    expect(() => recordKill(hero, "dragon")).not.toThrow();
    expect(hero.mastery?.fireborn).toBe(1);
  });
});
