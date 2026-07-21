import { useEffect, useRef } from "react";
import { playTrack, trackForState } from "./music";
import { ambienceForState, setAmbience } from "./ambience";
import { SFX } from "./sfx";
import { audioReady, initAudio } from "./synth";
import type { GameState } from "../game/types";

/** Audio is a pure side effect: watch state transitions, never touch the reducer. */
export function useAudio(state: GameState) {
  const prev = useRef(state);
  const stateRef = useRef(state);
  stateRef.current = state;

  useEffect(() => {
    const unlock = () => {
      initAudio();
      playTrack(trackForState(stateRef.current));
      setAmbience(ambienceForState(stateRef.current));
    };
    window.addEventListener("pointerdown", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);

  const mapId = state.world?.position.mapId;
  const monsterId = state.battle?.monster.def.id;
  useEffect(() => {
    if (!audioReady()) return;
    playTrack(trackForState(stateRef.current));
    setAmbience(ambienceForState(stateRef.current));
  }, [state.screen, mapId, monsterId]);

  useEffect(() => {
    const p = prev.current;
    prev.current = state;
    if (!audioReady() || state === p) return;

    if (state.hero && p.hero) {
      const sameFight = state.battle && p.battle && state.battle.encounterIndex === p.battle.encounterIndex;
      if (state.hero.level > p.hero.level) {
        SFX.levelUp();
      } else if (sameFight) {
        if (state.battle!.monster.hp < p.battle!.monster.hp) SFX.hit();
        if (state.hero.hp < p.hero.hp) SFX.hurt();
        if (state.hero.hp > p.hero.hp) SFX.heal();
      }
      if (state.gold > p.gold) SFX.coin();
      if (state.battle && p.battle && state.gear.length > p.gear.length) SFX.drop();
      if (state.battle?.phase === "cleared" && p.battle?.phase !== "cleared") SFX.victory();
      if (state.battle?.phase === "lost" && p.battle?.phase !== "lost") SFX.defeat();
    }
    if (state.hero && p.hero) {
      // the wardrobe, the workshop, the mind: each has a voice now
      if (state.equipped !== p.equipped) SFX.equip();
      if (state.hero.skillNodes.length > p.hero.skillNodes.length) SFX.learn();
      const jobsGrew = (Object.keys(state.hero.jobs) as (keyof typeof state.hero.jobs)[]).some(
        (job) =>
          state.hero!.jobs[job].xp > p.hero!.jobs[job].xp || state.hero!.jobs[job].level > p.hero!.jobs[job].level,
      );
      if (jobsGrew && !state.battle) SFX.craft();
    }
    if (state.world && p.world && state.world.openedChests.length > p.world.openedChests.length) SFX.chest();
    if (state.screen === "battle" && p.screen === "world") SFX.bump();
    if (state.screen === "world" && state.world && p.world) {
      const moved =
        Math.abs(state.world.position.x - p.world.position.x) + Math.abs(state.world.position.y - p.world.position.y);
      if (state.world.position.mapId !== p.world.position.mapId) SFX.door();
      else if (moved > 2) SFX.travel();
      else if (moved > 0) SFX.step();
    }
  }, [state]);
}
