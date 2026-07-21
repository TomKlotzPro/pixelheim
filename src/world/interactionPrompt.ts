import type { GameState } from "../game/types";
import { solidChestAt } from "./chests";
import { npcBeside } from "./npcs";
import type { Direction } from "./types";

export const FACING_DELTAS: Record<Direction, { dx: number; dy: number }> = {
  up: { dx: 0, dy: -1 },
  down: { dx: 0, dy: 1 },
  left: { dx: -1, dy: 0 },
  right: { dx: 1, dy: 0 },
};

/**
 * The one interaction-prompt rule (PIX-115). Before this module, all three
 * renderers re-implemented "idle → NPC beside (faced tile first) → unopened
 * chest on the faced tile" - and the DOM copy had already drifted (it forgot
 * the pack made the hero busy). Returns where the "!" floats, or null.
 */
export function interactionPrompt(state: GameState, mapId: string): { x: number; y: number } | null {
  const pos = state.world?.position;
  if (!pos || !state.hero || state.dialogue || state.openPanel) return null;
  const beside = npcBeside(mapId, pos.x, pos.y, pos.facing, state.worldSteps);
  if (beside) {
    const { dx, dy } = FACING_DELTAS[beside.facing];
    return { x: pos.x + dx, y: pos.y + dy };
  }
  const { dx, dy } = FACING_DELTAS[pos.facing];
  const chest = solidChestAt(mapId, pos.x + dx, pos.y + dy);
  if (chest && !(state.world?.openedChests ?? []).includes(chest.id)) {
    return { x: pos.x + dx, y: pos.y + dy };
  }
  return null;
}
