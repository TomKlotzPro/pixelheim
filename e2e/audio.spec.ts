import { expect, test } from "@playwright/test";

test("mute toggle works and the choice survives a reload", async ({ page }) => {
  await page.goto("./?pixi");
  const button = page.getByRole("button", { name: "Mute" });
  await expect(button).toBeVisible();
  await button.click();
  await expect(page.getByRole("button", { name: "Unmute" })).toBeVisible();
  await page.reload();
  await expect(page.getByRole("button", { name: "Unmute" })).toBeVisible();
  await page.getByRole("button", { name: "Unmute" }).click();
  await expect(page.getByRole("button", { name: "Mute" })).toBeVisible();
});
