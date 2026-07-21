import {
  EXPANSION_COST,
  EXPANSION_RENT,
  investmentsOf,
  SAVINGS_MAX_DAYS,
  SAVINGS_RATE,
  savingsValue,
  VENTURE_COST,
  VENTURE_STEPS,
  ventureReady,
} from "../../game/economy/bank";
import { PROPERTY_PRICES } from "../../state/shared";
import { dispatch, useGameState } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

const close = () => dispatch({ type: "TOGGLE_BANK" });

/**
 * Mirelle's ledger (PIX-93): savings that accrue by the day-wheel, one
 * caravan venture at a time, and expansions on owned businesses. Everything
 * shown here resolves deterministically from worldSteps.
 */
export function Bank() {
  const state = useGameState();
  useEscapeClose(close);
  const inv = investmentsOf(state);
  const steps = state.worldSteps;

  return (
    <div className="overlay" onClick={close}>
      <div className="panel inventory-panel hall-panel" onClick={(e) => e.stopPropagation()} data-testid="bank">
        <div className="inventory-header">
          <Sprite name="alchemist" size={40} alt="Mirelle the Banker" />
          <h2>The Bank</h2>
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <button className="btn btn-small" onClick={close}>
            Close
          </button>
        </div>
        <p className="merchant-line">"Idle gold is lazy gold. Let us put yours to work."</p>

        <div className="hall-current" data-testid="bank-savings">
          <h3 className="skill-branch-title">
            Savings · {Math.round(SAVINGS_RATE * 100)}% a day, up to {SAVINGS_MAX_DAYS} days
          </h3>
          {inv.savings ? (
            <div className="station-travel">
              <span>
                In the vault: <strong>{savingsValue(inv.savings, steps)}g</strong> (principal {inv.savings.principal}g)
              </span>
              <button className="btn btn-small" onClick={() => dispatch({ type: "BANK_WITHDRAW" })}>
                Withdraw all
              </button>
            </div>
          ) : (
            <p className="item-desc">The vault stands empty. Interest turns with the sun.</p>
          )}
          <div className="options-row options-actions">
            {[100, 500, 2000].map((amount) => (
              <button
                key={amount}
                className="btn btn-small"
                disabled={state.gold < amount}
                onClick={() => dispatch({ type: "BANK_DEPOSIT", amount })}
              >
                Deposit {amount}g
              </button>
            ))}
          </div>
        </div>

        <div className="hall-current" data-testid="bank-venture">
          <h3 className="skill-branch-title">The Caravan · risky</h3>
          {inv.venture ? (
            ventureReady(inv.venture, steps) ? (
              <div className="station-travel">
                <span>The caravan is back at the gates.</span>
                <button className="btn btn-small btn-primary" onClick={() => dispatch({ type: "COLLECT_VENTURE" })}>
                  Hear the news
                </button>
              </div>
            ) : (
              <p className="item-desc">
                On the road: {inv.venture.stake}g staked, back in{" "}
                {Math.max(0, VENTURE_STEPS - (steps - inv.venture.at))} steps.
              </p>
            )
          ) : (
            <div className="station-travel">
              <span className="item-desc">
                Stake {VENTURE_COST}g on a trade caravan. Most return heavy; some meet raiders.
              </span>
              <button
                className="btn btn-small"
                disabled={state.gold < VENTURE_COST}
                onClick={() => dispatch({ type: "FUND_VENTURE" })}
              >
                Fund it
              </button>
            </div>
          )}
        </div>

        <div className="hall-current" data-testid="bank-expansions">
          <h3 className="skill-branch-title">
            Expansions · {EXPANSION_COST}g each, +{EXPANSION_RENT}g rent per victory
          </h3>
          {state.properties.length === 0 && <p className="item-desc">Own a business first; then we grow it.</p>}
          {state.properties.map((mapId) => {
            const deed = PROPERTY_PRICES[mapId];
            const expanded = inv.expansions.includes(mapId);
            return (
              <div key={mapId} className="options-row">
                <span>{deed?.name ?? mapId}</span>
                {expanded ? (
                  <span className="station-banner">EXPANDED</span>
                ) : (
                  <button
                    className="btn btn-small"
                    disabled={state.gold < EXPANSION_COST}
                    onClick={() => dispatch({ type: "EXPAND_PROPERTY", mapId })}
                  >
                    Expand
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
