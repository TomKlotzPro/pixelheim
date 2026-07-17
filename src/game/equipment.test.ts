import { describe, expect, it } from "vitest";
import { carryCapacity, createHero, effectiveStat, grantedStat, totalArmor } from "./character";
import { itemStatLine } from "./itemStats";
import { getItem } from "./items";
import { createGear } from "./rarity";
import type { GameState } from "./types";
import { gameReducer, initialState } from "../state/gameReducer";

function heroWith(gearIds: string[]): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Tess", "warrior");
  s.gear = gearIds.map((id) => createGear(id));
  return s;
}

describe("the full wardrobe", () => {
  it("a ring takes the empty finger, the second ring takes the other", () => {
    let s = heroWith(["band_of_grit", "quickstep_ring"]);
    s = gameReducer(s, { type: "EQUIP", uid: s.gear[0].uid });
    expect(s.equipped.ring1).toBe(s.gear[0].uid);
    s = gameReducer(s, { type: "EQUIP", uid: s.gear[1].uid });
    expect(s.equipped.ring2).toBe(s.gear[1].uid);
    // both fingers full: a third ring replaces the first
    s = { ...s, gear: [...s.gear, createGear("ring_of_clarity")] };
    s = gameReducer(s, { type: "EQUIP", uid: s.gear[2].uid });
    expect(s.equipped.ring1).toBe(s.gear[2].uid);
    expect(s.equipped.ring2).toBe(s.gear[1].uid);
  });

  it("the same piece never occupies two slots", () => {
    let s = heroWith(["band_of_grit"]);
    s = gameReducer(s, { type: "EQUIP", uid: s.gear[0].uid });
    s = gameReducer(s, { type: "EQUIP", uid: s.gear[0].uid });
    expect(s.equipped.ring2).toBeUndefined();
  });

  it("jewelry grants stats while worn, armor slots add armor", () => {
    const s = heroWith(["bone_charm", "iron_helm"]);
    const equipped = { neck: s.gear[0].uid, head: s.gear[1].uid };
    expect(grantedStat(s.gear, equipped, "strength")).toBe(1);
    expect(effectiveStat(s.hero!, s.gear, equipped, "strength")).toBe(s.hero!.stats.strength + 1);
    expect(totalArmor(s.gear, equipped)).toBe(4);
    // a strength charm literally helps you carry more
    expect(carryCapacity(s.hero!, s.gear, equipped)).toBe(carryCapacity(s.hero!, [], {}) + 3);
  });

  it("stat lines advertise what jewelry grants", () => {
    expect(itemStatLine(getItem("moon_pendant"))).toContain("+2 INT");
    expect(itemStatLine(getItem("duelists_ring"))).toContain("+2 DEX");
  });

  it("head, hands and feet slots equip like any apparel", () => {
    let s = heroWith(["leather_cap", "wool_gloves", "worn_boots"]);
    for (const g of s.gear) s = gameReducer(s, { type: "EQUIP", uid: g.uid });
    expect(s.equipped.head).toBe(s.gear[0].uid);
    expect(s.equipped.hands).toBe(s.gear[1].uid);
    expect(s.equipped.feet).toBe(s.gear[2].uid);
    expect(totalArmor(s.gear, s.equipped)).toBe(4);
  });
});
