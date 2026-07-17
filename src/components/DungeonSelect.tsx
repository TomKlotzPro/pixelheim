import { carriedWeight, carryCapacity } from "../game/character";
import { getLevel } from "../game/levels";
import { getMonster } from "../game/monsters";
import { dispatch, useGameState, useHero } from "../state/store";
import type { DungeonId } from "../world/types";
import { Sprite } from "./Sprite";

const DUNGEONS: Record<DungeonId, { name: string; floors: number[]; sealed?: string }> = {
  mountain: {
    name: "The Ashen Mountain",
    floors: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  },
  undermountain: {
    name: "The Undermountain",
    floors: [11, 12, 13, 14, 15],
    sealed: "The seal on the deep holds fast. The dragon above still reigns.",
  },
};

export function DungeonSelect() {
  const state = useGameState();
  const dungeon = DUNGEONS[state.dungeonSelect!];
  const hero = useHero();
  const overEncumbered = carriedWeight(state.inventory, state.gear, state.equipped) > carryCapacity(hero, state.gear, state.equipped);
  const anyUnlocked = dungeon.floors.some((floor) => floor <= state.unlockedLevel);

  return (
    <div className="screen dungeon-select">
      <h2 className="screen-title">{dungeon.name}</h2>
      {overEncumbered && <p className="warning">Over-encumbered! Drop something before venturing in.</p>}
      {!anyUnlocked && dungeon.sealed && <p className="tagline">{dungeon.sealed}</p>}
      <div className="level-list">
        {dungeon.floors.map((floorNumber) => {
          const floor = getLevel(floorNumber);
          const cleared = state.clearedLevels.includes(floorNumber);
          const locked = floorNumber > state.unlockedLevel;
          const boss = getMonster(floor.encounters[floor.encounters.length - 1].monsterId);
          return (
            <button
              key={floorNumber}
              className={`level-card ${cleared ? "cleared" : ""} ${locked ? "locked" : ""}`}
              disabled={locked || overEncumbered}
              onClick={() => dispatch({ type: "ENTER_LEVEL", level: floorNumber })}
            >
              <span className="level-num">{floorNumber}</span>
              <span className="level-info">
                <span className="level-name">
                  {locked ? "???" : floor.name}
                  {cleared && <span className="cleared-tag"> CLEARED</span>}
                </span>
                <span className="level-desc">{locked ? "Clear the previous floor to unlock." : floor.description}</span>
              </span>
              {!locked && <Sprite name={boss.sprite} size={40} alt={boss.name} />}
            </button>
          );
        })}
      </div>
      <div className="battle-actions">
        <button className="btn" onClick={() => dispatch({ type: "CLOSE_DUNGEON_SELECT" })}>
          Step away
        </button>
      </div>
    </div>
  );
}
