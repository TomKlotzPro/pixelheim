import { expect, test } from '@playwright/test'
import { createHero } from './helpers'

test('Esc closes the open panel without opening the pause menu', async ({ page }) => {
  await createHero(page, 'Escapist')

  // the skill tree: Esc closes it, pause stays shut
  await page.getByRole('button', { name: 'Skills' }).click()
  await expect(page.locator('.skill-tree')).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(page.locator('.skill-tree')).toBeHidden()
  await expect(page.getByText('Paused')).toBeHidden()

  // the stat sheet, same deal
  await page.getByRole('button', { name: 'Stats' }).click()
  await expect(page.locator('.stat-sheet')).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(page.locator('.stat-sheet')).toBeHidden()
  await expect(page.getByText('Paused')).toBeHidden()

  // the inventory already peeled; make sure it still does
  await page.keyboard.press('i')
  await page.keyboard.press('Escape')
  await expect(page.getByText('Paused')).toBeHidden()

  // with nothing open, Esc pauses - the old behavior survives
  await page.keyboard.press('Escape')
  await expect(page.getByText('Paused')).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(page.getByText('Paused')).toBeHidden()
})

test('any stack can be dropped, one or all', async ({ page }) => {
  await createHero(page, 'Minimalist')
  await page.keyboard.press('i')

  // drop one bread from the pair
  const bread = page.locator('.item-row', { hasText: 'Bread Loaf' })
  await expect(bread).toContainText('x2')
  await bread.getByRole('button', { name: 'Drop', exact: true }).click()
  await expect(bread).not.toContainText('x2')

  // drop the whole potion stack at once
  const potion = page.locator('.item-row', { hasText: 'Health Potion' })
  await potion.getByRole('button', { name: 'All' }).click()
  await expect(page.locator('.item-row', { hasText: 'Health Potion' })).toHaveCount(0)

  // the lone cheese drops too
  await page.locator('.item-row', { hasText: 'Cheese Wheel' }).getByRole('button', { name: 'Drop', exact: true }).click()
  await expect(page.locator('.item-row', { hasText: 'Cheese Wheel' })).toHaveCount(0)
})
