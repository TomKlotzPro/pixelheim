import type { GameState } from "../game/types";
import { initialState } from "./gameReducer";

const SAVE_KEY = "pixelheim-save-v1";

export function loadSave(): GameState | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as GameState;
    if (!parsed.hero) return null;
    // Never resume mid-battle or mid-menu; wake up back in town.
    return { ...initialState, ...parsed, screen: "hub", battle: null, inventoryOpen: false };
  } catch {
    return null;
  }
}

export function persistSave(state: GameState): void {
  if (!state.hero) return;
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(state));
  } catch {
    // Storage full or unavailable; playing without saves is fine.
  }
}

export function clearSave(): void {
  localStorage.removeItem(SAVE_KEY);
}

export function hasSave(): boolean {
  return loadSave() !== null;
}
