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

  it("Vex talks before his counter while his quest waits for a word", () => {
    let s = structuredClone(initialState);
    s.screen = "world";
    s.hero = createHero("Gatherer", "warrior");
    s.world = {
      position: { mapId: "town_alchemist", x: 8, y: 3, facing: "up" },
      discovered: {},
      openedChests: [],
      slain: [],
    };
    // His quest untaken: E is a conversation, and closing it takes the quest.
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue?.npcId).toBe("alchemist_vex");
    expect(s.openPanel).toBeFalsy();
    s = talkedOut(s, "alchemist_vex");
    expect(s.quests.herbs_for_vex).toEqual({ progress: 0, done: false });

    // Under way: the counter, as for every keeper.
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.openPanel).toBe("shop");
    s = { ...s, openPanel: null, inventory: { forest_herb: 3 } };

    // Herbs in hand: he talks again, and closing turns them in.
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.dialogue?.npcId).toBe("alchemist_vex");
    s = talkedOut(s, "alchemist_vex");
    expect(s.quests.herbs_for_vex.done).toBe(true);
    expect(s.inventory.forest_herb).toBeUndefined();
    expect(s.inventory.greater_potion).toBe(1);

    // Done: back to the counter.
    s = gameReducer(s, { type: "INTERACT" });
    expect(s.openPanel).toBe("shop");
  });

  it("kill quests tick from battle victories", () => {
    let s = structuredClone(initialState);
    s.hero = createHero("Slayer", "warrior");
    s.world = { position: { mapId: "town", x: 1, y: 1, facing: "down" }, discovered: {}, openedChests: [], slain: [] };
    s = talkedOut(s, "innkeeper");
    expect(s.quests.slime_trouble.progress).toBe(0);
  });
});
