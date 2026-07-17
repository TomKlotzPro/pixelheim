import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(15);
  }
}

async function loadVeteranInTown(page: Page, extra: Record<string, unknown> = {}) {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      ...extra,
      world: { position: { mapId: "town", x: 14, y: 15, facing: "down" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
}

test("Hilda's forge upgrades gear for gold", async ({ page }) => {
  await loadVeteranInTown(page, { gold: 5000 });
  // route to the smithy: plaza, east, up into the third building, then Hilda
  await walk(page, "ArrowUp", 6);
  await walk(page, "ArrowRight", 7);
  await walk(page, "ArrowUp", 5);
  await walk(page, "ArrowUp", 3);
  await page.keyboard.press("e");
  await expect(page.getByText("Smith Hilda")).toBeVisible();

  await page.getByRole("button", { name: "Forge" }).click();
  const row = page.locator(".item-row", { hasText: "Dragonbane" });
  await expect(row).toContainText("DMG 19");
  await row.getByRole("button", { name: /\+1 for/ }).click();
  // base 19 becomes 20 with the new +1 bonus
  await expect(row).toContainText("DMG 20 (19+1)");

  // smiths pay 60% for steel where scrap rate is 50%
  await page.getByRole("button", { name: "Sell", exact: true }).click();
  await expect(page.getByText("Nothing to sell")).toBeHidden();
});

test("Vex pays full price for reagents", async ({ page }) => {
  await loadVeteranInTown(page, { inventory: { forest_herb: 1, wolf_pelt: 1 } });
  // route to the alchemist: west along the bottom lane, up to Vex's cauldron
  await walk(page, "ArrowLeft", 10);
  await walk(page, "ArrowUp", 2);
  await walk(page, "ArrowUp", 3);
  await page.keyboard.press("e");
  await expect(page.getByText("Alchemist Vex")).toBeVisible();

  await page.getByRole("button", { name: "Sell", exact: true }).click();
  // herb value 6: Vex pays 6 (full), not the scrap 3
  await expect(page.locator(".item-row", { hasText: "Forest Herb" }).getByRole("button")).toContainText("Sell 6g");
  // pelts are misc too: full 40
  await expect(page.locator(".item-row", { hasText: "Wolf Pelt" }).getByRole("button")).toContainText("Sell 40g");
});
