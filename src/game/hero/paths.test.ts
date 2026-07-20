import { describe, expect, it } from "vitest";
import { createHero, heroSprite } from "./character";
import { getHeroSkills, getPassives } from "./skillTree";
import { activeNode, canChoosePath, getPathNode, PATH_NODES, pathChains, pathChoices, pendingTier } from "./paths";
import type { GameState, RoleId } from "../types";
import { gameReducer, initialState } from "../../state/gameReducer";

const ROLES: RoleId[] = ["warrior", "mage", "rogue", "cleric", "ranger", "paladin", "necromancer"];

function heroAt(level: number, roleId: RoleId = "warrior"): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Walker", roleId);
  s.hero.level = level;
  return s;
}

describe("the path graph", () => {
  it("every class has two nodes per tier and four legal chains", () => {
    for (const roleId of ROLES) {
      for (const tier of [1, 2, 3] as const) {
        expect(PATH_NODES.filter((n) => n.roleId === roleId && n.tier === tier)).toHaveLength(2);
      }
      expect(pathChains(roleId)).toHaveLength(4);
    }
  });

  it("edges are sound: tier 2 accepts both forks, capstones only their own form", () => {
    for (const node of PATH_NODES) {
      if (node.tier === 1) expect(node.from).toHaveLength(0);
      if (node.tier === 2) {
        expect(node.from).toHaveLength(2);
        for (const id of node.from) expect(getPathNode(id)?.tier).toBe(1);
      }
      if (node.tier === 3) {
        expect(node.from).toHaveLength(1);
        const from = getPathNode(node.from[0])!;
        expect(from.tier).toBe(2);
        expect(from.branch).toBe(node.branch);
        expect(from.roleId).toBe(node.roleId);
      }
    }
    const ids = PATH_NODES.map((n) => n.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("each tier unlocks at its rank and each step is permanent", () => {
    let s = heroAt(4);
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "juggernaut" });
    expect(s.hero!.path).toBeUndefined(); // too green

    s = heroAt(5);
    expect(pendingTier(s.hero!)).toBe(1);
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "bastion" });
    expect(s.hero!.path).toBeUndefined(); // no skipping to tier 2

    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "juggernaut" });
    expect(s.hero!.path).toEqual(["juggernaut"]);
    expect(s.hero!.spec).toBe("juggernaut"); // the mirror for old saves
    expect(canChoosePath(s.hero!)).toBe(false); // tier 2 needs rank 2

    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "warlord" });
    expect(s.hero!.path).toEqual(["juggernaut"]); // a step is for life
  });

  it("the crossover is open at tier 2, capstones are gated by the walk", () => {
    let s = heroAt(10);
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "juggernaut" });
    // rank 2 with one step walked: tier 2 pending immediately
    expect(pendingTier(s.hero!)).toBe(2);
    expect(
      pathChoices(s.hero!)
        .map((n) => n.id)
        .toSorted(),
    ).toEqual(["bastion", "battlelord"]);
    // cross over to the other branch's advanced form
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "battlelord" });
    expect(s.hero!.path).toEqual(["juggernaut", "battlelord"]);

    // the reducer freezes its output; rebuild the state to level the hero up
    s = { ...s, hero: { ...s.hero!, level: 15 } };
    // only battlelord's capstone is reachable now
    expect(pathChoices(s.hero!).map((n) => n.id)).toEqual(["warfather"]);
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "unbroken" });
    expect(s.hero!.path).toEqual(["juggernaut", "battlelord"]);
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "warfather" });
    expect(s.hero!.path).toEqual(["juggernaut", "battlelord", "warfather"]);
    expect(canChoosePath(s.hero!)).toBe(false);
  });

  it("the deepest node owns the passives and the signature", () => {
    let s = heroAt(10, "mage");
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "stormcaller" });
    expect(getPassives(s.hero!).killRefundMp).toBe(4);
    expect(getHeroSkills(s.hero!).some((sk) => sk.name === "Thunderlash")).toBe(true);

    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "tempest" });
    const passives = getPassives(s.hero!);
    expect(passives.killRefundMp).toBe(6); // replaced, not stacked
    const skills = getHeroSkills(s.hero!);
    expect(skills.some((sk) => sk.name === "Stormlash")).toBe(true);
    expect(skills.some((sk) => sk.name === "Thunderlash")).toBe(false);
  });

  it("a walked path claims the wardrobe; pre-graph saves keep working", () => {
    let s = heroAt(10, "ranger");
    expect(heroSprite(s.hero!)).toBe("hero_ranger_r2");
    s = gameReducer(s, { type: "CHOOSE_PATH", nodeId: "beastmaster" });
    expect(heroSprite(s.hero!)).toBe("hero_ranger_pb_r2");

    // an old save: spec set by the pre-graph reducer, no path array
    const legacy = heroAt(10, "ranger");
    legacy.hero!.spec = "deadeye";
    expect(activeNode(legacy.hero!)?.id).toBe("deadeye");
    expect(pendingTier(legacy.hero!)).toBe(2);
    expect(heroSprite(legacy.hero!)).toBe("hero_ranger_pa_r2");
  });
});
