import { describe, expect, it } from "vitest";
import { createHero } from "./character";
import { canBuyNode, getHeroSkills, getPassives, rootNode, SKILL_TREES } from "./skillTree";

const warriorRoot = rootNode("warrior");
const warriorUpgrade = SKILL_TREES.warrior.find((n) => n.kind === "upgrade" && n.requires === warriorRoot.id)!;
const someLocked = SKILL_TREES.warrior.find((n) => n.requires && n.requires !== warriorRoot.id)!;

describe("canBuyNode", () => {
  it("requires a point, no double-buys, and the prerequisite", () => {
    const hero = createHero("Tess", "warrior");
    expect(canBuyNode(hero, warriorUpgrade)).toBe(false); // no points yet
    hero.skillPoints = 1;
    expect(canBuyNode(hero, warriorUpgrade)).toBe(true); // root is owned from creation
    expect(canBuyNode(hero, warriorRoot)).toBe(false); // already owned
    expect(canBuyNode(hero, someLocked)).toBe(false); // prerequisite not owned
  });
});

describe("getHeroSkills", () => {
  it("returns owned actives, with owned upgrades patched in", () => {
    const hero = createHero("Tess", "warrior");
    const base = getHeroSkills(hero);
    expect(base).toHaveLength(1);
    hero.skillNodes.push(warriorUpgrade.id);
    const upgraded = getHeroSkills(hero)[0];
    for (const [key, value] of Object.entries(warriorUpgrade.patch!)) {
      expect(upgraded[key as keyof typeof upgraded]).toEqual(value);
    }
  });
});

describe("getPassives", () => {
  it("owns nothing passive at creation and merges owned passives additively", () => {
    const hero = createHero("Tess", "cleric");
    expect(getPassives(hero).defense).toBe(0);
    expect(getPassives(hero).stunResist).toBe(false);
    hero.skillNodes.push("cleric_aegis", "cleric_serenity");
    const merged = getPassives(hero);
    expect(merged.defense).toBe(2);
    expect(merged.stunResist).toBe(true);
  });
});

describe("tree integrity", () => {
  it("every role has 12 nodes: 3 branches, 4 tiers, unique ids, resolvable chains", () => {
    for (const [roleId, tree] of Object.entries(SKILL_TREES)) {
      expect(tree, roleId).toHaveLength(12);
      expect(new Set(tree.map((n) => n.id)).size).toBe(12);
      const ids = new Set(tree.map((n) => n.id));
      for (const node of tree) {
        expect(node.branch, node.id).toBeGreaterThanOrEqual(0);
        expect(node.branch, node.id).toBeLessThanOrEqual(2);
        if (node.requires) expect(ids.has(node.requires), `${node.id} requires ${node.requires}`).toBe(true);
        else expect(node.tier, `${node.id} is a root`).toBe(0);
      }
      // every branch reaches tier 3
      for (const branch of [0, 1, 2]) {
        expect(
          tree.some((n) => n.branch === branch && n.tier === 3),
          `${roleId} branch ${branch} capstone`,
        ).toBe(true);
      }
    }
  });

  it("a hero walking a full branch ends with the capstone usable or counted", () => {
    const hero = createHero("Tess", "warrior");
    hero.skillPoints = 11;
    // buy every node in prerequisite order
    let bought = true;
    while (bought) {
      bought = false;
      for (const node of SKILL_TREES.warrior) {
        if (canBuyNode(hero, node)) {
          hero.skillNodes.push(node.id);
          hero.skillPoints -= 1;
          bought = true;
        }
      }
    }
    expect(hero.skillNodes).toHaveLength(12);
    // four actives usable in battle: root + 2 branch actives + the capstone
    expect(getHeroSkills(hero).length).toBe(4);
  });
});
