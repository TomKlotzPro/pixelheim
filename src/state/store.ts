import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";
import type { BattleState, GameState, Hero } from "../game/types";
import type { WorldState } from "../world/types";
import { type Action, gameReducer, initialState } from "./gameReducer";
import { persistSave } from "./save";
import { setHouseTier, setSettlers, setTownTier } from "../world/maps/index";

/**
 * The game state lives in a vanilla store so anything without React (the
 * balance sim, tests) can drive the exact same game. React subscribes
 * through useGameState.
 */
export function createGameStore(state: GameState = initialState) {
  const store = createStore<GameState>(() => state);
  // Every store keeps the world mirrors coherent, not just the app singleton
  // (PIX-115): a sim or test that funds the town sees the town it funded.
  store.subscribe(syncWorldMirrors);
  syncWorldMirrors(store.getState());
  return store;
}

/** The town mirrors (PIX-91/92/34): getMap and npcsOn take only ids, so the
 *  maps module keeps tier, house tier and settlers as module variables. */
function syncWorldMirrors(state: GameState): void {
  setTownTier(state.townTier ?? 1);
  setHouseTier(state.house.tier ?? 1);
  setSettlers(state.settlers ?? []);
}

export type GameStore = ReturnType<typeof createGameStore>;

/** The one store the app plays in. */
export const gameStore = createGameStore();

// Persistence is a store concern, not a render concern: every committed state
// is written straight through (persistSave itself skips heroless states).
gameStore.subscribe(persistSave);

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
