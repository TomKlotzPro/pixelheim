import { expect, test } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE, walk as sharedWalk } from "./helpers";

/** The hall route is longer; the slower cadence keeps it reliable in CI. */
const walk = (page: Page, key: string, times: number) => sharedWalk(page, key, times, 25);

async function loadRichVeteranAt(page: Page, x: number, y: number) {
  const save = structuredClone(VETERAN_SAVE) as typeof VETERAN_SAVE & { state: { gold: number } };
  save.state.gold = 5000;
  await page.goto("./?pixi");
  await page.evaluate(
    ([key, s, px, py]) => {
      const parsed = s as { state: { world: unknown } };
      parsed.state.world = {
        position: { mapId: "town", x: px, y: py, facing: "down" },
        discovered: {},
        openedChests: [],
      };
      localStorage.setItem(key as string, JSON.stringify(parsed));
    },
    [SAVE_KEY, save, x, y] as const,
  );
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
}

// The wow moment of PIX-91: pay the ledger, walk outside, and the town grew.
test("the city hall funds the Village and a settler moves in", async ({ page }) => {
  await loadRichVeteranAt(page, 49, 28);

  // the founding Hamlet: three townsfolk on the streets
  await expect(page.getByTestId("world-npc")).toHaveCount(3);

  // through the HALL door, up to the mayor's counter
  await walk(page, "ArrowUp", 2);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town_hall");
  await walk(page, "ArrowRight", 2);
  await walk(page, "ArrowUp", 3);
  await page.keyboard.press("e");

  // the ledger: Hamlet now, Village on offer
  await expect(page.getByTestId("town-hall")).toBeVisible();
  await expect(page.getByTestId("hall-tier")).toContainText("Hamlet");
  await page.getByRole("button", { name: /Fund the Village/ }).click();
  await expect(page.getByTestId("hall-tier")).toContainText("Village");
  await page.getByRole("button", { name: "Close" }).click();
  await expect(page.locator(".world-message")).toContainText("VILLAGE charter");

  // walk back out: the town redraws, and Mira the Weaver has moved in
  await walk(page, "ArrowDown", 3);
  await walk(page, "ArrowLeft", 2);
  await walk(page, "ArrowDown", 2);
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
  await expect(page.getByTestId("world-npc")).toHaveCount(4);
});
