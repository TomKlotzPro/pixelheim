import { expect, test, type Page } from '@playwright/test'

async function pressTimes(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key)
    await page.waitForTimeout(20)
  }
}

const hero = (page: Page) => page.getByTestId('world-hero')

test('world demo spawns the hero and arrows move him', async ({ page }) => {
  await page.goto('./?world')
  await expect(page.getByTestId('world-viewport')).toBeVisible()
  await expect(hero(page)).toHaveAttribute('data-pos', '8,8')

  await page.keyboard.press('ArrowRight')
  await expect(hero(page)).toHaveAttribute('data-pos', '9,8')
  await page.keyboard.press('a')
  await expect(hero(page)).toHaveAttribute('data-pos', '8,8')
})

test('mountains block movement but still turn the hero', async ({ page }) => {
  await page.goto('./?world')
  await expect(hero(page)).toHaveAttribute('data-pos', '8,8')
  // 7 steps reach the top grass row; the 8th bumps into the mountains
  await pressTimes(page, 'ArrowUp', 8)
  await expect(hero(page)).toHaveAttribute('data-pos', '8,1')
  await expect(hero(page)).toHaveClass(/facing-up/)
})

test('new heroes wake in the village and the gate leads to the overworld', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: 'New Game' }).click()
  await page.getByPlaceholder('Dragonsbane...').fill('Wanderer')
  await page.getByRole('button', { name: 'Begin the climb' }).click()
  // the three-line intro, then the village
  await page.getByRole('button', { name: 'Set out' }).click()
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town')
  await expect(hero(page)).toHaveAttribute('data-pos', '14,15')

  // out through the north gate onto the mountain road
  await pressTimes(page, 'ArrowUp', 10)
  await pressTimes(page, 'ArrowRight', 2)
  await pressTimes(page, 'ArrowUp', 5)
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'overworld')
  await expect(hero(page)).toHaveAttribute('data-pos', '24,20')

  // travel direction is preserved: holding up keeps walking AWAY from the door
  await page.keyboard.press('ArrowUp')
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'overworld')
  await expect(hero(page)).toHaveAttribute('data-pos', '24,19')

  // and deliberately back in through the gate
  await pressTimes(page, 'ArrowDown', 2)
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town')
  await expect(hero(page)).toHaveAttribute('data-pos', '16,1')

  // same going in: holding down walks INTO town, not back out
  await page.keyboard.press('ArrowDown')
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town')

  // Escape does nothing for a hero: the world IS the game now
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('world-viewport')).toBeVisible()
})

// Pinned to the legacy DOM renderer: it asserts per-tile danger markup, which
// the canvas has no DOM for. Retires with the DOM renderer (PIX-53).
test('wild terrain is visually telegraphed; safe ground is not', async ({ page }) => {
  await page.goto('./?dom')
  await page.getByRole('button', { name: 'New Game' }).click()
  await page.getByPlaceholder('Dragonsbane...').fill('Scout')
  await page.getByRole('button', { name: 'Begin the climb' }).click()
  await page.getByRole('button', { name: 'Set out' }).click()

  // the village has no encounter regions: nothing is marked dangerous
  await expect(page.locator('.world-tile[data-danger]')).toHaveCount(0)

  // out on the overworld, the wilds carry the danger overlay
  await pressTimes(page, 'ArrowUp', 10)
  await pressTimes(page, 'ArrowRight', 2)
  await pressTimes(page, 'ArrowUp', 5)
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'overworld')
  expect(await page.locator('.world-tile[data-danger]').count()).toBeGreaterThan(50)
})

test('doors travel between maps and Escape leaves the world', async ({ page }) => {
  await page.goto('./?world')
  await expect(hero(page)).toHaveAttribute('data-pos', '8,8')
  await pressTimes(page, 'ArrowRight', 9)
  await expect(hero(page)).toHaveAttribute('data-pos', '17,8')
  // through the hut door: map-to-map portal drops us inside
  await pressTimes(page, 'ArrowUp', 4)
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'demo_hut')
  await expect(hero(page)).toHaveAttribute('data-pos', '3,3')
  // back out through the interior door
  await page.keyboard.press('ArrowDown')
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'demo')
  await expect(hero(page)).toHaveAttribute('data-pos', '17,5')
  // Escape exits the demo to the title screen (no hero yet)
  await page.keyboard.press('Escape')
  await expect(page.getByRole('button', { name: 'New Game' })).toBeVisible()
})
