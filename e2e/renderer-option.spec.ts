import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// The renderer is an Options choice, persisted per device. WebGL is the
// default; Voxel is the three.js 3D diorama; Classic is the legacy DOM
// tile renderer kept as a fallback. The button cycles through all three.
test("the renderer choice cycles WebGL, Voxel, Classic, surviving reloads", async ({ page }) => {
  test.setTimeout(90_000);
  await loadVeteranAt(page, 28, 30, "town");

  // default: WebGL canvas
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "pixi");
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();

  // switch to Voxel: the page restarts into the 3D diorama
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("button", { name: "Toggle renderer" })).toHaveText("WebGL");
  await page.getByRole("button", { name: "Toggle renderer" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  // three.js + voxels.json load lazily; give the first voxel boot headroom
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "voxel", { timeout: 20_000 });
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();

  // switch to Classic: the DOM tile renderer, no canvas
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("button", { name: "Toggle renderer" })).toHaveText("Voxel");
  await page.getByRole("button", { name: "Toggle renderer" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.locator(".world-tile").first()).toBeVisible();
  await expect(page.getByTestId("world-viewport").locator("canvas")).not.toBeVisible();

  // and back to WebGL
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("button", { name: "Toggle renderer" })).toHaveText("Classic");
  await page.getByRole("button", { name: "Toggle renderer" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-renderer", "pixi");
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();
});
