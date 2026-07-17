import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

/** The veteran, plus a jewelry box: two rings and a charm to try on. */
async function loadJeweledVeteran(page: Page) {
  const save = structuredClone(VETERAN_SAVE) as typeof VETERAN_SAVE & {
    state: { gear: { uid: string; itemId: string; rarity: string; bonus: number }[] };
  };
  save.state.gear.push(
    { uid: "r1", itemId: "band_of_grit", rarity: "common", bonus: 0 },
    { uid: "r2", itemId: "quickstep_ring", rarity: "common", bonus: 0 },
    { uid: "n1", itemId: "bone_charm", rarity: "common", bonus: 0 },
  );
  await page.goto("./");
  await page.evaluate(([key, s]) => localStorage.setItem(key as string, JSON.stringify(s)), [SAVE_KEY, save] as const);
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.keyboard.press("i");
}

test("the paper doll shows every slot and the worn weapon", async ({ page }) => {
  await loadJeweledVeteran(page);
  // nine positions on the body
  for (const slot of ["head", "neck", "body", "hands", "weapon", "offhand", "ring1", "ring2", "feet"]) {
    await expect(page.getByTestId(`doll-${slot}`)).toBeVisible();
  }
  // the veteran's dragonbane sits in the weapon slot
  await expect(page.getByTestId("doll-weapon")).toHaveClass(/doll-filled/);
  await expect(page.getByTestId("doll-stats")).toContainText("ATK");
});

test("rings fill finger by finger and the stats panel feels it", async ({ page }) => {
  await loadJeweledVeteran(page);
  await page.getByRole("button", { name: "Apparel" }).click();

  // equip both rings from the list: first finger, then the other
  const equipButtons = page.getByRole("button", { name: "Equip" });
  await equipButtons.first().click(); // Band of Grit (+1 STR)
  await expect(page.getByTestId("doll-ring1")).toHaveClass(/doll-filled/);
  await expect(page.getByTestId("doll-stats")).toContainText("+1");

  await equipButtons.first().click(); // Bone Charm or Quickstep - either lands somewhere new
  const filled = page.locator(".doll-filled");
  await expect(filled).toHaveCount(3); // weapon + two new pieces

  // clicking a worn piece takes it off
  await page.getByTestId("doll-ring1").click();
  await expect(page.getByTestId("doll-ring1")).not.toHaveClass(/doll-filled/);
});
