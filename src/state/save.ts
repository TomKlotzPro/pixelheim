import type { GameState } from "../game/types";
import { initialState } from "./gameReducer";

const SAVE_KEY = "pixelheim-save-v1";
const CODE_PREFIX = "PXH1.";

/** Validates a parsed save and rebases it on the current initialState shape. */
function normalizeSave(parsed: unknown): GameState | null {
  if (!parsed || typeof parsed !== "object" || !(parsed as GameState).hero) return null;
  // Never resume mid-battle or mid-menu; wake up back in town.
  return { ...initialState, ...(parsed as GameState), screen: "hub", battle: null, inventoryOpen: false };
}

export function loadSave(): GameState | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    return normalizeSave(JSON.parse(raw));
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

/** Serializes a save into a copy-pastable code, e.g. to move progress between devices. */
export function encodeSaveCode(state: GameState): string {
  const bytes = new TextEncoder().encode(JSON.stringify(state));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return CODE_PREFIX + btoa(binary);
}

/** Parses a save code produced by encodeSaveCode. Returns null on anything invalid. */
export function decodeSaveCode(code: string): GameState | null {
  try {
    const trimmed = code.trim();
    if (!trimmed.startsWith(CODE_PREFIX)) return null;
    const binary = atob(trimmed.slice(CODE_PREFIX.length));
    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    return normalizeSave(JSON.parse(new TextDecoder().decode(bytes)));
  } catch {
    return null;
  }
}
