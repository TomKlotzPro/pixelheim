import { describe, expect, it } from "vitest";
import { createHero } from "../game/hero/character";
import type { GameState } from "../game/types";
import { initialState } from "../state/gameReducer";
import { ambienceForState } from "./ambience";
import { trackForState } from "./music";

function at(mapId: string, screen: GameState["screen"] = "world"): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Ear", "warrior");
  s.screen = screen;
  s.world = { position: { mapId, x: 1, y: 1, facing: "down" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("the score knows where you are", () => {
  it("each place gets its own theme", () => {
    expect(trackForState(at("town"))).toBe("town");
    expect(trackForState(at("overworld"))).toBe("world");
    expect(trackForState(at("deepwood"))).toBe("deepwood");
    expect(trackForState(at("mirefen"))).toBe("mirefen");
    expect(trackForState(at("town_shop"))).toBe("interior");
    expect(trackForState(at("town_inn"))).toBe("interior");
    expect(trackForState(at("town", "dungeon_select"))).toBe("descent");
    expect(trackForState(at("town", "title"))).toBe("title");
    expect(trackForState(at("town", "victory"))).toBe("victory");
  });

  it("bosses get the boss theme, everything else the battle theme", () => {
    const s = at("overworld", "battle");
    s.battle = { monster: { def: { id: "dragon" } } } as GameState["battle"];
    expect(trackForState(s)).toBe("boss");
    s.battle = { monster: { def: { id: "lich" } } } as GameState["battle"];
    expect(trackForState(s)).toBe("boss");
    s.battle = { monster: { def: { id: "slime" } } } as GameState["battle"];
    expect(trackForState(s)).toBe("battle");
  });

  it("ambience follows the terrain", () => {
    expect(ambienceForState(at("overworld"))).toBe("greenwood");
    expect(ambienceForState(at("deepwood"))).toBe("deepforest");
    expect(ambienceForState(at("mirefen"))).toBe("marsh");
    expect(ambienceForState(at("town_smith"))).toBe("indoor");
    expect(ambienceForState(at("town", "battle"))).toBe("none");
  });
});
