import { expect, test } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

test('the craft tab brews potions from foraged materials', async ({ page }) => {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      inventory: { forest_herb: 3, marsh_reed: 1 },
      world: { position: { mapId: 'town', x: 14, y: 15, facing: 'down' }, discovered: {}, openedChests: [] },
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)),
    [SAVE_KEY, save] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()

  await page.getByRole('button', { name: 'Inventory (I)' }).click()
  await page.getByRole('button', { name: 'Craft' }).click()

  // antidote needs 2 herbs: craftable; ember salve needs shards: not
  const antidote = page.locator('.item-row', { hasText: 'Antidote' })
  await expect(antidote).toContainText('2x Forest Herb (3)')
  const salve = page.locator('.item-row', { hasText: 'Ember Salve' })
  await expect(salve.getByRole('button', { name: 'Craft' })).toBeDisabled()

  await antidote.getByRole('button', { name: 'Craft' }).click()
  // herbs 3 -> 1: the antidote row now shows too few herbs and disables
  await expect(antidote).toContainText('2x Forest Herb (1)')
  await expect(antidote.getByRole('button', { name: 'Craft' })).toBeDisabled()

  // the brewed antidote is a real item on the potions tab
  await page.getByRole('button', { name: 'Potions' }).click()
  await expect(page.getByText('Antidote')).toBeVisible()
})
