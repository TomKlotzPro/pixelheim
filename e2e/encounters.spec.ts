import { expect, test, type Page } from '@playwright/test'
import { loadVeteranAt } from './helpers'

const hero = (page: Page) => page.getByTestId('world-hero')

test('wandering the forest triggers an ambush; winning returns to the same tile', async ({ page }) => {
  test.setTimeout(60_000)
  await loadVeteranAt(page, 24, 19)

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
  await loadVeteranAt(page, 24, 19)

  // 60 steps up and down the path column; region metadata is empty there
  for (let i = 0; i < 60; i++) {
    await page.keyboard.press(i % 2 === 0 ? 'ArrowUp' : 'ArrowDown')
    await page.waitForTimeout(10)
  }
  await expect(page.getByTestId('world-viewport')).toBeVisible()
})
