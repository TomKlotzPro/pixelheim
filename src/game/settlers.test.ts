import { afterEach, describe, expect, it, vi } from "vitest";
import { createHero } from "./hero/character";
import { heroAttackDamage } from "./combat/combat";
import { RECRUITS } from "./settlers";
import { setSettlers, setTownTier } from "../world/maps/index";
import { npcsOn } from "../world/npcs";
import { waypointUsable, WAYPOINTS } from "../world/waypoints";
import type { GameState } from "./types";
import { gameReducer, initialState } from "../state/gameReducer";

afterEach(() => {
  setSettlers([]);
  setTownTier(1);
  vi.restoreAllMocks();
});

/** The hero mid-conversation on the recruit's last line: E closes and resolves. */
function talkingTo(npcId: string, mapId: string, x: number, y: number, page: number): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Patron", "warrior");
  s.screen = "world";
  s.dialogue = { npcId, page };
  s.world = { position: { mapId, x, y, facing: "right" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("settlers (PIX-92)", () => {
  it("an unmet ask refuses politely and names the price", () => {
    let s = talkingTo("settler_iva", "mirefen", 51, 24, 1);
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.settlers).toEqual([]);
    expect(s.worldMessage).toContain("3x Marsh Reed");
  });

  it("a met ask recruits: the price is paid and the settler moves to town", () => {
    let s = talkingTo("settler_iva", "mirefen", 51, 24, 1);
    s = { ...s, inventory: { marsh_reed: 4 } };
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.settlers).toEqual(["settler_iva"]);
    expect(s.inventory.marsh_reed).toBe(1);
    expect(s.worldMessage).toContain("joins Pixelheim");

    // the mirrors decide where she stands: fen before, town after
    expect(npcsOn("mirefen").some((npc) => npc.id === "settler_iva")).toBe(true);
    setSettlers(s.settlers);
    expect(npcsOn("mirefen").some((npc) => npc.id === "settler_iva")).toBe(false);
    expect(npcsOn("town").some((npc) => npc.id === "settler_iva")).toBe(true);
  });

  it("finer folk hold out for a finer town", () => {
    let s = talkingTo("settler_loras", "deepwood", 5, 24, 1);
    s = { ...s, gold: 1000 };
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.settlers).toEqual([]);
    expect(s.worldMessage).toContain("fund the Village");

    s = { ...s, townTier: 2, dialogue: { npcId: "settler_loras", page: 1 } };
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.settlers).toEqual(["settler_loras"]);
    expect(s.gold).toBe(850);
  });

  it("Iva heals her patron for free, at home in town", () => {
    let s = talkingTo("settler_iva", "town", 33, 16, 1);
    s = { ...s, settlers: ["settler_iva"], hero: { ...s.hero!, hp: 5, mp: 1 } };
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.hero!.hp).toBe(s.hero!.stats.maxHp);
    expect(s.worldMessage).toContain("Fully healed");
  });

  it("the bard's song sharpens the blade, then fades with the fight", () => {
    let s = talkingTo("settler_loras", "town", 25, 10, 1);
    s = { ...s, settlers: ["settler_loras"] };
    s = gameReducer(s, { type: "ADVANCE_DIALOGUE" });
    expect(s.bardSong).toBe(true);

    // a crit that only lands because the song plays (roll under 0.12)
    vi.spyOn(Math, "random").mockReturnValue(0.05);
    const hero = s.hero!;
    const monster = { def: { id: "slime" }, hp: 100, maxHp: 100, defense: 0 } as never;
    const quiet = heroAttackDamage(hero, [], {}, monster, false);
    const sung = heroAttackDamage(hero, [], {}, monster, true);
    expect(sung).toBeGreaterThan(quiet);

    // the song fades when the fighting stops
    s = { ...s, battle: { phase: "lost" } as never };
    s = gameReducer(s, { type: "RETURN_TO_WORLD" });
    expect(s.bardSong).toBe(false);
  });

  it("the square waypoint waits for its stablemaster", () => {
    const square = WAYPOINTS.find((w) => w.id === "town_square")!;
    const discovered = { town: ["28,15"] };
    expect(waypointUsable(square, discovered, [])).toBe(false);
    expect(waypointUsable(square, discovered, ["settler_wren"])).toBe(true);
    expect(waypointUsable(square, {}, ["settler_wren"])).toBe(false); // still needs discovering
  });

  it("every recruit waits somewhere real and comes home to a real tile", () => {
    for (const recruit of RECRUITS) {
      expect(npcsOn(recruit.found.mapId).some((npc) => npc.id === recruit.id)).toBe(true);
    }
    setSettlers(RECRUITS.map((r) => r.id));
    const town = npcsOn("town").map((npc) => npc.id);
    for (const recruit of RECRUITS) expect(town).toContain(recruit.id);
  });
});
