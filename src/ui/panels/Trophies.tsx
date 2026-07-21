import { getItem } from "../../game/economy/items";
import { displayedTrophies, TROPHY_BUFFS } from "../../game/economy/house";
import { dispatch, useGameState } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

const close = () => dispatch({ type: "TOGGLE_TROPHIES" });

/**
 * The cottage's shelf of honor (PIX-34): the three great trophies can hang
 * here for living buffs, or come back down for the vault price. Sell or shine.
 */
export function Trophies() {
  const state = useGameState();
  useEscapeClose(close);
  const shown = displayedTrophies(state);

  return (
    <div className="overlay" onClick={close}>
      <div className="panel inventory-panel hall-panel" onClick={(e) => e.stopPropagation()} data-testid="trophies">
        <div className="inventory-header">
          <Sprite name="tile_trophy_shelf" size={40} alt="" />
          <h2>Shelf of Honor</h2>
          <button className="btn btn-small" onClick={close}>
            Close
          </button>
        </div>
        <p className="merchant-line">Proof of the deeds. Displayed, they keep working.</p>
        {Object.entries(TROPHY_BUFFS).map(([itemId, buff]) => {
          const item = getItem(itemId);
          const displayed = shown.includes(itemId);
          const inPack = (state.inventory[itemId] ?? 0) > 0;
          return (
            <div key={itemId} className="item-row">
              <Sprite name={item.sprite} size={32} alt={item.name} />
              <div className="item-info">
                <span className="item-name">{item.name}</span>
                <span className="item-stats">{buff.label}</span>
                <span className="item-desc">
                  {displayed ? "On the shelf, doing its quiet work." : inPack ? "In your pack." : item.description}
                </span>
              </div>
              <div className="item-actions">
                {displayed ? (
                  <button className="btn btn-small" onClick={() => dispatch({ type: "TAKE_TROPHY", itemId })}>
                    Take down
                  </button>
                ) : (
                  <button
                    className="btn btn-small btn-primary"
                    disabled={!inPack}
                    onClick={() => dispatch({ type: "DISPLAY_TROPHY", itemId })}
                  >
                    Display
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
