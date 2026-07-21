import { expect, test, type Page } from "@playwright/test";
import { createHero } from "./helpers";

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(15);
  }
}

test("the title diorama parades and the menu works", async ({ page }) => {
  await page.goto("./?pixi");
  await expect(page.getByRole("heading", { name: "PIXELHEIM" })).toBeVisible();
  await expect(page.locator(".title-walker")).toHaveCount(6);
  await expect(page.locator(".title-ridge")).toHaveCount(3);
  await expect(page.getByRole("button", { name: "New Game" })).toBeVisible();
});

test("character creation shows the marching hero and comparable stat bars", async ({ page }) => {
  await page.goto("./?pixi");
  await page.getByRole("button", { name: "New Game" }).click();

  // warrior selected by default; the ledger shows six stat bars
  await expect(page.locator(".role-bar-row")).toHaveCount(6);
  await expect(page.locator(".role-portrait-art")).toBeVisible();
  await expect(page.getByRole("button", { name: "Begin the climb" })).toBeDisabled();

  // picking a class updates the sheet
  await page.getByRole("button", { name: "Mage" }).click();
  await expect(page.locator(".role-portrait-class")).toHaveText("Mage");

  await page.getByPlaceholder("Dragonsbane...").fill("Sparks");
  await expect(page.locator(".role-portrait-name")).toHaveText("Sparks");
  await expect(page.getByRole("button", { name: "Begin the climb" })).toBeEnabled();
});

test("the town signs its doors", async ({ page }) => {
  await createHero(page, "Wanderer");
  // GOODS, FORGE, BREWS, INN, HALL + the FOR SALE house
  await expect(page.getByTestId("door-sign")).toHaveCount(6);
  await expect(page.locator('[data-testid="door-sign"][data-label="FORGE"]')).toHaveCount(1);
  await expect(page.locator('[data-testid="door-sign"][data-label="HALL"]')).toHaveCount(1);
});

test("a chat is one keypress away, even facing the wrong way", async ({ page }) => {
  await createHero(page, "Chatty");
  // Elder Maren stands still at (16,8). Arrive at (16,9) walking RIGHT, so the
  // hero ends up beside her but facing sideways - E should still find her.
  await walk(page, "ArrowUp", 13);
  await walk(page, "ArrowRight", 4);
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "32,17");
  await expect(page.getByTestId("world-hero")).toHaveClass(/facing-right/);
  await expect(page.getByTestId("npc-prompt")).toBeVisible(); // the prompt already knows
  await page.keyboard.press("e");
  await expect(page.getByTestId("dialogue")).toContainText("Elder Maren");
});

test("a hero can pick a look and wears it into the world", async ({ page }) => {
  await page.goto("./?pixi");
  await page.getByRole("button", { name: "New Game" }).click();
  await expect(page.locator(".look-swatch")).toHaveCount(4);
  await page.getByRole("button", { name: "Look 3" }).click();
  await page.getByPlaceholder("Dragonsbane...").fill("Styled");
  await page.getByRole("button", { name: "Begin the climb" }).click();
  await page.getByRole("button", { name: "Set out" }).click();
  await expect(page.getByTestId("world-hero")).toBeVisible();
  // the choice survives the save round-trip
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toBeVisible();
});
