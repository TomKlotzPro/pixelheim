import { expect, test } from '@playwright/test'
import { createHero } from './helpers'

test('clears floor 1 and unlocks floor 2', async ({ page }) => {
  await createHero(page, 'Smoke')
  await expect(page.getByRole('button', { name: /Whispering Woods/ })).toBeHidden()
  await page.getByRole('button', { name: /Mossy Cellar/ }).click()
  await expect(page.getByText('Floor 1: Mossy Cellar')).toBeVisible()

  // Fight through the floor: attack until each monster drops, press on, collect.
  for (let round = 0; round < 60; round++) {
    const collect = page.getByRole('button', { name: /Collect and return/ })
    const pressOn = page.getByRole('button', { name: 'Press on' })
    const attack = page.getByRole('button', { name: 'Attack', exact: true })
    if (await collect.isVisible().catch(() => false)) {
      await collect.click()
      break
    }
    if (await pressOn.isVisible().catch(() => false)) await pressOn.click()
    else if (await attack.isVisible().catch(() => false)) await attack.click()
    await page.waitForTimeout(25)
  }

  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
  await expect(page.getByRole('button', { name: /Mossy Cellar/ })).toContainText('CLEARED')
  await expect(page.getByRole('button', { name: /Whispering Woods/ })).toBeEnabled()
})

test('autosave persists across reload via Continue', async ({ page }) => {
  await createHero(page, 'Sleepy')
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()
  await expect(page.getByText('Sleepy')).toBeVisible()
  await expect(page.getByText('The Ashen Mountain')).toBeVisible()
})
