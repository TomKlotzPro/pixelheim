import { describe, expect, it } from "vitest";
import { createHero } from "../../game/hero/character";
import type { GameState } from "../../game/types";
import { gameReducer, initialState } from "../gameReducer";
import { npcBeside } from "../../world/npcs";

function townState(x: number, y: number, facing: "up" | "down" | "left" | "right"): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.screen = "world";
  s.world = { position: { mapId: "town", x, y, facing }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("friendly interact range", () => {
  // Elder Maren stands still at (16,8).
  it("chats with the NPC beside you even when you face away", () => {
    let s = townState(31, 16, "left");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue?.npcId).toBe("elder");
    expect(s.world!.position.facing).toBe("right"); // the hero turned to face her
  });

  it("prefers the faced tile when two sides could answer", () => {
    const beside = npcBeside("town", 31, 16, "right", 0);
    expect(beside?.npc.id).toBe("elder");
    expect(beside?.facing).toBe("right");
  });

  it("still does nothing with nobody around", () => {
    let s = townState(2, 16, "down");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue).toBeNull();
  });
});

// The shelf sits at (14,2) in town_house; the hero stands below, facing up.
function houseState(x: number, y: number, gold = 0) {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.screen = "world";
  s.gold = gold;
  s.house.owned = true;
  s.world = { position: { mapId: "town_house", x, y, facing: "up" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("home furniture answers to E (PIX-109)", () => {
  it("the shelf names the workbench price when the purse is light", () => {
    let s = houseState(14, 3, 100);
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.worldMessage).toContain("800g");
    expect(s.house.workbench).toBeUndefined();
    expect(s.gold).toBe(100);
  });

  it("the shelf takes the gold and fits the workbench", () => {
    let s = houseState(14, 3, 1000);
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.house.workbench).toBe(true);
    expect(s.gold).toBe(200);
    expect(s.worldMessage).toContain("workbench");
  });

  it("the fitted workbench opens the pack to craft from", () => {
    let s = houseState(14, 3, 1000);
    s = gameReducer(s, { type: "INTERACT" });
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.inventoryOpen).toBe(true);
  });

  it("the hearth and counter speak instead of staying silent", () => {
    // hearth at (16,4): stand below it
    let s = houseState(16, 5);
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.worldMessage).toContain("hearth crackles");

    // counter at (8,6): stand below it
    let c = houseState(8, 7);
    c = gameReducer(c, { type: "INTERACT" });
    expect(c.worldMessage).toContain("counter");
  });
});
