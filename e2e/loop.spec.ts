import { expect, test } from "@playwright/test";
import { createHero, chase, fightOut, walkPath as walk } from "./helpers";

/** Walk a path with small settles between steps. */
test("the full loop: a new hero quests, fights, shops and sleeps in one life", async ({ page }) => {
  test.setTimeout(90_000);
  await createHero(page, "Loop");

  // 1. take the elder's quest (static at 16,8)
  await walk(page, [
    ["ArrowUp", 12],
    ["ArrowRight", 4],
    ["ArrowUp", 2],
  ]);
  for (let i = 0; i < 4; i++) {
    await page.keyboard.press("e");
    await page.waitForTimeout(40);
  }
  await expect(page.locator(".world-message")).toContainText("Quest accepted");

  // 2. around the elder, north through the gate into the Ashenreach
  await walk(page, [
    ["ArrowRight", 2],
    ["ArrowUp", 4],
    ["ArrowLeft", 2],
    ["ArrowUp", 13],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");

  // 3. arrive at (24,20); north-east to the forest spawn around (31,17)
  await walk(page, [
    ["ArrowUp", 6],
    ["ArrowRight", 12],
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
    "ArrowDown",
    "ArrowLeft",
    "ArrowUp",
    "ArrowRight",
    "ArrowRight",
    "ArrowDown",
    "ArrowLeft",
    "ArrowUp",
    "ArrowRight",
    "ArrowRight",
  ]);
  await expect(page.getByText("Wild battle")).toBeVisible();
  await fightOut(page);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");

  // 4. home through the gate, into Odo's, buy bread
  await walk(page, [
    ["ArrowLeft", 13],
    ["ArrowDown", 8],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
  await walk(page, [
    ["ArrowDown", 16],
    ["ArrowLeft", 24],
    ["ArrowUp", 10],
    ["ArrowUp", 6],
  ]);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_shop");
  await page.keyboard.press("e");
  await page.getByRole("button", { name: "Buy 4g" }).click();
  await page.getByRole("button", { name: "Close" }).click();

  // 5. the pack remembers the day
  await page.keyboard.press("i");
  await expect(page.locator(".item-row", { hasText: "Bread Loaf" })).toBeVisible();
});
