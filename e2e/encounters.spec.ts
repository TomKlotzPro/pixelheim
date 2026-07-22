import { expect, test } from "@playwright/test";
import { loadVeteranAt, chase } from "./helpers";

/** Chase the wandering spawn: press toward its 2x2 loop until the fight starts. */
test("a visible monster prowls the forest; bumping it starts the fight", async ({ page }) => {
  test.setTimeout(60_000);
  await loadVeteranAt(page, 60, 34);

  // the spawn is visible before any fight
  await expect(page.getByTestId("world-monster").first()).toBeVisible();

  // walk into it (it paces a 2x2 loop around 31,17)
  await chase(page, [
    "ArrowRight",
    "ArrowRight",
    "ArrowDown",
    "ArrowLeft",
    "ArrowUp",
    "ArrowRight",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    "ArrowRight",
  ]);
  await expect(page.getByText("Wild battle")).toBeVisible();

  // the veteran wins; the spawn is gone until the map is left and re-entered
  for (let i = 0; i < 30; i++) {
    const walkOn = page.getByRole("button", { name: "Walk on" });
    if (await walkOn.isVisible().catch(() => false)) {
      await walkOn.click();
      break;
    }
    const attack = page.getByRole("button", { name: "Attack", exact: true });
    if (await attack.isVisible().catch(() => false)) await attack.click();
    await page.waitForTimeout(30);
  }
  await expect(page.getByTestId("world-viewport")).toBeVisible();
  const remaining = await page.getByTestId("world-monster").count();
  // one of the overworld's ten spawns is down
  expect(remaining).toBe(9);
});

test("the wilds no longer ambush: pacing wild grass starts nothing", async ({ page }) => {
  await loadVeteranAt(page, 72, 42);
  // 40 steps on forest-region grass, far from any spawn loop
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press(i % 2 === 0 ? "ArrowUp" : "ArrowDown");
    await page.waitForTimeout(10);
  }
  await expect(page.getByTestId("world-viewport")).toBeVisible();
  await expect(page.getByText(/The Wilds:/)).not.toBeVisible();
});
