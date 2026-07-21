import { PanelShell } from "./PanelShell";
import { useEffect, useRef } from "react";
import { carriedWeight, carryCapacity } from "../../game/hero/character";
import { dispatch, useGameState, useHero, useWorld } from "../../state/store";
import { paintMap, tileColor } from "../../world/mapColors";
import { getMap } from "../../world/maps/index";
import { signsOn } from "../../world/signs";
import { waypointDiscovered, waypointUsable, WAYPOINTS } from "../../world/waypoints";

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
  const encumbered =
    carriedWeight(state.inventory, state.gear, state.equipped) > carryCapacity(hero, state.gear, state.equipped);

  useEffect(() => {
    const ctx = canvasRef.current?.getContext("2d");
    if (!ctx) return;
    paintMap(ctx, overworld, world.discovered, TILE_PX);
    // discovered waypoints get a marker
    for (const waypoint of WAYPOINTS) {
      // the canvas paints the overworld: only its own waypoints get markers
      if (waypoint.mapId !== "overworld" || !waypointDiscovered(waypoint, world.discovered)) continue;
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
    <PanelShell onClose={onClose} className="map-panel" testId="map-screen" title="The Ashenreach">
      <canvas
        ref={canvasRef}
        className="map-canvas"
        width={overworld.width * TILE_PX}
        height={overworld.height * TILE_PX}
      />
      <div className="map-waypoints">
        {WAYPOINTS.map((waypoint) => {
          const known = waypointDiscovered(waypoint, world.discovered);
          const usable = waypointUsable(waypoint, world.discovered, state.settlers ?? []);
          const here =
            world.position.mapId === waypoint.mapId &&
            world.position.x === waypoint.arrival.x &&
            world.position.y === waypoint.arrival.y;
          return (
            <div key={waypoint.id} className="options-row">
              <span className={known ? "" : "options-note"}>{known ? waypoint.name : "Unknown"}</span>
              <button
                className="btn btn-small"
                disabled={!usable || here || encumbered}
                title={
                  encumbered
                    ? "Too heavy to travel"
                    : known && !usable
                      ? "The post stands empty - it needs its stablemaster"
                      : undefined
                }
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
    </PanelShell>
  );
}

/** The corner mini-map: the hero's surroundings, fog included. */
export function MiniMap() {
  const world = useWorld();
  const house = useGameState().house;
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
    // landmarks: gold for the craft stations, green for your house
    for (const sign of signsOn(map.id, house.owned)) {
      const dx = sign.x - world.position.x;
      const dy = sign.y - world.position.y;
      if (Math.abs(dx) > half || Math.abs(dy) > half) continue;
      ctx.fillStyle = sign.icon
        ? "#e8c34a"
        : sign.label === "HOME" || sign.label === "FOR SALE"
          ? "#4ec04e"
          : "#c8a8e8";
      ctx.fillRect((dx + half) * PX, (dy + half) * PX, PX, PX);
    }
    // the hero, dead center
    ctx.fillStyle = "#f0f0e8";
    ctx.fillRect(half * PX, half * PX, PX, PX);
  }, [world, house.owned]);

  return <canvas ref={canvasRef} className="mini-map" width={WINDOW * PX} height={WINDOW * PX} aria-hidden="true" />;
}
