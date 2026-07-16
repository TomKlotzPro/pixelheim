import { expect, test, type Page } from '@playwright/test'
import { SAVE_KEY } from './helpers'

// A veteran hero who cannot realistically lose a forest encounter, so the
// win path is deterministic enough to test.
const VETERAN_SAVE = {
  version: 4,
  state: {
    screen: 'hub',
    hero: {
      name: 'Ranger',
      roleId: 'warrior',
      level: 10,
      xp: 0,
      xpToNext: 200,
      hp: 105,
      mp: 17,
      stats: { maxHp: 105, maxMp: 17, strength: 36, intelligence: 12, dexterity: 14, defense: 23 },
    },
    gold: 100,
    inventory: { potion_hp: 5 },
    gear: [{ uid: 'w1', itemId: 'dragonbane', rarity: 'common', bonus: 0 }],
    equipped: { weapon: 'w1' },
    unlockedLevel: 10,
    clearedLevels: [1, 2, 3, 4, 5, 6, 7, 8, 9],
    battle: null,
    inventoryOpen: false,
    shopOpen: false,
    world: null,
  },
}

const hero = (page: Page) => page.getByTestId('world-hero')

test('wandering the forest triggers an ambush; winning returns to the same tile', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, VETERAN_SAVE] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.getByRole('button', { name: 'World (beta)' }).click()
  await expect(hero(page)).toHaveAttribute('data-pos', '24,19')

  // head east into the forest region, then pace on wild grass until the
  // 10%-per-step roll fires; every move stays on row 19
  let ambushed = false
  for (let i = 0; i < 130; i++) {
    await page.keyboard.press(i < 9 ? 'ArrowRight' : i % 2 === 0 ? 'ArrowRight' : 'ArrowLeft')
    await page.waitForTimeout(15)
    if (await page.getByText('Ambush!').isVisible().catch(() => false)) {
      ambushed = true
      break
    }
  }
  expect(ambushed).toBe(true)
  await expect(page.getByText(/The Wilds:/)).toBeVisible()

  // the veteran wins, then walks on from the tile the fight started on
  for (let i = 0; i < 30; i++) {
    const walkOn = page.getByRole('button', { name: 'Walk on' })
    if (await walkOn.isVisible().catch(() => false)) {
      await walkOn.click()
      break
    }
    const attack = page.getByRole('button', { name: 'Attack', exact: true })
    if (await attack.isVisible().catch(() => false)) await attack.click()
    await page.waitForTimeout(30)
  }
  await expect(page.getByTestId('world-viewport')).toBeVisible()
  // still standing in the wilds on the row he was walking, not teleported
  expect(await hero(page).getAttribute('data-pos')).toMatch(/^\d+,19$/)
})

test('paths are safe: pacing the road never triggers a battle', async ({ page }) => {
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, VETERAN_SAVE] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.getByRole('button', { name: 'World (beta)' }).click()
  await expect(hero(page)).toHaveAttribute('data-pos', '24,19')

  // 60 steps up and down the path column; region metadata is empty there
  for (let i = 0; i < 60; i++) {
    await page.keyboard.press(i % 2 === 0 ? 'ArrowUp' : 'ArrowDown')
    await page.waitForTimeout(10)
  }
  await expect(page.getByTestId('world-viewport')).toBeVisible()
})
