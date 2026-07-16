import { totalArmor } from "../game/character";
import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import type { Action } from "../state/gameReducer";
import { Sprite } from "./Sprite";
import { StatBar } from "./StatBar";

type WorldHudProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

/** Compact hero panel floating over the world viewport. */
export function WorldHud({ state, dispatch }: WorldHudProps) {
  const hero = state.hero!;
  const role = ROLES[hero.roleId];
  return (
    <div className="world-hud panel">
      <div className="hud-top">
        <Sprite name={role.sprite} size={32} alt={role.name} />
        <div className="hud-id">
          <span className="hero-name">{hero.name}</span>
          <span className="hero-role">
            Lv {hero.level} {role.name} · DEF {hero.stats.defense + totalArmor(state.gear, state.equipped)}
          </span>
        </div>
        <span className="gold-line">
          <Sprite name="gold" size={16} /> {state.gold}
        </span>
      </div>
      <StatBar label="HP" value={hero.hp} max={hero.stats.maxHp} color="var(--hp)" />
      <StatBar label="MP" value={hero.mp} max={hero.stats.maxMp} color="var(--mp)" />
      <StatBar label="XP" value={hero.xp} max={hero.xpToNext} color="var(--xp)" />
      <button className="btn btn-small" onClick={() => dispatch({ type: "TOGGLE_INVENTORY" })}>
        Inventory (I)
      </button>
    </div>
  );
}
