import { useEffect, useRef } from "react";
import { carriedWeight, carryCapacity } from "../game/character";
import { dispatch, useGameState, useHero, useWorld } from "../state/store";
import { paintMap, tileColor } from "../world/mapColors";
import { getMap } from "../world/maps";
import { waypointDiscovered, WAYPOINTS } from "../world/waypoints";

const TILE_PX = 8;

type MapScreenProps = {
  onClose: () => void;
};

/** The fog-of-war world map: what you have seen, and where you can jump. */
export function MapScreen({ onClose }: MapScreenProps) {
  const state = useGameState();
  const hero = useHero();
  const world = useWorld();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const overworld = getMap("overworld");
  const encumbered = carriedWeight(state.inventory, state.gear, state.equipped) > carryCapacity(hero, state.gear, state.equipped);

  useEffect(() => {
    const ctx = canvasRef.current?.getContext("2d");
    if (!ctx) return;
    paintMap(ctx, overworld, world.discovered, TILE_PX);
    // discovered waypoints get a marker
    for (const waypoint of WAYPOINTS) {
      if (!waypointDiscovered(waypoint, world.discovered)) continue;
      ctx.fillStyle = "#e8c34a";
      ctx.fillRect(waypoint.at.x * TILE_PX - 2, waypoint.at.y * TILE_PX - 2, TILE_PX + 4, TILE_PX + 4);
      ctx.fillStyle = "#2a2118";
      ctx.fillRect(waypoint.at.x * TILE_PX, waypoint.at.y * TILE_PX, TILE_PX, TILE_PX);
    }
    // the hero, if they are on this map
    if (world.position.mapId === overworld.id) {
      ctx.fillStyle = "#f0f0e8";
      ctx.fillRect(world.position.x * TILE_PX - 1, world.position.y * TILE_PX - 1, TILE_PX + 2, TILE_PX + 2);
    }
  }, [overworld, world]);

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel map-panel" onClick={(e) => e.stopPropagation()} data-testid="map-screen">
        <div className="inventory-header">
          <h2>The Ashenreach</h2>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <canvas
          ref={canvasRef}
          className="map-canvas"
          width={overworld.width * TILE_PX}
          height={overworld.height * TILE_PX}
        />
        <div className="map-waypoints">
          {WAYPOINTS.map((waypoint) => {
            const known = waypointDiscovered(waypoint, world.discovered);
            const here =
              world.position.mapId === waypoint.mapId &&
              world.position.x === waypoint.arrival.x &&
              world.position.y === waypoint.arrival.y;
            return (
              <div key={waypoint.id} className="options-row">
                <span className={known ? "" : "options-note"}>{known ? waypoint.name : "Unknown"}</span>
                <button
                  className="btn btn-small"
                  disabled={!known || here || encumbered}
                  title={encumbered ? "Too heavy to travel" : undefined}
                  onClick={() => {
                    dispatch({ type: "FAST_TRAVEL", waypointId: waypoint.id });
                    onClose();
                  }}
                >
                  {here ? "Here" : "Travel"}
                </button>
              </div>
            );
          })}
        </div>
        <p className="options-footer">
          {encumbered ? "Too heavy to travel. Lighten the pack." : "Seen once, reachable forever."}
        </p>
      </div>
    </div>
  );
}

/** The corner mini-map: the hero's surroundings, fog included. */
export function MiniMap() {
  const world = useWorld();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const WINDOW = 21;
  const PX = 4;

  useEffect(() => {
    const ctx = canvasRef.current?.getContext("2d");
    if (!ctx) return;
    const map = getMap(world.position.mapId);
    const seen = new Set(world.discovered[map.id] ?? []);
    const half = Math.floor(WINDOW / 2);
    ctx.fillStyle = "#0b0c10";
    ctx.fillRect(0, 0, WINDOW * PX, WINDOW * PX);
    for (let dy = -half; dy <= half; dy++) {
      for (let dx = -half; dx <= half; dx++) {
        const x = world.position.x + dx;
        const y = world.position.y + dy;
        if (x < 0 || y < 0 || x >= map.width || y >= map.height) continue;
        if (!seen.has(`${x},${y}`)) continue;
        ctx.fillStyle = tileColor(map.tiles[y][x]);
        ctx.fillRect((dx + half) * PX, (dy + half) * PX, PX, PX);
      }
    }
    // the hero, dead center
    ctx.fillStyle = "#f0f0e8";
    ctx.fillRect(half * PX, half * PX, PX, PX);
  }, [world]);

  return <canvas ref={canvasRef} className="mini-map" width={WINDOW * PX} height={WINDOW * PX} aria-hidden="true" />;
}
