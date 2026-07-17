import { expect, test } from "@playwright/test";

test("the changelog is a page of its own with a back button", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("button", { name: /a retro RPG built with/ }).click();
  await expect(page.getByRole("heading", { name: "Changelog" })).toBeVisible();
  // the title screen is gone: this is a page, not an overlay
  await expect(page.getByRole("button", { name: "New Game" })).not.toBeVisible();
  await expect(page.getByText("The Undermountain")).toBeVisible();
  await expect(page.getByText("The Painted World")).toBeVisible();
  await page.getByRole("button", { name: "< Back" }).click();
  await expect(page.getByRole("heading", { name: "Changelog" })).toBeHidden();
  await expect(page.getByRole("button", { name: "New Game" })).toBeVisible();
});

test("NEW badge shows for a new version and clears after viewing", async ({ page }) => {
  await page.goto("./");
  await expect(page.getByText("NEW", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: /a retro RPG built with/ }).click();
  await page.getByRole("button", { name: "< Back" }).click();
  await expect(page.getByText("NEW", { exact: true })).toBeHidden();
  // stays cleared on reload
  await page.reload();
  await expect(page.getByText("NEW", { exact: true })).toBeHidden();
});
