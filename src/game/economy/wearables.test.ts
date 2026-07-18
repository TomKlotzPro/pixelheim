import { describe, expect, it } from "vitest";
import { ITEMS } from "./items";
import { outfitFor, WEAR_OF } from "./wearables";
import type { Equipped, GearInstance } from "../types";

const RENDERED_SLOTS = new Set(["weapon", "body", "head", "offhand"]);

function piece(itemId: string): GearInstance {
  return { uid: `uid_${itemId}`, itemId, rarity: "common", bonus: 0 };
}

describe("wearables", () => {
  it("dresses every weapon, body, head and offhand item in the game", () => {
    const undressed = Object.values(ITEMS)
      .filter((item) => item.slot && RENDERED_SLOTS.has(item.slot))
      .filter((item) => !WEAR_OF[item.id])
      .map((item) => item.id);
    expect(undressed).toEqual([]);
  });

  it("maps every overlay to a real slotted item", () => {
    for (const itemId of Object.keys(WEAR_OF)) {
      expect(ITEMS[itemId], `WEAR_OF references unknown item ${itemId}`).toBeDefined();
      expect(RENDERED_SLOTS.has(ITEMS[itemId].slot ?? "")).toBe(true);
    }
  });

  it("paints in body, offhand, head, weapon order so the blade sits on top", () => {
    const gear = [piece("iron_sword"), piece("iron_armor"), piece("iron_helm"), piece("steel_shield")];
    const equipped: Equipped = {
      weapon: "uid_iron_sword",
      body: "uid_iron_armor",
      head: "uid_iron_helm",
      offhand: "uid_steel_shield",
    };
    expect(outfitFor(gear, equipped)).toEqual(["wear_plate", "wear_shield_small", "wear_helm", "wear_sword"]);
  });

  it("skips empty slots and invisible jewelry", () => {
    const gear = [piece("rusty_sword"), piece("copper_ring")];
    const equipped: Equipped = { weapon: "uid_rusty_sword", ring1: "uid_copper_ring" };
    expect(outfitFor(gear, equipped)).toEqual(["wear_sword_rusty"]);
  });
});
