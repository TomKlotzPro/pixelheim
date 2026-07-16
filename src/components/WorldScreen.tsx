import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import type { Action } from "../state/gameReducer";
import { getMap } from "../world/maps/demo";
import { TILES } from "../world/tiles";
import type { Direction } from "../world/types";
import { Sprite } from "./Sprite";

export const TILE_PX = 32;
const VIEW_W = 15;
const VIEW_H = 11;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

type WorldScreenProps = {
  state: GameState;
  dispatch: (action: Action) => void;
};

export function WorldScreen({ state, dispatch }: WorldScreenProps) {
  const world = state.world!;
  const map = getMap(world.mapId);
  const heroSprite = ROLES[state.hero?.roleId ?? "warrior"].sprite;

  const cameraX = clamp(world.x - Math.floor(VIEW_W / 2), 0, Math.max(0, map.width - VIEW_W));
  const cameraY = clamp(world.y - Math.floor(VIEW_H / 2), 0, Math.max(0, map.height - VIEW_H));

  const clickTile = (x: number, y: number) => {
    const dx = x - world.x;
    const dy = y - world.y;
    if (Math.abs(dx) + Math.abs(dy) !== 1) return;
    const direction: Direction = dx === 1 ? "right" : dx === -1 ? "left" : dy === 1 ? "down" : "up";
    dispatch({ type: "MOVE", direction });
  };

  return (
    <div className="screen world-screen">
      <div
        className="world-viewport"
        data-testid="world-viewport"
        style={{ width: VIEW_W * TILE_PX, height: VIEW_H * TILE_PX }}
      >
        <div
          className="world-map"
          style={{
            width: map.width * TILE_PX,
            height: map.height * TILE_PX,
            transform: `translate(${-cameraX * TILE_PX}px, ${-cameraY * TILE_PX}px)`,
          }}
        >
          {map.tiles.map((row, y) =>
            row.map((tile, x) => (
              <div
                key={`${x},${y}`}
                className="world-tile"
                onClick={() => clickTile(x, y)}
                style={{
                  left: x * TILE_PX,
                  top: y * TILE_PX,
                  backgroundImage: `url(${import.meta.env.BASE_URL}sprites/${TILES[tile].sprite}.png)`,
                }}
              />
            )),
          )}
          <div
            className={`world-hero facing-${world.facing}`}
            data-testid="world-hero"
            data-pos={`${world.x},${world.y}`}
            style={{ left: world.x * TILE_PX, top: world.y * TILE_PX }}
          >
            <Sprite name={heroSprite} size={TILE_PX} alt="hero" />
          </div>
        </div>
      </div>
      <p className="world-hint">Arrows / WASD to move, or tap an adjacent tile. Find the door.</p>
    </div>
  );
}
