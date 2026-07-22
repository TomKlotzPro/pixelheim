import { expect, test } from "@playwright/test";
import { createHero, loadVeteranAt, walk } from "./helpers";

test("the town corner chest opens once and stays open", async ({ page }) => {
  await createHero(page, "Looter");

  // two chests live in town
  await expect(page.getByTestId("world-chest")).toHaveCount(2);

  // from spawn (14,15) to the south-west corner chest at (1,16)
  await walk(page, "ArrowLeft", 26);
  await walk(page, "ArrowDown", 2); // second press bumps: face the chest, it blocks the tile
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "2,31");
  await expect(page.getByTestId("npc-prompt")).toBeVisible();

  await page.keyboard.press("e");
  await expect(page.locator(".world-message")).toContainText("2x Health Potion");
  await expect(page.locator('[data-testid="world-chest"][data-open]')).toHaveCount(1);

  // a chest gives exactly once
  await page.keyboard.press("e");
  await expect(page.getByTestId("npc-prompt")).toBeHidden();
});

test("ground treasure is taken in stride", async ({ page }) => {
  await loadVeteranAt(page, 38, 58);
  await walk(page, "ArrowRight", 2);
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "40,58");
  await expect(page.locator(".world-message")).toContainText("glitters");
});

test("the mirefen mimic bites instead of paying out", async ({ page }) => {
  await loadVeteranAt(page, 44, 12, "mirefen");
  await walk(page, "ArrowLeft", 2); // second press bumps: the chest is solid
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "43,12");
  await page.keyboard.press("e");
  await expect(page.getByText("It was a mimic all along!")).toBeVisible();
  await expect(page.getByText("Wild battle")).toBeVisible();
});
