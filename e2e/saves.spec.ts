import { expect, test } from '@playwright/test'
import { createHero, SAVE_KEY, V1_SAVE } from './helpers'

test('a v1 save (pre-envelope) loads and is re-persisted as a v2 envelope', async ({ page }) => {
  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, V1_SAVE] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()

  await expect(page.getByText('OldTimer')).toBeVisible()
  await expect(page.locator('.hero-panel .gold-line')).toHaveText(/123/)

  // shopOpen did not exist in v1; the shop must still work on a migrated save
  await page.getByRole('button', { name: 'Merchant' }).click()
  await expect(page.getByText('Finest goods')).toBeVisible()
  // floor 4 was unlocked in the fixture, so the elixir is stocked
  await expect(page.getByText('Elixir', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Close' }).click()

  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.version).toBe(2)
  expect(persisted.state.hero.name).toBe('OldTimer')
})

test('a v1-format save code still imports', async ({ page }) => {
  const v1Code = 'PXH1.' + Buffer.from(JSON.stringify(V1_SAVE)).toString('base64')
  await page.goto('./')
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill(v1Code)
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.getByText('OldTimer')).toBeVisible()
})

test('save code round-trip: copy on one profile, import on a fresh one', async ({ page }) => {
  await createHero(page, 'Traveler')
  await page.reload()
  await page.getByRole('button', { name: 'Copy save code' }).click()
  const code = await page.evaluate(() => navigator.clipboard.readText())
  expect(code).toMatch(/^PXH1\./)

  await page.evaluate(() => localStorage.clear())
  await page.reload()
  await expect(page.getByRole('button', { name: 'Continue' })).toBeHidden()
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill(code)
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.getByText('Traveler')).toBeVisible()
})

test('a pre-Undermountain finisher save wakes up with floor 11 unlocked', async ({ page }) => {
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
  await expect(page.getByText('The Undermountain')).toBeVisible()
  await expect(page.getByRole('button', { name: /The Sunless Stair/ })).toBeEnabled()
  // floor 12 must still be locked, and locked floors hide their name behind ???
  await expect(page.getByText('Hall of Echoes')).toBeHidden()
  await expect(page.getByText('???')).toHaveCount(4)
})

test('garbage save codes are rejected with an error', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: 'Import save code' }).click()
  await page.locator('.import-input').fill('garbage')
  await page.getByRole('button', { name: 'Load save' }).click()
  await expect(page.getByText('valid save code')).toBeVisible()
})
