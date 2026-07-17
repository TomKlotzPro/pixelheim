import { useState } from "react";
import { FAMILY_NAMES, FAMILY_OF, killsOf, MASTERY_TIERS, masteryTier, type Family } from "../../game/hero/mastery";
import { MONSTERS } from "../../game/combat/monsters";

const BESTIARY = Object.values(MONSTERS);
import { useHero } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { useEscapeClose } from "../useEscapeClose";

const FAMILIES = Object.keys(FAMILY_NAMES) as Family[];

/** The trophy case: what you have slain, and what the slaying taught you. */
export function Codex({ onClose }: { onClose: () => void }) {
  useEscapeClose(onClose);
  const hero = useHero();
  const [tab, setTab] = useState<"masteries" | "bestiary">("masteries");

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel codex-panel" onClick={(e) => e.stopPropagation()} data-testid="codex">
        <div className="inventory-header">
          <h2>Codex</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <div className="tabs">
          <button className={`tab ${tab === "masteries" ? "active" : ""}`} onClick={() => setTab("masteries")}>
            Masteries
          </button>
          <button className={`tab ${tab === "bestiary" ? "active" : ""}`} onClick={() => setTab("bestiary")}>
            Bestiary
          </button>
        </div>
        <div className="panel-body">
          {tab === "masteries" &&
            FAMILIES.map((family) => {
              const kills = killsOf(hero, family);
              const tier = masteryTier(hero, family);
              const next = MASTERY_TIERS[tier];
              return (
                <div key={family} className="mastery-row" data-testid={`mastery-${family}`}>
                  <div className="options-row">
                    <span>
                      {FAMILY_NAMES[family]}
                      {tier > 0 && <em className="doll-granted"> Slayer {["I", "II", "III"][tier - 1]}</em>}
                    </span>
                    <span className="options-note">{kills} slain</span>
                  </div>
                  <div className="mastery-track">
                    <div
                      className="mastery-fill"
                      style={{ width: next ? `${Math.min(100, (kills / next.kills) * 100)}%` : "100%" }}
                    />
                  </div>
                  <p className="stat-blurb">
                    {tier > 0 && `+${Math.round(MASTERY_TIERS[tier - 1].bonus * 100)}% damage against them. `}
                    {next
                      ? `${next.kills - kills} more for +${Math.round(next.bonus * 100)}%.`
                      : "Nothing left to teach you."}
                  </p>
                </div>
              );
            })}
          {tab === "bestiary" &&
            BESTIARY.map((monster) => {
              const family = FAMILY_OF[monster.id];
              const met = family && killsOf(hero, family) > 0;
              return (
                <div key={monster.id} className="item-row">
                  <Sprite name={monster.sprite} size={32} alt={met ? monster.name : "Unknown"} />
                  <div className="item-info">
                    {met ? (
                      <>
                        <span className="item-name">{monster.name}</span>
                        <span className="item-stats">
                          HP {monster.maxHp} ATK {monster.attack} DEF {monster.defense} {monster.xp} xp
                        </span>
                        <span className="item-desc">{FAMILY_NAMES[family]}</span>
                      </>
                    ) : (
                      <span className="options-note">Unmet. The wilds keep their secrets.</span>
                    )}
                  </div>
                </div>
              );
            })}
        </div>
        <p className="options-footer">Every kill teaches. Families over faces.</p>
      </div>
    </div>
  );
}
