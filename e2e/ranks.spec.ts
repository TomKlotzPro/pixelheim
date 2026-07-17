import { expect, test } from '@playwright/test'
import { loadVeteranAt } from './helpers'

test('a level-10 veteran wears the Champion title and its aura', async ({ page }) => {
  await loadVeteranAt(page, 24, 20)
  // the HUD titles the hero by rank, not just class
  await expect(page.locator('.world-hud')).toContainText('Lv 10 Champion')
  // the mirror carries the rank for the renderers
  await expect(page.getByTestId('world-hero')).toHaveAttribute('data-rank', '2')
})
