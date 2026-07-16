import { expect, test, type Page } from '@playwright/test'
import { loadVeteranAt } from './helpers'

const hero = (page: Page) => page.getByTestId('world-hero')

test('the mountain gate opens the floor select; clearing a floor returns to the door', async ({ page }) => {
  test.setTimeout(60_000)
  await loadVeteranAt(page, 24, 4)

  // step up into the gate
  await page.keyboard.press('ArrowUp')
  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
  await expect(page.getByRole('button', { name: /Mossy Cellar/ })).toContainText('CLEARED')
  await expect(page.getByRole('button', { name: /The Ashen Throne/ })).toBeEnabled()

  // run floor 1: the veteran one-shots slimes
  await page.getByRole('button', { name: /Mossy Cellar/ }).click()
  for (let i = 0; i < 30; i++) {
    const collect = page.getByRole('button', { name: /Collect and return/ })
    if (await collect.isVisible().catch(() => false)) {
      await collect.click()
      break
    }
    const pressOn = page.getByRole('button', { name: 'Press on' })
    if (await pressOn.isVisible().catch(() => false)) await pressOn.click()
    else {
      const attack = page.getByRole('button', { name: 'Attack', exact: true })
      if (await attack.isVisible().catch(() => false)) await attack.click()
    }
    await page.waitForTimeout(30)
  }

  // back in the world, still standing at the gate
  await expect(page.getByTestId('world-viewport')).toBeVisible()
  await expect(hero(page)).toHaveAttribute('data-pos', '24,4')
})

test('stepping away from the gate returns to the world without entering', async ({ page }) => {
  await loadVeteranAt(page, 24, 4)
  await page.keyboard.press('ArrowUp')
  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
  await page.getByRole('button', { name: 'Step away' }).click()
  await expect(page.getByTestId('world-viewport')).toBeVisible()
  await expect(hero(page)).toHaveAttribute('data-pos', '24,4')
})

test('the Undermountain cave stays sealed until the dragon falls', async ({ page }) => {
  await loadVeteranAt(page, 13, 5)
  await page.keyboard.press('ArrowLeft')
  await expect(page.getByText('The Undermountain')).toBeVisible()
  await expect(page.getByText('The seal on the deep holds fast')).toBeVisible()
  // all five floors locked
  await expect(page.getByText('???')).toHaveCount(5)
})
