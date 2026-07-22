import { useEffect, useRef, useState } from "react";
import { rankIndex, rankTitle } from "../game/hero/ranks";
import { SFX } from "../audio/sfx";
import type { GameState } from "../game/types";
import { gameStore } from "../state/store";

/**
 * The ascension scene: shows when the hero crosses a rank. While a path
 * choice is pending (PIX-105) the scene HOLDS - the cards are the moment -
 * and the timer only starts once the walk is chosen (or the scene dismissed).
 */
export function useRankUp(state: GameState, hold: boolean): { title: string | null; dismiss: () => void } {
  const [title, setTitle] = useState<string | null>(null);
  const pending = useRef<string | null>(null);
  const prevLevel = useRef(state.hero?.level ?? 0);
  const level = state.hero?.level ?? 0;
  useEffect(() => {
    const before = prevLevel.current;
    prevLevel.current = level;
    const hero = gameStore.getState().hero;
    if (level > before && before > 0 && rankIndex(level) > rankIndex(before) && hero) {
      // Ascension waits for daylight: the scene plays on the map, never over
      // the battle where the level actually landed (PIX-101).
      pending.current = rankTitle(hero);
    }
  }, [level]);
  useEffect(() => {
    if (state.screen === "world" && pending.current) {
      setTitle(pending.current);
      pending.current = null;
      SFX.evolve();
    }
  }, [state.screen, level]);
  // The dismiss timer lives on the title alone: an hp tick or xp gain used
  // to clean it up and strand the card on screen forever (PIX-100).
  useEffect(() => {
    if (!title || hold) return;
    const timer = setTimeout(() => setTitle(null), 4200);
    return () => clearTimeout(timer);
  }, [title, hold]);
  return { title, dismiss: () => setTitle(null) };
}
