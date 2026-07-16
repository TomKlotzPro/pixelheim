import { useEffect, useRef } from "react";
import { dispatch, gameStore } from "../state/store";
import type { Direction } from "../world/types";
import { ART, VIEW_H, VIEW_W, WorldRenderer } from "./worldRenderer";

/** Clicking an adjacent tile walks toward it, same as the DOM viewport. */
function clickTile(x: number, y: number): void {
  const pos = gameStore.getState().world?.position;
  if (!pos) return;
  const dx = x - pos.x;
  const dy = y - pos.y;
  if (Math.abs(dx) + Math.abs(dy) !== 1) return;
  const direction: Direction = dx === 1 ? "right" : dx === -1 ? "left" : dy === 1 ? "down" : "up";
  dispatch({ type: "MOVE", direction });
}

/**
 * Mounts the Pixi world renderer and bridges it to the store: state flows in
 * via subscribe, input flows out via dispatch. React owns nothing inside the
 * canvas; it only provides the host element and the lifecycle.
 */
export function PixiWorldView({ scale, mapId }: { scale: number; mapId: string }) {
  const host = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const renderer = new WorldRenderer(clickTile);
    let unsubscribe: (() => void) | null = null;
    let disposed = false;
    const boot = async () => {
      await renderer.init(host.current!, scale);
      if (disposed) return;
      renderer.update(gameStore.getState());
      unsubscribe = gameStore.subscribe((state) => renderer.update(state));
    };
    void boot();
    return () => {
      disposed = true;
      unsubscribe?.();
      renderer.destroy();
    };
  }, [scale]);

  return (
    <div
      ref={host}
      className="world-viewport"
      data-testid="world-viewport"
      data-map={mapId}
      data-renderer="pixi"
      style={{ width: VIEW_W * ART * scale, height: VIEW_H * ART * scale }}
    />
  );
}
