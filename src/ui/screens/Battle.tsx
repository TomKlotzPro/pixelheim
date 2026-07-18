import { lazy, Suspense, useEffect, useRef } from "react";
import { getItem } from "../../game/economy/items";
import { heroSprite as heroSpriteOf, resourceLabel } from "../../game/hero/character";
import { outfitFor } from "../../game/economy/wearables";
import { DressedSprite } from "../widgets/DressedSprite";
import { getLevel } from "../../game/hero/levels";
import { getHeroSkills } from "../../game/hero/skillTree";
import type { StatusEffect } from "../../game/types";
import { USE_PIXI } from "../../render/flag";
import { dispatch, useBattle, useGameState, useHero } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
import { StatBar } from "../widgets/StatBar";

// Lazy so pixi.js stays out of the main bundle until the flag asks for it.
const BattleSceneView = lazy(() =>
  import("../../render/BattleSceneView").then((m) => ({ default: m.BattleSceneView })),
);

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

export function Battle() {
  const state = useGameState();
  const hero = useHero();
  const battle = useBattle();
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
    <div className={`screen battle-screen ${battle.wild ? "battle-wild" : ""}`}>
      <div className="battle-header">
        {battle.wild ? (
          <>
            <span>The Wilds: {battle.wildRegion}</span>
            <span>Wild battle</span>
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

      {USE_PIXI && (
        <div className="battle-stage">
          <Suspense fallback={null}>
            <BattleSceneView />
          </Suspense>
        </div>
      )}
      <div className={`battle-arena ${USE_PIXI ? "battle-arena-bars" : ""}`}>
        <div className="combatant">
          {battle.wild && !USE_PIXI && (
            <span className="ambush-mark" aria-hidden="true">
              !
            </span>
          )}
          {!USE_PIXI && (
            <DressedSprite
              name={heroSpriteOf(hero)}
              outfit={outfitFor(state.gear, state.equipped)}
              size={96}
              alt={hero.name}
              className={battle.phase === "lost" ? "fallen" : ""}
            />
          )}
          <div className="combatant-name">{hero.name}</div>
          <StatBar label="HP" value={hero.hp} max={hero.stats.maxHp} color="var(--hp)" />
          <StatBar
            label={resourceLabel(hero.roleId)}
            value={hero.mp}
            max={hero.stats.maxMp}
            color={resourceLabel(hero.roleId) === "EN" ? "var(--en)" : "var(--mp)"}
          />
          <EffectBadges effects={battle.heroEffects} />
        </div>
        <div className="vs">VS</div>
        <div className={`combatant ${battle.wild && !USE_PIXI ? "combatant-lunge" : ""}`}>
          {!USE_PIXI && (
            <Sprite
              name={battle.monster.def.sprite}
              size={96}
              alt={battle.monster.name}
              className={battle.monster.hp <= 0 ? "fallen" : ""}
            />
          )}
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
              {skill.name} ({skill.mpCost} {resourceLabel(hero.roleId)}
              {skill.hpCost ? ` + ${skill.hpCost} HP` : ""})
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
