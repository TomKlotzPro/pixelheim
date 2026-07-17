import { useState } from "react";
import { carriedWeight, carryCapacity, gearByUid, grantedStat, totalDefense, weaponOf } from "../../game/hero/character";
import { getItem } from "../../game/economy/items";
import { itemStatLine } from "../../game/economy/itemStats";
import { gearDamage, gearItem, gearName, gearValue } from "../../game/economy/rarity";
import { JOB_NAMES, JOB_STATIONS } from "../../game/economy/jobs";
import { canCraft, RECIPES } from "../../game/economy/recipes";
import { ROLES } from "../../game/hero/roles";
import type { EquippedSlot, GrantStat, ItemCategory } from "../../game/types";
import { dispatch, useGameState, useHero } from "../../state/store";
import { Sprite } from "../widgets/Sprite";

const TABS: { id: ItemCategory | "all" | "craft"; label: string }[] = [
  { id: "all", label: "All" },
  { id: "weapons", label: "Weapons" },
  { id: "apparel", label: "Apparel" },
  { id: "potions", label: "Potions" },
  { id: "food", label: "Food" },
  { id: "misc", label: "Misc" },
  { id: "craft", label: "Craft" },
];

/** The doll's positions, laid out around the hero: left column, then right. */
const DOLL_SLOTS: { slot: EquippedSlot; label: string }[] = [
  { slot: "head", label: "Head" },
  { slot: "neck", label: "Neck" },
  { slot: "body", label: "Body" },
  { slot: "hands", label: "Hands" },
  { slot: "weapon", label: "Weapon" },
  { slot: "offhand", label: "Off-hand" },
  { slot: "ring1", label: "Ring" },
  { slot: "ring2", label: "Ring" },
  { slot: "feet", label: "Feet" },
];

const GRANT_STATS: { stat: GrantStat; label: string }[] = [
  { stat: "strength", label: "STR" },
  { stat: "intelligence", label: "INT" },
  { stat: "dexterity", label: "DEX" },
];

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
  const capacity = carryCapacity(hero, state.gear, state.equipped);

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

        <div className="inventory-body">
        {!inBattle && (
          <div className="doll-column">
            <div className="doll">
              <div className="doll-portrait" aria-hidden="true">
                <Sprite name={ROLES[hero.roleId].sprite} size={80} />
              </div>
              {DOLL_SLOTS.map(({ slot, label }, i) => {
                const instance = gearByUid(state.gear, state.equipped[slot]);
                return (
                  <button
                    key={`${slot}${i}`}
                    className={`doll-slot doll-${slot} ${instance ? "doll-filled" : ""}`}
                    data-testid={`doll-${slot}`}
                    title={instance ? `${gearName(instance)} - click to unequip` : `${label}: empty`}
                    disabled={!instance}
                    onClick={() => dispatch({ type: "UNEQUIP", slot })}
                  >
                    {instance ? (
                      <Sprite name={gearItem(instance).sprite} size={28} alt={gearName(instance)} />
                    ) : (
                      <span className="doll-slot-label">{label}</span>
                    )}
                  </button>
                );
              })}
            </div>
            <div className="doll-stats" data-testid="doll-stats">
              <div className="doll-stat-row">
                <span>ATK</span>
                <strong>
                  {(() => {
                    const weapon = weaponOf(state.gear, state.equipped);
                    const scaling = weapon ? (gearItem(weapon).scaling ?? "strength") : "strength";
                    return (
                      hero.stats[scaling] +
                      grantedStat(state.gear, state.equipped, scaling) +
                      (weapon ? gearDamage(weapon) : 2)
                    );
                  })()}
                </strong>
              </div>
              <div className="doll-stat-row">
                <span>DEF</span>
                <strong>{totalDefense(hero, state.gear, state.equipped)}</strong>
              </div>
              {GRANT_STATS.map(({ stat, label }) => {
                const granted = grantedStat(state.gear, state.equipped, stat);
                return (
                  <div key={stat} className="doll-stat-row">
                    <span>{label}</span>
                    <strong>
                      {hero.stats[stat]}
                      {granted > 0 && <em className="doll-granted"> +{granted}</em>}
                    </strong>
                  </div>
                );
              })}
              <div className="doll-stat-row">
                <span>Carry</span>
                <strong>
                  {weight}/{capacity}
                </strong>
              </div>
            </div>
          </div>
        )}

        <div className="inventory-main">
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
      </div>
    </div>
  );
}
