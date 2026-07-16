import { expect, test } from '@playwright/test'

test('changelog opens from the title screen and lists releases', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: /a retro RPG built with/ }).click()
  await expect(page.getByRole('heading', { name: 'Changelog' })).toBeVisible()
  await expect(page.getByText('The Undermountain')).toBeVisible()
  await expect(page.getByText('The Ashen Mountain', { exact: false }).first()).toBeVisible()
  await page.getByRole('button', { name: 'Close' }).click()
  await expect(page.getByRole('heading', { name: 'Changelog' })).toBeHidden()
})

test('NEW badge shows for a new version and clears after viewing', async ({ page }) => {
  await page.goto('./')
  await expect(page.getByText('NEW', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: /a retro RPG built with/ }).click()
  await page.getByRole('button', { name: 'Close' }).click()
  await expect(page.getByText('NEW', { exact: true })).toBeHidden()
  // stays cleared on reload
  await page.reload()
  await expect(page.getByText('NEW', { exact: true })).toBeHidden()
})
