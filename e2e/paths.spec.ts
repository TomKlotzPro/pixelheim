import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

/** A veteran one battle away from rank 2: any wild kill crosses the line. */
async function loadAscendingVeteran(page: Page): Promise<void> {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      hero: { ...VETERAN_SAVE.state.hero, level: 9, xp: 181, xpToNext: 182 },
      world: { position: { mapId: "overworld", x: 14, y: 19, facing: "up" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.goto("./");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "14,19");
}

/** Bump into the nearest pacing spawn: read the mirror, step toward it. */
async function chaseSpawn(page: Page): Promise<void> {
  for (let i = 0; i < 60; i++) {
    if (
      await page
        .getByText(/The Wilds:/)
        .isVisible()
        .catch(() => false)
    )
      return;
    const hero = (await page.getByTestId("world-hero").getAttribute("data-pos"))!.split(",").map(Number);
    const monsters = await page
      .getByTestId("world-monster")
      .evaluateAll((nodes) => nodes.map((n) => (n.getAttribute("data-pos") ?? "0,0").split(",").map(Number)));
    const target = monsters.toSorted(
      (m, n) =>
        Math.abs(m[0] - hero[0]) + Math.abs(m[1] - hero[1]) - (Math.abs(n[0] - hero[0]) + Math.abs(n[1] - hero[1])),
    )[0];
    const dx = target[0] - hero[0];
    const dy = target[1] - hero[1];
    const key = Math.abs(dx) >= Math.abs(dy) ? (dx > 0 ? "ArrowRight" : "ArrowLeft") : dy > 0 ? "ArrowDown" : "ArrowUp";
    await page.keyboard.press(key);
    await page.waitForTimeout(40);
  }
  await expect(page.getByText(/The Wilds:/)).toBeVisible();
}

// The ascension cinematic IS the choice now (PIX-105): crossing a rank holds
// the letterboxed scene open and presents the fork as cards.
test("crossing a rank offers the path fork inside the cinematic", async ({ page }) => {
  test.setTimeout(60_000);
  await loadAscendingVeteran(page);

  // hunt down the ash prowler two tiles away, then put it down
  await chaseSpawn(page);
  for (let i = 0; i < 40; i++) {
    const walkOn = page.getByRole("button", { name: "Walk on" });
    if (await walkOn.isVisible().catch(() => false)) {
      await walkOn.click();
      break;
    }
    const attack = page.getByRole("button", { name: "Attack", exact: true });
    if (await attack.isVisible().catch(() => false)) await attack.click();
    await page.waitForTimeout(60);
  }

  // back on the map, the scene holds: title, fork, and both cards
  await expect(page.getByText("Ascension")).toBeVisible();
  await expect(page.getByText("The path forks")).toBeVisible();
  await expect(page.getByTestId("rankup-path-juggernaut")).toBeVisible();
  await page.getByTestId("rankup-path-warlord").click();

  // rank 2 with one step walked: the scene rolls straight into tier 2
  await expect(page.getByTestId("rankup-path-bastion")).toBeVisible();
  await page.getByTestId("rankup-path-battlelord").click();

  // both choices stick and the scene lets go
  await expect(page.getByText("The path forks")).not.toBeVisible();
  await page.getByRole("button", { name: /Skills/ }).click();
  await expect(page.getByTestId("spec-chosen")).toContainText("Battlelord");
});
