import { afterEach, describe, expect, it, vi } from "vitest";
import { createHero } from "../../game/hero/character";
import type { GameState } from "../../game/types";
import { CHESTS } from "../../world/chests";
import { gameReducer, initialState } from "../gameReducer";

afterEach(() => vi.restoreAllMocks());

/** A hero standing at (x,y) on a map, ready to loot. */
function explorerState(mapId: string, x: number, y: number, facing: "up" | "down" | "left" | "right"): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "rogue");
  s.screen = "world";
  s.world = { position: { mapId, x, y, facing }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("chests", () => {
  it("validates every placement at load", () => {
    expect(CHESTS.length).toBeGreaterThanOrEqual(10);
  });

  it("opens the chest the hero faces and gives exactly once", () => {
    // town_corner at (1,16): 2x potion_hp
    let s = explorerState("town", 1, 15, "down");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.inventory.potion_hp).toBe(2);
    expect(s.world!.openedChests).toContain("town_corner");
    expect(s.worldMessage).toMatch(/chest holds/i);
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.inventory.potion_hp).toBe(2);
  });

  it("pays gold from the town nook", () => {
    let s = explorerState("town", 31, 8, "down");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.gold).toBe(initialState.gold + 60);
    expect(s.world!.openedChests).toContain("town_nook");
  });

  it("stays shut when the loot would break the hero's back", () => {
    let s = explorerState("overworld", 3, 6, "left"); // ash_west: iron_sword gear
    s.inventory = { iron_armor: 20 }; // 320 weight, heavier than any capacity
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.world!.openedChests).toHaveLength(0);
    expect(s.gear).toHaveLength(0);
    expect(s.worldMessage).toMatch(/too heavy/i);
  });

  it("grants gear as an instance", () => {
    let s = explorerState("overworld", 3, 6, "left");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.gear.map((g) => g.itemId)).toContain("iron_sword");
    expect(s.world!.openedChests).toContain("ash_west");
  });

  it("blocks walking through a chest but turns the hero toward it", () => {
    let s = explorerState("town", 1, 15, "right");
    s = gameReducer(s, { type: "MOVE", direction: "down" });
    expect(s.world!.position).toMatchObject({ x: 1, y: 15, facing: "down" });
  });

  it("takes ground treasure in stride", () => {
    let s = explorerState("overworld", 19, 29, "right"); // road_glint at (20,29)
    s = gameReducer(s, { type: "MOVE", direction: "right" });
    expect(s.world!.position).toMatchObject({ x: 20, y: 29 });
    expect(s.gold).toBe(initialState.gold + 45);
    expect(s.world!.openedChests).toContain("road_glint");
  });

  it("springs the mimic instead of paying out", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.99); // no elite roll
    let s = explorerState("mirefen", 22, 6, "left"); // mire_mimic at (21,6)
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.screen).toBe("battle");
    expect(s.battle!.monster.name).toMatch(/mimic/i);
    expect(s.battle!.wild).toBe(true);
    expect(s.world!.openedChests).toContain("mire_mimic"); // no second ambush
  });
});
