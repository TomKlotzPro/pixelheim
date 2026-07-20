import { expect, test, type Page } from "@playwright/test";
import { createHero } from "./helpers";

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(15);
  }
}

test("villagers live in town and the elder tells her tale", async ({ page }) => {
  await createHero(page, "Neighbor");

  // three villagers out in the town itself
  await expect(page.getByTestId("world-npc")).toHaveCount(3);

  // walk up to the shrine square and face Elder Maren (static at 16,8)
  await walk(page, "ArrowUp", 12);
  await walk(page, "ArrowRight", 4);
  await page.keyboard.press("ArrowUp"); // bump: face her without stepping through
  await page.keyboard.press("e");

  const dialogue = page.getByTestId("dialogue");
  await expect(dialogue).toBeVisible();
  await expect(dialogue).toContainText("Elder Maren");
  await expect(dialogue).toContainText("The mountain burned");

  // pages advance with the same key, and the last one closes
  await page.keyboard.press("e");
  await expect(dialogue).toContainText("Ten floors of teeth");
  await page.keyboard.press("e");
  await expect(dialogue).toContainText("older things below");
  await page.keyboard.press("e");
  await expect(dialogue).toBeHidden();

  // movement is blocked mid-dialogue, not after
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "32,17");
});

test("the innkeeper has a face and a stew", async ({ page }) => {
  await createHero(page, "Guest");
  // route: up the lot, across the plaza, into the inn door at (12,4)
  await walk(page, "ArrowUp", 12);
  await walk(page, "ArrowLeft", 4);
  await walk(page, "ArrowUp", 10);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_inn");
  // the innkeeper stands at (4,1) in the bigger inn; walk up from the door and face her
  await walk(page, "ArrowUp", 6);
  await page.keyboard.press("e");
  await expect(page.getByTestId("dialogue")).toContainText("Innkeeper Sela");
});
