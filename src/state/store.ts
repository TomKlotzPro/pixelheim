import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";
import type { BattleState, GameState, Hero } from "../game/types";
import type { WorldState } from "../world/types";
import { type Action, gameReducer, initialState } from "./gameReducer";
import { persistSave } from "./save";
import { setSettlers, setTownTier } from "../world/maps/index";

/**
 * The game state lives in a vanilla store so anything without React (the
 * balance sim, tests) can drive the exact same game. React subscribes
 * through useGameState.
 */
export function createGameStore(state: GameState = initialState) {
  return createStore<GameState>(() => state);
}

export type GameStore = ReturnType<typeof createGameStore>;

/** The one store the app plays in. */
export const gameStore = createGameStore();

// Persistence is a store concern, not a render concern: every committed state
// is written straight through (persistSave itself skips heroless states).
gameStore.subscribe(persistSave);

// The town mirrors (PIX-91/92): getMap and npcsOn take only ids, so the maps
// module keeps the current tier and settlers as module variables, fed here.
gameStore.subscribe((state) => {
  setTownTier(state.townTier ?? 1);
  setSettlers(state.settlers ?? []);
});

/** Dispatches an action against the live store. Stable identity, safe to pass anywhere. */
export function dispatch(action: Action): void {
  gameStore.setState((state) => gameReducer(state, action), true);
}

export function useGameState(): GameState {
  return useStore(gameStore);
}

/**
 * Screen guards: hooks for screens that cannot exist without their slice.
 * They throw (into the ErrorBoundary) instead of scattering `!` assertions;
 * the reducer never routes to these screens without the data. Convention:
 * no new non-null assertions on game state - reach for these instead.
 */
export function useHero(): Hero {
  const hero = useStore(gameStore, (state) => state.hero);
  if (!hero) throw new Error("useHero rendered on a heroless screen");
  return hero;
}

export function useBattle(): BattleState {
  const battle = useStore(gameStore, (state) => state.battle);
  if (!battle) throw new Error("useBattle rendered outside a battle");
  return battle;
}

export function useWorld(): WorldState {
  const world = useStore(gameStore, (state) => state.world);
  if (!world) throw new Error("useWorld rendered before the world exists");
  return world;
}
