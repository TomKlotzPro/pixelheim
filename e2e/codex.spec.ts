import { expect, test } from '@playwright/test'
import { loadVeteranAt, SAVE_KEY, VETERAN_SAVE } from './helpers'

test('the codex tracks masteries and reveals the bestiary', async ({ page }) => {
  // a veteran with 12 beast kills on record
  const save = structuredClone(VETERAN_SAVE) as typeof VETERAN_SAVE & {
    state: { hero: { mastery?: Record<string, number> } }
  }
  save.state.hero.mastery = { beasts: 12 }
  await page.goto('./')
  await page.evaluate(
    ([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)),
    [SAVE_KEY, save] as const,
  )
  await page.reload()
  await page.getByRole('button', { name: 'Continue' }).click()

  await page.getByRole('button', { name: 'Codex' }).click()
  await expect(page.getByTestId('codex')).toBeVisible()

  // 12 beast kills: Slayer I earned, progress toward II shown
  const beasts = page.getByTestId('mastery-beasts')
  await expect(beasts).toContainText('Slayer I')
  await expect(beasts).toContainText('12 slain')
  await expect(beasts).toContainText('13 more')

  // the bestiary knows beasts, keeps the rest secret
  await page.getByRole('button', { name: 'Bestiary' }).click()
  await expect(page.locator('.item-row', { hasText: 'Dire Wolf' })).toBeVisible()
  await expect(page.getByText('Unmet. The wilds keep their secrets.').first()).toBeVisible()

  // Esc closes just the codex
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('codex')).toBeHidden()
  await expect(page.getByText('Paused')).toBeHidden()
})

test('an unbloodied hero has an empty ledger', async ({ page }) => {
  await loadVeteranAt(page, 24, 20)
  await page.getByRole('button', { name: 'Codex' }).click()
  await expect(page.getByTestId('mastery-beasts')).toContainText('0 slain')
})
