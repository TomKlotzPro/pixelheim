import { describe, expect, it } from "vitest";
import { createHero } from "./character";
import { getHeroSkills, getPassives } from "./skillTree";
import { canChooseSpec, getSpec, SPECS } from "./specs";
import type { GameState } from "../types";
import { gameReducer, initialState } from "../../state/gameReducer";

function heroAt(level: number, roleId: "warrior" | "ranger" = "ranger"): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Fork", roleId);
  s.hero.level = level;
  return s;
}

describe("specializations", () => {
  it("every class offers exactly two paths", () => {
    const byRole = new Map<string, number>();
    for (const spec of SPECS) byRole.set(spec.roleId, (byRole.get(spec.roleId) ?? 0) + 1);
    expect([...byRole.values()]).toEqual([2, 2, 2, 2, 2, 2, 2]);
  });

  it("the fork opens at rank 1 and closes once chosen", () => {
    let s = heroAt(4);
    s = gameReducer(s, { type: "CHOOSE_SPEC", specId: "deadeye" });
    expect(s.hero!.spec).toBeUndefined(); // too green

    s = heroAt(5);
    s = gameReducer(s, { type: "CHOOSE_SPEC", specId: "juggernaut" });
    expect(s.hero!.spec).toBeUndefined(); // wrong class

    s = gameReducer(s, { type: "CHOOSE_SPEC", specId: "deadeye" });
    expect(s.hero!.spec).toBe("deadeye");
    expect(canChooseSpec(s.hero!)).toBe(false);

    s = gameReducer(s, { type: "CHOOSE_SPEC", specId: "beastmaster" });
    expect(s.hero!.spec).toBe("deadeye"); // a path is for life
  });

  it("a spec grants its passive theme and signature skill", () => {
    const s = heroAt(5);
    const hero = structuredClone(s.hero!);
    const before = getPassives(hero).critChance;
    hero.spec = "deadeye";
    expect(getPassives(hero).critChance).toBeCloseTo(before + 0.15);
    expect(getHeroSkills(hero).map((sk) => sk.name)).toContain("Piercing Shot");
    expect(getSpec(hero)?.name).toBe("Deadeye");
  });

  it("old saves without a spec lose nothing", () => {
    const hero = createHero("Vet", "warrior");
    hero.level = 10;
    expect(getSpec(hero)).toBeNull();
    expect(() => getPassives(hero)).not.toThrow();
  });
});
