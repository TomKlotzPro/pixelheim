import { describe, expect, it } from "vitest";
import { createHero } from "../../game/character";
import { gameReducer, initialState, TOWN_SPAWN } from "../gameReducer";

describe("QUIT_TO_TITLE", () => {
  it("returns to the title with the run intact and menus closed", () => {
    let state = structuredClone(initialState);
    state.hero = createHero("Tess", "warrior");
    state.screen = "world";
    state.world = { position: { ...TOWN_SPAWN }, discovered: {}, openedChests: [], slain: [] };
    state.inventoryOpen = true;

    state = gameReducer(state, { type: "QUIT_TO_TITLE" });
    expect(state.screen).toBe("title");
    expect(state.inventoryOpen).toBe(false);
    expect(state.hero?.name).toBe("Tess");

    // Continue resumes in place: RETURN_TO_WORLD puts the live hero back
    state = gameReducer(state, { type: "RETURN_TO_WORLD" });
    expect(state.screen).toBe("world");
    expect(state.world?.position).toEqual(TOWN_SPAWN);
  });
});
