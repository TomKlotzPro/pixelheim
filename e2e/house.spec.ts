import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

async function loadRichVeteranAt(page: Page, x: number, y: number) {
  const save = structuredClone(VETERAN_SAVE) as typeof VETERAN_SAVE & { state: { gold: number } };
  save.state.gold = 5000;
  await page.goto("./");
  await page.evaluate(
    ([key, s, px, py]) => {
      const parsed = s as { state: { world: unknown } };
      parsed.state.world = {
        position: { mapId: "town", x: px, y: py, facing: "down" },
        discovered: {},
        openedChests: [],
      };
      localStorage.setItem(key as string, JSON.stringify(parsed));
    },
    [SAVE_KEY, save, x, y] as const,
  );
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
}

test("the deed, the door, the bed and the barrel", async ({ page }) => {
  // stand above the shut door at (60,26)
  await loadRichVeteranAt(page, 60, 25);

  // bump the door: it names its price
  await page.keyboard.press("ArrowDown");
  await expect(page.locator(".world-message")).toContainText("1500g");

  // E buys the deed
  await page.keyboard.press("e");
  await expect(page.locator(".world-message")).toContainText("The deed is yours");

  // bump again: welcome home
  await page.keyboard.press("ArrowDown");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_house");

  // store a potion in the barrel (it sits left of the spawn)
  for (let i = 0; i < 6; i++) await page.keyboard.press("ArrowLeft"); // last press bumps: face the barrel
  await page.keyboard.press("e");
  await expect(page.getByTestId("house-storage")).toBeVisible();
  const packRow = page.locator(".storage-column").first().locator(".options-row", { hasText: "Health Potion" });
  await packRow.getByRole("button", { name: "All" }).click();
  await expect(page.locator(".storage-column").nth(1)).toContainText("Health Potion x5");
  // take one back
  await page.locator(".storage-column").nth(1).getByRole("button", { name: "Take" }).click();
  await expect(page.locator(".storage-column").first()).toContainText("Health Potion x1");
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("house-storage")).toBeHidden();

  // the bed rests for free
  for (let i = 0; i < 5; i++) await page.keyboard.press("ArrowUp");
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowUp"); // bump: face a bed at the top wall
  await page.keyboard.press("e");
  await expect(page.locator(".world-message")).toContainText("Fully rested");
});

test("the keeper sells you the whole shop, then works for you", async ({ page }) => {
  await loadRichVeteranAt(page, 28, 18);
  // into Odo's: up the west road and through the GOODS door
  for (const [key, n] of [
    ["ArrowLeft", 20],
    ["ArrowUp", 10],
  ] as const) {
    for (let i = 0; i < n; i++) {
      await page.keyboard.press(key);
      await page.waitForTimeout(15);
    }
  }
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_shop");
  for (let i = 0; i < 6; i++) {
    await page.keyboard.press("ArrowUp");
    await page.waitForTimeout(15);
  }
  await page.keyboard.press("e");

  await expect(page.getByTestId("property-offer")).toContainText("Odo's Emporium");
  await page.getByRole("button", { name: "Buy the deed" }).click();
  await expect(page.getByTestId("property-owned")).toContainText("YOURS");
});
