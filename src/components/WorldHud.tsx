import { useState } from "react";
import { resourceLabel, totalDefense } from "../game/character";
import { statInfo } from "../game/statInfo";
import { ROLES } from "../game/roles";
import type { SpendableStat } from "../game/types";
import { dispatch, useGameState, useHero } from "../state/store";
import { SkillTree } from "./SkillTree";
import { Sprite } from "./Sprite";
import { StatBar } from "./StatBar";

const SPENDABLE: { stat: SpendableStat; label: string }[] = [
  { stat: "strength", label: "STR" },
  { stat: "intelligence", label: "INT" },
  { stat: "dexterity", label: "DEX" },
  { stat: "defense", label: "DEF" },
  { stat: "endurance", label: "END" },
];

function StatSheet({ onClose }: { onClose: () => void }) {
  const state = useGameState();
  const hero = useHero();
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
        {SPENDABLE.map(({ stat, label }) => {
          const info = statInfo(stat, hero, state.gear, state.equipped);
          return (
            <div key={stat} className="stat-row">
              <div className="options-row">
                <span>
                  {label} {hero.stats[stat]}
                </span>
                <button
                  className="btn btn-small"
                  disabled={hero.statPoints <= 0}
                  aria-label={`Increase ${label}`}
                  title={info.blurb}
                  onClick={() => dispatch({ type: "SPEND_STAT_POINT", stat })}
                >
                  +
                </button>
              </div>
              <p className="stat-blurb">{info.blurb}</p>
              <p className="stat-derived">
                {info.now}
                {hero.statPoints > 0 && (
                  <>
                    {" "}
                    <span className="stat-arrow">{"\u2192"}</span> <span className="stat-next">{info.next}</span>
                  </>
                )}
              </p>
            </div>
          );
        })}
        <p className="options-footer">Spent points are permanent. Choose like it matters.</p>
      </div>
    </div>
  );
}

/** Compact hero panel floating over the world viewport. */
export function WorldHud() {
  const state = useGameState();
  const hero = useHero();
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
      <StatBar label={resourceLabel(hero.roleId)} value={hero.mp} max={hero.stats.maxMp} color={resourceLabel(hero.roleId) === "EN" ? "var(--en)" : "var(--mp)"} />
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
      {sheetOpen && <StatSheet onClose={() => setSheetOpen(false)} />}
      {treeOpen && <SkillTree onClose={() => setTreeOpen(false)} />}
    </div>
  );
}
