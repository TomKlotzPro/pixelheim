import { afterEach, describe, expect, it } from "vitest";
import { createHero } from "../hero/character";
import { furnitureAt, furnitureBlocks, gardenYield, houseTier, nextHouseTier } from "./house";
import { getMap, setHouseTier } from "../../world/maps/index";
import type { GameState } from "../types";
import { gameReducer, initialState } from "../../state/gameReducer";

afterEach(() => setHouseTier(1));

function homeowner(gold: number, tier = 1): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Nester", "warrior");
  s.screen = "world";
  s.gold = gold;
  s.house = { owned: true, storage: {}, tier };
  s.world = {
    position: { mapId: "town_house", x: 8, y: 8, facing: "up" },
    discovered: {},
    openedChests: [],
    slain: [],
  };
  return s;
}

describe("the growing house (PIX-34)", () => {
  it("Odo sells the bigger deeds, in order and gated on gold", () => {
    let s = homeowner(20_000);
    expect(nextHouseTier(s)?.name).toBe("Cottage");

    // no shop open, no sale
    s = gameReducer(s, { type: "BUY_HOUSE_UPGRADE" });
    expect(houseTier(s)).toBe(1);

    s = { ...s, world: { ...s.world!, position: { mapId: "town_shop", x: 8, y: 4, facing: "up" } }, shopOpen: true };
    s = gameReducer(s, { type: "BUY_HOUSE_UPGRADE" });
    expect(houseTier(s)).toBe(2);
    expect(s.gold).toBe(15_000);
    s = gameReducer(s, { type: "BUY_HOUSE_UPGRADE" });
    expect(houseTier(s)).toBe(3);
    expect(s.gold).toBe(3000);
    s = gameReducer(s, { type: "BUY_HOUSE_UPGRADE" });
    expect(houseTier(s)).toBe(3); // the manor is the summit
    expect(nextHouseTier(s)).toBeNull();
  });

  it("the mirror serves each tier its own interior", () => {
    expect(getMap("town_house").width).toBe(20);
    setHouseTier(2);
    expect(getMap("town_house").width).toBe(26);
    expect(getMap("town_house").tiles[2][11]).toBe("trophy_shelf");
    setHouseTier(3);
    expect(getMap("town_house").width).toBe(30);
    expect(getMap("town_house").tiles[5][19]).toBe("garden");
  });

  it("trophies buff while displayed, and give it back when taken down", () => {
    let s = homeowner(0, 2);
    s.inventory = { dragon_scale: 1, lich_crown: 1 };
    const baseDef = s.hero!.stats.defense;
    const baseStr = s.hero!.stats.strength;

    s = gameReducer(s, { type: "TOGGLE_TROPHIES" });
    s = gameReducer(s, { type: "DISPLAY_TROPHY", itemId: "dragon_scale" });
    expect(s.hero!.stats.defense).toBe(baseDef + 2);
    s = gameReducer(s, { type: "DISPLAY_TROPHY", itemId: "lich_crown" });
    expect(s.hero!.stats.defense).toBe(baseDef + 4);
    expect(s.hero!.stats.strength).toBe(baseStr + 2);
    expect(s.inventory.dragon_scale ?? 0).toBe(0);

    s = gameReducer(s, { type: "TAKE_TROPHY", itemId: "dragon_scale" });
    expect(s.hero!.stats.defense).toBe(baseDef + 2);
    expect(s.inventory.dragon_scale).toBe(1);
    // displaying what you do not own does nothing
    s = gameReducer(s, { type: "DISPLAY_TROPHY", itemId: "gem" });
    expect(s.house.trophies).toEqual(["lich_crown"]);
  });

  it("the nook distills two brews into a better one", () => {
    let s = homeowner(0, 3);
    s.inventory = { potion_hp: 3 };
    s = gameReducer(s, { type: "TOGGLE_NOOK" });
    s = gameReducer(s, { type: "COMBINE_POTIONS", itemId: "potion_hp" });
    expect(s.inventory.potion_hp).toBe(1);
    expect(s.inventory.greater_potion).toBe(1);
    // one left is not enough
    s = gameReducer(s, { type: "COMBINE_POTIONS", itemId: "potion_hp" });
    expect(s.inventory.greater_potion).toBe(1);
  });

  it("furniture places on faced floor, blocks walkers, and comes back with a touch", () => {
    setHouseTier(1);
    let s = homeowner(0);
    s.inventory = { furn_plant: 1, furn_rug: 1 };
    s.world!.position = { mapId: "town_house", x: 8, y: 6, facing: "down" };

    s = gameReducer(s, { type: "PLACE_FURNITURE", itemId: "furn_plant" });
    expect(furnitureAt(s, "town_house", 8, 7)).toMatchObject({ itemId: "furn_plant" });
    expect(s.inventory.furn_plant ?? 0).toBe(0);

    // the tile is taken now, and the fern is solid
    s = gameReducer(s, { type: "PLACE_FURNITURE", itemId: "furn_rug" });
    expect(s.inventory.furn_rug).toBe(1);
    expect(furnitureBlocks("furn_plant")).toBe(true);
    expect(furnitureBlocks("furn_rug")).toBe(false);
    s = gameReducer(s, { type: "MOVE", direction: "down" });
    expect(s.world!.position.y).toBe(6); // bumped, not through

    s = gameReducer(s, { type: "INTERACT" });
    expect(furnitureAt(s, "town_house", 8, 7)).toBeNull();
    expect(s.inventory.furn_plant).toBe(1);
  });

  it("the garden alternates bread and cheese", () => {
    expect(gardenYield(0)).toBe("bread");
    expect(gardenYield(1)).toBe("cheese_wheel");
    expect(gardenYield(2)).toBe("bread");
  });
});
