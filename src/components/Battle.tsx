import { useEffect, useRef } from "react";
import { getItem } from "../game/items";
import { getLevel } from "../game/levels";
import { ROLES } from "../game/roles";
import { getHeroSkills } from "../game/skillTree";
import type { GameState, StatusEffect } from "../game/types";
import type { Action } from "../state/gameReducer";
import { Sprite } from "./Sprite";
import { StatBar } from "./StatBar";

function EffectBadges({ effects }: { effects: StatusEffect[] }) {
  return (
    <div className="effect-badges">
      {effects.map((effect) => (
        <span
          key={effect.kind}
          className="effect-badge"
          title={`${effect.kind}${effect.power ? `: ${effect.power} damage per turn` : ""}, ${effect.turnsLeft} turn(s) left`}
        >
          <Sprite name={`effect_${effect.kind}`} size={16} alt={effect.kind} /> {effect.turnsLeft}
        </span>
      ))}
    </div>
  );
}

type BattleProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

export function Battle({ state, dispatch }: BattleProps) {
  const hero = state.hero!;
  const battle = state.battle!;
  const role = ROLES[hero.roleId];
  const dungeon = getLevel(battle.dungeonLevel);
  const logRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight });
  }, [battle.log.length]);

  const acting = battle.phase === "player";
  const hasConsumables = Object.entries(state.inventory).some(([id, count]) => {
    const item = getItem(id);
    return count > 0 && (item.restoreHp || item.restoreMp);
  });

  return (
    <div className="screen battle-screen">
      <div className="battle-header">
        {battle.wild ? (
          <>
            <span>The Wilds: {battle.wildRegion}</span>
            <span>Ambush!</span>
          </>
        ) : (
          <>
            <span>
              Floor {battle.dungeonLevel}: {dungeon.name}
            </span>
            <span>
              Fight {battle.encounterIndex + 1}/{dungeon.encounters.length}
            </span>
          </>
        )}
      </div>

      <div className="battle-arena">
        <div className="combatant">
          <Sprite name={role.sprite} size={96} alt={hero.name} className={battle.phase === "lost" ? "fallen" : ""} />
          <div className="combatant-name">{hero.name}</div>
          <StatBar label="HP" value={hero.hp} max={hero.stats.maxHp} color="var(--hp)" />
          <StatBar label="MP" value={hero.mp} max={hero.stats.maxMp} color="var(--mp)" />
          <EffectBadges effects={battle.heroEffects} />
        </div>
        <div className="vs">VS</div>
        <div className="combatant">
          <Sprite
            name={battle.monster.def.sprite}
            size={96}
            alt={battle.monster.name}
            className={battle.monster.hp <= 0 ? "fallen" : ""}
          />
          <div className="combatant-name">{battle.monster.name}</div>
          <StatBar label="HP" value={battle.monster.hp} max={battle.monster.maxHp} color="var(--hp)" />
          <EffectBadges effects={battle.monsterEffects} />
        </div>
      </div>

      <div className="battle-log" ref={logRef}>
        {battle.log.map((line, i) => (
          <div key={i} className="log-line">
            {line}
          </div>
        ))}
      </div>

      {acting && (
        <div className="battle-actions">
          <button className="btn btn-primary" onClick={() => dispatch({ type: "ATTACK" })}>
            Attack
          </button>
          {getHeroSkills(hero).map((skill, index) => (
            <button
              key={skill.name}
              className="btn"
              disabled={hero.mp < skill.mpCost || (skill.hpCost ?? 0) >= hero.hp}
              onClick={() => dispatch({ type: "SKILL", skillIndex: index })}
              title={skill.description}
            >
              {skill.name} ({skill.mpCost} MP{skill.hpCost ? ` + ${skill.hpCost} HP` : ""})
            </button>
          ))}
          <button className="btn" onClick={() => dispatch({ type: "TOGGLE_INVENTORY" })} disabled={!hasConsumables}>
            Item
          </button>
          <button className="btn" onClick={() => dispatch({ type: "FLEE" })}>
            Flee
          </button>
        </div>
      )}

      {battle.phase === "won" && (
        <div className="battle-actions">
          <button className="btn btn-primary" onClick={() => dispatch({ type: "NEXT_ENCOUNTER" })}>
            Press on
          </button>
        </div>
      )}

      {battle.phase === "cleared" && battle.wild && (
        <div className="battle-actions">
          <button className="btn btn-primary" onClick={() => dispatch({ type: "COLLECT_AND_RETURN" })}>
            Walk on
          </button>
        </div>
      )}

      {battle.phase === "cleared" && !battle.wild && (
        <div className="battle-actions battle-cleared">
          <div className="panel reward-panel">
            <div className="reward-title">Floor cleared!</div>
            <div className="reward-list">
              <span className="gold-line">
                <Sprite name="gold" size={16} /> {dungeon.rewardGold}
              </span>
              {dungeon.rewardItemIds.map((id, i) => (
                <span key={`${id}-${i}`} className="reward-item">
                  <Sprite name={getItem(id).sprite} size={16} /> {getItem(id).name}
                </span>
              ))}
            </div>
          </div>
          <button className="btn btn-primary" onClick={() => dispatch({ type: "COLLECT_AND_RETURN" })}>
            Collect and return to town
          </button>
        </div>
      )}

      {battle.phase === "lost" && (
        <div className="battle-actions">
          <button className="btn btn-danger" onClick={() => dispatch({ type: "RETURN_TO_WORLD" })}>
            Wake up at the inn
          </button>
        </div>
      )}
    </div>
  );
}
