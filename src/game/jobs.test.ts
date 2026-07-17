import { describe, expect, it } from "vitest";
import { createHero } from "./character";
import {
  doubleBrewChance,
  forageChance,
  forgeCapFor,
  forgeCostFor,
  freshJobs,
  grantJobXp,
  JOB_LEVEL_CAP,
  jobXpToNext,
} from "./jobs";
import { getItem } from "./items";
import { forgeCost } from "./shop";

describe("job leveling", () => {
  it("fresh heroes start every job at level 1 with no xp", () => {
    const hero = createHero("Tess", "warrior");
    expect(hero.jobs).toEqual(freshJobs());
  });

  it("xp accumulates, levels chain, and the cap holds", () => {
    const hero = createHero("Tess", "warrior");
    expect(grantJobXp(hero, "alchemy", jobXpToNext(1) + jobXpToNext(2))).toBe(2);
    expect(hero.jobs.alchemy.level).toBe(3);
    hero.jobs.foraging.level = JOB_LEVEL_CAP;
    expect(grantJobXp(hero, "foraging", 999)).toBe(0);
    expect(hero.jobs.foraging.level).toBe(JOB_LEVEL_CAP);
  });
});

describe("what the levels buy", () => {
  it("smithing discounts the forge and unlocks the masterwork cap", () => {
    const sword = getItem("iron_sword");
    expect(forgeCostFor(sword, 0, 1)).toBe(forgeCost(sword, 0)); // level 1 = list price
    expect(forgeCostFor(sword, 3, 6)).toBeLessThan(forgeCost(sword, 3));
    expect(forgeCostFor(sword, 0, 10)).toBeGreaterThanOrEqual(20); // the floor holds
    expect(forgeCapFor(1)).toBe(7);
    expect(forgeCapFor(5)).toBe(8);
  });

  it("alchemy and foraging odds start at the old baselines and grow", () => {
    expect(doubleBrewChance(1)).toBe(0);
    expect(doubleBrewChance(6)).toBeCloseTo(0.3);
    expect(forageChance(1)).toBeCloseTo(0.6);
    expect(forageChance(11)).toBeLessThanOrEqual(0.95);
  });
});
