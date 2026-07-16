import { expect, test, type Page } from '@playwright/test'
import { createHero } from './helpers'

async function walk(page: Page, key: string, times: number) {
  for (let i = 0; i < times; i++) {
    await page.keyboard.press(key)
    await page.waitForTimeout(15)
  }
}

test('walking into the merchant building opens the shop; gold math holds', async ({ page }) => {
  await createHero(page, 'Trader')

  // from the village square into the shop doorway
  await walk(page, 'ArrowLeft', 4)
  await walk(page, 'ArrowUp', 4)
  await expect(page.getByText('Finest goods')).toBeVisible()
  const gold = page.locator('.inventory-header .gold-line')
  await expect(gold).toHaveText(/30/)

  // bread costs 4g
  await page.getByRole('button', { name: 'Buy 4g' }).click()
  await expect(gold).toHaveText(/26/)

  // the starter cheese wheel (value 12) sells for half: 6g
  await page.getByRole('button', { name: 'Sell', exact: true }).click()
  await page.getByRole('button', { name: 'Sell 6g' }).click()
  await expect(gold).toHaveText(/32/)

  // close the counter: we are standing inside the shop
  await page.getByRole('button', { name: 'Close' }).click()
  await expect(page.getByTestId('world-viewport')).toHaveAttribute('data-map', 'town_shop')

  // the bread is in the satchel
  await page.getByRole('button', { name: 'Inventory (I)' }).click()
  await expect(page.getByText('Bread Loaf')).toBeVisible()
  await expect(page.getByText('x3')).toBeVisible()
})
