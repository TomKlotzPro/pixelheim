import { useEffect, useRef, useState } from "react";
import { dispatch, gameStore } from "../../state/store";
import type { Direction } from "../../world/types";
import { ART } from "./voxelData";
import { VIEW_H, VIEW_W, VoxelWorldRenderer } from "./voxelWorldRenderer";

/** Clicking an adjacent tile walks toward it, same as the other renderers. */
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
 * Mounts the voxel world renderer and bridges it to the store, exactly like
 * PixiWorldView: state flows in via subscribe, input flows out via dispatch.
 * React owns nothing inside the canvas.
 */
export function VoxelWorldView({ scale, mapId }: { scale: number; mapId: string }) {
  const host = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const renderer = new VoxelWorldRenderer(clickTile);
    let unsubscribe: (() => void) | null = null;
    let disposed = false;
    // Same boot retry as the Pixi view: a flaky fetch should not strand a
    // black canvas (PIX-100).
    const boot = async (attempt = 0): Promise<void> => {
      try {
        await renderer.init(host.current!, scale);
        if (disposed) return;
        renderer.update(gameStore.getState());
        unsubscribe = gameStore.subscribe((state) => renderer.update(state));
        setReady(true);
      } catch (error) {
        if (disposed || attempt >= 4) {
          console.error("voxel renderer failed to boot", error);
          return;
        }
        await new Promise((resolve) => setTimeout(resolve, 400 * 2 ** attempt));
        if (!disposed) await boot(attempt + 1);
      }
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
      data-renderer="voxel"
      style={{ width: VIEW_W * ART * scale, height: VIEW_H * ART * scale, position: "relative" }}
    >
      {!ready && (
        <div className="world-loading" aria-live="polite">
          <span className="world-loading-text">
            Loading
            <span className="loading-dots" />
          </span>
        </div>
      )}
    </div>
  );
}
