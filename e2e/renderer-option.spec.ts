import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// The renderer is an Options choice, persisted per device. WebGL is the
// default; Classic is the legacy DOM tile renderer kept as a fallback.
test("the renderer toggle switches to Classic and back, surviving reloads", async ({ page }) => {
  await loadVeteranAt(page, 28, 30, "town");

  // default: WebGL canvas
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();

  // switch to Classic: the page restarts into the DOM tile renderer
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("button", { name: "Toggle renderer" })).toHaveText("WebGL");
  await page.getByRole("button", { name: "Toggle renderer" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.locator(".world-tile").first()).toBeVisible();
  await expect(page.getByTestId("world-viewport").locator("canvas")).not.toBeVisible();

  // and back to WebGL
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("button", { name: "Toggle renderer" })).toHaveText("Classic");
  await page.getByRole("button", { name: "Toggle renderer" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();
});
