import { expect, test, type Page } from '@playwright/test'
import { createHero, SAVE_KEY, V1_SAVE } from './helpers'

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key)
    await page.waitForTimeout(15)
  }
}

test('a v1 save (pre-envelope) replays the full migration chain and wakes in town', async ({ page }) => {
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, V1_SAVE] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()

  // the hub-era save wakes up standing in the village with its gold intact
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town')
  await expect(page.locator('.world-hud')).toContainText('OldTimer')
  await expect(page.locator('.world-hud .gold-line')).toHaveText(/123/)

  // shopOpen did not exist in v1; walk into the merchant's building
  await walk(page, 'ArrowLeft', 4)
  await walk(page, 'ArrowUp', 4)
  await expect(page.getByText('Finest goods')).toBeVisible()
  // floor 4 was unlocked in the fixture, so the elixir is stocked
  await expect(page.getByText('Elixir', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Close' }).click()

  // v1 -> v2 (envelope) -> v3 (world) -> v4 (gear): re-persisted current
  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.version).toBe(4)
  expect(persisted.state.hero.name).toBe('OldTimer')
  expect(persisted.state.gear).toHaveLength(1)
  expect(persisted.state.gear[0].itemId).toBe('iron_sword')
  expect(persisted.state.equipped.weapon).toBe(persisted.state.gear[0].uid)
})

test('a v2 save with a flat world position migrates to the v3 world state', async ({ page }) => {
  // Frozen v2-era shape: world was a bare position with no exploration memory.
  const v2Save = {
    version: 2,
    state: {
      ...V1_SAVE,
      shopOpen: false,
      world: { mapId: 'demo', x: 5, y: 8, facing: 'left' },
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, v2Save] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await expect(page.locator('.world-hud')).toContainText('OldTimer')

  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.version).toBe(4)
  expect(persisted.state.world.position).toEqual({ mapId: 'demo', x: 5, y: 8, facing: 'left' })
  expect(persisted.state.world.openedChests).toEqual([])
})

test('a v3 save migrates gear counts and equipped ids into instances', async ({ page }) => {
  // Frozen v3-era shape: gear lived as inventory counts, equipped held item ids.
  const v3Save = {
    version: 3,
    state: {
      ...V1_SAVE,
      shopOpen: false,
      world: null,
      inventory: { potion_hp: 2, iron_armor: 1, hunting_bow: 2 },
      equipped: { weapon: 'rusty_sword' },
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, v3Save] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await expect(page.getByTestId('world-viewport')).toBeVisible()

  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.version).toBe(4)
  // 1 armor + 2 bows + the equipped sword = 4 instances, all common
  expect(persisted.state.gear).toHaveLength(4)
  expect(persisted.state.gear.every((g: { rarity: string }) => g.rarity === 'common')).toBe(true)
  expect(persisted.state.inventory).toEqual({ potion_hp: 2 })
  expect(persisted.state.equipped.weapon).toBeDefined()

  // the migrated armor is equippable through the UI
  await page.getByRole('button', { name: 'Inventory (I)' }).click()
  await expect(page.locator('.equipped-slot', { hasText: 'Weapon' }).getByText('Rusty Sword')).toBeVisible()
  await page
    .locator('.item-row', { hasText: 'Iron Armor' })
    .getByRole('button', { name: 'Equip' })
    .click()
  await expect(page.locator('.equipped-slot', { hasText: 'Body' }).getByText('Iron Armor')).toBeVisible()
})

test('a v1-format save code still imports', async ({ page }) => {
  const v1Code = 'PXH1.' + Buffer.from(JSON.stringify(V1_SAVE)).toString('base64')
  await page.goto('./')
  await page.getByRole('button', { name: 'Options', exact: true }).click()
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill(v1Code)
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.locator('.world-hud')).toContainText('OldTimer')
})

test('save code round-trip: copy on one profile, import on a fresh one', async ({ page }) => {
  await createHero(page, 'Traveler')
  await page.reload()
  await page.getByRole('button', { name: 'Options', exact: true }).click()
  await page.getByRole('button', { name: 'Copy save code' }).click()
  const code = await page.evaluate(() => navigator.clipboard.readText())
  expect(code).toMatch(/^PXH1\./)

  await page.evaluate(() => localStorage.clear())
  await page.reload()
  await expect(page.getByRole('button', { name: 'Continue' })).toBeHidden()
  await page.getByRole('button', { name: 'Options', exact: true }).click()
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill(code)
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.locator('.world-hud')).toContainText('Traveler')
})

test('a pre-Undermountain finisher save unlocks floor 11 on load', async ({ page }) => {
  // A v2 save from when floor 10 was the end: unlockedLevel capped at 10.
  const finisher = {
    version: 2,
    state: {
      ...V1_SAVE,
      hero: { ...V1_SAVE.hero, level: 12, hp: 100, mp: 10 },
      unlockedLevel: 10,
      clearedLevels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      shopOpen: false,
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, finisher] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await expect(page.getByTestId('world-viewport')).toBeVisible()
  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.state.unlockedLevel).toBe(11)
})

test('garbage save codes are rejected with an error', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: 'Options', exact: true }).click()
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill('garbage')
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.getByText('valid save code')).toBeVisible()
})
