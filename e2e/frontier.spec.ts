import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// PIX-54: the frontier regions beyond the mountain ring.
test("the east pass leads to the Deepwood and back without bouncing", async ({ page }) => {
  await loadVeteranAt(page, 92, 32);

  // through the pass, travel direction preserved
  await page.keyboard.press("ArrowRight");
  await page.keyboard.press("ArrowRight");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "deepwood");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "2,24");
  await page.keyboard.press("ArrowRight");
  await page.keyboard.press("ArrowRight");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "4,24");

  // and back out west
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowLeft");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "92,32");
  // continuing away from the pass stays on the overworld
  await page.keyboard.press("ArrowLeft");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");
});

test("the west pass leads to the Mirefen causeway", async ({ page }) => {
  await loadVeteranAt(page, 2, 32);
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowLeft");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "mirefen");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "56,24");
});
