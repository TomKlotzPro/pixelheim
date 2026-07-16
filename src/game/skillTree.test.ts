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
