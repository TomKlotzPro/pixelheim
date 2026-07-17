import { carriedWeight, carryCapacity } from "../../game/hero/character";
import { getItem } from "../../game/economy/items";
import { dispatch, useGameState, useHero } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

/**
 * The storage barrel: move stackables between the pack and the house.
 * Stored goods weigh nothing on the road - hoarding, finally legal.
 */
export function HouseStorage() {
  useEscapeClose(() => dispatch({ type: "TOGGLE_STORAGE" }));
  const state = useGameState();
  const hero = useHero();
  const weight = carriedWeight(state.inventory, state.gear, state.equipped);
  const capacity = carryCapacity(hero, state.gear, state.equipped);
  const pack = Object.entries(state.inventory).toSorted(([a], [b]) => a.localeCompare(b));
  const stored = Object.entries(state.house.storage).toSorted(([a], [b]) => a.localeCompare(b));

  return (
    <div className="overlay" onClick={() => dispatch({ type: "TOGGLE_STORAGE" })}>
      <div className="panel storage-panel" onClick={(e) => e.stopPropagation()} data-testid="house-storage">
        <div className="inventory-header">
          <h2>Home Storage</h2>
          <span className={weight > capacity ? "weight-over" : ""}>
            Weight {weight}/{capacity}
          </span>
          <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_STORAGE" })}>
            Close
          </button>
        </div>
        <div className="storage-columns">
          <div className="storage-column">
            <h3 className="options-title">Your pack</h3>
            {pack.length === 0 && <p className="empty-note">Empty pockets.</p>}
            {pack.map(([itemId, count]) => (
              <div key={itemId} className="options-row">
                <span className="storage-item">
                  <Sprite name={getItem(itemId).sprite} size={16} /> {getItem(itemId).name} x{count}
                </span>
                <span className="storage-actions">
                  <button className="btn btn-small" onClick={() => dispatch({ type: "STORE_ITEM", itemId })}>
                    Store
                  </button>
                  {count > 1 && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "STORE_ITEM", itemId, count })}>
                      All
                    </button>
                  )}
                </span>
              </div>
            ))}
          </div>
          <div className="storage-column">
            <h3 className="options-title">The barrel</h3>
            {stored.length === 0 && <p className="empty-note">Echoes. Fill it.</p>}
            {stored.map(([itemId, count]) => (
              <div key={itemId} className="options-row">
                <span className="storage-item">
                  <Sprite name={getItem(itemId).sprite} size={16} /> {getItem(itemId).name} x{count}
                </span>
                <span className="storage-actions">
                  <button className="btn btn-small" onClick={() => dispatch({ type: "TAKE_ITEM", itemId })}>
                    Take
                  </button>
                  {count > 1 && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "TAKE_ITEM", itemId, count })}>
                      All
                    </button>
                  )}
                </span>
              </div>
            ))}
          </div>
        </div>
        <p className="options-footer">Stored goods weigh nothing on the road.</p>
      </div>
    </div>
  );
}
