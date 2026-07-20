import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// Regression for PIX-58: walking while a shop menu was open used to carry the
// hero out of the building, strand the shop overlay on a map with no shop,
// and crash the whole tree ("everything disappears, I need to reload").
test("movement keys are ignored while a shop menu is open", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(String(error)));

  // The smithy door in town; walk in, then up to Hilda, and talk to trade.
  await loadVeteranAt(page, 42, 10, "town");
  for (let i = 0; i < 7; i++) await page.keyboard.press("ArrowUp");
  await page.keyboard.press("e");
  await expect(page.getByRole("heading", { name: "Smith Hilda" })).toBeVisible();

  // Mash movement with the menu open: nothing should move, nothing should die.
  for (const key of ["ArrowDown", "ArrowDown", "ArrowLeft", "ArrowUp", "ArrowRight"] as const) {
    await page.keyboard.press(key);
  }
  await expect(page.getByRole("heading", { name: "Smith Hilda" })).toBeVisible();

  // Closing the shop returns to a live world, hero still inside the smithy.
  await page.getByRole("button", { name: "Close" }).click();
  await expect(page.getByTestId("world-hero")).toBeVisible();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_smith");

  expect(errors).toEqual([]);
});
