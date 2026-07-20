import { expect, type Page } from "@playwright/test";

/** Creates a hero (default role: Warrior), dismisses the intro, lands in town. */
export async function createHero(page: Page, name: string, role?: string) {
  await page.goto("./?pixi");
  await page.getByRole("button", { name: "New Game" }).click();
  await page.getByPlaceholder("Dragonsbane...").fill(name);
  if (role) await page.getByRole("button", { name: role }).click();
  await page.getByRole("button", { name: "Begin the climb" }).click();
  await page.getByRole("button", { name: "Set out" }).click();
  await expect(page.getByTestId("world-viewport")).toHaveAttribute("data-map", "town");
}

/** Loads the veteran fixture standing at a specific overworld tile. */
export async function loadVeteranAt(page: Page, x: number, y: number, mapId = "overworld") {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      world: { position: { mapId, x, y, facing: "up" }, discovered: {}, openedChests: [] },
    },
  };
  await page.goto("./?pixi");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-pos", `${x},${y}`);
}

export const SAVE_KEY = "pixelheim-save-v1";

/**
 * A veteran hero who cannot realistically lose an overworld fight, for specs
 * that need deterministic battle outcomes. Spread and override as needed.
 */
export const VETERAN_SAVE = {
  version: 4,
  state: {
    screen: "hub",
    hero: {
      name: "Ranger",
      roleId: "warrior",
      level: 10,
      xp: 0,
      xpToNext: 200,
      hp: 105,
      mp: 17,
      stats: { maxHp: 105, maxMp: 17, strength: 36, intelligence: 12, dexterity: 14, defense: 23 },
    },
    gold: 100,
    inventory: { potion_hp: 5 },
    gear: [{ uid: "w1", itemId: "dragonbane", rarity: "common", bonus: 0 }],
    equipped: { weapon: "w1" },
    unlockedLevel: 10,
    clearedLevels: [1, 2, 3, 4, 5, 6, 7, 8, 9],
    battle: null,
    inventoryOpen: false,
    shopOpen: false,
    world: null,
    dungeonSelect: null,
  },
};

/**
 * A genuine v1 save: bare GameState, no version envelope, no shopOpen field.
 * FROZEN FOREVER. This is the regression fixture proving that saves from the
 * first release keep loading. Never update it to match new state shapes; that
 * is what migrations are for.
 */
export const V1_SAVE = {
  screen: "hub",
  hero: {
    name: "OldTimer",
    roleId: "warrior",
    level: 3,
    xp: 10,
    xpToNext: 74,
    hp: 40,
    mp: 5,
    stats: { maxHp: 56, maxMp: 10, strength: 15, intelligence: 5, dexterity: 7, defense: 9 },
  },
  gold: 123,
  inventory: { potion_hp: 2, gem: 1 },
  equipped: { weapon: "iron_sword" },
  unlockedLevel: 4,
  clearedLevels: [1, 2, 3],
  battle: null,
  inventoryOpen: false,
} as const;
