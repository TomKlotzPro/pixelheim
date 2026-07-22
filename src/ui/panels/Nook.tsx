import { getItem } from "../../game/economy/items";
import { NOOK_COMBINES } from "../../game/economy/house";
import { dispatch, useGameState } from "../../state/store";
import { PanelShell } from "./PanelShell";
import { Sprite } from "../widgets/Sprite";

const close = () => dispatch({ type: "TOGGLE_NOOK" });

/** The manor's alchemy nook (PIX-34): two of a brew distill into a better one. */
export function Nook() {
  const state = useGameState();

  return (
    <PanelShell
      onClose={close}
      className="inventory-panel hall-panel"
      testId="nook"
      title="Alchemy Nook"
      sprite="tile_cauldron"
    >
      <p className="merchant-line">Two of a kind go in. Something better comes out.</p>
      {NOOK_COMBINES.map(({ from, to }) => {
        const have = state.inventory[from] ?? 0;
        const fromItem = getItem(from);
        const toItem = getItem(to);
        return (
          <div key={`${from}-${to}`} className="item-row">
            <Sprite name={fromItem.sprite} size={32} alt={fromItem.name} />
            <div className="item-info">
              <span className="item-name">
                2x {fromItem.name} → {toItem.name}
              </span>
              <span className="item-stats">You have {have}</span>
              <span className="item-desc">{toItem.description}</span>
            </div>
            <div className="item-actions">
              <button
                className="btn btn-small"
                disabled={have < 2}
                onClick={() => dispatch({ type: "COMBINE_POTIONS", itemId: from })}
              >
                Distill
              </button>
            </div>
          </div>
        );
      })}
    </PanelShell>
  );
}
