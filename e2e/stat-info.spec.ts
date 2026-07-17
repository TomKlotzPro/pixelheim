import { expect, test } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

// PIX-64 part 1: the stat sheet explains what stats do, with live numbers
// and a preview of what the next point buys.
test('the stat sheet explains each stat and previews the next point', async ({ page }) => {
  // a veteran with points banked, standing in town
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      hero: { ...VETERAN_SAVE.state.hero, statPoints: 3 },
      world: { position: { mapId: 'town', x: 14, y: 15, facing: 'down' }, discovered: {}, openedChests: [] },
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)),
    [SAVE_KEY, save] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await expect(page.getByTestId('world-hero')).toBeVisible()
  await page.getByRole('button', { name: /Stats/ }).click()

  await expect(page.getByText(/Melee attack with STR weapons/)).toBeVisible()
  await expect(page.getByText(/flee \d+%/)).toBeVisible()
  await expect(page.getByText(/blocks \d+ per hit/)).toBeVisible()
  // the warrior's grit row: stamina pool and per-turn regen
  await expect(page.getByText(/EN \d+ · regen \d+\/turn/)).toBeVisible()

  // the veteran has banked points, so the arrow preview is showing
  await expect(page.locator('.stat-next').first()).toBeVisible()

  // spending a point moves the live readout
  const strRow = page.locator('.stat-row').first()
  const before = await strRow.locator('.stat-derived').textContent()
  await page.getByRole('button', { name: 'Increase STR' }).click()
  await expect(strRow.locator('.stat-derived')).not.toHaveText(before!)
})
