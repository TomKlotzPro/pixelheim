import { expect, test } from "@playwright/test";
import { loadVeteranAt } from "./helpers";

test("a level-10 veteran wears the Champion title and its aura", async ({ page }) => {
  await loadVeteranAt(page, 48, 40);
  // the HUD titles the hero by rank, not just class
  await expect(page.locator(".world-hud")).toContainText("Lv 10 Champion");
  // the mirror carries the rank for the renderers
  await expect(page.getByTestId("world-hero")).toHaveAttribute("data-rank", "2");
});

test("the ascended veteran walks the path graph, crossover included", async ({ page }) => {
  await loadVeteranAt(page, 48, 40);
  await page.getByRole("button", { name: "Skills +7" }).click();

  // rank 2, nothing walked: the tier-1 fork is waiting
  await expect(page.getByText("Your ascension demands a path")).toBeVisible();
  await expect(page.getByTestId("spec-juggernaut")).toBeVisible();
  await page.getByTestId("spec-warlord").getByRole("button", { name: "Walk this path" }).click();

  // chosen - and at rank 2 the NEXT tier opens immediately, crossover allowed
  await expect(page.getByTestId("spec-chosen")).toContainText("Warlord");
  await expect(page.getByTestId("spec-juggernaut")).toHaveCount(0);
  await expect(page.getByTestId("spec-bastion")).toBeVisible();
  await page.getByTestId("spec-bastion").getByRole("button", { name: "Walk this path" }).click();

  // the crossover took: identity is now the other branch's advanced form
  await expect(page.getByTestId("spec-chosen")).toContainText("Bastion");
  // rank 3 is a level away: the capstones stay locked in the graph
  await expect(page.getByTestId("path-node-unbroken")).toContainText("Rank 3");
  await page.getByRole("button", { name: "Close" }).click();

  // and the stat sheet wears the deepest identity
  await page.getByRole("button", { name: /^Stats/ }).click();
  await expect(page.locator(".sheet-role")).toContainText("Bastion");
});
