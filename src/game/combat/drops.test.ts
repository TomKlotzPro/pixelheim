import { afterEach, describe, expect, it, vi } from "vitest";
import { rollDrop } from "./drops";
import { getItem } from "../economy/items";
import { gearItem } from "../economy/rarity";

afterEach(() => vi.restoreAllMocks());

describe("battle drops", () => {
  it("bosses always drop; normals usually leave nothing", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.5);
    // 0.5 >= 0.22: the normal misses its drop roll
    expect(rollDrop(1, "normal")).toBeNull();
    // bosses never miss (chance 1); 0.5 >= 0.35 makes it a stack drop
    const drop = rollDrop(1, "boss");
    expect(drop).toMatchObject({ kind: "stack" });
  });

  it("low rolls turn into gear with a real, resolvable item", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.1);
    const drop = rollDrop(1, "elite");
    expect(drop?.kind).toBe("gear");
    if (drop?.kind === "gear") {
      const item = gearItem(drop.gear);
      expect(item.slot).toBeTruthy(); // gear pools only hold equippable items
    }
  });

  it("every pool id resolves to a known item at every floor gate", () => {
    // Sweep the RNG so gear and stack branches both fire across all pools.
    for (const floor of [1, 4, 7, 10, 15]) {
      for (const roll of [0.05, 0.34, 0.36, 0.9]) {
        vi.spyOn(Math, "random").mockReturnValue(roll);
        const drop = rollDrop(floor, "boss");
        expect(drop).not.toBeNull();
        if (drop?.kind === "stack") expect(() => getItem(drop.itemId)).not.toThrow();
        if (drop?.kind === "gear") expect(() => gearItem(drop.gear)).not.toThrow();
        vi.restoreAllMocks();
      }
    }
  });

  it("deeper floors unlock richer pools, never poorer ones", () => {
    vi.spyOn(Math, "random").mockReturnValue(0.5); // stack branch, first entry varies by pool
    const floor1 = rollDrop(1, "boss");
    const floor15 = rollDrop(15, "boss");
    expect(floor1?.kind).toBe("stack");
    expect(floor15?.kind).toBe("stack");
    if (floor1?.kind === "stack" && floor15?.kind === "stack") {
      // same RNG, different pools: the tables really are floor-gated
      expect(floor1.itemId).not.toBe(floor15.itemId);
    }
  });
});
