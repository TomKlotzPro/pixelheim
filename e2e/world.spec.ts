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

test('the hub opens the Ashenreach and the town gate leads into the village', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: 'New Game' }).click()
  await page.getByPlaceholder('Dragonsbane...').fill('Wanderer')
  await page.getByRole('button', { name: 'Begin the climb' }).click()

  await page.getByRole('button', { name: 'World (beta)' }).click()
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'overworld')
  await expect(hero(page)).toHaveAttribute('data-pos', '24,19')

  // two steps south: through the town gate into the village
  await pressTimes(page, 'ArrowDown', 2)
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town')
  await expect(hero(page)).toHaveAttribute('data-pos', '9,9')

  // out through the gate, back on the overworld path
  await page.keyboard.press('ArrowDown')
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'overworld')
  await expect(hero(page)).toHaveAttribute('data-pos', '24,20')

  // Escape returns to the hub with the hero intact, and re-entering resumes in place
  await page.keyboard.press('Escape')
  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
  await page.getByRole('button', { name: 'World (beta)' }).click()
  await expect(hero(page)).toHaveAttribute('data-pos', '24,20')
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
