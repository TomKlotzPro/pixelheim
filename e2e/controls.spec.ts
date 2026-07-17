import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

// PIX-59: controls are rebindable and persist. Bindings hold physical key
// codes, so the WASD defaults land on ZQSD for AZERTY players for free.
test("a rebound key drives the game and survives a reload", async ({ page }) => {
  await loadVeteranAt(page, 14, 15, "town");

  // The physical W-position key moves up out of the box (event.code based).
  await page.keyboard.press("w");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "14,14");

  // Rebind inventory from I to P.
  await page.getByRole("button", { name: "Settings" }).click();
  await page.getByRole("button", { name: "Rebind Inventory" }).click();
  await expect(page.getByRole("button", { name: "Rebind Inventory" })).toContainText("Press a key");
  await page.keyboard.press("p");
  await expect(page.getByRole("button", { name: "Rebind Inventory" })).toContainText("P");
  await page.getByRole("button", { name: "Close" }).click();

  // P opens the pack now; I no longer does.
  await page.keyboard.press("i");
  await expect(page.getByRole("button", { name: "Apparel" })).not.toBeVisible();
  await page.keyboard.press("p");
  await expect(page.getByRole("button", { name: "Apparel" })).toBeVisible();
  await page.keyboard.press("p");

  // The binding persists across a reload.
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toBeVisible();
  await page.keyboard.press("p");
  await expect(page.getByRole("button", { name: "Apparel" })).toBeVisible();
});
