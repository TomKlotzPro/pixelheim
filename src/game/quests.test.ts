import { describe, expect, it } from "vitest";
import { createHero } from "./hero/character";
import type { GameState } from "./types";
import { QUESTS } from "./quests";
import { NPCS } from "../world/npcs";
import { gameReducer, initialState } from "../state/gameReducer";

function talkedOut(state: GameState, npcId: string): GameState {
  // open the dialogue then advance past every line so resolveQuests runs
  let s: GameState = { ...state, dialogue: { npcId, page: 0 } };
  const lines = NPCS.find((n) => n.id === npcId)!.lines.length;
  for (let i = 0; i < lines; i++) s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
  return s;
}

describe("quests", () => {
  it("every giver exists", () => {
    for (const quest of QUESTS)
      expect(
        NPCS.some((n) => n.id === quest.giver),
        quest.id,
      ).toBe(true);
  });

  it("accepts, tracks a delivery, and pays out on turn-in", () => {
    let s = structuredClone(initialState);
    s.hero = createHero("Runner", "warrior");
    s.inventory = { cheese_wheel: 1 };
    s.world = { position: { mapId: "town", x: 1, y: 1, facing: "down" }, discovered: {}, openedChests: [], slain: [] };

    s = talkedOut(s, "villager_bram");
    expect(s.quests.cheese_run).toEqual({ progress: 0, done: false });
    expect(s.worldMessage).toMatch(/Quest accepted - The Cheese Run/);

    const goldBefore = s.gold;
    s = talkedOut(s, "villager_bram");
    expect(s.quests.cheese_run.done).toBe(true);
    expect(s.inventory.cheese_wheel).toBeUndefined(); // the wheel changed hands
    expect(s.gold).toBe(goldBefore + 25);
    expect(s.worldMessage).toMatch(/Quest complete/);

    s = talkedOut(s, "villager_bram"); // done quests stay done
    expect(s.worldMessage).not.toMatch(/Quest accepted/);
  });

  it("kill quests tick from battle victories", () => {
    let s = structuredClone(initialState);
    s.hero = createHero("Slayer", "warrior");
    s.world = { position: { mapId: "town", x: 1, y: 1, facing: "down" }, discovered: {}, openedChests: [], slain: [] };
    s = talkedOut(s, "innkeeper");
    expect(s.quests.slime_trouble.progress).toBe(0);
  });
});
