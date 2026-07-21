import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(15);
  }
}

async function loadHomeownerAt(
  page: Page,
  mapId: string,
  x: number,
  y: number,
  facing: string,
  extra: Record<string, unknown> = {},
) {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      gold: 20_000,
      house: { owned: true, storage: {}, ...(extra.house as object) },
      ...extra,
      world: { position: { mapId, x, y, facing }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./?pixi");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
}

test("Odo sells the Cottage deed, then offers the Manor", async ({ page }) => {
  await loadHomeownerAt(page, "town_shop", 8, 8, "up");
  await walk(page, "ArrowUp", 6);
  await page.keyboard.press("e");

  const deed = page.getByTestId("house-deed");
  await expect(deed).toContainText("Cottage");
  await deed.getByRole("button", { name: /Buy 5000g/ }).click();
  // the next rung appears in its place, and the gold is spent
  await expect(deed).toContainText("Manor");
  await expect(page.locator(".gold-line").last()).toContainText("15000");
});

test("the cottage shelf displays a trophy and gives it back", async ({ page }) => {
  await loadHomeownerAt(page, "town_house", 12, 3, "up", {
    inventory: { dragon_scale: 1 },
    house: { owned: true, storage: {}, tier: 2 },
  });
  await page.keyboard.press("e");
  await expect(page.getByTestId("trophies")).toBeVisible();

  const scaleRow = page.locator(".item-row", { hasText: "Dragon Scale" });
  await scaleRow.getByRole("button", { name: "Display" }).click();
  await expect(scaleRow).toContainText("On the shelf");
  await scaleRow.getByRole("button", { name: "Take down" }).click();
  await expect(scaleRow).toContainText("In your pack");
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("trophies")).toHaveCount(0);
});

test("furniture places on the faced floor and returns with a touch", async ({ page }) => {
  await loadHomeownerAt(page, "town_house", 8, 4, "down", { inventory: { furn_plant: 1 } });
  await page.keyboard.press("i");
  await page.getByRole("button", { name: "Home", exact: true }).click();
  await page.getByRole("button", { name: "Place" }).click();

  const placed = page.locator('[data-testid="world-furniture"][data-pos="8,5"]');
  await expect(placed).toHaveCount(1);
  // it blocks the walk south, and E takes it back
  await page.keyboard.press("ArrowDown");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "8,4");
  await page.keyboard.press("e");
  await expect(placed).toHaveCount(0);
  await expect(page.locator(".world-message")).toContainText("back in the pack");
});

test("the manor nook distills two health potions into a greater one", async ({ page }) => {
  await loadHomeownerAt(page, "town_house", 19, 3, "up", {
    inventory: { potion_hp: 2 },
    house: { owned: true, storage: {}, tier: 3 },
  });
  await page.keyboard.press("e");
  await expect(page.getByTestId("nook")).toBeVisible();

  const row = page.locator(".item-row", { hasText: "Greater Health Potion" }).first();
  await row.getByRole("button", { name: "Distill" }).click();
  await expect(row).toContainText("You have 0");
  await expect(row.getByRole("button", { name: "Distill" })).toBeDisabled();
});
