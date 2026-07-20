import { currentTier, fundBlocker, nextTier, TOWN_TIERS, townTierOf } from "../../game/economy/town";
import { dispatch, useGameState } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

/**
 * The city-hall ledger (PIX-91): where Pixelheim's growth is read and paid
 * for. Shows the four ages, the current one, and what the next one asks -
 * the FUND button signs the charter, and the town redraws itself outside.
 */
const close = () => dispatch({ type: "TOGGLE_HALL" });

export function TownHall() {
  const state = useGameState();
  useEscapeClose(close);
  const tier = townTierOf(state);
  const now = currentTier(state);
  const next = nextTier(state);
  const blocker = fundBlocker(state);

  return (
    <div className="overlay" onClick={close}>
      <div className="panel inventory-panel hall-panel" onClick={(e) => e.stopPropagation()} data-testid="town-hall">
        <div className="inventory-header">
          <Sprite name="mayor" size={40} alt="Mayor Aldric" />
          <h2>City Hall</h2>
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <button className="btn btn-small" onClick={close}>
            Close
          </button>
        </div>
        <p className="merchant-line">"Every coin you invest, the town wears. Sign, and watch Pixelheim rise."</p>

        <div className="hall-track" aria-label="Town tiers">
          {TOWN_TIERS.map((t) => (
            <span
              key={t.tier}
              className={`hall-age ${t.tier < tier ? "hall-age-past" : t.tier === tier ? "hall-age-now" : "hall-age-locked"}`}
            >
              {t.name}
            </span>
          ))}
        </div>

        <div className="hall-current" data-testid="hall-tier">
          <h3 className="skill-branch-title">
            Pixelheim, {now.name} {tier > 1 && "· charter signed"}
          </h3>
          <p className="item-desc">{now.blurb}</p>
          <ul className="hall-perks">
            {now.perks.map((perk) => (
              <li key={perk}>{perk}</li>
            ))}
          </ul>
        </div>

        {next ? (
          <div className="station-travel hall-next" data-testid="hall-next">
            <div className="hall-next-body">
              <span className="spec-name">Next: {next.name}</span>
              <p className="item-desc">{next.blurb}</p>
              <ul className="hall-perks">
                {next.perks.map((perk) => (
                  <li key={perk}>{perk}</li>
                ))}
              </ul>
              {blocker && <span className="item-locked">{blocker}</span>}
            </div>
            <button
              className="btn btn-small btn-primary"
              disabled={blocker !== null}
              onClick={() => dispatch({ type: "FUND_TOWN" })}
            >
              Fund the {next.name} ({next.cost}g)
            </button>
          </div>
        ) : (
          <p className="station-banner">Pixelheim stands at its full height. The city remembers who paid for it.</p>
        )}
      </div>
    </div>
  );
}
