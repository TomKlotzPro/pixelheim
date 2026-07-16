import { carriedWeight, carryCapacity, totalArmor, weaponOf } from "../game/character";
import { LEVELS } from "../game/levels";
import { getMonster } from "../game/monsters";
import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import { REST_COST } from "../state/gameReducer";
import { Sprite } from "./Sprite";
import { StatBar } from "./StatBar";

type HubProps = {
  state: GameState;
  onEnterLevel: (level: number) => void;
  onRest: () => void;
  onOpenInventory: () => void;
  onOpenShop: () => void;
};

export function Hub({ state, onEnterLevel, onRest, onOpenInventory, onOpenShop }: HubProps) {
  const hero = state.hero!;
  const role = ROLES[hero.roleId];
  const weight = carriedWeight(state.inventory);
  const capacity = carryCapacity(hero);
  const overEncumbered = weight > capacity;
  const weapon = weaponOf(state.equipped);

  return (
    <div className="screen hub-screen">
      <aside className="panel hero-panel">
        <div className="hero-head">
          <Sprite name={role.sprite} size={72} alt={role.name} />
          <div>
            <div className="hero-name">{hero.name}</div>
            <div className="hero-role">
              Lv {hero.level} {role.name}
            </div>
          </div>
        </div>
        <StatBar label="HP" value={hero.hp} max={hero.stats.maxHp} color="var(--hp)" />
        <StatBar label="MP" value={hero.mp} max={hero.stats.maxMp} color="var(--mp)" />
        <StatBar label="XP" value={hero.xp} max={hero.xpToNext} color="var(--xp)" />
        <div className="hero-stats">
          <span>STR {hero.stats.strength}</span>
          <span>INT {hero.stats.intelligence}</span>
          <span>DEX {hero.stats.dexterity}</span>
          <span>DEF {hero.stats.defense + totalArmor(state.equipped)}</span>
        </div>
        <div className="hero-meta">
          <span className="gold-line">
            <Sprite name="gold" size={16} /> {state.gold}
          </span>
          <span className={overEncumbered ? "weight-over" : ""}>
            Weight {weight}/{capacity}
          </span>
        </div>
        <div className="hero-meta">
          <span>Weapon: {weapon ? weapon.name : "Fists"}</span>
        </div>
        <div className="hub-actions">
          <button className="btn" onClick={onOpenInventory}>
            Inventory
          </button>
          <button className="btn" onClick={onOpenShop}>
            Merchant
          </button>
          <button
            className="btn"
            onClick={onRest}
            disabled={state.gold < REST_COST || (hero.hp === hero.stats.maxHp && hero.mp === hero.stats.maxMp)}
          >
            Rest ({REST_COST}g)
          </button>
        </div>
        {overEncumbered && <p className="warning">Over-encumbered! Drop something before venturing out.</p>}
      </aside>

      <main className="level-list">
        <h2 className="screen-title">The Ashen Mountain</h2>
        {LEVELS.map((lvl) => {
          const cleared = state.clearedLevels.includes(lvl.level);
          const locked = lvl.level > state.unlockedLevel;
          const boss = getMonster(lvl.encounters[lvl.encounters.length - 1].monsterId);
          return (
            <button
              key={lvl.level}
              className={`level-card ${cleared ? "cleared" : ""} ${locked ? "locked" : ""}`}
              disabled={locked || overEncumbered}
              onClick={() => onEnterLevel(lvl.level)}
            >
              <span className="level-num">{lvl.level}</span>
              <span className="level-info">
                <span className="level-name">
                  {locked ? "???" : lvl.name}
                  {cleared && <span className="cleared-tag"> CLEARED</span>}
                </span>
                <span className="level-desc">{locked ? "Clear the previous floor to unlock." : lvl.description}</span>
              </span>
              {!locked && <Sprite name={boss.sprite} size={40} alt={boss.name} />}
            </button>
          );
        })}
      </main>
    </div>
  );
}
