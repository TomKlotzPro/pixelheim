import { expect, test } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

// The WebGL renderer is behind ?pixi while it grows to parity (PIX-51).
// This smoke test proves it boots, draws, and survives play: assets load,
// a canvas appears, and moving around (including through a door) throws
// nothing. Visual parity is reviewed by eye; correctness stays with the
// DOM-renderer specs, which drive the same reducer.
test('the ?pixi renderer draws the world and survives movement', async ({ page }) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(String(error)))

  await page.goto('./')
  await page.evaluate(
    ([key, save]) => localStorage.setItem(key as string, JSON.stringify(save)),
    [SAVE_KEY, VETERAN_SAVE] as const,
  )
  await page.goto('./?pixi')
  await page.getByRole('button', { name: 'Continue' }).click()

  const viewport = page.getByTestId('world-viewport')
  await expect(viewport).toHaveAttribute('data-renderer', 'pixi')
  await expect(viewport.locator('canvas')).toBeVisible()

  // Walk a few steps; the reducer (and save) advance even though the DOM
  // shows no tiles, proving input and state flow through the canvas path.
  const before = await page.evaluate((key) => localStorage.getItem(key), SAVE_KEY)
  for (const key of ['ArrowUp', 'ArrowUp', 'ArrowLeft', 'ArrowDown'] as const) {
    await page.keyboard.press(key)
  }
  await expect
    .poll(async () => page.evaluate((key) => localStorage.getItem(key), SAVE_KEY))
    .not.toBe(before)

  expect(errors).toEqual([])
})
