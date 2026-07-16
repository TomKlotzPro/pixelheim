import { useEffect, useRef } from "react";
import { gameStore } from "../state/store";
import { BattleRenderer, SCENE_H, SCENE_W } from "./battleRenderer";

function computeScale(): number {
  return Math.max(2, Math.min(4, Math.floor((window.innerWidth - 64) / SCENE_W)));
}

/** Mounts the Pixi battle scene; state flows in via store subscription. */
export function BattleSceneView() {
  const host = useRef<HTMLDivElement>(null);
  const scale = computeScale();

  useEffect(() => {
    const renderer = new BattleRenderer();
    let unsubscribe: (() => void) | null = null;
    let disposed = false;
    const boot = async () => {
      await renderer.init(host.current!, scale, gameStore.getState());
      if (disposed) return;
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
      className="battle-scene-host"
      data-testid="battle-scene"
      style={{ width: SCENE_W * scale, height: SCENE_H * scale }}
    />
  );
}
