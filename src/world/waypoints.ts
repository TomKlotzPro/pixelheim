import type { WorldState } from "./types";

/**
 * Fast-travel destinations. A waypoint unlocks the moment its marker tile has
 * been SEEN (it is in world.discovered) - exploration is the gate, walking
 * back is optional. `at` is the marker on the map; `arrival` is the safe
 * adjacent tile travel drops you on (never the portal itself).
 */
export type Waypoint = {
  id: string;
  name: string;
  mapId: string;
  /** The marker tile that must be discovered. */
  at: { x: number; y: number };
  /** Where travel puts you. */
  arrival: { x: number; y: number };
  /** Some posts need someone to run them: the settler id that staffs this stop (PIX-92). */
  requiresSettler?: string;
};

export const WAYPOINTS: Waypoint[] = [
  {
    id: "town_gate",
    name: "Pixelheim Gate",
    mapId: "overworld",
    at: { x: 48, y: 42 },
    arrival: { x: 48, y: 40 },
  },
  {
    id: "mountain_gate",
    name: "The Ashen Mountain",
    mapId: "overworld",
    at: { x: 48, y: 6 },
    arrival: { x: 48, y: 8 },
  },
  {
    id: "deepwood_pass",
    name: "The Deepwood Pass",
    mapId: "overworld",
    at: { x: 94, y: 32 },
    arrival: { x: 92, y: 32 },
  },
  {
    id: "mirefen_pass",
    name: "The Mirefen Pass",
    mapId: "overworld",
    at: { x: 0, y: 32 },
    arrival: { x: 2, y: 32 },
  },
  {
    id: "undermountain_cave",
    name: "The Undermountain",
    mapId: "overworld",
    at: { x: 24, y: 10 },
    arrival: { x: 26, y: 10 },
  },
  {
    id: "town_square",
    name: "Pixelheim Square",
    mapId: "town",
    at: { x: 28, y: 15 },
    arrival: { x: 28, y: 15 },
    requiresSettler: "settler_wren",
  },
];

export function waypointDiscovered(waypoint: Waypoint, discovered: WorldState["discovered"]): boolean {
  return (discovered[waypoint.mapId] ?? []).includes(`${waypoint.at.x},${waypoint.at.y}`);
}

/** Discovered AND staffed: a settler-run post only works once they moved in. */
export function waypointUsable(waypoint: Waypoint, discovered: WorldState["discovered"], settlers: string[]): boolean {
  if (!waypointDiscovered(waypoint, discovered)) return false;
  return !waypoint.requiresSettler || settlers.includes(waypoint.requiresSettler);
}
