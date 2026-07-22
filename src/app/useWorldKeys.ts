import { useEffect } from "react";
import type { GameState } from "../game/types";
import { dispatch, gameStore } from "../state/store";
import type { Direction } from "../world/types";
import type { Settings } from "./settings";

/** Arrows always move regardless of custom bindings. */
const ARROW_DIRECTIONS: Record<string, Direction> = {
  ArrowUp: "up",
  ArrowDown: "down",
  ArrowLeft: "left",
  ArrowRight: "right",
};

/**
 * The world keyboard: Escape peels back one layer at a time (map, panel,
 * dialogue, pause), the custom bindings walk and interact, J calls the
 * journal, M the map. Lived inline in App for 400 lines' worth of company.
 */
export function useWorldKeys(
  state: GameState,
  settings: Settings,
  paused: boolean,
  setPaused: (fn: (open: boolean) => boolean) => void,
  mapOpen: boolean,
  setMapOpen: (fn: (open: boolean) => boolean) => void,
): void {
  useEffect(() => {
    if (state.screen !== "world") return;
    const { bindings } = settings;
    const onKeyDown = (event: KeyboardEvent) => {
      // Escape peels back one layer at a time: menus first, then the pause
      // screen. Fresh state via the store: this listener outlives renders.
      if (event.key === "Escape") {
        const now = gameStore.getState();
        if (mapOpen) setMapOpen(() => false);
        else if (now.openPanel === "storage") dispatch({ type: "TOGGLE_STORAGE" });
        else if (now.openPanel === "shop") dispatch({ type: "TOGGLE_SHOP" });
        else if (now.openPanel === "inventory") dispatch({ type: "TOGGLE_INVENTORY" });
        else if (now.dialogue) dispatch({ type: "ADVANCE_DIALOGUE" });
        else if (!now.hero) dispatch({ type: "EXIT_WORLD" });
        else setPaused((open) => !open);
        return;
      }
      if (paused) return;
      if (event.code === bindings.inventory) {
        dispatch({ type: "TOGGLE_INVENTORY" });
        return;
      }
      if (event.code === "KeyJ" && state.hero) {
        window.dispatchEvent(new CustomEvent("pixelheim:journal"));
        return;
      }
      if (event.code === bindings.map && state.hero) {
        setMapOpen((open) => !open);
        return;
      }
      if (mapOpen) return;
      // Enter and Space always interact, on top of the custom binding.
      if (event.code === bindings.interact || event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        dispatch({ type: "INTERACT" });
        return;
      }
      const direction =
        ARROW_DIRECTIONS[event.key] ??
        (event.code === bindings.up
          ? "up"
          : event.code === bindings.down
            ? "down"
            : event.code === bindings.left
              ? "left"
              : event.code === bindings.right
                ? "right"
                : null);
      if (!direction) return;
      event.preventDefault();
      dispatch({ type: "MOVE", direction });
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [state.screen, settings, paused, mapOpen, state.hero, setPaused, setMapOpen]);
}
