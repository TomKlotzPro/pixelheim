import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

test("the craft tab walks you to the stations", async ({ page }) => {
  // a veteran out in the wilds, town already seen
  await loadVeteranAt(page, 60, 34);
  await page.evaluate(() => {
    const raw = localStorage.getItem("pixelheim-save-v1")!;
    const save = JSON.parse(raw);
    save.state.world.discovered = { overworld: ["48,42"] }; // the town gate marker
    localStorage.setItem("pixelheim-save-v1", JSON.stringify(save));
  });
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();

  await page.keyboard.press("i");
  await page.getByRole("button", { name: "Craft", exact: true }).click();

  // away from a station: the guide row offers the trip
  await expect(page.getByText("The stations are in town")).toBeVisible();
  await page.getByRole("button", { name: "Travel to town" }).click();

  // inventory closed, hero standing at Pixelheim Gate
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "48,40");
  await expect(page.getByText("You travel to Pixelheim Gate.")).toBeVisible();
});

test("standing at the forge, the craft tab says so", async ({ page }) => {
  await loadVeteranAt(page, 8, 8, "town_smith");
  await page.keyboard.press("i");
  await page.getByRole("button", { name: "Craft", exact: true }).click();
  await expect(page.getByTestId("station-banner")).toContainText("Hilda's forge");
});

test("station doors carry their trade icons", async ({ page }) => {
  await loadVeteranAt(page, 48, 40);
  // walk south into town
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("ArrowDown");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
  const icons = page.locator('[data-testid="door-sign"][data-icon]');
  await expect(icons).toHaveCount(2);
});
