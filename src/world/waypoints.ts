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
};

export const WAYPOINTS: Waypoint[] = [
  {
    id: "town_gate",
    name: "Pixelheim Gate",
    mapId: "overworld",
    at: { x: 24, y: 21 },
    arrival: { x: 24, y: 20 },
  },
  {
    id: "mountain_gate",
    name: "The Ashen Mountain",
    mapId: "overworld",
    at: { x: 24, y: 3 },
    arrival: { x: 24, y: 4 },
  },
  {
    id: "undermountain_cave",
    name: "The Undermountain",
    mapId: "overworld",
    at: { x: 12, y: 5 },
    arrival: { x: 13, y: 5 },
  },
];

export function waypointDiscovered(waypoint: Waypoint, discovered: WorldState["discovered"]): boolean {
  return (discovered[waypoint.mapId] ?? []).includes(`${waypoint.at.x},${waypoint.at.y}`);
}
