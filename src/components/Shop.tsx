import { useState } from "react";
import { getItem } from "../game/items";
import { itemStatLine } from "../game/itemStats";
import { buyPrice, sellPrice, shopStock } from "../game/shop";
import type { GameState } from "../game/types";
import type { Action } from "../state/gameReducer";
import { Sprite } from "./Sprite";

type ShopProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

export function Shop({ state, dispatch }: ShopProps) {
  const [tab, setTab] = useState<"buy" | "sell">("buy");
  const stock = shopStock(state.unlockedLevel);
  const owned = Object.entries(state.inventory).map(([id, count]) => ({ item: getItem(id), count }));

  return (
    <div className="overlay" onClick={() => dispatch({ type: "TOGGLE_SHOP" })}>
      <div className="panel inventory-panel" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <Sprite name="merchant" size={40} alt="Merchant" />
          <h2>Merchant</h2>
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_SHOP" })}>
            Close
          </button>
        </div>
        <p className="merchant-line">
          {tab === "buy"
            ? "Finest goods this side of the mountain. New stock as you climb higher."
            : "I pay half of what it is worth. That is the deal, take it or leave it."}
        </p>

        <div className="tabs">
          <button className={`tab ${tab === "buy" ? "active" : ""}`} onClick={() => setTab("buy")}>
            Buy
          </button>
          <button className={`tab ${tab === "sell" ? "active" : ""}`} onClick={() => setTab("sell")}>
            Sell
          </button>
        </div>

        <div className="item-list">
          {tab === "buy" &&
            stock.map((item) => (
              <div key={item.id} className="item-row">
                <Sprite name={item.sprite} size={32} alt={item.name} />
                <div className="item-info">
                  <span className="item-name">{item.name}</span>
                  <span className="item-stats">{itemStatLine(item)}</span>
                  <span className="item-desc">{item.description}</span>
                </div>
                <div className="item-actions">
                  <button
                    className="btn btn-small"
                    disabled={state.gold < buyPrice(item)}
                    onClick={() => dispatch({ type: "BUY_ITEM", itemId: item.id })}
                  >
                    Buy {buyPrice(item)}g
                  </button>
                </div>
              </div>
            ))}
          {tab === "sell" && owned.length === 0 && <p className="empty-note">Nothing to sell. Go loot something.</p>}
          {tab === "sell" &&
            owned.map(({ item, count }) => (
              <div key={item.id} className="item-row">
                <Sprite name={item.sprite} size={32} alt={item.name} />
                <div className="item-info">
                  <span className="item-name">
                    {item.name}
                    {count > 1 && <span className="item-count"> x{count}</span>}
                  </span>
                  <span className="item-stats">{itemStatLine(item)}</span>
                  <span className="item-desc">{item.description}</span>
                </div>
                <div className="item-actions">
                  <button className="btn btn-small" onClick={() => dispatch({ type: "SELL_ITEM", itemId: item.id })}>
                    Sell {sellPrice(item)}g
                  </button>
                </div>
              </div>
            ))}
        </div>
      </div>
    </div>
  );
}
