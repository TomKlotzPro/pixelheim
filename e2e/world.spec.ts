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
