import { expect, test } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

// PIX-28: the fog-of-war map on M, and fast travel to anything once seen.
test('the map opens on M and fast travel jumps to a seen waypoint', async ({ page }) => {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      world: {
        position: { mapId: 'overworld', x: 24, y: 20, facing: 'up' },
        // the mountain gate has been seen; the cave has not
        discovered: { overworld: ['24,20', '24,3'] },
        openedChests: [],
      },
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

  await page.keyboard.press('m')
  await expect(page.getByTestId('map-screen')).toBeVisible()

  // the unseen cave stays a mystery; the seen gate is a destination
  await expect(page.getByText('Unknown').first()).toBeVisible()
  const mountainRow = page.locator('.options-row', { hasText: 'The Ashen Mountain' })
  await mountainRow.getByRole('button', { name: 'Travel' }).click()

  await expect(page.getByTestId('map-screen')).not.toBeVisible()
  await expect(page.getByTestId('world-hero')).toHaveAttribute('data-pos', '24,4')
  await expect(page.getByText('You travel to The Ashen Mountain.')).toBeVisible()

  // the mini-map rides in the corner
  await expect(page.locator('.mini-map')).toBeVisible()
})
