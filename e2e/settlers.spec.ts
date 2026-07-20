import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

type Overrides = {
  mapId: string;
  x: number;
  y: number;
  inventory?: Record<string, number>;
  settlers?: string[];
  hp?: number;
  discovered?: Record<string, string[]>;
};

async function loadSettlerScene(page: Page, over: Overrides) {
  const save = structuredClone(VETERAN_SAVE) as never as {
    state: {
      world: unknown;
      inventory: Record<string, number>;
      settlers?: string[];
      hero: { hp: number };
    };
  };
  save.state.world = {
    position: { mapId: over.mapId, x: over.x, y: over.y, facing: "right" },
    discovered: over.discovered ?? {},
    openedChests: [],
  };
  if (over.inventory) save.state.inventory = over.inventory;
  if (over.settlers) save.state.settlers = over.settlers;
  if (over.hp !== undefined) save.state.hero.hp = over.hp;
  await page.goto("./");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.goto("./");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", `${over.x},${over.y}`);
}

// Recruiting (PIX-92): meet Iva in the fen with reeds in the pack, hear her
// out, and she moves to Pixelheim - gone from the marsh in the same breath.
test("Iva the Healer joins for three marsh reeds", async ({ page }) => {
  await loadSettlerScene(page, { mapId: "mirefen", x: 51, y: 24, inventory: { marsh_reed: 3 } });

  await page.keyboard.press("e"); // hello
  await expect(page.getByTestId("dialogue")).toContainText("Iva the Healer");
  await page.keyboard.press("e"); // her story
  await page.keyboard.press("e"); // farewell - and the ask resolves
  await expect(page.locator(".world-message")).toContainText("joins Pixelheim");
  // she has already left the fen
  await expect(page.locator('[data-testid="world-npc"]')).toHaveCount(0);
});

// Settled services: Iva heals in town, and the whole trio walks its streets.
test("a settled healer mends her patron for free", async ({ page }) => {
  await loadSettlerScene(page, {
    mapId: "town",
    x: 33,
    y: 16,
    hp: 5,
    settlers: ["settler_iva", "settler_loras", "settler_wren"],
  });

  // three founders + three settlers on the streets
  await expect(page.getByTestId("world-npc")).toHaveCount(6);

  await page.keyboard.press("e");
  await expect(page.getByTestId("dialogue")).toContainText("Iva the Healer");
  await page.keyboard.press("e");
  await page.keyboard.press("e");
  await expect(page.locator(".world-message")).toContainText("Fully healed");
  await expect(page.locator(".world-hud")).toContainText("105/105");
});

// The stablemaster's post: the square waypoint only answers once Wren runs it.
test("fast travel to the square needs its stablemaster", async ({ page }) => {
  await loadSettlerScene(page, {
    mapId: "overworld",
    x: 48,
    y: 40,
    settlers: ["settler_wren"],
    discovered: { town: ["28,15"], overworld: ["48,42"] },
  });

  await page.keyboard.press("m");
  const row = page.locator(".options-row", { hasText: "Pixelheim Square" });
  await expect(row).toBeVisible();
  await row.getByRole("button", { name: "Travel" }).click();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", "28,15");
});
