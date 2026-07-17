import { useState } from "react";
import { carriedWeight, carryCapacity, gearByUid } from "../game/character";
import { getItem } from "../game/items";
import { itemStatLine } from "../game/itemStats";
import { gearItem, gearName, gearValue } from "../game/rarity";
import { JOB_NAMES, JOB_STATIONS } from "../game/jobs";
import { canCraft, RECIPES } from "../game/recipes";
import type { EquipSlot, ItemCategory } from "../game/types";
import { dispatch, useGameState, useHero } from "../state/store";
import { Sprite } from "./Sprite";

const TABS: { id: ItemCategory | "all" | "craft"; label: string }[] = [
  { id: "all", label: "All" },
  { id: "weapons", label: "Weapons" },
  { id: "apparel", label: "Apparel" },
  { id: "potions", label: "Potions" },
  { id: "food", label: "Food" },
  { id: "misc", label: "Misc" },
  { id: "craft", label: "Craft" },
];

const SLOT_LABELS: Record<EquipSlot, string> = {
  weapon: "Weapon",
  body: "Body",
  offhand: "Off-hand",
};

export function Inventory() {
  const state = useGameState();
  const [tab, setTab] = useState<ItemCategory | "all" | "craft">("all");
  const hero = useHero();
  const inBattle = state.screen === "battle";
  const equippedUids = new Set(Object.values(state.equipped));

  const stacks = Object.entries(state.inventory)
    .map(([id, count]) => ({ item: getItem(id), count }))
    .filter(({ item }) => tab === "all" || item.category === tab)
    // mid-fight you can only rummage for something drinkable or edible
    .filter(({ item }) => !inBattle || item.restoreHp || item.restoreMp || item.cures)
    .toSorted((a, b) => a.item.category.localeCompare(b.item.category) || a.item.name.localeCompare(b.item.name));

  const gearRows = inBattle
    ? []
    : state.gear
        .filter((g) => tab === "all" || gearItem(g).category === tab)
        .toSorted(
          (a, b) => gearItem(a).category.localeCompare(gearItem(b).category) || gearName(a).localeCompare(gearName(b)),
        );

  const weight = carriedWeight(state.inventory, state.gear, state.equipped);
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
              const instance = gearByUid(state.gear, state.equipped[slot]);
              return (
                <div key={slot} className="equipped-slot">
                  <span className="slot-label">{SLOT_LABELS[slot]}</span>
                  {instance ? (
                    <button
                      className="btn btn-small"
                      title="Unequip"
                      onClick={() => dispatch({ type: "UNEQUIP", slot })}
                    >
                      <Sprite name={gearItem(instance).sprite} size={16} />{" "}
                      <span className={`rarity-${instance.rarity}`}>{gearName(instance)}</span>
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
          {tab === "craft" &&
            RECIPES.map((recipe) => {
              const result = getItem(recipe.itemId);
              const jobOk = hero.jobs[recipe.job.id].level >= recipe.job.level;
              const atStation = state.world?.position.mapId === JOB_STATIONS[recipe.job.id].mapId;
              const craftable = canCraft(recipe, state.inventory, hero.jobs) && atStation && !inBattle;
              return (
                <div key={recipe.id} className="item-row">
                  <Sprite name={result.sprite} size={32} alt={result.name} />
                  <div className="item-info">
                    <span className="item-name">{result.name}</span>
                    <span className="item-stats">
                      {Object.entries(recipe.needs)
                        .map(([id, count]) => `${count}x ${getItem(id).name} (${state.inventory[id] ?? 0})`)
                        .join("  +  ")}
                    </span>
                    <span className="item-desc">{result.description}</span>
                    {!jobOk && (
                      <span className="item-locked">
                        Requires {JOB_NAMES[recipe.job.id]} {recipe.job.level}
                      </span>
                    )}
                    {jobOk && !atStation && !inBattle && (
                      <span className="item-locked">{JOB_STATIONS[recipe.job.id].hint}</span>
                    )}
                  </div>
                  <div className="item-actions">
                    <button
                      className="btn btn-small"
                      disabled={!craftable}
                      onClick={() => dispatch({ type: "CRAFT", recipeId: recipe.id })}
                    >
                      Craft
                    </button>
                  </div>
                </div>
              );
            })}
          {tab !== "craft" && stacks.length === 0 && gearRows.length === 0 && (
            <p className="empty-note">Nothing here. Go hit some monsters.</p>
          )}
          {gearRows.map((instance) => {
            const item = gearItem(instance);
            const isEquipped = equippedUids.has(instance.uid);
            return (
              <div key={instance.uid} className="item-row">
                <Sprite name={item.sprite} size={32} alt={gearName(instance)} />
                <div className="item-info">
                  <span className={`item-name rarity-${instance.rarity}`}>
                    {gearName(instance)}
                    {isEquipped && <span className="equipped-tag"> EQUIPPED</span>}
                  </span>
                  <span className="item-stats">{itemStatLine(item, { bonus: instance.bonus, value: gearValue(instance) })}</span>
                  <span className="item-desc">{item.description}</span>
                </div>
                <div className="item-actions">
                  {!isEquipped && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "EQUIP", uid: instance.uid })}>
                      Equip
                    </button>
                  )}
                  {!isEquipped && (
                    <button
                      className="btn btn-small btn-danger"
                      onClick={() => dispatch({ type: "DROP_GEAR", uid: instance.uid })}
                    >
                      Drop
                    </button>
                  )}
                </div>
              </div>
            );
          })}
          {stacks.map(({ item, count }) => {
            const usable = Boolean(item.restoreHp || item.restoreMp || item.cures);
            return (
              <div key={item.id} className="item-row">
                <Sprite name={item.sprite} size={32} alt={item.name} />
                <div className="item-info">
                  <span className="item-name">
                    {item.name}
                    {count > 1 && <span className="item-count"> x{count}</span>}
                  </span>
                  <span className="item-stats">{itemStatLine(item, { value: item.value })}</span>
                  <span className="item-desc">{item.description}</span>
                </div>
                <div className="item-actions">
                  {usable && (
                    <button className="btn btn-small" onClick={() => dispatch({ type: "USE_ITEM", itemId: item.id })}>
                      Use
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
