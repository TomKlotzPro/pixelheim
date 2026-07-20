import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// PIX-65: Escape pauses the game with save/options/quit at hand.
test("Escape pauses, blocks input, and quit-to-title resumes in place", async ({ page }) => {
  await loadVeteranAt(page, 28, 30, "town");

  // pause: menu up, movement keys go dead
  await page.keyboard.press("Escape");
  await expect(page.getByRole("heading", { name: "Paused" })).toBeVisible();
  await page.keyboard.press("ArrowUp");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "28,30");

  // resume: menu gone, movement lives again
  await page.getByRole("button", { name: "Resume" }).click();
  await expect(page.getByRole("heading", { name: "Paused" })).not.toBeVisible();
  await page.keyboard.press("ArrowUp");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "28,29");

  // quit to title: the hero stays warm and Continue resumes in place
  await page.keyboard.press("Escape");
  await page.getByRole("button", { name: "Quit to title" }).click();
  await expect(page.getByRole("button", { name: "New Game" })).toBeVisible();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "28,29");
});

test("Escape closes open menus before pausing", async ({ page }) => {
  await loadVeteranAt(page, 28, 30, "town");
  await page.keyboard.press("i");
  await expect(page.getByRole("button", { name: "Apparel" })).toBeVisible();
  await page.keyboard.press("Escape");
  // first Escape closed the inventory, not opened the pause menu
  await expect(page.getByRole("button", { name: "Apparel" })).not.toBeVisible();
  await expect(page.getByRole("heading", { name: "Paused" })).not.toBeVisible();
});
