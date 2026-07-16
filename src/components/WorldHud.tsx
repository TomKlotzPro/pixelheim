import { useState } from "react";
import { totalDefense } from "../game/character";
import { ROLES } from "../game/roles";
import type { GameState, SpendableStat } from "../game/types";
import type { Action } from "../state/gameReducer";
import { SkillTree } from "./SkillTree";
import { Sprite } from "./Sprite";
import { StatBar } from "./StatBar";

const SPENDABLE: { stat: SpendableStat; label: string }[] = [
  { stat: "strength", label: "STR" },
  { stat: "intelligence", label: "INT" },
  { stat: "dexterity", label: "DEX" },
  { stat: "defense", label: "DEF" },
];

function StatSheet({ state, dispatch, onClose }: WorldHudProps & { onClose: () => void }) {
  const hero = state.hero!;
  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel stat-sheet" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <h2>{hero.name}</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <p className={hero.statPoints > 0 ? "stat-points" : "empty-note"}>
          {hero.statPoints > 0
            ? `${hero.statPoints} stat point${hero.statPoints > 1 ? "s" : ""} to spend`
            : "No points to spend. Go level up."}
        </p>
        {SPENDABLE.map(({ stat, label }) => (
          <div key={stat} className="options-row">
            <span>
              {label} {hero.stats[stat]}
            </span>
            <button
              className="btn btn-small"
              disabled={hero.statPoints <= 0}
              aria-label={`Increase ${label}`}
              onClick={() => dispatch({ type: "SPEND_STAT_POINT", stat })}
            >
              +
            </button>
          </div>
        ))}
        <p className="options-footer">Spent points are permanent. Choose like it matters.</p>
      </div>
    </div>
  );
}

type WorldHudProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

/** Compact hero panel floating over the world viewport. */
export function WorldHud({ state, dispatch }: WorldHudProps) {
  const hero = state.hero!;
  const role = ROLES[hero.roleId];
  const [sheetOpen, setSheetOpen] = useState(false);
  const [treeOpen, setTreeOpen] = useState(false);
  return (
    <div className="world-hud panel">
      <div className="hud-top">
        <Sprite name={role.sprite} size={32} alt={role.name} />
        <div className="hud-id">
          <span className="hero-name">{hero.name}</span>
          <span className="hero-role">
            Lv {hero.level} {role.name} · DEF {totalDefense(hero, state.gear, state.equipped)}
          </span>
        </div>
        <span className="gold-line">
          <Sprite name="gold" size={16} /> {state.gold}
        </span>
      </div>
      <StatBar label="HP" value={hero.hp} max={hero.stats.maxHp} color="var(--hp)" />
      <StatBar label="MP" value={hero.mp} max={hero.stats.maxMp} color="var(--mp)" />
      <StatBar label="XP" value={hero.xp} max={hero.xpToNext} color="var(--xp)" />
      <div className="hud-actions">
        <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_INVENTORY" })}>
          Inventory (I)
        </button>
        <button className="btn btn-small" onClick={() => setSheetOpen(true)}>
          Stats{hero.statPoints > 0 && <span className="new-badge"> +{hero.statPoints}</span>}
        </button>
        <button className="btn btn-small" onClick={() => setTreeOpen(true)}>
          Skills{hero.skillPoints > 0 && <span className="new-badge"> +{hero.skillPoints}</span>}
        </button>
      </div>
      {sheetOpen && <StatSheet state={state} dispatch={dispatch} onClose={() => setSheetOpen(false)} />}
      {treeOpen && <SkillTree state={state} dispatch={dispatch} onClose={() => setTreeOpen(false)} />}
    </div>
  );
}
