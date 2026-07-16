import { expect, test } from '@playwright/test'
import { createHero } from './helpers'

test('buying and selling moves gold and inventory correctly', async ({ page }) => {
  await createHero(page, 'Trader')
  await page.getByRole('button', { name: 'Merchant' }).click()
  const gold = page.locator('.inventory-header .gold-line')
  await expect(gold).toHaveText(/30/)

  // bread costs 4g
  await page.getByRole('button', { name: 'Buy 4g' }).click()
  await expect(gold).toHaveText(/26/)

  // the starter cheese wheel (value 12) sells for half: 6g
  await page.getByRole('button', { name: 'Sell', exact: true }).click()
  await page.getByRole('button', { name: 'Sell 6g' }).click()
  await expect(gold).toHaveText(/32/)

  // the bread we bought is in the inventory
  await page.getByRole('button', { name: 'Close' }).click()
  await page.getByRole('button', { name: 'Inventory' }).click()
  await expect(page.getByText('Bread Loaf')).toBeVisible()
  await expect(page.getByText('x3')).toBeVisible()
})
