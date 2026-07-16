import { expect, test, type Page } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

async function loadVeteranInTown(page: Page) {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
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
  await expect(page.getByTestId('world-viewport')).toBeVisible()
}

test('veterans are seeded their old skills plus retroactive points', async ({ page }) => {
  await loadVeteranInTown(page)

  // level 10 warrior: 3 old skills owned, 9 points earned, 2 spent -> 7 banked
  await page.getByRole('button', { name: 'Skills +7' }).click()
  await expect(page.getByText('7 skill points')).toBeVisible()
  const owned = page.locator('.skill-node.owned')
  await expect(owned).toHaveCount(3)
  await expect(owned.filter({ hasText: 'Power Strike' })).toBeVisible()

  // tier-2 nodes stay locked behind their parent
  await expect(
    page.locator('.skill-node', { hasText: 'Unshakeable' }).getByText('Requires the skill above'),
  ).toBeVisible()

  // learn Iron Skin (+2 DEF passive): DEF in the HUD goes 23 -> 25
  await expect(page.locator('.world-hud')).toContainText('DEF 23')
  await page
    .locator('.skill-node', { hasText: 'Iron Skin' })
    .getByRole('button', { name: 'Learn (1 pt)' })
    .click()
  await expect(page.getByText('6 skill points')).toBeVisible()
  await page.getByRole('button', { name: 'Close' }).click()
  await expect(page.locator('.world-hud')).toContainText('DEF 25')

  // the purchase persists
  await page.reload()
  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.state.hero.skillNodes).toContain('warrior_iron_skin')
  expect(persisted.state.hero.skillPoints).toBe(6)
})

test('upgrades patch the battle skill they improve', async ({ page }) => {
  await loadVeteranInTown(page)
  await page.getByRole('button', { name: 'Skills +7' }).click()
  // Blood Rage: Berserk costs 4 HP instead of 8
  await page
    .locator('.skill-node', { hasText: 'Blood Rage' })
    .getByRole('button', { name: 'Learn (1 pt)' })
    .click()
  await page.getByRole('button', { name: 'Close' }).click()

  // walk out of town and pace the forest for a fight to check the button label
  for (const key of ['ArrowDown', 'ArrowDown']) {
    await page.keyboard.press(key)
    await page.waitForTimeout(20)
  }
  for (let i = 0; i < 130; i++) {
    await page.keyboard.press(i < 10 ? 'ArrowRight' : i % 2 === 0 ? 'ArrowRight' : 'ArrowLeft')
    await page.waitForTimeout(15)
    if (await page.getByText('Ambush!').isVisible().catch(() => false)) break
  }
  await expect(page.getByRole('button', { name: 'Berserk (5 MP + 4 HP)' })).toBeVisible()
})
