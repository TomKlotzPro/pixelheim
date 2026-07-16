import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";
import type { GameState } from "../game/types";
import { type Action, gameReducer, initialState } from "./gameReducer";

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

/** Dispatches an action against the live store. Stable identity, safe to pass anywhere. */
export function dispatch(action: Action): void {
  gameStore.setState((state) => gameReducer(state, action), true);
}

export function useGameState(): GameState {
  return useStore(gameStore);
}
