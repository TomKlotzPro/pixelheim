import { useState } from "react";
import { getItem } from "../game/items";
import { itemStatLine } from "../game/itemStats";
import { gearItem, gearName, gearValue } from "../game/rarity";
import { forgeCapFor, forgeCostFor } from "../game/jobs";
import { buyPrice, sellPriceAt, SHOPS, shopStock } from "../game/shop";
import { activeShopId } from "../state/gameReducer";
import { dispatch, useGameState, useHero } from "../state/store";
import { Sprite } from "./Sprite";

export function Shop() {
  const state = useGameState();
  const hero = useHero();
  const shopId = activeShopId(state);
  const [tab, setTab] = useState<"buy" | "sell" | "forge">("buy");
  // No shop on this map: render nothing rather than crash (PIX-58).
  if (!shopId) return null;
  const def = SHOPS[shopId];
  const stock = shopStock(shopId, state.unlockedLevel);
  const owned = Object.entries(state.inventory).map(([id, count]) => ({ item: getItem(id), count }));
  const equippedUids = new Set(Object.values(state.equipped));
  const sellableGear = def.buyRates.weapons ? state.gear.filter((g) => !equippedUids.has(g.uid)) : [];

  return (
    <div className="overlay" onClick={() => dispatch({ type: "TOGGLE_SHOP" })}>
      <div className="panel inventory-panel" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <Sprite name={def.sprite} size={40} alt={def.keeper} />
          <h2>{def.keeper}</h2>
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_SHOP" })}>
            Close
          </button>
        </div>
        <p className="merchant-line">{def.greeting}</p>

        <div className="tabs">
          <button className={`tab ${tab === "buy" ? "active" : ""}`} onClick={() => setTab("buy")}>
            Buy
          </button>
          <button className={`tab ${tab === "sell" ? "active" : ""}`} onClick={() => setTab("sell")}>
            Sell
          </button>
          {def.forge && (
            <button className={`tab ${tab === "forge" ? "active" : ""}`} onClick={() => setTab("forge")}>
              Forge
            </button>
          )}
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
          {tab === "sell" && owned.length === 0 && sellableGear.length === 0 && (
            <p className="empty-note">Nothing to sell. Go loot something.</p>
          )}
          {tab === "sell" &&
            sellableGear.map((instance) => (
              <div key={instance.uid} className="item-row">
                <Sprite name={gearItem(instance).sprite} size={32} alt={gearName(instance)} />
                <div className="item-info">
                  <span className={`item-name rarity-${instance.rarity}`}>{gearName(instance)}</span>
                  <span className="item-stats">{itemStatLine(gearItem(instance), { bonus: instance.bonus })}</span>
                </div>
                <div className="item-actions">
                  <button className="btn btn-small" onClick={() => dispatch({ type: "SELL_GEAR", uid: instance.uid })}>
                    Sell{" "}
                    {Math.max(
                      1,
                      Math.floor(gearValue(instance) * (SHOPS[shopId].buyRates[gearItem(instance).category] ?? 0.5)),
                    )}
                    g
                  </button>
                </div>
              </div>
            ))}
          {tab === "sell" &&
            owned.map(({ item, count }) => (
              <div key={item.id} className="item-row">
                <Sprite name={item.sprite} size={32} alt={item.name} />
                <div className="item-info">
                  <span className="item-name">
                    {item.name}
                    {count > 1 && <span className="item-count"> x{count}</span>}
                  </span>
                  <span className="item-stats">{itemStatLine(item, { value: item.value })}</span>
                </div>
                <div className="item-actions">
                  <button className="btn btn-small" onClick={() => dispatch({ type: "SELL_ITEM", itemId: item.id })}>
                    Sell {sellPriceAt(shopId, item)}g
                  </button>
                </div>
              </div>
            ))}
          {tab === "forge" && state.gear.length === 0 && <p className="empty-note">Bring me steel to work with.</p>}
          {tab === "forge" &&
            state.gear.map((instance) => {
              const item = gearItem(instance);
              const capped = instance.bonus >= forgeCapFor(hero.jobs.smithing.level);
              const cost = forgeCostFor(item, instance.bonus, hero.jobs.smithing.level);
              return (
                <div key={instance.uid} className="item-row">
                  <Sprite name={item.sprite} size={32} alt={gearName(instance)} />
                  <div className="item-info">
                    <span className={`item-name rarity-${instance.rarity}`}>
                      {gearName(instance)}
                      {equippedUids.has(instance.uid) && <span className="equipped-tag"> EQUIPPED</span>}
                    </span>
                    <span className="item-stats">{itemStatLine(item, { bonus: instance.bonus })}</span>
                  </div>
                  <div className="item-actions">
                    <button
                      className="btn btn-small"
                      disabled={capped || state.gold < cost}
                      onClick={() => dispatch({ type: "UPGRADE_GEAR", uid: instance.uid })}
                    >
                      {capped ? "Perfected" : `+1 for ${cost}g`}
                    </button>
                  </div>
                </div>
              );
            })}
        </div>
      </div>
    </div>
  );
}
