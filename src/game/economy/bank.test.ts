import { describe, expect, it } from "vitest";
import { createHero } from "../hero/character";
import {
  DAY_STEPS,
  expansionRent,
  SAVINGS_MAX_DAYS,
  savingsValue,
  VENTURE_STEPS,
  ventureOutcome,
  ventureReady,
} from "./bank";
import type { GameState } from "../types";
import { gameReducer, initialState } from "../../state/gameReducer";

function atBank(gold: number): GameState {
  const s = structuredClone(initialState);
  s.hero = createHero("Coin", "warrior");
  s.screen = "world";
  s.gold = gold;
  s.townTier = 3;
  s.settlers = ["settler_mirelle"];
  s.openPanel = "bank";
  s.worldSteps = 1000;
  s.world = { position: { mapId: "town", x: 45, y: 20, facing: "right" }, discovered: {}, openedChests: [], slain: [] };
  return s;
}

describe("the bank (PIX-93)", () => {
  it("savings accrue by the day-wheel and cap out", () => {
    const pot = { principal: 1000, at: 0 };
    expect(savingsValue(pot, 0)).toBe(1000);
    expect(savingsValue(pot, DAY_STEPS - 1)).toBe(1000);
    expect(savingsValue(pot, DAY_STEPS)).toBe(1020);
    expect(savingsValue(pot, DAY_STEPS * 3)).toBe(1060);
    expect(savingsValue(pot, DAY_STEPS * 100)).toBe(1000 + 20 * SAVINGS_MAX_DAYS); // capped
  });

  it("deposits fold accrued interest into the new principal", () => {
    let s = atBank(2000);
    s = gameReducer(s, { type: "BANK_DEPOSIT", amount: 1000 });
    expect(s.gold).toBe(1000);
    expect(s.investments?.savings).toEqual({ principal: 1000, at: 1000 });

    // a day later, deposit again: the 2% rides into the principal
    s = { ...s, worldSteps: 1000 + DAY_STEPS };
    s = gameReducer(s, { type: "BANK_DEPOSIT", amount: 500 });
    expect(s.investments?.savings?.principal).toBe(1520);
    expect(s.gold).toBe(500);

    s = gameReducer(s, { type: "BANK_WITHDRAW" });
    expect(s.gold).toBe(2020);
    expect(s.investments?.savings).toBeUndefined();
  });

  it("the ledger only opens across Mirelle's counter", () => {
    let s = atBank(1000);
    s = { ...s, openPanel: null, settlers: [] };
    s = gameReducer(s, { type: "TOGGLE_BANK" });
    expect(s.openPanel).toBeNull(); // no banker, no bank

    s = { ...s, settlers: ["settler_mirelle"] };
    s = gameReducer(s, { type: "TOGGLE_BANK" });
    expect(s.openPanel).toBe("bank");
  });

  it("the caravan is sealed at departure and pays deterministically", () => {
    const venture = { stake: 500, at: 1000 };
    expect(ventureReady(venture, 1000 + VENTURE_STEPS - 1)).toBe(false);
    expect(ventureReady(venture, 1000 + VENTURE_STEPS)).toBe(true);
    const a = ventureOutcome(venture);
    const b = ventureOutcome(venture);
    expect(a).toEqual(b); // same road, same fate
    expect(a.payout).toBe(a.won ? 800 : 200);

    let s = atBank(600);
    s = gameReducer(s, { type: "FUND_VENTURE" });
    expect(s.gold).toBe(100);
    expect(s.investments?.venture).toEqual({ stake: 500, at: 1000 });
    s = gameReducer(s, { type: "FUND_VENTURE" });
    expect(s.gold).toBe(100); // one caravan at a time

    s = gameReducer(s, { type: "COLLECT_VENTURE" });
    expect(s.investments?.venture).toBeDefined(); // not back yet
    s = { ...s, worldSteps: 1000 + VENTURE_STEPS };
    s = gameReducer(s, { type: "COLLECT_VENTURE" });
    expect(s.investments?.venture).toBeUndefined();
    expect(s.gold).toBeGreaterThan(100);
  });

  it("expansions cost gold once and raise the rent", () => {
    let s = atBank(2500);
    s = { ...s, properties: ["town_shop"] };
    s = gameReducer(s, { type: "EXPAND_PROPERTY", mapId: "town_smith" });
    expect(s.investments?.expansions ?? []).toEqual([]); // not owned
    s = gameReducer(s, { type: "EXPAND_PROPERTY", mapId: "town_shop" });
    expect(s.gold).toBe(1500);
    expect(expansionRent(s)).toBe(2);
    s = gameReducer(s, { type: "EXPAND_PROPERTY", mapId: "town_shop" });
    expect(s.gold).toBe(1500); // once
  });
});
