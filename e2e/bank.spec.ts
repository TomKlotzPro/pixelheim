import { expect, test, type Page } from "@playwright/test";
import { SAVE_KEY, VETERAN_SAVE } from "./helpers";

// A City-tier veteran with Mirelle already settled, standing at her counter
// beside the city hall, with a business deed in the pack.
async function loadInvestorAt(page: Page, x: number, y: number) {
  const save = structuredClone(VETERAN_SAVE) as typeof VETERAN_SAVE & {
    state: { gold: number; townTier: number; settlers: string[]; properties: string[] };
  };
  save.state.gold = 5000;
  save.state.townTier = 3;
  save.state.settlers = ["settler_mirelle"];
  save.state.properties = ["town_shop"];
  await page.goto("./?pixi");
  await page.evaluate(
    ([key, s, px, py]) => {
      const parsed = s as { state: { world: unknown } };
      parsed.state.world = {
        position: { mapId: "town", x: px, y: py, facing: "right" },
        discovered: {},
        openedChests: [],
      };
      localStorage.setItem(key as string, JSON.stringify(parsed));
    },
    [SAVE_KEY, save, x, y] as const,
  );
  await page.reload();
  await page.getByRole("button", { name: "Continue" }).click();
}

// The wow moment of PIX-93: gold goes to work - savings, a caravan, an expansion.
test("Mirelle's bank takes deposits, funds a caravan and expands a business", async ({ page }) => {
  await loadInvestorAt(page, 45, 20); // facing Mirelle at (46,20)

  await page.keyboard.press("e");
  await expect(page.getByTestId("bank")).toBeVisible();
  const gold = page.getByTestId("bank").locator(".gold-line");
  await expect(gold).toContainText("5000");

  // the vault: 500 in, principal on display
  await page.getByRole("button", { name: "Deposit 500g" }).click();
  await expect(gold).toContainText("4500");
  await expect(page.getByTestId("bank-savings")).toContainText("principal 500g");

  // the caravan rolls out
  await page.getByRole("button", { name: "Fund it" }).click();
  await expect(gold).toContainText("4000");
  await expect(page.getByTestId("bank-venture")).toContainText("On the road");

  // the emporium grows
  await page.getByTestId("bank-expansions").getByRole("button", { name: "Expand" }).click();
  await expect(gold).toContainText("3000");
  await expect(page.getByTestId("bank-expansions")).toContainText("EXPANDED");

  // Esc closes the ledger like every other panel
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("bank")).toHaveCount(0);
});
