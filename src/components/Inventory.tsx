import { useState } from "react";
import { carriedWeight, carryCapacity } from "../game/character";
import { getItem } from "../game/items";
import { itemStatLine } from "../game/itemStats";
import type { EquipSlot, GameState, ItemCategory } from "../game/types";
import type { Action } from "../state/gameReducer";
import { Sprite } from "./Sprite";

const TABS: { id: ItemCategory | "all"; label: string }[] = [
  { id: "all", label: "All" },
  { id: "weapons", label: "Weapons" },
  { id: "apparel", label: "Apparel" },
  { id: "potions", label: "Potions" },
  { id: "food", label: "Food" },
  { id: "misc", label: "Misc" },
];

const SLOT_LABELS: Record<EquipSlot, string> = {
  weapon: "Weapon",
  body: "Body",
  offhand: "Off-hand",
};

type InventoryProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

export function Inventory({ state, dispatch }: InventoryProps) {
  const [tab, setTab] = useState<ItemCategory | "all">("all");
  const hero = state.hero!;
  const inBattle = state.screen === "battle";

  const entries = Object.entries(state.inventory)
    .map(([id, count]) => ({ item: getItem(id), count }))
    .filter(({ item }) => tab === "all" || item.category === tab)
    // mid-fight you can only rummage for something drinkable or edible
    .filter(({ item }) => !inBattle || item.restoreHp || item.restoreMp)
    .sort((a, b) => a.item.category.localeCompare(b.item.category) || a.item.name.localeCompare(b.item.name));

  const weight = carriedWeight(state.inventory);
  const capacity = carryCapacity(hero);

  return (
    <div className="overlay" onClick={() => dispatch({ type: "TOGGLE_INVENTORY" })}>
      <div className="panel inventory-panel" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <h2>Inventory</h2>
          <span className={weight > capacity ? "weight-over" : ""}>
            Weight {weight}/{capacity}
          </span>
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_INVENTORY" })}>
            Close
          </button>
        </div>

        {!inBattle && (
          <div className="equipped-row">
            {(Object.keys(SLOT_LABELS) as EquipSlot[]).map((slot) => {
              const id = state.equipped[slot];
              const item = id ? getItem(id) : null;
              return (
                <div key={slot} className="equipped-slot">
                  <span className="slot-label">{SLOT_LABELS[slot]}</span>
                  {item ? (
                    <button
                      className="btn btn-small"
                      title="Unequip"
                      onClick={() => dispatch({ type: "UNEQUIP", slot })}
                    >
                      <Sprite name={item.sprite} size={16} /> {item.name}
                    </button>
                  ) : (
                    <span className="slot-empty">empty</span>
                  )}
                </div>
              );
            })}
          </div>
        )}

        <div className="tabs">
          {TABS.map((t) => (
            <button key={t.id} className={`tab ${tab === t.id ? "active" : ""}`} onClick={() => setTab(t.id)}>
              {t.label}
            </button>
          ))}
        </div>

        <div className="item-list">
          {entries.length === 0 && <p className="empty-note">Nothing here. Go hit some monsters.</p>}
          {entries.map(({ item, count }) => {
            const usable = Boolean(item.restoreHp || item.restoreMp);
            const equippable = Boolean(item.slot) && !inBattle;
            return (
              <div key={item.id} className="item-row">
                <Sprite name={item.sprite} size={32} alt={item.name} />
                <div className="item-info">
                  <span className="item-name">
                    {item.name}
                    {count > 1 && <span className="item-count"> x{count}</span>}
                  </span>
                  <span className="item-stats">{itemStatLine(item, { withValue: true })}</span>
                  <span className="item-desc">{item.description}</span>
                </div>
                <div className="item-actions">
                  {usable && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "USE_ITEM", itemId: item.id })}>
                      Use
                    </button>
                  )}
                  {equippable && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "EQUIP", itemId: item.id })}>
                      Equip
                    </button>
                  )}
                  {!inBattle && (
                    <button className="btn btn-small btn-danger" onClick={() => dispatch({ type: "DROP", itemId: item.id })}>
                      Drop
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
