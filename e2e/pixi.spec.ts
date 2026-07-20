import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

/** loadVeteranAt against the classic WebGL canvas, pinned via ?pixi. */
async function loadCanvasVeteranAt(page: Page, x: number, y: number, mapId = "overworld") {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      world: { position: { mapId, x, y, facing: "up" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./?pixi");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.goto("./?pixi");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-viewport").locator("canvas")).toBeVisible();
}

// The classic WebGL canvas stays fully playable behind ?pixi (the voxel
// diorama is the default since the PIX-112 cutover).
// This smoke test proves it boots, draws, and survives play: assets load,
// a canvas appears, and moving around (including through a door) throws
// nothing. Visual parity is reviewed by eye; correctness stays with the
// DOM-renderer specs, which drive the same reducer.
test("the canvas world renderer draws and survives movement", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(String(error)));

  await page.goto("./?pixi");
  await page.evaluate(([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)), [
    SAVE_KEY,
    VETERAN_SAVE,
  ] as const);
  await page.goto("./?pixi");
  await page.getByRole("button", { name: "Continue" }).click();

  const viewport = page.getByTestId("world-viewport");
  await expect(viewport).toHaveAttribute("data-renderer", "pixi");
  await expect(viewport.locator("canvas")).toBeVisible();

  // Walk a few steps; the reducer (and save) advance even though the DOM
  // shows no tiles, proving input and state flow through the canvas path.
  const before = await page.evaluate((key) => localStorage.getItem(key), SAVE_KEY);
  for (const key of ["ArrowUp", "ArrowUp", "ArrowLeft", "ArrowDown"] as const) {
    await page.keyboard.press(key);
  }
  await expect.poll(async () => page.evaluate((key) => localStorage.getItem(key), SAVE_KEY)).not.toBe(before);

  expect(errors).toEqual([]);
});

// The G3 battle scene: enter a dungeon through the gate, fight one round on
// the canvas stage, and come out with zero page errors. Battle mechanics stay
// covered by the DOM specs; this proves the Pixi path renders and reacts.
test("the canvas battle scene draws and survives a fight", async ({ page }) => {
  test.setTimeout(60_000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(String(error)));

  await loadCanvasVeteranAt(page, 48, 8);
  await page.keyboard.press("ArrowUp");
  await page.keyboard.press("ArrowUp");
  await page.getByRole("button", { name: /Mossy Cellar/ }).click();

  await expect(page.getByTestId("battle-scene").locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: "Attack", exact: true }).click();
  // The veteran one-shots slimes: the won phase offers the next fight.
  await expect(page.getByRole("button", { name: "Press on" })).toBeVisible();
  await page.getByRole("button", { name: "Press on" }).click();
  await expect(page.getByTestId("battle-scene").locator("canvas")).toBeVisible();

  expect(errors).toEqual([]);
});
