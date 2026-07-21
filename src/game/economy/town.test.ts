import { afterEach, describe, expect, it } from "vitest";
import { createHero } from "../hero/character";
import { rentPerProperty, restCostFor, TOWN_TIERS } from "./town";
import { sellMultiplier, sellPriceAt } from "./shop";
import { TOWN_MAPS } from "../../world/maps/ashenreach";
import { getMap, setTownTier } from "../../world/maps/index";
import { npcsOn } from "../../world/npcs";
import { getItem } from "./items";
import type { GameState } from "../types";
import { gameReducer, initialState } from "../../state/gameReducer";

afterEach(() => setTownTier(1));

function atHall(gold: number): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Patron", "warrior");
  s.screen = "world";
  s.gold = gold;
  s.hallOpen = true;
  s.world = { position: { mapId: "town_hall", x: 8, y: 8, facing: "up" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("the town tiers (PIX-91)", () => {
  it("four authored ages, each a valid map with every portal intact", () => {
    expect(TOWN_TIERS).toHaveLength(4);
    expect(TOWN_MAPS).toHaveLength(4);
    for (const map of TOWN_MAPS) {
      expect(map.id).toBe("town");
      expect(map.portals).toHaveLength(6);
    }
    // the redraw is real: the fountain joins the shrine only from tier 3
    expect(TOWN_MAPS[1].tiles[17][30]).toBe("grass");
    expect(TOWN_MAPS[2].tiles[17][30]).toBe("well");
    // the city raises a slate townhouse at tier 4
    expect(TOWN_MAPS[2].tiles[21][67]).toBe("grass");
    expect(TOWN_MAPS[3].tiles[21][67]).toBe("roof_slate");
  });

  it("funding pays gold, raises the tier, and respects requirements", () => {
    let s = atHall(10_000);
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(2);
    expect(s.gold).toBe(7500);

    // tier 3 demands a homeowner, not just a purse
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(2);
    s = { ...s, house: { ...s.house, owned: true } };
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(3);
    expect(s.gold).toBe(500);

    // tier 4 demands all three businesses - and 15,000g this hero lacks
    s = { ...s, gold: 20_000, properties: ["town_shop", "town_smith"] };
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(3);
    s = { ...s, properties: ["town_shop", "town_smith", "town_alchemist"] };
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(4);
    s = gameReducer(s, { type: "FUND_TOWN" });
    expect(s.townTier).toBe(4); // the ledger tops out
  });

  it("the mirror serves the tiered map and the settlers arrive on cue", () => {
    setTownTier(1);
    expect(getMap("town").tiles[17][30]).toBe("grass");
    const founders = npcsOn("town").length;

    setTownTier(3);
    expect(getMap("town").tiles[17][30]).toBe("well");
    const townFolk = npcsOn("town").map((npc) => npc.id);
    expect(townFolk).toContain("settler_mira");
    expect(townFolk).toContain("settler_tomas");
    expect(townFolk).not.toContain("settler_serra");
    expect(townFolk.length).toBe(founders + 2);

    setTownTier(4);
    expect(npcsOn("town").map((npc) => npc.id)).toContain("settler_serra");
  });

  it("the perks pay out: rent, rest, and city sale prices", () => {
    expect(rentPerProperty(1)).toBe(2);
    expect(rentPerProperty(2)).toBe(3);
    expect(restCostFor(2)).toBe(10);
    expect(restCostFor(3)).toBe(5);
    expect(sellMultiplier(4)).toBe(1.2);
    const pelt = getItem("wolf_pelt");
    expect(sellPriceAt("odo", pelt, 4)).toBeGreaterThan(sellPriceAt("odo", pelt, 1));
  });
});
