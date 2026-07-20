import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

/** loadVeteranAt against the voxel (three.js) entry point, via ?voxel. */
async function loadVoxelVeteranAt(page: Page, x: number, y: number, mapId = "overworld") {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      world: { position: { mapId, x, y, facing: "up" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./?voxel");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.goto("./?voxel");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();
}

// The voxel diorama (PIX-111): same reducer, third renderer. This smoke test
// proves it boots, draws, and survives play: voxels.json loads, a canvas
// appears, and moving around (including through a door) throws nothing.
// Looks are reviewed by eye; correctness stays with the DOM-renderer specs.
test("the voxel world renderer draws and survives movement", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(String(error)));

  await loadVoxelVeteranAt(page, 26, 14, "town");

  const viewport = page.getByTestId("world-viewport");
  await expect(viewport).toHaveAttribute("data-renderer", "voxel");

  // Walk a few steps; the reducer (and save) advance even though the DOM
  // shows no tiles, proving input and state flow through the canvas path.
  const before = await page.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  for (const key of ["ArrowUp", "ArrowUp", "ArrowLeft", "ArrowDown"] as const) {
    await page.keyboard.press(key);
  }
  await expect.poll(async () => page.evaluate((key) => localStorage.getItem(key), SAVE_KEY)).not.toBe(before);

  expect(errors).toEqual([]);
});

// Doors still lead somewhere: enter the inn and the renderer rebuilds the
// interior scene without a page error.
test("the voxel renderer survives walking through a door", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(String(error)));

  // One tile south of the inn door at 24,8: one step up walks through it.
  await loadVoxelVeteranAt(page, 24, 9, "town");
  await page.keyboard.press("ArrowUp");
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_inn");

  expect(errors).toEqual([]);
});
