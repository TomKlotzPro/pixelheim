import { describe, expect, it } from "vitest";
import { createHero } from "../../game/hero/character";
import type { GameState } from "../../game/types";
import { gameReducer, initialState } from "../gameReducer";

function travelerState(discovered: string[]): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.screen = "world";
  s.world = {
    position: { mapId: "overworld", x: 24, y: 20, facing: "up" },
    discovered: { overworld: discovered },
    openedChests: [],
    slain: [],
  };
  return s;
}

describe("FAST_TRAVEL", () => {
  it("jumps to a waypoint the hero has seen", () => {
    let s = travelerState(["24,3"]);
    s = gameReducer(s, { type: "FAST_TRAVEL", waypointId: "mountain_gate" });
    expect(s.world!.position).toMatchObject({ mapId: "overworld", x: 24, y: 4 });
    expect(s.worldMessage).toContain("Ashen Mountain");
  });

  it("refuses waypoints still under fog", () => {
    let s = travelerState([]);
    s = gameReducer(s, { type: "FAST_TRAVEL", waypointId: "mountain_gate" });
    expect(s.world!.position.y).toBe(20);
  });

  it("refuses the over-encumbered (the classic)", () => {
    let s = travelerState(["24,3"]);
    s.inventory = { cheese_wheel: 999 };
    s = gameReducer(s, { type: "FAST_TRAVEL", waypointId: "mountain_gate" });
    expect(s.world!.position.y).toBe(20);
    expect(s.worldMessage).toContain("Too heavy");
  });
});
