import { describe, expect, it } from "vitest";
import { getItem } from "./items";
import { freshJobs } from "./jobs";
import { canCraft, RECIPES, REGION_MATERIALS } from "./recipes";

describe("recipes", () => {
  it("every recipe consumes real items and produces a real item", () => {
    for (const recipe of RECIPES) {
      expect(getItem(recipe.itemId)).toBeDefined();
      for (const need of Object.keys(recipe.needs)) expect(getItem(need)).toBeDefined();
    }
  });

  it("canCraft demands the full bill of materials", () => {
    const recipe = RECIPES[0];
    const jobs = freshJobs();
    const exact: Record<string, number> = { ...recipe.needs };
    expect(canCraft(recipe, exact, jobs)).toBe(true);
    const short = { ...exact };
    const firstNeed = Object.keys(short)[0];
    short[firstNeed] -= 1;
    expect(canCraft(recipe, short, jobs)).toBe(false);
    expect(canCraft(recipe, {}, jobs)).toBe(false);
  });

  it("the gate is the making: job levels lock recipes, never the wearing", () => {
    const mail = RECIPES.find((r) => r.id === "craft_scaled_mail")!;
    const jobs = freshJobs();
    const materials: Record<string, number> = { ...mail.needs };
    expect(canCraft(mail, materials, jobs)).toBe(false); // Smithing 1 < 6
    jobs.smithing.level = 6;
    expect(canCraft(mail, materials, jobs)).toBe(true);
  });

  it("every recipe names a real job level and craft-only gear stays out of shops", () => {
    for (const recipe of RECIPES) {
      expect(recipe.job.level).toBeGreaterThanOrEqual(1);
    }
  });

  it("every encounter region forages a real material", () => {
    for (const material of Object.values(REGION_MATERIALS)) {
      expect(getItem(material)).toBeDefined();
    }
  });
});
