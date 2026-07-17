import { describe, expect, it } from "vitest";
import { getItem } from "./items";
import { buyPrice, FORGE_BONUS_CAP, forgeCost, sellPriceAt, SHOPS, shopStock } from "./shop";

describe("shopStock", () => {
  it("every shop only stocks its own trade", () => {
    for (const shop of Object.values(SHOPS)) {
      for (const item of shopStock(shop.id, 15)) {
        expect(shop.sells).toContain(item.category);
      }
    }
  });

  it("stock grows with progression and never shrinks", () => {
    for (const shop of Object.values(SHOPS)) {
      const early = shopStock(shop.id, 1);
      const late = shopStock(shop.id, 15);
      expect(late.length).toBeGreaterThanOrEqual(early.length);
      for (const item of early) expect(late.map((i) => i.id)).toContain(item.id);
    }
  });
});

describe("prices", () => {
  it("buying costs face value; scrap sells at half; specialists pay their rate", () => {
    const herb = getItem("forest_herb");
    expect(buyPrice(herb)).toBe(herb.value);
    // Odo has no misc rate: scrap half
    expect(sellPriceAt("odo", herb)).toBe(Math.max(1, Math.floor(herb.value * 0.5)));
    // Vex pays reagents in full
    expect(sellPriceAt("alchemist", herb)).toBe(herb.value);
  });

  it("the forge gets pricier with every bonus and respects the cap", () => {
    const sword = getItem("iron_sword");
    let previous = 0;
    for (let bonus = 0; bonus < FORGE_BONUS_CAP; bonus++) {
      const cost = forgeCost(sword, bonus);
      expect(cost).toBeGreaterThanOrEqual(Math.max(20, previous));
      previous = cost;
    }
  });
});
