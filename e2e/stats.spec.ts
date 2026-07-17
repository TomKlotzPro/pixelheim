import { expect, test } from '@playwright/test'
import { SAVE_KEY, VETERAN_SAVE } from './helpers'

test('banked stat points can be spent and persist', async ({ page }) => {
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      hero: { ...VETERAN_SAVE.state.hero, statPoints: 3 },
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

  // the HUD badge advertises the unspent points
  await page.getByRole('button', { name: 'Stats +3' }).click()
  await expect(page.getByText('3 stat points to spend')).toBeVisible()
  await expect(page.getByText('STR 36')).toBeVisible()

  await page.getByRole('button', { name: 'Increase STR' }).click()
  await expect(page.getByText('STR 37')).toBeVisible()
  await expect(page.getByText('2 stat points to spend')).toBeVisible()

  // permanence: the spend survives a reload
  await page.reload()
  const persisted = await page.evaluate((key) => JSON.parse(localStorage.getItem(key)!), SAVE_KEY)
  expect(persisted.state.hero.statPoints).toBe(2)
  expect(persisted.state.hero.stats.strength).toBe(37)
})

test('leveling up banks 5 points, announced in the battle log', async ({ page }) => {
  test.setTimeout(60_000)
  // a veteran-strength hero one XP short of level 2: any wild kill levels him
  const save = {
    ...VETERAN_SAVE,
    state: {
      ...VETERAN_SAVE.state,
      hero: { ...VETERAN_SAVE.state.hero, level: 1, xp: 37, xpToNext: 38, statPoints: 0 },
    },
  }
  await page.goto('./')
  await page.evaluate(
    ([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)),
    [SAVE_KEY, { ...save, state: { ...save.state, world: { position: { mapId: 'overworld', x: 30, y: 17, facing: 'right' }, discovered: {}, openedChests: [] } } }] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()

  // bump the forest spawn, then win
  for (const key of ['ArrowRight', 'ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowRight', 'ArrowRight', 'ArrowLeft'] as string[]) {
    if (await page.getByText(/The Wilds:/).isVisible().catch(() => false)) break
    await page.keyboard.press(key)
    await page.waitForTimeout(30)
  }
  for (let i = 0; i < 30; i++) {
    const walkOn = page.getByRole('button', { name: 'Walk on' })
    if (await walkOn.isVisible().catch(() => false)) break
    const attack = page.getByRole('button', { name: 'Attack', exact: true })
    if (await attack.isVisible().catch(() => false)) await attack.click()
    await page.waitForTimeout(30)
  }
  await expect(page.getByText(/\+5 stat points/)).toBeVisible()
  await page.getByRole('button', { name: 'Walk on' }).click()
  await expect(page.getByRole('button', { name: 'Stats +5' })).toBeVisible()
})
