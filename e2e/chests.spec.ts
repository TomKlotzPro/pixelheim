import { expect, test, type Page } from '@playwright/test'
import { createHero, loadVeteranAt } from './helpers'

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key)
    await page.waitForTimeout(15)
  }
}

test('the town corner chest opens once and stays open', async ({ page }) => {
  await createHero(page, 'Looter')

  // two chests live in town
  await expect(page.getByTestId('world-chest')).toHaveCount(2)

  // from spawn (14,15) to the south-west corner chest at (1,16)
  await walk(page, 'ArrowLeft', 13)
  await page.keyboard.press('ArrowDown') // bump: face the chest, it blocks the tile
  await expect(page.getByTestId('world-hero')).toHaveAttribute('data-pos', '1,15')
  await expect(page.getByTestId('npc-prompt')).toBeVisible()

  await page.keyboard.press('e')
  await expect(page.locator('.world-message')).toContainText('2x Health Potion')
  await expect(page.locator('[data-testid="world-chest"][data-open]')).toHaveCount(1)

  // a chest gives exactly once
  await page.keyboard.press('e')
  await expect(page.getByTestId('npc-prompt')).toBeHidden()
})

test('ground treasure is taken in stride', async ({ page }) => {
  await loadVeteranAt(page, 19, 29)
  await page.keyboard.press('ArrowRight')
  await expect(page.getByTestId('world-hero')).toHaveAttribute('data-pos', '20,29')
  await expect(page.locator('.world-message')).toContainText('glitters')
})

test('the mirefen mimic bites instead of paying out', async ({ page }) => {
  await loadVeteranAt(page, 22, 6, 'mirefen')
  await page.keyboard.press('ArrowLeft') // bump: the chest is solid
  await expect(page.getByTestId('world-hero')).toHaveAttribute('data-pos', '22,6')
  await page.keyboard.press('e')
  await expect(page.getByText('It was a mimic all along!')).toBeVisible()
  await expect(page.getByText('Wild battle')).toBeVisible()
})
