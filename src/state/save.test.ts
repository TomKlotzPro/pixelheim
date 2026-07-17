import { describe, expect, it } from "vitest";
import type { GameState } from "../game/types";
import { decodeSaveCode, encodeSaveCode, migrate } from "./save";

/** A frozen v1-era save: bare state, no envelope, item-id equipment, no world. */
const V1 = {
  screen: "hub",
  hero: {
    name: "OldTimer",
    roleId: "warrior",
    level: 3,
    xp: 10,
    xpToNext: 74,
    hp: 40,
    mp: 5,
    stats: { maxHp: 56, maxMp: 10, strength: 15, intelligence: 5, dexterity: 7, defense: 9 },
  },
  gold: 123,
  inventory: { potion_hp: 2, gem: 1 },
  equipped: { weapon: "iron_sword" },
  unlockedLevel: 4,
  clearedLevels: [1, 2, 3],
  battle: null,
  inventoryOpen: false,
};

describe("migrate", () => {
  it("upgrades a bare v1 save all the way to the current shape", () => {
    const state = migrate(structuredClone(V1));
    expect(state).not.toBeNull();
    const s = state!;

    // never resume mid-menu; the world is the game now
    expect(s.screen).toBe("world");
    expect(s.battle).toBeNull();
    expect(s.shopOpen).toBe(false);

    // v3: heroes without a world wake up in the village
    expect(s.world?.position.mapId).toBe("town");

    // v4: the equipped item id became a gear instance
    expect(s.gear).toHaveLength(1);
    expect(s.gear[0].itemId).toBe("iron_sword");
    expect(s.equipped.weapon).toBe(s.gear[0].uid);

    // compat seeding: banked points, the old level-gated skills, and grit
    expect(s.hero!.statPoints).toBe(0);
    expect(s.hero!.stats.endurance).toBe(8); // warrior base
    expect(s.hero!.skillNodes).toHaveLength(2); // level 3 owned the level-1 and level-3 skills
    expect(s.hero!.skillPoints).toBe(1); // level 3 = 2 earned, 1 spent on the second skill

    // progress preserved
    expect(s.gold).toBe(123);
    expect(s.unlockedLevel).toBe(4);
    expect(s.clearedLevels).toEqual([1, 2, 3]);
  });

  it("recomputes unlock progress from cleared floors", () => {
    const capped = { ...structuredClone(V1), unlockedLevel: 10, clearedLevels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] };
    const s = migrate(capped)!;
    // players who cleared the old final floor must see the new floors
    expect(s.unlockedLevel).toBe(11);
  });

  it("rejects saves from the future and garbage", () => {
    expect(migrate({ version: 999, state: { hero: {} } })).toBeNull();
    expect(migrate("PXH1.not-json")).toBeNull();
    expect(migrate(null)).toBeNull();
    expect(migrate({ version: 4, state: { noHero: true } })).toBeNull();
  });
});

describe("save codes", () => {
  it("round-trips a current-version state byte for byte", () => {
    const state = migrate(structuredClone(V1)) as GameState;
    const decoded = decodeSaveCode(encodeSaveCode(state));
    expect(decoded).toEqual(state);
  });

  it("rejects invalid codes", () => {
    expect(decodeSaveCode("PXH1.@@@not-base64@@@")).toBeNull();
    expect(decodeSaveCode("nonsense")).toBeNull();
    expect(decodeSaveCode("")).toBeNull();
  });
});
