import { expect, test } from "@playwright/test";
import { createHero, walk } from "./helpers";

test("a new hero walks from the village to the mountain and clears floor 1", async ({ page }) => {
  test.setTimeout(60_000);
  await createHero(page, "Smoke");

  // out of the north gate onto the overworld road
  await walk(page, "ArrowUp", 20);
  await walk(page, "ArrowRight", 4);
  await walk(page, "ArrowUp", 10);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "overworld");
  // north along the safe path, over the bridge, into the mountain gate
  await walk(page, "ArrowUp", 34);
  await expect(page.getByText("The Ashen Mountain")).toBeVisible();
  await expect(page.getByRole("button", { name: /Whispering Woods/ })).toBeHidden();

  await page.getByRole("button", { name: /Mossy Cellar/ }).click();
  await expect(page.getByText("Floor 1: Mossy Cellar")).toBeVisible();
  for (let round = 0; round < 60; round++) {
    const collect = page.getByRole("button", { name: /Collect and return/ });
    const pressOn = page.getByRole("button", { name: "Press on" });
    const attack = page.getByRole("button", { name: "Attack", exact: true });
    if (await collect.isVisible().catch(() => false)) {
      await collect.click();
      break;
    }
    if (await pressOn.isVisible().catch(() => false)) await pressOn.click();
    else if (await attack.isVisible().catch(() => false)) await attack.click();
    await page.waitForTimeout(25);
  }

  // back outside the gate; floor 2 is now unlocked
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "48,7");
  await page.keyboard.press("ArrowUp");
  await expect(page.getByRole("button", { name: /Mossy Cellar/ })).toContainText("CLEARED");
  await expect(page.getByRole("button", { name: /Whispering Woods/ })).toBeEnabled();
});

test("autosave persists across reload via Continue", async ({ page }) => {
  await createHero(page, "Sleepy");
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport")).toBeVisible();
  await expect(page.locator(".world-hud")).toContainText("Sleepy");
});
