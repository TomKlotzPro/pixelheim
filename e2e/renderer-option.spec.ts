import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

/** The one spec that must enter through the REAL default: no URL override. */
async function loadDefaultVeteranAt(page: Page, x: number, y: number, mapId: string) {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      world: { position: { mapId, x, y, facing: "up" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", `${x},${y}`);
}

// The renderer is an Options choice, persisted per device. The voxel diorama
// IS the game since the PIX-112 cutover; WebGL is the classic 2D canvas and
// Classic the legacy DOM tiles. A dropdown picks between the three.
test("the renderer dropdown picks Voxel, Classic and WebGL, surviving reloads", async ({ page }) => {
  test.setTimeout(90_000);
  await loadDefaultVeteranAt(page, 28, 30, "town");

  // default: the voxel diorama (three.js + voxels.json load lazily)
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "voxel", { timeout: 20_000 });
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();

  // switch to Classic: the DOM tile renderer, no canvas
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByLabel("Renderer")).toHaveValue("voxel");
  await page.getByLabel("Renderer").selectOption("classic");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.locator(".world-tile").first()).toBeVisible();
  await expect(page.getByTestId("world-viewport").locator("canvas")).not.toBeVisible();

  // switch to WebGL: the classic 2D canvas
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByLabel("Renderer")).toHaveValue("classic");
  await page.getByLabel("Renderer").selectOption("webgl");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "pixi");
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();

  // and back to the diorama
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByLabel("Renderer")).toHaveValue("webgl");
  await page.getByLabel("Renderer").selectOption("voxel");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "voxel", { timeout: 20_000 });
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();
});
