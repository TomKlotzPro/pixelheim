import { describe, expect, it } from "vitest";
import { createHero } from "../../game/hero/character";
import { createGear } from "../../game/economy/rarity";
import { SKILL_TREES } from "../../game/hero/skillTree";
import type { GameState } from "../../game/types";
import { gameReducer, initialState } from "../gameReducer";

/**
 * Wiring tests for the small reducers (PIX-116): the underlying game math is
 * unit-tested elsewhere; these prove the actions actually reach it, with the
 * guards in the right places. Previously only Playwright covered this.
 */
function fresh(): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Wiring", "warrior");
  s.screen = "world";
  s.world = { position: { mapId: "town", x: 28, y: 30, facing: "down" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("inventory reducer wiring", () => {
  it("equips into the right slot, rings find a free finger, unequip clears", () => {
    let s = fresh();
    const sword = createGear("rusty_sword");
    const ringA = createGear("bone_charm");
    const ringB = createGear("moon_pendant");
    s.gear = [sword, ringA, ringB];

    s = gameReducer(s, { type: "EQUIP", uid: sword.uid });
    expect(s.equipped.weapon).toBe(sword.uid);
    // equipping the same piece twice does nothing
    s = gameReducer(s, { type: "EQUIP", uid: sword.uid });
    expect(s.equipped.weapon).toBe(sword.uid);

    s = gameReducer(s, { type: "UNEQUIP", slot: "weapon" });
    expect(s.equipped.weapon).toBeUndefined();
  });

  it("drops shed stacks but never equipped gear", () => {
    let s = fresh();
    s.inventory = { bread: 3 };
    const sword = createGear("rusty_sword");
    s.gear = [sword];
    s = gameReducer(s, { type: "EQUIP", uid: sword.uid });

    s = gameReducer(s, { type: "DROP", itemId: "bread", count: 2 });
    expect(s.inventory.bread).toBe(1);
    s = gameReducer(s, { type: "DROP_GEAR", uid: sword.uid });
    expect(s.gear).toHaveLength(1); // equipped: refused
    s = gameReducer(s, { type: "UNEQUIP", slot: "weapon" });
    s = gameReducer(s, { type: "DROP_GEAR", uid: sword.uid });
    expect(s.gear).toHaveLength(0);
  });
});

describe("progression reducer wiring", () => {
  it("stat points spend one at a time and stop at zero", () => {
    let s = fresh();
    s.hero!.statPoints = 1;
    const str = s.hero!.stats.strength;
    s = gameReducer(s, { type: "SPEND_STAT_POINT", stat: "strength" });
    expect(s.hero!.stats.strength).toBe(str + 1);
    expect(s.hero!.statPoints).toBe(0);
    s = gameReducer(s, { type: "SPEND_STAT_POINT", stat: "strength" });
    expect(s.hero!.stats.strength).toBe(str + 1); // no points, no gain
  });

  it("skill nodes cost points and land on the hero", () => {
    let s = fresh();
    const first = SKILL_TREES[s.hero!.roleId].find((n) => n.tier === 1)!;
    s.hero!.skillPoints = 1;
    s = gameReducer(s, { type: "BUY_SKILL_NODE", nodeId: first.id });
    expect(s.hero!.skillNodes).toContain(first.id);
    expect(s.hero!.skillPoints).toBe(0);
  });
});
