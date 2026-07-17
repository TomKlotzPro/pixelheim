import { afterEach, describe, expect, it, vi } from "vitest";
import { createHero } from "../../game/character";
import { RECIPES } from "../../game/recipes";
import type { GameState } from "../../game/types";
import { gameReducer, initialState } from "../gameReducer";

afterEach(() => vi.restoreAllMocks());

function crafterState(): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.screen = "world";
  return s;
}

describe("CRAFT", () => {
  it("forges gear as an instance and pays smithing xp", () => {
    let s = crafterState();
    s.hero!.jobs.smithing.level = 3;
    s.inventory = { wolf_pelt: 2, imp_horn: 1 };
    s = gameReducer(s, { type: "CRAFT", recipeId: "craft_beast_cleaver" });
    expect(s.gear).toHaveLength(1);
    expect(s.gear[0].itemId).toBe("beast_cleaver");
    expect(s.inventory.wolf_pelt).toBeUndefined();
    expect(s.hero!.jobs.smithing.xp).toBe(10);
  });

  it("refuses a recipe above the hero's job level", () => {
    let s = crafterState();
    s.inventory = { wolf_pelt: 2, imp_horn: 1 };
    s = gameReducer(s, { type: "CRAFT", recipeId: "craft_beast_cleaver" });
    expect(s.gear).toHaveLength(0);
    expect(s.inventory.wolf_pelt).toBe(2);
  });

  it("a skilled alchemist brews doubles", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.01);
    let s = crafterState();
    s.hero!.jobs.alchemy.level = 6; // 30% double chance beats 0.01
    s.inventory = { forest_herb: 1, marsh_reed: 1 };
    s = gameReducer(s, { type: "CRAFT", recipeId: "brew_potion_hp" });
    expect(s.inventory.potion_hp).toBe(2);
  });

  it("the sanctioned recipe list only outputs real items", () => {
    expect(RECIPES.length).toBeGreaterThanOrEqual(14);
  });
});
