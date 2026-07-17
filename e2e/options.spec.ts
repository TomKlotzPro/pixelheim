import { expect, test } from "@playwright/test";
import { createHero } from "./helpers";

test("options opens from the title menu and volume changes persist", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("button", { name: "Options", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Options" })).toBeVisible();

  await page.getByLabel("Music volume").fill("20");
  await page.getByRole("button", { name: "Close" }).click();
  await page.reload();
  await page.getByRole("button", { name: "Options", exact: true }).click();
  await expect(page.getByLabel("Music volume")).toHaveValue("20");
});

test("options opens in-game from the gear button and scanlines toggle applies", async ({ page }) => {
  await createHero(page, "Tinkerer");
  await page.getByRole("button", { name: "Settings" }).click();
  await expect(page.getByRole("heading", { name: "Options" })).toBeVisible();
  await page.locator(".options-row", { hasText: "CRT scanlines" }).getByRole("button").click();
  await expect(page.locator("html.no-scanlines")).toHaveCount(1);
});

test("deleting the save requires a confirm and clears Continue", async ({ page }) => {
  await createHero(page, "Doomed");
  await page.reload();
  await expect(page.getByRole("button", { name: "Continue" })).toBeVisible();
  await page.getByRole("button", { name: "Options", exact: true }).click();
  await page.getByRole("button", { name: "Delete save" }).click();
  await page.getByRole("button", { name: "Really delete?" }).click();
  // the app reloads with no save
  await expect(page.getByRole("button", { name: "New Game" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Continue" })).toBeHidden();
});
