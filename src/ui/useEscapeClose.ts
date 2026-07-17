import { useEffect } from "react";

/**
 * Esc closes THIS panel and nothing else. Capture phase + immediate stop so
 * the panel wins over the world's keydown listener - no more pause menu
 * stacking on top of whatever you were reading (PIX-83).
 */
export function useEscapeClose(close: () => void): void {
  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopImmediatePropagation();
      close();
    };
    window.addEventListener("keydown", handler, true);
    return () => window.removeEventListener("keydown", handler, true);
  }, [close]);
}
