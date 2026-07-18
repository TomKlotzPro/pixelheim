import { expect, test, type Page } from "@playwright/test";
import { createHero } from "./helpers";

/** Walk a path with small settles between steps. */
async function walk(page: Page, steps: [string, number][]): Promise<void> {
  for (const [key, n] of steps) {
    for (let i = 0; i < n; i++) {
      await page.keyboard.press(key);
      await page.waitForTimeout(20);
    }
  }
}

/** Press keys until a wild battle starts (spawns pace a 2x2 loop). */
async function chase(page: Page, keys: string[]): Promise<void> {
  for (const key of keys) {
    if (
      await page
        .getByText(/The Wilds:/)
        .isVisible()
        .catch(() => false)
    )
      return;
    await page.keyboard.press(key);
    await page.waitForTimeout(30);
  }
  await expect(page.getByText(/The Wilds:/)).toBeVisible();
}

/** Attack until the fight resolves one way or the other. */
async function fightOut(page: Page): Promise<void> {
  for (let i = 0; i < 40; i++) {
    const walkOn = page.getByRole("button", { name: "Walk on" });
    if (await walkOn.isVisible().catch(() => false)) {
      await walkOn.click();
      return;
    }
    const attack = page.getByRole("button", { name: "Attack", exact: true });
    if (await attack.isVisible().catch(() => false)) await attack.click();
    await page.waitForTimeout(60);
  }
  throw new Error("the fight never resolved");
}

test("the full loop: a new hero quests, fights, shops and sleeps in one life", async ({ page }) => {
  test.setTimeout(90_000);
  await createHero(page, "Loop");

  // 1. take the elder's quest (static at 16,8)
  await walk(page, [
    ["ArrowUp", 6],
    ["ArrowRight", 2],
    ["ArrowUp", 1],
  ]);
  for (let i = 0; i < 4; i++) {
    await page.keyboard.press("e");
    await page.waitForTimeout(40);
  }
  await expect(page.locator(".world-message")).toContainText("Quest accepted");

  // 2. around the elder, north through the gate into the Ashenreach
  await walk(page, [
    ["ArrowRight", 1],
    ["ArrowUp", 2],
    ["ArrowLeft", 1],
    ["ArrowUp", 8],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");

  // 3. arrive at (24,20); north-east to the forest spawn around (31,17)
  await walk(page, [
    ["ArrowUp", 3],
    ["ArrowRight", 6],
  ]);
  await chase(page, [
    "ArrowRight",
    "ArrowRight",
    "ArrowDown",
    "ArrowLeft",
    "ArrowUp",
    "ArrowRight",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    "ArrowRight",
  ]);
  await expect(page.getByText("Wild battle")).toBeVisible();
  await fightOut(page);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");

  // 4. home through the gate, into Odo's, buy bread
  await walk(page, [
    ["ArrowLeft", 7],
    ["ArrowDown", 4],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
  await walk(page, [
    ["ArrowDown", 8],
    ["ArrowLeft", 12],
    ["ArrowUp", 5],
    ["ArrowUp", 3],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_shop");
  await page.keyboard.press("e");
  await page.getByRole("button", { name: "Buy 4g" }).click();
  await page.getByRole("button", { name: "Close" }).click();

  // 5. the pack remembers the day
  await page.keyboard.press("i");
  await expect(page.locator(".item-row", { hasText: "Bread Loaf" })).toBeVisible();
});
