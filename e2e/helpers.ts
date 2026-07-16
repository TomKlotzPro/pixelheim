import { expect, type Page } from '@playwright/test'

/** Creates a hero (default role: Warrior) and lands in the hub. */
export async function createHero(page: Page, name: string, role?: string) {
  await page.goto('./')
  await page.getByRole('button', { name: 'New Game' }).click()
  await page.getByPlaceholder('Dragonsbane...').fill(name)
  if (role) await page.getByRole('button', { name: role }).click()
  await page.getByRole('button', { name: 'Begin the climb' }).click()
  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
}

export const SAVE_KEY = 'pixelheim-save-v1'

/**
 * A genuine v1 save: bare GameState, no version envelope, no shopOpen field.
 * FROZEN FOREVER. This is the regression fixture proving that saves from the
 * first release keep loading. Never update it to match new state shapes; that
 * is what migrations are for.
 */
export const V1_SAVE = {
  screen: 'hub',
  hero: {
    name: 'OldTimer',
    roleId: 'warrior',
    level: 3,
    xp: 10,
    xpToNext: 74,
    hp: 40,
    mp: 5,
    stats: { maxHp: 56, maxMp: 10, strength: 15, intelligence: 5, dexterity: 7, defense: 9 },
  },
  gold: 123,
  inventory: { potion_hp: 2, gem: 1 },
  equipped: { weapon: 'iron_sword' },
  unlockedLevel: 4,
  clearedLevels: [1, 2, 3],
  battle: null,
  inventoryOpen: false,
} as const
