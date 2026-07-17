import { expect, test, type Page } from "@playwright/test";
import { createHero } from "./helpers";

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(15);
  }
}

test("the elder hands out the troll toll and the journal tracks it", async ({ page }) => {
  await createHero(page, "Runner");

  // Elder Maren, static at (16,8) - the proven path
  await walk(page, "ArrowUp", 6);
  await walk(page, "ArrowRight", 2);
  await page.keyboard.press("ArrowUp");
  await page.keyboard.press("e");
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("e");
    await page.waitForTimeout(30);
  }
  await expect(page.locator(".world-message")).toContainText("Quest accepted - The Troll Toll");

  // the journal knows the promise and the count
  await page.keyboard.press("j");
  await expect(page.getByTestId("quest-troll_toll")).toContainText("The Troll Toll");
  await expect(page.getByTestId("quest-troll_toll")).toContainText("0/1");
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("journal")).toBeHidden();

  // talking again reports progress instead of re-accepting
  await page.keyboard.press("e");
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("e");
    await page.waitForTimeout(30);
  }
  await expect(page.locator(".world-message")).toContainText("The Troll Toll: 0/1");
});
