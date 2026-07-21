import { getItem } from "../../game/economy/items";
import { NOOK_COMBINES } from "../../game/economy/house";
import { dispatch, useGameState } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

const close = () => dispatch({ type: "TOGGLE_NOOK" });

/** The manor's alchemy nook (PIX-34): two of a brew distill into a better one. */
export function Nook() {
  const state = useGameState();
  useEscapeClose(close);

  return (
    <div className="overlay" onClick={close}>
      <div className="panel inventory-panel hall-panel" onClick={(e) => e.stopPropagation()} data-testid="nook">
        <div className="inventory-header">
          <Sprite name="tile_cauldron" size={40} alt="" />
          <h2>Alchemy Nook</h2>
          <button className="btn btn-small" onClick={close}>
            Close
          </button>
        </div>
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
      </div>
    </div>
  );
}
