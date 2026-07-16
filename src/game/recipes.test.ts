import { describe, expect, it } from "vitest";
import { getItem } from "./items";
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
    const exact: Record<string, number> = { ...recipe.needs };
    expect(canCraft(recipe, exact)).toBe(true);
    const short = { ...exact };
    const firstNeed = Object.keys(short)[0];
    short[firstNeed] -= 1;
    expect(canCraft(recipe, short)).toBe(false);
    expect(canCraft(recipe, {})).toBe(false);
  });

  it("every encounter region forages a real material", () => {
    for (const material of Object.values(REGION_MATERIALS)) {
      expect(getItem(material)).toBeDefined();
    }
  });
});
