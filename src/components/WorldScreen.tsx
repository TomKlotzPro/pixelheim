import { useEffect, useState } from "react";
import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import type { Action } from "../state/gameReducer";
import { getMap } from "../world/maps";
import { regionAt } from "../world/parseMap";
import { TILES } from "../world/tiles";
import type { Direction, TileId } from "../world/types";

/** Must mirror the reducer's encounter terrain: only these tiles grow tufts. */
const WILD_TILES = new Set<TileId>(["grass", "forest", "marsh", "ash", "sand"]);
import { Sprite } from "./Sprite";
import { WorldHud } from "./WorldHud";

const ART_PX = 16;
const VIEW_W = 15;
const VIEW_H = 11;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** Largest integer art scale that fits the window; pixels stay crisp. */
function computeScale(): number {
  const availW = window.innerWidth - 48;
  const availH = window.innerHeight - 150;
  return Math.max(2, Math.min(Math.floor(availW / (VIEW_W * ART_PX)), Math.floor(availH / (VIEW_H * ART_PX))));
}

function useTileScale(): number {
  const [scale, setScale] = useState(computeScale);
  useEffect(() => {
    const onResize = () => setScale(computeScale());
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);
  return scale;
}

type WorldScreenProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

export function WorldScreen({ state, dispatch }: WorldScreenProps) {
  const world = state.world!.position;
  const map = getMap(world.mapId);
  const heroSprite = ROLES[state.hero?.roleId ?? "warrior"].sprite;
  const tilePx = ART_PX * useTileScale();

  // Maps smaller than the viewport are centered; larger ones scroll, clamped at edges.
  const cameraX =
    map.width <= VIEW_W
      ? -Math.floor((VIEW_W - map.width) / 2)
      : clamp(world.x - Math.floor(VIEW_W / 2), 0, map.width - VIEW_W);
  const cameraY =
    map.height <= VIEW_H
      ? -Math.floor((VIEW_H - map.height) / 2)
      : clamp(world.y - Math.floor(VIEW_H / 2), 0, map.height - VIEW_H);

  const clickTile = (x: number, y: number) => {
    const dx = x - world.x;
    const dy = y - world.y;
    if (Math.abs(dx) + Math.abs(dy) !== 1) return;
    const direction: Direction = dx === 1 ? "right" : dx === -1 ? "left" : dy === 1 ? "down" : "up";
    dispatch({ type: "MOVE", direction });
  };

  return (
    <div className="screen world-screen">
      {state.hero && <WorldHud state={state} dispatch={dispatch} />}
      {state.hero && !state.introSeen && (
        <div className="overlay">
          <div className="panel intro-panel">
            <p>The mountain burned once. The village rebuilt. The monsters never left.</p>
            <p>Pixelheim needs someone stubborn enough to climb the Ashen Mountain.</p>
            <p>The gate is south. The merchant buys and sells. The inn is warm. Good luck.</p>
            <button className="btn btn-primary" onClick={() => dispatch({ type: "DISMISS_INTRO" })}>
              Set out
            </button>
          </div>
        </div>
      )}
      <div
        className="world-viewport"
        data-testid="world-viewport"
        data-map={map.id}
        style={{ width: VIEW_W * tilePx, height: VIEW_H * tilePx }}
      >
        <div
          className="world-map"
          style={{
            width: map.width * tilePx,
            height: map.height * tilePx,
            transform: `translate(${-cameraX * tilePx}px, ${-cameraY * tilePx}px)`,
          }}
        >
          {map.tiles.map((row, y) =>
            row.map((tile, x) => {
              // Dangerous ground is visible: wild-region tiles grow dark tufts.
              const dangerous = WILD_TILES.has(tile) && regionAt(map, x, y) !== null;
              const terrain = `url(${import.meta.env.BASE_URL}sprites/${TILES[tile].sprite}.png)`;
              const overlay = `url(${import.meta.env.BASE_URL}sprites/overlay_wild.png)`;
              return (
                <div
                  key={`${x},${y}`}
                  className="world-tile"
                  data-danger={dangerous || undefined}
                  onClick={() => clickTile(x, y)}
                  style={{
                    left: x * tilePx,
                    top: y * tilePx,
                    width: tilePx,
                    height: tilePx,
                    backgroundSize: `${tilePx}px ${tilePx}px`,
                    backgroundImage: dangerous ? `${overlay}, ${terrain}` : terrain,
                  }}
                />
              );
            }),
          )}
          <div
            className={`world-hero facing-${world.facing}`}
            data-testid="world-hero"
            data-pos={`${world.x},${world.y}`}
            style={{ left: world.x * tilePx, top: world.y * tilePx, width: tilePx, height: tilePx }}
          >
            <Sprite name={heroSprite} size={tilePx} alt="hero" />
          </div>
        </div>
      </div>
      {state.worldMessage ? (
        <p className="world-hint world-message">{state.worldMessage}</p>
      ) : (
        <p className="world-hint">Arrows / WASD to move, or tap an adjacent tile. I opens the inventory.</p>
      )}
    </div>
  );
}
