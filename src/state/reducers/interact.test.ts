import { describe, expect, it } from "vitest";
import { createHero } from "../../game/character";
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
    let s = townState(15, 8, "left");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue?.npcId).toBe("elder");
    expect(s.world!.position.facing).toBe("right"); // the hero turned to face her
  });

  it("prefers the faced tile when two sides could answer", () => {
    const beside = npcBeside("town", 15, 8, "right", 0);
    expect(beside?.npc.id).toBe("elder");
    expect(beside?.facing).toBe("right");
  });

  it("still does nothing with nobody around", () => {
    let s = townState(2, 16, "down");
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue).toBeNull();
  });
});
